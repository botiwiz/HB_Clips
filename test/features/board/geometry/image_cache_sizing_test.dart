import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/image_cache_sizing.dart';

void main() {
  group('ImageCacheSizing.quantize', () {
    test('rounds up to the nearest 64px bucket', () {
      // 100 logical px * 1.0 dpr = 100 -> rounds up to 128.
      expect(ImageCacheSizing.quantize(100, 1.0), 128);
      // Exactly on a bucket boundary stays put.
      expect(ImageCacheSizing.quantize(128, 1.0), 128);
      // Just over a boundary rounds up to the next one.
      expect(ImageCacheSizing.quantize(129, 1.0), 192);
    });

    test('small/continuous changes within the same bucket are stable', () {
      final a = ImageCacheSizing.quantize(100, 1.0);
      final b = ImageCacheSizing.quantize(105, 1.0);
      expect(a, b);
    });

    test('scales with devicePixelRatio', () {
      expect(ImageCacheSizing.quantize(100, 2.0), 256);
    });

    test('clamps to defaultCeiling when no native size is given', () {
      expect(
        ImageCacheSizing.quantize(10000, 3.0),
        ImageCacheSizing.defaultCeiling,
      );
    });

    test('clamps to nativeSize when given and smaller than the bucketed '
        'target', () {
      expect(
        ImageCacheSizing.quantize(1000, 1.0, nativeSize: 500),
        500,
      );
    });

    test('nativeSize larger than the bucketed target has no effect', () {
      expect(
        ImageCacheSizing.quantize(100, 1.0, nativeSize: 5000),
        128,
      );
    });

    test('never returns less than one bucket for a tiny size', () {
      expect(ImageCacheSizing.quantize(1, 1.0), ImageCacheSizing.bucket);
    });
  });
}
