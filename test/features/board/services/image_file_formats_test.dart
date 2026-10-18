import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/image_file_formats.dart';

void main() {
  group('extractImageUrlFromHtml', () {
    test('finds a double-quoted src', () {
      final uri = extractImageUrlFromHtml(
        '<img src="https://example.com/pic.png" width="100">',
      );
      expect(uri, Uri.parse('https://example.com/pic.png'));
    });

    test('finds a single-quoted src', () {
      final uri = extractImageUrlFromHtml(
        "<img alt='cat' src='https://example.com/cat.jpg'>",
      );
      expect(uri, Uri.parse('https://example.com/cat.jpg'));
    });

    test('returns null when there is no img tag', () {
      final uri = extractImageUrlFromHtml('<p>no image here</p>');
      expect(uri, isNull);
    });

    test('picks the first of multiple img tags', () {
      final uri = extractImageUrlFromHtml(
        '<img src="https://example.com/first.png">'
        '<img src="https://example.com/second.png">',
      );
      expect(uri, Uri.parse('https://example.com/first.png'));
    });

    test('prefers data-iurl over a plain src on the same tag', () {
      final uri = extractImageUrlFromHtml(
        '<img src="https://example.com/thumb.png" '
        'data-iurl="https://example.com/full-res.png">',
      );
      expect(uri, Uri.parse('https://example.com/full-res.png'));
    });

    test('falls back to data-src when data-iurl is absent', () {
      final uri = extractImageUrlFromHtml(
        '<img src="https://example.com/thumb.png" '
        'data-src="https://example.com/lazy-loaded.png">',
      );
      expect(uri, Uri.parse('https://example.com/lazy-loaded.png'));
    });

    test('skips a data: URI src and uses data-iurl instead', () {
      final uri = extractImageUrlFromHtml(
        '<img src="data:image/jpeg;base64,/9j/4AAQSkZJRg==" '
        'data-iurl="https://example.com/source.jpg">',
      );
      expect(uri, Uri.parse('https://example.com/source.jpg'));
    });

    test('returns null when only a data: URI is present', () {
      final uri = extractImageUrlFromHtml(
        '<img src="data:image/jpeg;base64,/9j/4AAQSkZJRg==">',
      );
      expect(uri, isNull);
    });

    test(
      'prefers a non-thumbnail candidate over a gstatic encrypted-tbn one',
      () {
        final uri = extractImageUrlFromHtml(
          '<img src="https://encrypted-tbn0.gstatic.com/images?q=thumb">'
          '<img data-iurl="https://realsite.example.com/photo.jpg">',
        );
        expect(uri, Uri.parse('https://realsite.example.com/photo.jpg'));
      },
    );

    test(
      'falls back to a gstatic encrypted-tbn thumbnail when nothing better '
      'is found',
      () {
        final uri = extractImageUrlFromHtml(
          '<img src="https://encrypted-tbn0.gstatic.com/images?q=thumb">',
        );
        expect(
          uri,
          Uri.parse('https://encrypted-tbn0.gstatic.com/images?q=thumb'),
        );
      },
    );
  });
}
