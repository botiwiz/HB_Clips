import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/data/remote/boards_remote_source.dart';
import 'package:hb_clips/data/remote/clips_remote_source.dart';
import 'package:hb_clips/data/remote/storage_source.dart';
import 'package:hb_clips/data/remote/strokes_remote_source.dart';
import 'package:hb_clips/data/repositories/boards_repository.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/strokes_repository.dart';
import 'package:hb_clips/data/sync/sync_queue_drainer.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class FakeClipsRemoteSource implements ClipsRemoteSource {
  final List<BoardClip> upserted = [];
  final List<String> deleted = [];
  final List<Map<String, dynamic>> remoteRows = [];
  bool shouldThrow = false;

  @override
  Future<void> upsert(BoardClip clip) async {
    if (shouldThrow) throw Exception('fake clip upsert failure');
    upserted.add(clip);
  }

  @override
  Future<void> delete(String id) async {
    if (shouldThrow) throw Exception('fake clip delete failure');
    deleted.add(id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => remoteRows;
}

class FakeStrokesRemoteSource implements StrokesRemoteSource {
  final List<Stroke> upserted = [];
  final List<String> deleted = [];

  @override
  Future<void> upsert(Stroke stroke) async => upserted.add(stroke);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => [];
}

class FakeBoardsRemoteSource implements BoardsRemoteSource {
  final List<BoardRow> upserted = [];
  final List<String> deleted = [];

  @override
  Future<void> upsert(BoardRow board) async => upserted.add(board);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<List<Map<String, dynamic>>> fetchAll() async => [];
}

class FakeStorageSource implements StorageSource {
  final List<String> uploadedClipIds = [];

  @override
  Future<String> uploadImage({
    required String userId,
    required String clipId,
    required File localFile,
  }) async {
    uploadedClipIds.add(clipId);
    return '$userId/$clipId/original.png';
  }

  @override
  Future<String> downloadImage({
    required String clipId,
    required String storagePath,
  }) async => '/tmp/$clipId.png';
}

void main() {
  late AppDatabase db;
  late ClipsRepository clipsRepo;
  late StrokesRepository strokesRepo;
  late BoardsRepository boardsRepo;
  late FakeClipsRemoteSource fakeClips;
  late FakeStrokesRemoteSource fakeStrokes;
  late FakeBoardsRemoteSource fakeBoards;
  late FakeStorageSource fakeStorage;
  late SyncQueueDrainer drainer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clipsRepo = ClipsRepository(db);
    strokesRepo = StrokesRepository(db);
    boardsRepo = BoardsRepository(db);
    fakeClips = FakeClipsRemoteSource();
    fakeStrokes = FakeStrokesRemoteSource();
    fakeBoards = FakeBoardsRemoteSource();
    fakeStorage = FakeStorageSource();
    drainer = SyncQueueDrainer(
      db,
      () => 'user-1',
      fakeClips,
      fakeStrokes,
      fakeBoards,
      fakeStorage,
    );
  });

  tearDown(() => db.close());

  test('drains a text clip upsert and clears the outbox + dirty flag', () async {
    final clip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );

    await drainer.drainOnce();

    expect(fakeClips.upserted, hasLength(1));
    expect(fakeClips.upserted.single.id, clip.id);
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingle();
    expect(row.dirty, isFalse);
  });

  test('uploads an image clip before upserting its metadata', () async {
    final clip = await clipsRepo.addImageClip(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      localFilePath: '/tmp/fake.png',
      x: 0,
      y: 0,
    );

    await drainer.drainOnce();

    expect(fakeStorage.uploadedClipIds, [clip.id]);
    expect(fakeClips.upserted.single.storagePath, 'user-1/${clip.id}/original.png');
    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingle();
    expect(row.storagePath, 'user-1/${clip.id}/original.png');
  });

  test('drains a stroke upsert and a board upsert', () async {
    await boardsRepo.createBoard('board-2', 'Second board');
    await strokesRepo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    await drainer.drainOnce();

    expect(fakeStrokes.upserted, hasLength(1));
    expect(fakeBoards.upserted.map((b) => b.id), contains('board-2'));
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
  });

  test('drains a delete entry', () async {
    final clip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );
    await drainer.drainOnce(); // push the initial insert first
    fakeClips.upserted.clear();

    await clipsRepo.deleteForever(clip.id);
    await drainer.drainOnce();

    expect(fakeClips.deleted, [clip.id]);
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
  });

  test('a failing entry keeps its row, records the error, and does not '
      'block other entities from draining', () async {
    final failingClip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'will fail',
      x: 0,
      y: 0,
    );
    await strokesRepo.addStroke(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
    );

    fakeClips.shouldThrow = true;
    await drainer.drainOnce();

    // The failing clip's entry survives, with attemptCount/lastError set.
    final remaining = await db.select(db.syncQueueEntries).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.entityId, failingClip.id);
    expect(remaining.single.attemptCount, 1);
    expect(remaining.single.lastError, contains('fake clip upsert failure'));

    // The unrelated stroke still drained successfully.
    expect(fakeStrokes.upserted, hasLength(1));
  });

  test('a stale upsert entry for an already-deleted row is dropped harmlessly', () async {
    final clip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'hello',
      x: 0,
      y: 0,
    );
    // Delete straight from Drift without going through the repository, so
    // the original 'upsert' entry is still queued with nothing following
    // it - simulating a race between local deletion and a drain in flight.
    await (db.delete(db.clips)..where((c) => c.id.equals(clip.id))).go();

    await drainer.drainOnce();

    expect(fakeClips.upserted, isEmpty);
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
  });
}
