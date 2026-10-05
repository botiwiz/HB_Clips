import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart' show FrameRow;
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/features/board/geometry/pdf_export_selection.dart';

FrameRow _frame(String id) {
  final now = DateTime.now();
  return FrameRow(
    id: id,
    boardId: 'board-1',
    name: id,
    x: 0,
    y: 0,
    width: 200,
    height: 200,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _clip(String id, {String? frameId}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.image,
    frameId: frameId,
    x: 0,
    y: 0,
    width: 50,
    height: 50,
    createdAt: now,
    updatedAt: now,
  );
}

Stroke _stroke(String id, {String? clipId}) {
  final now = DateTime.now();
  return Stroke(
    id: id,
    boardId: 'board-1',
    clipId: clipId,
    colorHex: '#FF0000',
    strokeWidth: 2,
    points: const [],
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test(
    'a selected frame brings all its children, with nothing else selected',
    () {
      final frame = _frame('f1');
      final child1 = _clip('c1', frameId: 'f1');
      final child2 = _clip('c2', frameId: 'f1');
      final strokes = [_stroke('s1')];

      final result = resolveExportSelection(
        selectedFrameIds: {'f1'},
        selectedClipIds: {},
        frames: [frame],
        clips: [child1, child2],
        strokes: strokes,
      );

      expect(result.frames, [frame]);
      expect(result.clips, [child1, child2]);
      expect(result.strokes, strokes);
      expect(result.isEmpty, isFalse);
    },
  );

  test('a clip belonging to a different, unselected frame is excluded', () {
    final selectedFrame = _frame('f1');
    final otherFrame = _frame('f2');
    final otherChild = _clip('c1', frameId: 'f2');

    final result = resolveExportSelection(
      selectedFrameIds: {'f1'},
      selectedClipIds: {},
      frames: [selectedFrame, otherFrame],
      clips: [otherChild],
      strokes: const [],
    );

    expect(result.frames, [selectedFrame]);
    expect(result.clips, isEmpty);
  });

  test('a selected loose clip with no frame selection is kept', () {
    final loose = _clip('c1');

    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {'c1'},
      frames: const [],
      clips: [loose],
      strokes: const [],
    );

    expect(result.frames, isEmpty);
    expect(result.clips, [loose]);
    expect(result.isEmpty, isFalse);
  });

  test('a clip selected inside an UNselected frame is excluded entirely, '
      'even though the clip itself is in selectedClipIds', () {
    final frame = _frame('f1');
    final child = _clip('c1', frameId: 'f1');

    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {'c1'},
      frames: [frame],
      clips: [child],
      strokes: const [],
    );

    expect(result.frames, isEmpty);
    expect(result.clips, isEmpty);
    expect(result.isEmpty, isTrue);
  });

  test('both selection sets empty resolves to an empty selection', () {
    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {},
      frames: [_frame('f1')],
      clips: [_clip('c1', frameId: 'f1')],
      strokes: const [],
    );

    expect(result.isEmpty, isTrue);
  });

  test('strokes always pass through unfiltered regardless of selection', () {
    final strokes = [_stroke('s1'), _stroke('s2', clipId: 'c1')];

    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {},
      frames: const [],
      clips: const [],
      strokes: strokes,
    );

    expect(result.strokes, same(strokes));
  });
}
