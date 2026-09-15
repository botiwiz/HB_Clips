import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/frames_repository.dart';

void main() {
  late AppDatabase db;
  late FramesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FramesRepository(db);
  });

  tearDown(() => db.close());

  Future<List<SyncQueueEntry>> outboxRows() =>
      db.select(db.syncQueueEntries).get();

  test('createFrame enqueues an upsert outbox entry', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );

    final entries = await outboxRows();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, 'frame');
    expect(entries.single.entityId, 'frame-1');
    expect(entries.single.operation, 'upsert');
  });

  test('renameFrame enqueues an upsert entry and marks the row dirty', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    await repo.renameFrame('frame-1', 'Renamed');

    final entries = await outboxRows();
    expect(entries.last.entityId, 'frame-1');
    expect(entries.last.operation, 'upsert');

    final row = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-1'))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.name, 'Renamed');
  });

  test('updateTransform enqueues an upsert entry and marks the row dirty', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    await repo.updateTransform('frame-1', x: 50, width: 500);

    final row = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-1'))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.x, 50);
    expect(row.width, 500);
    // Untouched fields are left as-is.
    expect(row.y, 0);
    expect(row.height, 300);
  });

  test('deleteFrame enqueues only one delete entry for the frame itself', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    final beforeCount = (await outboxRows()).length;

    await repo.deleteFrame('frame-1');

    final newEntries = (await outboxRows()).skip(beforeCount).toList();
    expect(newEntries, hasLength(1));
    expect(newEntries.single.entityType, 'frame');
    expect(newEntries.single.entityId, 'frame-1');
    expect(newEntries.single.operation, 'delete');
  });
}
