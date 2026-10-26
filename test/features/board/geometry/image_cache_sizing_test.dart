import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/image_cache_sizing.dart';

void main() {
  group('ImageCacheSizing.quantize', () {
    final bucket = ImageCacheSizing.bucket;

    test('rounds up to the nearest bucket', () {
      // Just over one bucket rounds up to two buckets.
      expect(
        ImageCacheSizing.quantize((bucket + 1).toDouble(), 1.0),
        bucket * 2,
      );
      // Exactly on a bucket boundary stays put.
      expect(
        ImageCacheSizing.quantize((bucket * 2).toDouble(), 1.0),
        bucket * 2,
      );
      // Just over a boundary rounds up to the next one.
      expect(
        ImageCacheSizing.quantize((bucket * 2 + 1).toDouble(), 1.0),
        bucket * 3,
      );
    });

    test('small/continuous changes within the same bucket are stable', () {
      final a = ImageCacheSizing.quantize(bucket * 0.5, 1.0);
      final b = ImageCacheSizing.quantize(bucket * 0.5 + 5, 1.0);
      expect(a, b);
    });

    test('scales with devicePixelRatio', () {
      expect(
        ImageCacheSizing.quantize(bucket.toDouble(), 2.0),
        bucket * 2,
      );
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
        ImageCacheSizing.quantize(bucket * 0.5, 1.0, nativeSize: 5000),
        bucket,
      );
    });

    test('never returns less than one bucket for a tiny size', () {
      expect(ImageCacheSizing.quantize(1, 1.0), ImageCacheSizing.bucket);
    });
  });
}
