import 'package:flutter/rendering.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
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

  /// Whether a board-space marquee rect overlaps [frame]'s body - exact
  /// (not an approximation, unlike `ClipGeometry.marqueeIntersects`'s
  /// rotated-clip version), since frames never rotate.
  static bool marqueeIntersects(Rect marqueeBoardRect, FrameRow frame) =>
      marqueeBoardRect.overlaps(boardRect(frame));

  /// Board-space height of the clickable band directly above a frame,
  /// covering its floating name label (which renders 22 screen px above the
  /// frame's top-left) with real margin - lets a click near the title
  /// reliably select/drag the frame itself, even when its interior is fully
  /// covered by child clips (frames render behind clips, so clicking inside
  /// the body usually hits a child instead).
  static const double titleBandHeight = 32;

  /// Whether [boardPoint] falls within the title band itself (not the
  /// frame's body) - split out from [pointInFrameOrTitleBand] so a
  /// double-click specifically on the title (which starts an inline
  /// rename) can be told apart from one on the body (which keeps its
  /// normal plain-select/drag behavior).
  static bool pointInTitleBand(Offset boardPoint, FrameRow frame) {
    final band = Rect.fromLTWH(
      frame.x,
      frame.y - titleBandHeight,
      frame.width,
      titleBandHeight,
    );
    return band.contains(boardPoint);
  }

  /// Like [pointInFrame], but also true for the title band above the
  /// frame - used only for the frame *selection/drag* hit-test, deliberately
  /// not by the clip-drop containment check, which must keep testing the
  /// frame's exact body rect only: a clip dropped above a frame's title
  /// should not become that frame's child.
  static bool pointInFrameOrTitleBand(Offset boardPoint, FrameRow frame) =>
      pointInFrame(boardPoint, frame) || pointInTitleBand(boardPoint, frame);

  static Offset _boardToScreen(Offset boardPoint, BoardViewState view) =>
      boardPoint * view.scale + view.panOffset;

  /// Screen-space position of the single bottom-right resize handle.
  static Offset resizeHandleScreenPosition(
    FrameRow frame,
    BoardViewState view,
  ) {
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

  /// Scales every clip in [startClips] (gesture-start snapshots, keyed by
  /// id) to match a frame resize from [startRect] to [newRect], anchored at
  /// the frame's fixed top-left corner (matching [resize] itself, which
  /// only ever moves the bottom-right corner). Independent per-axis scale
  /// factors, not locked to a single uniform value - a frame resize is
  /// already free-form via its single corner handle, so its children follow
  /// the same non-uniform stretch. No minimum-size clamp: a frame's
  /// children shrinking proportionally with their container is the whole
  /// point, not an edge case to guard against.
  static Map<String, ({double x, double y, double width, double height})>
  scaleChildren({
    required Map<String, BoardClip> startClips,
    required Rect startRect,
    required Rect newRect,
  }) {
    final scaleX = startRect.width == 0 ? 1.0 : newRect.width / startRect.width;
    final scaleY = startRect.height == 0
        ? 1.0
        : newRect.height / startRect.height;
    final anchor = startRect.topLeft;

    return startClips.map((id, clip) {
      final newX = anchor.dx + (clip.x - anchor.dx) * scaleX;
      final newY = anchor.dy + (clip.y - anchor.dy) * scaleY;
      return MapEntry(id, (
        x: newX,
        y: newY,
        width: clip.width * scaleX,
        height: clip.height * scaleY,
      ));
    });
  }

  /// The lowest-numbered "Frame N" name not already used by [frames] -
  /// "Frame 1" if none exist, reuses a gap left by a deleted frame
  /// rather than always growing (delete "Frame 2", create a new one,
  /// get "Frame 2" back - not "Frame 4"). Names that don't match the
  /// plain "Frame" + a number pattern are ignored, not treated as a
  /// collision.
  static String nextAvailableFrameName(List<FrameRow> frames) {
    final used = <int>{};
    final pattern = RegExp(r'^Frame (\d+)$');
    for (final f in frames) {
      final match = pattern.firstMatch(f.name);
      if (match != null) used.add(int.parse(match.group(1)!));
    }
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return 'Frame $n';
  }
}
