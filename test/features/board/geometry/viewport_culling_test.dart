import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/frame_geometry.dart';
import 'package:hb_clips/features/board/geometry/selection_geometry.dart';
import 'package:hb_clips/features/board/geometry/viewport_culling.dart';

FrameRow _frame({
  required double x,
  required double y,
  double width = 100,
  double height = 100,
}) {
  final now = DateTime(2026);
  return FrameRow(
    id: 'frame-1',
    boardId: 'board',
    name: 'Frame',
    x: x,
    y: y,
    width: width,
    height: height,
    sortOrder: 0,
    backgroundColorHex: null,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _clip({
  required double x,
  required double y,
  double width = 100,
  double height = 100,
}) {
  final now = DateTime(2026);
  return BoardClip(
    id: 'clip-1',
    boardId: 'board',
    type: ClipType.image,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: 0,
    createdAt: now,
    updatedAt: now,
  );
}

KanbanElementRow _kanbanElement({
  required double x,
  required double y,
  double width = 300,
  double height = 480,
  bool screenPinned = false,
}) {
  final now = DateTime(2026);
  return KanbanElementRow(
    id: 'el-1',
    boardId: 'board',
    name: 'Kanban',
    x: x,
    y: y,
    width: width,
    height: height,
    screenPinned: screenPinned,
    scale: 1.0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ViewportCulling.boardRectFor', () {
    test('covers the on-screen viewport, padded by one viewport-extent '
        'per side', () {
      const view = BoardViewState(panOffset: Offset.zero, scale: 1);
      const canvasSize = Size(800, 600);
      final rect = ViewportCulling.boardRectFor(view, canvasSize);

      // Raw viewport (unpadded) would be (0,0)-(800,600) at scale 1.
      expect(rect.left, -800);
      expect(rect.top, -600);
      expect(rect.right, 1600);
      expect(rect.bottom, 1200);
    });

    test('accounts for pan offset and scale', () {
      const view = BoardViewState(panOffset: Offset(100, 50), scale: 2);
      const canvasSize = Size(400, 200);
      final rect = ViewportCulling.boardRectFor(view, canvasSize);

      // Raw viewport: screenToBoard(0,0) = (-50,-25), screenToBoard(400,200)
      // = (150,75) -> raw rect (-50,-25)-(150,75), width 200, height 100.
      expect(rect.left, closeTo(-250, 0.001));
      expect(rect.top, closeTo(-125, 0.001));
      expect(rect.right, closeTo(350, 0.001));
      expect(rect.bottom, closeTo(175, 0.001));
    });
  });

  group('viewport-culling predicates', () {
    test('a clip fully inside the viewport is kept', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      final clip = _clip(x: 100, y: 100);
      expect(ClipGeometry.marqueeIntersects(viewport, clip), isTrue);
    });

    test('a clip fully outside the padded viewport is dropped', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      final clip = _clip(x: 5000, y: 5000);
      expect(ClipGeometry.marqueeIntersects(viewport, clip), isFalse);
    });

    test('a clip straddling the viewport edge is kept (conservative)', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      final clip = _clip(x: 950, y: 950, width: 100, height: 100);
      expect(ClipGeometry.marqueeIntersects(viewport, clip), isTrue);
    });

    test('a frame fully outside the viewport is dropped, straddling is '
        'kept', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      expect(
        FrameGeometry.marqueeIntersects(viewport, _frame(x: 100, y: 100)),
        isTrue,
      );
      expect(
        FrameGeometry.marqueeIntersects(viewport, _frame(x: 5000, y: 5000)),
        isFalse,
      );
      expect(
        FrameGeometry.marqueeIntersects(
          viewport,
          _frame(x: 950, y: 950, width: 100, height: 100),
        ),
        isTrue,
      );
    });

    test('a non-pinned kanban element follows the same overlap rule', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      expect(
        ViewportCulling.isKanbanElementVisible(
          viewport,
          _kanbanElement(x: 100, y: 100),
        ),
        isTrue,
      );
      expect(
        ViewportCulling.isKanbanElementVisible(
          viewport,
          _kanbanElement(x: 5000, y: 5000),
        ),
        isFalse,
      );
    });

    test('a screen-pinned kanban element is always visible, regardless of '
        'its (screen-space) coordinates relative to the board-space '
        'viewport rect', () {
      const viewport = Rect.fromLTWH(0, 0, 1000, 1000);
      expect(
        ViewportCulling.isKanbanElementVisible(
          viewport,
          _kanbanElement(x: 999999, y: 999999, screenPinned: true),
        ),
        isTrue,
      );
    });
  });
}
