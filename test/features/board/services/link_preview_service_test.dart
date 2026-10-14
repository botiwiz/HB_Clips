import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/link_preview_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

void main() {
  group('looksLikeUrl', () {
    test('accepts an absolute https URL', () {
      expect(looksLikeUrl('https://example.com/article'), isTrue);
    });

    test('accepts an absolute http URL', () {
      expect(looksLikeUrl('http://example.com'), isTrue);
    });

    test('rejects plain text', () {
      expect(looksLikeUrl('just some pasted text'), isFalse);
    });

    test('rejects a bare word', () {
      expect(looksLikeUrl('hello'), isFalse);
    });

    test('rejects a non-http(s) scheme', () {
      expect(looksLikeUrl('mailto:someone@example.com'), isFalse);
      expect(looksLikeUrl('ftp://example.com/file'), isFalse);
    });
  });

  group('fetchLinkPreviewMetadata', () {
    test('extracts og:title and og:image (property before content)', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head>'
          '<meta property="og:title" content="A Great Article">'
          '<meta property="og:image" content="https://cdn.example.com/hero.jpg">'
          '</head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/article'),
        client: client,
      );
      expect(result.title, 'A Great Article');
      expect(result.imageUri, Uri.parse('https://cdn.example.com/hero.jpg'));
    });

    test('extracts meta tags with content before property/name', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head>'
          '<meta content="Other Order Title" property="og:title">'
          '<meta content="https://cdn.example.com/hero2.jpg" property="og:image">'
          '</head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/article'),
        client: client,
      );
      expect(result.title, 'Other Order Title');
      expect(result.imageUri, Uri.parse('https://cdn.example.com/hero2.jpg'));
    });

    test('resolves a relative og:image path against the page URI', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head>'
          '<meta property="og:image" content="/static/hero.jpg">'
          '</head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/blog/article'),
        client: client,
      );
      expect(result.imageUri, Uri.parse('https://example.com/static/hero.jpg'));
    });

    test('decodes HTML entities in a title/image URL', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head>'
          '<meta property="og:title" content="Rock &amp; Roll">'
          '<meta property="og:image" '
          'content="https://cdn.example.com/img?a=1&amp;b=2">'
          '</head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/article'),
        client: client,
      );
      expect(result.title, 'Rock & Roll');
      expect(result.imageUri, Uri.parse('https://cdn.example.com/img?a=1&b=2'));
    });

    test(
      'falls back to twitter:title/twitter:image when no og tags exist',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            '<html><head>'
            '<meta name="twitter:title" content="Twitter Title">'
            '<meta name="twitter:image" content="https://cdn.example.com/t.jpg">'
            '</head></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        });
        final result = await fetchLinkPreviewMetadata(
          Uri.parse('https://example.com/article'),
          client: client,
        );
        expect(result.title, 'Twitter Title');
        expect(result.imageUri, Uri.parse('https://cdn.example.com/t.jpg'));
      },
    );

    test('falls back to the <title> tag and a /favicon.ico guess when no '
        'meta tags are found at all', () async {
      final client = MockClient((request) async {
        return http.Response(
          '<html><head><title>Plain Page Title</title></head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/article'),
        client: client,
      );
      expect(result.title, 'Plain Page Title');
      expect(result.imageUri, Uri.parse('https://example.com/favicon.ico'));
    });

    test('returns (null, null) on a non-200 status', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/missing'),
        client: client,
      );
      expect(result.title, isNull);
      expect(result.imageUri, isNull);
    });

    test('returns (null, null) on a non-HTML response', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(
          Uint8List.fromList([1, 2, 3]),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      });
      final result = await fetchLinkPreviewMetadata(
        Uri.parse('https://example.com/file.pdf'),
        client: client,
      );
      expect(result.title, isNull);
      expect(result.imageUri, isNull);
    });

    test(
      'returns (null, null) instead of throwing on a network error',
      () async {
        final client = MockClient((request) async {
          throw Exception('network unreachable');
        });
        final result = await fetchLinkPreviewMetadata(
          Uri.parse('https://example.com/article'),
          client: client,
        );
        expect(result.title, isNull);
        expect(result.imageUri, isNull);
      },
    );
  });

  group('squareThumbnailBytes', () {
    test('center-crops/resizes a landscape image to a square', () {
      final source = img.Image(width: 200, height: 100);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      final bytes = Uint8List.fromList(img.encodePng(source));

      final result = squareThumbnailBytes(bytes, size: 32);
      expect(result, isNotNull);

      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 32);
      expect(decoded.height, 32);
    });

    test('returns null for undecodable bytes', () {
      final result = squareThumbnailBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(result, isNull);
    });
  });
}
