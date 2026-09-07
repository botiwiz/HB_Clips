import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/strokes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late StrokesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = StrokesRepository(db);
  });

  tearDown(() => db.close());

  Future<List<SyncQueueEntry>> outboxRows() =>
      db.select(db.syncQueueEntries).get();

  test('addStroke enqueues an upsert outbox entry', () async {
    final id = _uuid.v4();
    await repo.addStroke(
      id: id,
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    final entries = await outboxRows();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, 'stroke');
    expect(entries.single.entityId, id);
    expect(entries.single.operation, 'upsert');
  });

  test('deleteStroke enqueues a delete outbox entry', () async {
    final id = _uuid.v4();
    await repo.addStroke(
      id: id,
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    await repo.deleteStroke(id);

    final entries = await outboxRows();
    expect(entries.last.entityId, id);
    expect(entries.last.operation, 'delete');
  });

  test('deleteStrokesForClip enqueues a delete entry per stroke', () async {
    const clipId = 'clip-1';
    final id1 = _uuid.v4();
    final id2 = _uuid.v4();
    await repo.addStroke(
      id: id1,
      boardId: kLocalBoardId,
      clipId: clipId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );
    await repo.addStroke(
      id: id2,
      boardId: kLocalBoardId,
      clipId: clipId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    await repo.deleteStrokesForClip(clipId);

    final deleteEntries = (await outboxRows())
        .where((e) => e.operation == 'delete')
        .map((e) => e.entityId)
        .toSet();
    expect(deleteEntries, {id1, id2});
  });
}
