import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Whether [text] looks like an absolute http(s) URL worth treating as a
/// link paste - the "is this plain-text clipboard paste actually a link"
/// detector `clipboard_paste_service.dart` needs and this codebase doesn't
/// otherwise have (confirmed: no `isUrl`/`isValidUrl` helper exists
/// anywhere else in `lib/`).
bool looksLikeUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null) return false;
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
}

/// A regex-only scrape of [pageUri]'s HTML for a page title and preview
/// image - same single-targeted-regex style as `image_file_formats.dart`'s
/// `extractImageUrlFromHtml`, not a real HTML parser (deliberately - see
/// Part 94's plan). Returns `(null, null)` on any failure (network error,
/// non-200, non-HTML response) rather than throwing, matching this
/// codebase's established "skip, don't crash" convention for best-effort
/// remote fetches (`fetchImageBytes`).
Future<({String? title, Uri? imageUri})> fetchLinkPreviewMetadata(
  Uri pageUri, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.get(
      pageUri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      },
    );
    if (response.statusCode != 200) return (title: null, imageUri: null);
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.isNotEmpty && !contentType.contains('html')) {
      return (title: null, imageUri: null);
    }

    final html = response.body;
    final rawTitle =
        _metaContent(html, 'og:title') ?? _metaContent(html, 'twitter:title');
    final title = rawTitle != null ? _unescapeHtml(rawTitle) : _titleTag(html);

    var imageUri =
        _resolveMetaImage(html, 'og:image', pageUri) ??
        _resolveMetaImage(html, 'twitter:image', pageUri);
    imageUri ??= pageUri.resolve('/favicon.ico');

    return (title: title, imageUri: imageUri);
  } catch (_) {
    return (title: null, imageUri: null);
  } finally {
    if (client == null) httpClient.close();
  }
}

Uri? _resolveMetaImage(String html, String property, Uri pageUri) {
  final raw = _metaContent(html, property);
  if (raw == null || raw.isEmpty) return null;
  final decoded = _unescapeHtml(raw);
  try {
    return pageUri.resolve(decoded);
  } catch (_) {
    return null;
  }
}

/// Finds `<meta property="$property" content="...">` (or `name=` in place
/// of `property=`), checking both attribute orders since real-world pages
/// vary (`content` before or after `property`/`name`).
String? _metaContent(String html, String property) {
  final propertyFirst = RegExp(
    '<meta[^>]+(?:property|name)=["\']${RegExp.escape(property)}["\']'
    '[^>]*content=["\']([^"\']*)["\']',
    caseSensitive: false,
  ).firstMatch(html);
  if (propertyFirst != null) return propertyFirst.group(1);

  final contentFirst = RegExp(
    '<meta[^>]+content=["\']([^"\']*)["\']'
    '[^>]*(?:property|name)=["\']${RegExp.escape(property)}["\']',
    caseSensitive: false,
  ).firstMatch(html);
  return contentFirst?.group(1);
}

String? _titleTag(String html) {
  final match = RegExp(
    r'<title[^>]*>([^<]*)</title>',
    caseSensitive: false,
  ).firstMatch(html);
  final title = match?.group(1)?.trim();
  return (title == null || title.isEmpty) ? null : _unescapeHtml(title);
}

/// Decodes the handful of HTML entities that commonly appear in a page's
/// title or an image URL's query string - no new dependency, same
/// "regex-only" scope the rest of this file keeps to.
String _unescapeHtml(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

/// Decodes [bytes] and center-crops/resizes it to a [size] x [size]
/// square, re-encoded as PNG - turns a fetched (usually landscape) preview
/// image into the small square thumbnail a link clip shows. Returns null
/// if [bytes] can't be decoded as an image at all (e.g. the "image" URL
/// was actually an HTML error page, or a favicon guess 404'd).
Uint8List? squareThumbnailBytes(Uint8List bytes, {int size = 128}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }
    final square = img.copyResizeCropSquare(decoded, size: size);
    return Uint8List.fromList(img.encodePng(square));
  } catch (_) {
    return null;
  }
}
