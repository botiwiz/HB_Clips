import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/pinterest_service.dart';

void main() {
  group('PinterestService.parseBoardIdentifier', () {
    test('parses a full https URL with trailing slash', () {
      final result = PinterestService.parseBoardIdentifier(
        'https://www.pinterest.com/someuser/someboard/',
      );
      expect(result, (username: 'someuser', slug: 'someboard'));
    });

    test('parses a scheme-less pinterest.com URL', () {
      final result = PinterestService.parseBoardIdentifier(
        'pinterest.com/someuser/someboard',
      );
      expect(result, (username: 'someuser', slug: 'someboard'));
    });

    test('parses a URL with query params', () {
      final result = PinterestService.parseBoardIdentifier(
        'https://www.pinterest.com/someuser/someboard/?invite_code=abc',
      );
      expect(result, (username: 'someuser', slug: 'someboard'));
    });

    test('parses a bare username/slug pair with no domain', () {
      final result = PinterestService.parseBoardIdentifier(
        'someuser/someboard',
      );
      expect(result, (username: 'someuser', slug: 'someboard'));
    });

    test('trims surrounding whitespace', () {
      final result = PinterestService.parseBoardIdentifier(
        '  someuser/someboard  ',
      );
      expect(result, (username: 'someuser', slug: 'someboard'));
    });

    test('rejects a pin permalink', () {
      final result = PinterestService.parseBoardIdentifier(
        'https://www.pinterest.com/pin/123456789/',
      );
      expect(result, isNull);
    });

    test('rejects a bare profile URL with no board segment', () {
      final result = PinterestService.parseBoardIdentifier(
        'https://www.pinterest.com/someuser/',
      );
      expect(result, isNull);
    });

    test('rejects a plain keyword query with no slash', () {
      final result = PinterestService.parseBoardIdentifier(
        'mid-century furniture',
      );
      expect(result, isNull);
    });

    test('rejects an empty string', () {
      expect(PinterestService.parseBoardIdentifier(''), isNull);
      expect(PinterestService.parseBoardIdentifier('   '), isNull);
    });
  });
}
