import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';
import 'package:hb_clips/features/board/geometry/view_focus_geometry.dart';

void main() {
  group('isReturningToSameFocus', () {
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    const view = BoardViewState(panOffset: Offset(10, 20), scale: 2.0);

    test('false on the first-ever press (no prior focus recorded)', () {
      expect(
        ViewFocusGeometry.isReturningToSameFocus(
          lastFocusedRect: null,
          lastPostFocusView: null,
          targetRect: rect,
          currentView: view,
        ),
        isFalse,
      );
    });

    test('true when the rect and view both match the last focus exactly', () {
      expect(
        ViewFocusGeometry.isReturningToSameFocus(
          lastFocusedRect: rect,
          lastPostFocusView: view,
          targetRect: rect,
          currentView: view,
        ),
        isTrue,
      );
    });

    test('false when the view has changed since (a manual pan/zoom)', () {
      expect(
        ViewFocusGeometry.isReturningToSameFocus(
          lastFocusedRect: rect,
          lastPostFocusView: view,
          targetRect: rect,
          currentView: const BoardViewState(
            panOffset: Offset(10, 20),
            scale: 2.5,
          ),
        ),
        isFalse,
      );
    });

    test('false when the target rect has changed (selection changed)', () {
      expect(
        ViewFocusGeometry.isReturningToSameFocus(
          lastFocusedRect: rect,
          lastPostFocusView: view,
          targetRect: const Rect.fromLTWH(500, 500, 50, 50),
          currentView: view,
        ),
        isFalse,
      );
    });
  });
}
