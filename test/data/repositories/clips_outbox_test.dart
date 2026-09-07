import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late ClipsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ClipsRepository(db);
  });

  tearDown(() => db.close());

  Future<List<SyncQueueEntry>> outboxRows() =>
      db.select(db.syncQueueEntries).get();

  test('addTextNote enqueues an upsert outbox entry', () async {
    final clip = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );

    final entries = await outboxRows();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, 'clip');
    expect(entries.single.entityId, clip.id);
    expect(entries.single.operation, 'upsert');
  });

  test('updateTransform enqueues an upsert entry and marks the row dirty', () async {
    final clip = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );

    await repo.updateTransform(clip.id, x: 50);

    final entries = await outboxRows();
    expect(entries, hasLength(2)); // insert + update
    expect(entries.last.operation, 'upsert');

    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.x, 50);
  });

  test('deleteForever enqueues a delete outbox entry', () async {
    final clip = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );

    await repo.deleteForever(clip.id);

    final entries = await outboxRows();
    expect(entries.last.entityType, 'clip');
    expect(entries.last.entityId, clip.id);
    expect(entries.last.operation, 'delete');
  });

  test('emptyBin enqueues one delete entry per binned clip', () async {
    final clip1 = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'one',
      x: 0,
      y: 0,
    );
    final clip2 = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'two',
      x: 0,
      y: 0,
    );
    await repo.binClip(clip1.id);
    await repo.binClip(clip2.id);

    await repo.emptyBin(kLocalBoardId);

    final deleteEntries = (await outboxRows())
        .where((e) => e.operation == 'delete')
        .map((e) => e.entityId)
        .toSet();
    expect(deleteEntries, {clip1.id, clip2.id});
  });

  test('groupClips enqueues an upsert entry for every grouped clip', () async {
    final clip1 = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'one',
      x: 0,
      y: 0,
    );
    final clip2 = await repo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'two',
      x: 0,
      y: 0,
    );

    final beforeCount = (await outboxRows()).length;
    await repo.groupClips([clip1.id, clip2.id]);

    final newEntries = (await outboxRows()).skip(beforeCount);
    expect(newEntries.map((e) => e.entityId).toSet(), {clip1.id, clip2.id});
    expect(newEntries.every((e) => e.operation == 'upsert'), isTrue);
  });
}
