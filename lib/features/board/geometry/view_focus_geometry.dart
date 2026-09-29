import 'package:flutter/rendering.dart';

import '../controllers/board_controller.dart';

/// Pure decision logic for board_canvas.dart's Space-tap "focus on
/// selection, tap again to revert" toggle - kept separate from the
/// keyboard-event plumbing so the toggle/revert decision itself is
/// unit-testable.
class ViewFocusGeometry {
  ViewFocusGeometry._();

  /// True if focusing [targetRect] right now is "pressing Space again on
  /// the same focus" (revert to the pre-focus view) rather than a fresh
  /// focus - i.e. the caller last focused exactly this rect, and nothing
  /// has panned/zoomed the view since (checked by comparing the current
  /// view to the view [lastPostFocusView] recorded right after that
  /// focus - any manual pan/zoom/other-selection-focus in between will
  /// have changed it).
  static bool isReturningToSameFocus({
    required Rect? lastFocusedRect,
    required BoardViewState? lastPostFocusView,
    required Rect targetRect,
    required BoardViewState currentView,
  }) {
    if (lastFocusedRect == null || lastPostFocusView == null) return false;
    return lastFocusedRect == targetRect &&
        currentView.panOffset == lastPostFocusView.panOffset &&
        currentView.scale == lastPostFocusView.scale;
  }
}
