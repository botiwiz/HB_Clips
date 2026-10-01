import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/shape_geometry.dart';

void main() {
  const size = Size(100, 60);

  group('polygonVertices', () {
    test('rectangle is the 4 corners of the box', () {
      expect(ShapeGeometry.polygonVertices(ShapeKind.rectangle, size), [
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(100, 60),
        const Offset(0, 60),
      ]);
    });

    test('triangle is apex-top-center, base corners', () {
      expect(ShapeGeometry.polygonVertices(ShapeKind.triangle, size), [
        const Offset(50, 0),
        const Offset(100, 60),
        const Offset(0, 60),
      ]);
    });

    test(
      'trapezoid insets the top edge 18% per side, bottom edge full width',
      () {
        expect(ShapeGeometry.polygonVertices(ShapeKind.trapezoid, size), [
          const Offset(18, 0),
          const Offset(82, 0),
          const Offset(100, 60),
          const Offset(0, 60),
        ]);
      },
    );

    test('parallelogram shifts the top edge right by 20% of width', () {
      expect(ShapeGeometry.polygonVertices(ShapeKind.parallelogram, size), [
        const Offset(20, 0),
        const Offset(100, 0),
        const Offset(80, 60),
        const Offset(0, 60),
      ]);
    });

    test('ellipse has no polygon form', () {
      expect(
        () => ShapeGeometry.polygonVertices(ShapeKind.ellipse, size),
        throwsArgumentError,
      );
    });
  });

  group('pathFor', () {
    for (final kind in ShapeKind.values) {
      test('$kind produces a closed path bounded by the given size', () {
        final bounds = ShapeGeometry.pathFor(kind, size).getBounds();
        expect(bounds.left, closeTo(0, 0.01));
        expect(bounds.top, closeTo(0, 0.01));
        expect(bounds.width, closeTo(size.width, 0.01));
        expect(bounds.height, closeTo(size.height, 0.01));
      });
    }

    test('isEllipse is true only for ShapeKind.ellipse', () {
      for (final kind in ShapeKind.values) {
        expect(ShapeGeometry.isEllipse(kind), kind == ShapeKind.ellipse);
      }
    });
  });
}
