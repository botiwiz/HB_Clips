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
  });
}
