import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _mimeToExtension = {
  'image/png': '.png',
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/bmp': '.bmp',
  'image/tiff': '.tiff',
};

String extensionForContentType(String? contentType) {
  if (contentType == null) return '';
  final mime = contentType.split(';').first.trim().toLowerCase();
  return _mimeToExtension[mime] ?? '';
}

String? extensionForUrl(Uri uri) {
  final path = uri.path.toLowerCase();
  for (final ext in _mimeToExtension.values.toSet()) {
    if (path.endsWith(ext)) return ext;
  }
  return null;
}

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Headers for fetching [uri]'s bytes. A browser-like User-Agent is always
/// sent - image CDNs that only expect to serve embedded page content (not
/// direct requests) commonly 403 a request with no User-Agent at all, same
/// reasoning `link_preview_service.dart` already applies to its own
/// best-effort remote fetch. A `Referer` is added only for Google's own
/// image-serving hosts (`gstatic.com`/`google.com`, covers both the
/// `encrypted-tbn*.gstatic.com` thumbnail CDN and a Google Images result's
/// full-resolution source host) - some of those specifically check for it,
/// but sending an unrelated Referer to an arbitrary third-party site risks
/// tripping a hotlink guard that would otherwise allow a referer-less
/// request through.
Map<String, String> _headersFor(Uri uri) {
  final headers = {'User-Agent': _browserUserAgent, 'Accept': 'image/*,*/*;q=0.8'};
  final host = uri.host.toLowerCase();
  if (host.endsWith('gstatic.com') || host.endsWith('google.com')) {
    headers['Referer'] = 'https://www.google.com/';
  }
  return headers;
}

/// Fetches a remote image found on a browser's drag payload as raw bytes,
/// for the same bytes+extension -> addImageClipFromBytes pipeline local
/// files and clipboard images already use. Returns null on any failure
/// (network error, non-200, empty body) rather than throwing - matches
/// this codebase's existing "skip one bad item, don't fail the whole
/// operation" philosophy (see pur_reader.dart's unrecoverable-image
/// handling). [client] is injectable for tests
/// (package:http/testing.dart's MockClient) - a real Client is created and
/// closed per call otherwise.
Future<({Uint8List bytes, String extension})?> fetchImageBytes(
  Uri uri, {
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.get(uri, headers: _headersFor(uri));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    var extension = extensionForContentType(response.headers['content-type']);
    if (extension.isEmpty) extension = extensionForUrl(uri) ?? '.png';
    return (bytes: response.bodyBytes, extension: extension);
  } catch (_) {
    return null;
  } finally {
    if (client == null) httpClient.close();
  }
}
