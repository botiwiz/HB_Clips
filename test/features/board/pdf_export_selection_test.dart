import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart' show FrameRow;
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/connector.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/features/board/geometry/pdf_export_selection.dart';

FrameRow _frame(String id, {double x = 0, double y = 0}) {
  final now = DateTime.now();
  return FrameRow(
    id: id,
    boardId: 'board-1',
    name: id,
    x: x,
    y: y,
    width: 200,
    height: 200,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _clip(String id, {String? frameId, double x = 0, double y = 0}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.image,
    frameId: frameId,
    x: x,
    y: y,
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

Connector _connector(String id) {
  final now = DateTime.now();
  return Connector(
    id: id,
    boardId: 'board-1',
    fromClipId: 'c1',
    fromSide: ConnectorSide.right,
    toClipId: 'c2',
    colorHex: '#FFFFFF',
    strokeWidth: 2,
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
        connectors: const [],
      );

      expect(result.frames, [frame]);
      expect(result.clips, [child1, child2]);
      expect(result.strokes, strokes);
      expect(result.isEmpty, isFalse);
    },
  );

  test('a clip belonging to a different, unselected frame is excluded when '
      "it doesn't spatially overlap the selected frame", () {
    final selectedFrame = _frame('f1', x: 0, y: 0);
    final otherFrame = _frame('f2', x: 1000, y: 1000);
    final otherChild = _clip('c1', frameId: 'f2', x: 1000, y: 1000);

    final result = resolveExportSelection(
      selectedFrameIds: {'f1'},
      selectedClipIds: {},
      frames: [selectedFrame, otherFrame],
      clips: [otherChild],
      strokes: const [],
      connectors: const [],
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
      connectors: const [],
    );

    expect(result.frames, isEmpty);
    expect(result.clips, [loose]);
    expect(result.isEmpty, isFalse);
  });

  test('a clip explicitly selected inside an UNselected frame is now '
      "included - its own rect still counts as the selection's screen "
      'area, even though its frame was never selected', () {
    final frame = _frame('f1');
    final child = _clip('c1', frameId: 'f1');

    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {'c1'},
      frames: [frame],
      clips: [child],
      strokes: const [],
      connectors: const [],
    );

    expect(result.frames, isEmpty);
    expect(result.clips, [child]);
    expect(result.isEmpty, isFalse);
  });

  test('a loose clip never explicitly selected is still included because it '
      "spatially overlaps a selected frame's rect - the direct fix for an "
      'element mocked up near a frame without being grouped into it', () {
    final frame = _frame('f1', x: 0, y: 0);
    // Never selected, never parented to f1 - just physically overlapping
    // its rect (0,0,200,200).
    final nearbyLoose = _clip('c1', x: 50, y: 50);

    final result = resolveExportSelection(
      selectedFrameIds: {'f1'},
      selectedClipIds: {},
      frames: [frame],
      clips: [nearbyLoose],
      strokes: const [],
      connectors: const [],
    );

    expect(result.clips, [nearbyLoose]);
  });

  test('both selection sets empty resolves to an empty selection', () {
    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {},
      frames: [_frame('f1')],
      clips: [_clip('c1', frameId: 'f1')],
      strokes: const [],
      connectors: const [],
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
      connectors: const [],
    );

    expect(result.strokes, same(strokes));
  });

  test('connectors always pass through unfiltered regardless of selection', () {
    final connectors = [_connector('conn1'), _connector('conn2')];

    final result = resolveExportSelection(
      selectedFrameIds: {},
      selectedClipIds: {},
      frames: const [],
      clips: const [],
      strokes: const [],
      connectors: connectors,
    );

    expect(result.connectors, same(connectors));
  });
}
