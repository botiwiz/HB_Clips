import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/frames_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late FramesRepository repo;
  late ClipsRepository clipsRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FramesRepository(db);
    clipsRepo = ClipsRepository(db);
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

  test('updateColor enqueues an upsert entry and marks the row dirty', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    await repo.updateColor('frame-1', '#FF3B30');

    final row = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-1'))).getSingle();
    expect(row.dirty, isTrue);
    expect(row.backgroundColorHex, '#FF3B30');

    await repo.updateColor('frame-1', null);
    final reverted = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-1'))).getSingle();
    expect(reverted.backgroundColorHex, isNull);
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

  test('deleteFrame unparents its children instead of deleting them', () async {
    await repo.createFrame(
      id: 'frame-1',
      boardId: kLocalBoardId,
      name: 'Section 1',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    final child = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'inside',
      x: 10,
      y: 10,
    );
    await clipsRepo.setFrameId(child.id, 'frame-1');

    await repo.deleteFrame('frame-1');

    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(child.id))).getSingle();
    expect(row.frameId, isNull);
    expect(row.isBinned, isFalse);
  });
}
