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
    final response = await httpClient.get(uri);
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
