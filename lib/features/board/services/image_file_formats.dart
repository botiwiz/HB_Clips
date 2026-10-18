import 'dart:async';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

/// Every image format this app knows how to read off the OS clipboard or a
/// drag-and-drop payload, mapped to the file extension used when writing it
/// to local blob storage. Shared by clipboard paste and drag-and-drop so
/// both recognize exactly the same set of image types.
const imageFileFormats = <SimpleFileFormat, String>{
  Formats.png: '.png',
  Formats.jpeg: '.jpg',
  Formats.gif: '.gif',
  Formats.webp: '.webp',
  Formats.bmp: '.bmp',
  Formats.tiff: '.tiff',
};

/// Returns the first format in [imageFileFormats] that [reader] can
/// provide, or null if it doesn't look like an image at all.
SimpleFileFormat? matchImageFormat(DataReader reader) {
  for (final format in imageFileFormats.keys) {
    if (reader.canProvide(format)) return format;
  }
  return null;
}

/// `getFile` is callback-based even on the otherwise-`Future`-based
/// `DataReader` API, so this wraps it the same way the super_clipboard
/// example app does. Works for both a clipboard read and a drag-and-drop
/// item's reader - `ClipboardReader` and `DropItem.dataReader` are both a
/// `DataReader` under the hood. `getFile`'s default `allowVirtualFiles:
/// true` is what makes this work for a browser-dragged image too (no local
/// file exists yet - the OS/browser generates one on demand).
Future<Uint8List?> readImageFileBytes(DataReader reader, FileFormat format) {
  final completer = Completer<Uint8List?>();
  final progress = reader.getFile(format, (file) async {
    try {
      completer.complete(await file.readAll());
    } catch (error) {
      completer.completeError(error);
    }
  }, onError: completer.completeError);
  if (progress == null) completer.complete(null);
  return completer.future;
}

/// Tries `Formats.uri` first (an exact URL, when the source app provides
/// one), then falls back to [extractImageUrlFromHtml] against
/// `Formats.htmlText` - covers a cross-origin web image (Pinterest,
/// Instagram, a Google Images result, any page's hover/preview image) that
/// has no raw image bytes on the drag at all, only a link to fetch.
Future<Uri?> matchImageUrl(DataReader reader) async {
  if (reader.canProvide(Formats.uri)) {
    final named = await _readValue(reader, Formats.uri);
    if (named?.uri != null) return named!.uri;
  }
  if (reader.canProvide(Formats.htmlText)) {
    final html = await _readValue(reader, Formats.htmlText);
    if (html != null) {
      final uri = extractImageUrlFromHtml(html);
      if (uri != null) return uri;
    }
  }
  return null;
}

/// Attribute names that can hold an `<img>`'s real image URL, checked in
/// this priority order - a lazy-loading/search-result page (Google Images
/// chief among them) very often puts a tiny placeholder or `data:` URI in
/// plain `src` and the actual full-resolution source URL in one of these
/// instead.
const _imageUrlAttributes = ['data-iurl', 'data-src', 'data-original', 'src'];

/// A known thumbnail-only CDN host - a URL found there is kept only as a
/// last resort (see [extractImageUrlFromHtml]), since it's reachable but
/// deliberately low-resolution, not the image the user meant to drag.
bool _isThumbnailHost(String host) =>
    host.endsWith('gstatic.com') && host.contains('encrypted-tbn');

/// Pulls the best candidate image URL out of an HTML snippet - the shape
/// browsers attach to a dragged/copied `<img>` element. Scans every
/// `<img>` tag, and within each one tries [_imageUrlAttributes] in
/// priority order, skipping `data:` URIs entirely (never fetchable over
/// HTTP) and anything that doesn't parse as an absolute URL. A candidate
/// on a known thumbnail CDN ([_isThumbnailHost]) is remembered but not
/// returned immediately - the first non-thumbnail candidate found (in any
/// tag) wins instead, falling back to the thumbnail only if nothing better
/// turned up anywhere in the snippet.
Uri? extractImageUrlFromHtml(String html) {
  final imgTags = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html);

  Uri? thumbnailFallback;
  for (final imgTag in imgTags) {
    final tag = imgTag.group(0)!;
    for (final attr in _imageUrlAttributes) {
      final match = RegExp(
        '$attr=["\']([^"\']+)["\']',
        caseSensitive: false,
      ).firstMatch(tag);
      if (match == null) continue;
      final raw = match.group(1)!;
      if (raw.startsWith('data:')) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasScheme) continue;
      if (_isThumbnailHost(uri.host)) {
        thumbnailFallback ??= uri;
        continue;
      }
      return uri;
    }
  }
  return thumbnailFallback;
}

/// `getValue` is callback-based (same shape as `getFile`, see
/// [readImageFileBytes]'s doc comment) - this wraps it the same way.
Future<T?> _readValue<T extends Object>(
  DataReader reader,
  ValueFormat<T> format,
) {
  final completer = Completer<T?>();
  final progress = reader.getValue<T>(
    format,
    (value) => completer.complete(value),
    onError: completer.completeError,
  );
  if (progress == null) completer.complete(null);
  return completer.future;
}
