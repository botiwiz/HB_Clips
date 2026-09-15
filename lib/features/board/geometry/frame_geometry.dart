import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../controllers/board_controller.dart';

/// Pure geometry for frame hit-testing/resizing - a strict subset of
/// [ClipGeometry]'s math, since frames never rotate. No widget imports,
/// unit-testable the same way `selection_geometry.dart` is.
class FrameGeometry {
  FrameGeometry._();

  static const double handleHitRadius = 10;
  static const double minFrameSize = 80;

  static Rect boardRect(FrameRow frame) =>
      Rect.fromLTWH(frame.x, frame.y, frame.width, frame.height);

  static bool pointInFrame(Offset boardPoint, FrameRow frame) =>
      boardRect(frame).contains(boardPoint);

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) =>
      boardPoint * view.scale + view.panOffset;

  /// Screen-space position of the single bottom-right resize handle.
  static Offset resizeHandleScreenPosition(FrameRow frame, BoardViewState view) {
    return _boardToScreen(
      Offset(frame.x + frame.width, frame.y + frame.height),
      view,
    );
  }

  static bool hitTestResizeHandle(
    FrameRow frame,
    BoardViewState view,
    Offset screenPoint,
  ) {
    return (resizeHandleScreenPosition(frame, view) - screenPoint).distance <=
        handleHitRadius;
  }

  /// Resizes [startRect] by dragging its bottom-right corner to the current
  /// board-space pointer position, keeping the top-left corner fixed -
  /// frames don't rotate, so this is simpler than [ClipGeometry.resize].
  static Rect resize({required Rect startRect, required Offset pointerBoard}) {
    final width = (pointerBoard.dx - startRect.left) < minFrameSize
        ? minFrameSize
        : pointerBoard.dx - startRect.left;
    final height = (pointerBoard.dy - startRect.top) < minFrameSize
        ? minFrameSize
        : pointerBoard.dy - startRect.top;
    return Rect.fromLTWH(startRect.left, startRect.top, width, height);
  }
}
