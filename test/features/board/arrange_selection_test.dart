import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/widgets/arrange_selection_button.dart';

BoardClip _clip({
  required String id,
  required ClipType type,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final now = DateTime(2026);
  return BoardClip(
    id: id,
    boardId: 'board',
    type: type,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ArrangeSelectionButton.packImages', () {
    test('fewer than 2 images returns null', () {
      final one = [
        _clip(id: 'a', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
      ];
      final result = ArrangeSelectionButton.packImages(
        one,
        const Rect.fromLTWH(0, 0, 500, 500),
      );
      expect(result, isNull);
    });

    test('text notes in the selection are excluded from packing', () {
      final selected = [
        _clip(id: 'a', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
        _clip(id: 'b', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
        _clip(id: 'note', type: ClipType.text, x: 0, y: 0, width: 100, height: 100),
      ];
      final result = ArrangeSelectionButton.packImages(
        selected,
        const Rect.fromLTWH(0, 0, 500, 500),
      );
      expect(result, isNotNull);
      expect(result!.containsKey('note'), isFalse);
      expect(result.length, 2);
    });

    test('packed rects are shifted into targetRect (not left at origin)', () {
      final selected = [
        _clip(id: 'a', type: ClipType.image, x: 999, y: 999, width: 100, height: 100),
        _clip(id: 'b', type: ClipType.image, x: 999, y: 999, width: 100, height: 100),
      ];
      const targetRect = Rect.fromLTWH(200, 300, 400, 200);

      final result = ArrangeSelectionButton.packImages(selected, targetRect)!;

      for (final r in result.values) {
        expect(r.x, greaterThanOrEqualTo(targetRect.left));
        expect(r.y, greaterThanOrEqualTo(targetRect.top));
      }
      // At least one image should start exactly at the target's top-left.
      expect(
        result.values.any(
          (r) => (r.x - targetRect.left).abs() < 1e-6 && (r.y - targetRect.top).abs() < 1e-6,
        ),
        isTrue,
      );
    });

    test('a wider target rect still packs with no gaps/overflow (delegates to JustifiedLayout)', () {
      final selected = [
        _clip(id: 'a', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
        _clip(id: 'b', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
        _clip(id: 'c', type: ClipType.image, x: 0, y: 0, width: 100, height: 100),
      ];
      const narrow = Rect.fromLTWH(0, 0, 200, 200);
      const wide = Rect.fromLTWH(0, 0, 800, 200);

      final narrowResult = ArrangeSelectionButton.packImages(selected, narrow)!;
      final wideResult = ArrangeSelectionButton.packImages(selected, wide)!;

      // A wider target should pack images noticeably wider on average.
      final narrowAvgWidth =
          narrowResult.values.map((r) => r.width).reduce((a, b) => a + b) /
          narrowResult.length;
      final wideAvgWidth =
          wideResult.values.map((r) => r.width).reduce((a, b) => a + b) /
          wideResult.length;
      expect(wideAvgWidth, greaterThan(narrowAvgWidth));
    });

    test('a zero-movement drag (targetRect equals the original selection box) reproduces the same pack every time', () {
      final selected = [
        _clip(id: 'a', type: ClipType.image, x: 0, y: 0, width: 150, height: 100),
        _clip(id: 'b', type: ClipType.image, x: 0, y: 0, width: 100, height: 150),
      ];
      const rect = Rect.fromLTWH(10, 20, 300, 200);

      final first = ArrangeSelectionButton.packImages(selected, rect)!;
      final second = ArrangeSelectionButton.packImages(selected, rect)!;

      for (final id in first.keys) {
        expect(second[id]!.x, closeTo(first[id]!.x, 1e-9));
        expect(second[id]!.y, closeTo(first[id]!.y, 1e-9));
        expect(second[id]!.width, closeTo(first[id]!.width, 1e-9));
        expect(second[id]!.height, closeTo(first[id]!.height, 1e-9));
      }
    });
  });
}
