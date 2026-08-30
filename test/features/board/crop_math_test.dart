import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/crop_geometry.dart';

BoardClip _clip({double rotation = 0}) {
  final now = DateTime(2026);
  return BoardClip(
    id: 'a',
    boardId: 'board',
    type: ClipType.image,
    x: 100,
    y: 100,
    width: 200,
    height: 100,
    rotation: rotation,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('updateCropRect', () {
    const fullRect = Rect.fromLTWH(0, 0, 1, 1);

    test('dragging the bottom-right corner moves right/bottom only', () {
      final result = CropGeometry.updateCropRect(
        fullRect,
        CropHandleKind.br,
        const Offset(0.7, 0.6),
      );
      expect(result.left, 0);
      expect(result.top, 0);
      expect(result.right, closeTo(0.7, 1e-9));
      expect(result.bottom, closeTo(0.6, 1e-9));
    });

    test('dragging the left edge only moves the left edge', () {
      final result = CropGeometry.updateCropRect(
        fullRect,
        CropHandleKind.left,
        const Offset(0.3, 0.9),
      );
      expect(result.left, closeTo(0.3, 1e-9));
      expect(result.top, 0);
      expect(result.right, 1);
      expect(result.bottom, 1);
    });

    test('clamps to the minimum crop size instead of collapsing to zero', () {
      final result = CropGeometry.updateCropRect(
        fullRect,
        CropHandleKind.right,
        const Offset(0.0, 0.5),
      );
      expect(result.width, closeTo(CropGeometry.minCropFraction, 1e-9));
    });

    test('clamps the pointer fraction to [0,1]', () {
      final result = CropGeometry.updateCropRect(
        fullRect,
        CropHandleKind.br,
        const Offset(1.5, -0.5),
      );
      expect(result.right, 1);
      expect(result.bottom, closeTo(CropGeometry.minCropFraction, 1e-9));
    });
  });

  group('handleScreenPositions', () {
    test('unrotated clip: corner handles sit at the crop rect corners', () {
      final clip = _clip();
      const view = BoardViewState();
      const cropRect = Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);
      final positions = CropGeometry.handleScreenPositions(
        clip,
        view,
        cropRect,
      );
      // clip spans x:100-300, y:100-200; crop rect is the central half.
      expect(positions[CropHandleKind.tl], const Offset(150, 125));
      expect(positions[CropHandleKind.br], const Offset(250, 175));
    });

    test('rotated clip: handles rotate around the clip center', () {
      final clip = _clip(rotation: math.pi / 2);
      const view = BoardViewState();
      const fullRect = Rect.fromLTWH(0, 0, 1, 1);
      final positions = CropGeometry.handleScreenPositions(
        clip,
        view,
        fullRect,
      );
      // A 90-degree rotation of the full (unrotated-at-corners) rect should
      // still land on the clip's own (now rotated) bounding corners.
      final hit = CropGeometry.hitTestHandle(
        clip,
        view,
        fullRect,
        positions[CropHandleKind.tl]!,
      );
      expect(hit, CropHandleKind.tl);
    });
  });
}
