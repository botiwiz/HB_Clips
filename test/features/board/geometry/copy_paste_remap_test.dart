import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/connector.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/features/board/geometry/copy_paste_remap.dart';

void main() {
  final fixedNow = DateTime(2026, 1, 1);
  var nextId = 0;
  String newId() => 'new-${nextId++}';

  setUp(() => nextId = 0);

  group('remapConnectorsForPaste', () {
    test(
      'remaps fromClipId/toClipId through clipIdMap and assigns new id/board',
      () {
        final connector = Connector(
          id: 'old-conn',
          boardId: 'board-a',
          fromClipId: 'old-1',
          fromSide: ConnectorSide.right,
          toClipId: 'old-2',
          toRelX: 0.5,
          toRelY: 0.25,
          colorHex: '#FF0000',
          strokeWidth: 2,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        );

        final result = remapConnectorsForPaste(
          [connector],
          {'old-1': 'new-1', 'old-2': 'new-2'},
          'board-b',
          newId: newId,
          now: () => fixedNow,
        );

        expect(result, hasLength(1));
        final remapped = result.single;
        expect(remapped.id, 'new-0');
        expect(remapped.boardId, 'board-b');
        expect(remapped.fromClipId, 'new-1');
        expect(remapped.toClipId, 'new-2');
        expect(remapped.fromSide, ConnectorSide.right);
        expect(remapped.toRelX, 0.5);
        expect(remapped.toRelY, 0.25);
        expect(remapped.colorHex, '#FF0000');
        expect(remapped.strokeWidth, 2);
        expect(remapped.createdAt, fixedNow);
      },
    );

    test('drops a connector whose endpoint is missing from clipIdMap', () {
      final connector = Connector(
        id: 'old-conn',
        boardId: 'board-a',
        fromClipId: 'old-1',
        fromSide: ConnectorSide.top,
        toClipId: 'not-copied',
        colorHex: '#FFFFFF',
        strokeWidth: 1,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );

      final result = remapConnectorsForPaste(
        [connector],
        {'old-1': 'new-1'},
        'board-b',
        newId: newId,
        now: () => fixedNow,
      );

      expect(result, isEmpty);
    });
  });

  group('remapStrokesForPaste', () {
    test('remaps clipId through clipIdMap and assigns new id/board', () {
      final stroke = Stroke(
        id: 'old-stroke',
        boardId: 'board-a',
        clipId: 'old-1',
        colorHex: '#00FF00',
        strokeWidth: 3,
        points: const [Offset(0, 0), Offset(1, 1)],
        dashed: true,
        arrowEnd: true,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );

      final result = remapStrokesForPaste(
        [stroke],
        {'old-1': 'new-1'},
        'board-b',
        newId: newId,
        now: () => fixedNow,
      );

      expect(result, hasLength(1));
      final remapped = result.single;
      expect(remapped.id, 'new-0');
      expect(remapped.boardId, 'board-b');
      expect(remapped.clipId, 'new-1');
      expect(remapped.points, [const Offset(0, 0), const Offset(1, 1)]);
      expect(remapped.dashed, isTrue);
      expect(remapped.arrowEnd, isTrue);
    });

    test('drops a stroke whose clipId is missing from clipIdMap', () {
      final stroke = Stroke(
        id: 'old-stroke',
        boardId: 'board-a',
        clipId: 'not-copied',
        colorHex: '#000000',
        strokeWidth: 1,
        points: const [Offset(0, 0)],
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );

      final result = remapStrokesForPaste(
        [stroke],
        const {},
        'board-b',
        newId: newId,
        now: () => fixedNow,
      );

      expect(result, isEmpty);
    });
  });
}
