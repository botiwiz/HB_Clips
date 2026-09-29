import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/controllers/board_controller.dart';

void main() {
  group('fitRect', () {
    test('fits a frame with the constraining axis exactly at the padding margin', () {
      final notifier = BoardViewNotifier();
      const frameRect = Rect.fromLTWH(0, 0, 320, 240);
      const screenSize = Size(1600, 900);

      notifier.fitRect(frameRect, screenSize, padding: 40);
      final view = notifier.state;

      // availableWidth=1520/320=4.75, availableHeight=820/240=3.4167 -
      // height is the constraining axis.
      expect(view.scale, closeTo(3.4167, 1e-3));

      // The frame's screen-space rect after this transform...
      final screenTopLeft = frameRect.topLeft * view.scale + view.panOffset;
      final screenBottomRight =
          frameRect.bottomRight * view.scale + view.panOffset;
      // ...has its top/bottom margins exactly at the requested padding...
      expect(screenTopLeft.dy, closeTo(40, 1e-6));
      expect(screenSize.height - screenBottomRight.dy, closeTo(40, 1e-6));
      // ...and is horizontally centered (larger, symmetric margins).
      expect(screenTopLeft.dx, closeTo(screenSize.width - screenBottomRight.dx, 1e-6));
      expect(screenTopLeft.dx, greaterThan(40));
    });

    test('clamps to maxScale for a tiny rect instead of zooming in arbitrarily far', () {
      final notifier = BoardViewNotifier();
      notifier.fitRect(const Rect.fromLTWH(0, 0, 1, 1), const Size(1000, 1000));
      expect(notifier.state.scale, BoardViewNotifier.maxScale);
    });

    test('clamps to minScale for a huge rect instead of zooming out arbitrarily far', () {
      final notifier = BoardViewNotifier();
      notifier.fitRect(
        const Rect.fromLTWH(0, 0, 1000000, 1000000),
        const Size(1000, 1000),
      );
      expect(notifier.state.scale, BoardViewNotifier.minScale);
    });

    test('maps the rect center to the screen center', () {
      final notifier = BoardViewNotifier();
      const frameRect = Rect.fromLTWH(100, 200, 300, 300); // square, centers cleanly
      const screenSize = Size(800, 800);

      notifier.fitRect(frameRect, screenSize, padding: 0);
      final view = notifier.state;

      final screenCenter = frameRect.center * view.scale + view.panOffset;
      expect(screenCenter.dx, closeTo(screenSize.width / 2, 1e-9));
      expect(screenCenter.dy, closeTo(screenSize.height / 2, 1e-9));
    });
  });
}
