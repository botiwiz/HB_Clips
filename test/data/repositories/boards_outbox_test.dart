import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/boards_repository.dart';

void main() {
  late AppDatabase db;
  late BoardsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BoardsRepository(db);
  });

  tearDown(() => db.close());

  Future<List<SyncQueueEntry>> outboxRows() =>
      db.select(db.syncQueueEntries).get();

  test('createBoard enqueues an upsert outbox entry', () async {
    await repo.createBoard('board-2', 'Second board');

    final entries = await outboxRows();
    expect(entries, hasLength(1));
    expect(entries.single.entityType, 'board');
    expect(entries.single.entityId, 'board-2');
    expect(entries.single.operation, 'upsert');
  });

  test('renameBoard enqueues an upsert entry and marks the row dirty', () async {
    await repo.createBoard('board-2', 'Second board');
    await repo.renameBoard('board-2', 'Renamed');

    final entries = await outboxRows();
    expect(entries.last.entityId, 'board-2');
    expect(entries.last.operation, 'upsert');

    final row = await (db.select(
      db.boards,
    )..where((b) => b.id.equals('board-2'))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.name, 'Renamed');
  });

  test('deleteBoard enqueues only one delete entry for the board itself', () async {
    await repo.createBoard('board-2', 'Second board');
    final beforeCount = (await outboxRows()).length;

    await repo.deleteBoard('board-2');

    final newEntries = (await outboxRows()).skip(beforeCount).toList();
    expect(newEntries, hasLength(1));
    expect(newEntries.single.entityType, 'board');
    expect(newEntries.single.entityId, 'board-2');
    expect(newEntries.single.operation, 'delete');
  });
}
