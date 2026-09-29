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
  final progress = reader.getFile(
    format,
    (file) async {
      try {
        completer.complete(await file.readAll());
      } catch (error) {
        completer.completeError(error);
      }
    },
    onError: completer.completeError,
  );
  if (progress == null) completer.complete(null);
  return completer.future;
}

/// Tries `Formats.uri` first (an exact URL, when the source app provides
/// one), then falls back to the first `<img src="...">` found in
/// `Formats.htmlText` - covers a cross-origin web image (Pinterest,
/// Instagram, any page's hover/preview image) that has no raw image bytes
/// on the drag at all, only a link to fetch.
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

/// Pulls the first `<img src="...">` (single or double-quoted) out of an
/// HTML snippet - the shape browsers attach to a dragged/copied `<img>`
/// element.
Uri? extractImageUrlFromHtml(String html) {
  final match = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) return null;
  return Uri.tryParse(match.group(1)!);
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
