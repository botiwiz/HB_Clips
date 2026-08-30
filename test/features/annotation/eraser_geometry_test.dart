import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/annotation/geometry/eraser_geometry.dart';

void main() {
  group('strokeNearPoint', () {
    test('detects a point close to a segment of a multi-point stroke', () {
      final points = [const Offset(0, 0), const Offset(100, 0), const Offset(100, 100)];
      expect(EraserGeometry.strokeNearPoint(points, const Offset(50, 3), 5), isTrue);
      expect(EraserGeometry.strokeNearPoint(points, const Offset(97, 50), 5), isTrue);
    });

    test('misses a point far from every segment', () {
      final points = [const Offset(0, 0), const Offset(100, 0)];
      expect(EraserGeometry.strokeNearPoint(points, const Offset(50, 50), 5), isFalse);
    });

    test('a single-point stroke is treated as a dot', () {
      final points = [const Offset(10, 10)];
      expect(EraserGeometry.strokeNearPoint(points, const Offset(12, 12), 5), isTrue);
      expect(EraserGeometry.strokeNearPoint(points, const Offset(50, 50), 5), isFalse);
    });

    test('an empty stroke never matches', () {
      expect(EraserGeometry.strokeNearPoint([], const Offset(0, 0), 100), isFalse);
    });

    test('respects the maxDistance boundary', () {
      final points = [const Offset(0, 0), const Offset(100, 0)];
      expect(EraserGeometry.strokeNearPoint(points, const Offset(50, 4.9), 5), isTrue);
      expect(EraserGeometry.strokeNearPoint(points, const Offset(50, 5.1), 5), isFalse);
    });
  });
}
