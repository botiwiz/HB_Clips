import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/remote_image_fetch_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('extensionForContentType', () {
    test('maps known mime types', () {
      expect(extensionForContentType('image/png'), '.png');
      expect(extensionForContentType('image/jpeg; charset=binary'), '.jpg');
    });

    test('unknown or missing content type returns empty', () {
      expect(extensionForContentType('application/octet-stream'), '');
      expect(extensionForContentType(null), '');
    });
  });

  group('extensionForUrl', () {
    test('matches a known extension in the path', () {
      expect(
        extensionForUrl(Uri.parse('https://example.com/pic.jpg')),
        '.jpg',
      );
    });

    test('returns null when the path has no recognized extension', () {
      expect(
        extensionForUrl(Uri.parse('https://example.com/pic')),
        isNull,
      );
    });
  });

  group('fetchImageBytes', () {
    final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);

    test('returns bytes and extension from content-type on a 200', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          fakeBytes,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      final result = await fetchImageBytes(
        Uri.parse('https://example.com/pic'),
        client: client,
      );
      expect(result, isNotNull);
      expect(result!.bytes, fakeBytes);
      expect(result.extension, '.png');
    });

    test('falls back to the URL extension when content-type is unknown', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(fakeBytes, 200);
      });
      final result = await fetchImageBytes(
        Uri.parse('https://example.com/pic.jpg'),
        client: client,
      );
      expect(result!.extension, '.jpg');
    });

    test('defaults to .png when nothing identifies the format', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(fakeBytes, 200);
      });
      final result = await fetchImageBytes(
        Uri.parse('https://example.com/pic'),
        client: client,
      );
      expect(result!.extension, '.png');
    });

    test('returns null on a non-200 status', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });
      final result = await fetchImageBytes(
        Uri.parse('https://example.com/missing.png'),
        client: client,
      );
      expect(result, isNull);
    });

    test('returns null instead of throwing on a network error', () async {
      final client = MockClient((request) async {
        throw Exception('network unreachable');
      });
      final result = await fetchImageBytes(
        Uri.parse('https://example.com/pic.png'),
        client: client,
      );
      expect(result, isNull);
    });
  });
}
