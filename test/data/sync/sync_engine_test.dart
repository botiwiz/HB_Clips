import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/frames_repository.dart';
import 'package:hb_clips/data/sync/realtime_listener.dart';
import 'package:hb_clips/data/sync/sync_engine.dart';
import 'package:hb_clips/data/sync/sync_queue_drainer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'sync_queue_drainer_test.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late ClipsRepository clipsRepo;
  late FakeClipsRemoteSource fakeClips;
  late FakeStrokesRemoteSource fakeStrokes;
  late FakeBoardsRemoteSource fakeBoards;
  late FakeFramesRemoteSource fakeFrames;
  late FakeStorageSource fakeStorage;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clipsRepo = ClipsRepository(db);
    fakeClips = FakeClipsRemoteSource();
    fakeStrokes = FakeStrokesRemoteSource();
    fakeBoards = FakeBoardsRemoteSource();
    fakeFrames = FakeFramesRemoteSource();
    fakeStorage = FakeStorageSource();

    final drainer = SyncQueueDrainer(
      db,
      () => 'user-1',
      fakeClips,
      fakeStrokes,
      fakeBoards,
      fakeFrames,
      fakeStorage,
      FakeLocalBlobStore(),
    );
    // Never started (.start()/.stop() aren't called in these tests, so no
    // real network I/O happens) - only its public applyXRecord methods,
    // which operate purely on local Drift + a plain Map, are exercised.
    final realtime = RealtimeListener(
      db,
      SupabaseClient('http://localhost:0', 'test-anon-key'),
      fakeStorage,
    );
    engine = SyncEngine(
      db,
      drainer,
      realtime,
      fakeClips,
      fakeStrokes,
      fakeBoards,
      fakeFrames,
    );
  });

  tearDown(() => db.close());

  test('reconcile inserts a remote clip missing locally', () async {
    fakeClips.remoteRows.add({
      'id': 'remote-clip-1',
      'board_id': kLocalBoardId,
      'type': 'text',
      'x': 10.0,
      'y': 20.0,
      'width': 200.0,
      'height': 140.0,
      'rotation': 0.0,
      'z_index': 0,
      'opacity': 1.0,
      'text_content': 'from another device',
      'background_color_hex': null,
      'group_id': null,
      'storage_path': null,
      'is_binned': false,
      'binned_at': null,
      'created_at': DateTime(2024, 1, 1).toIso8601String(),
      'updated_at': DateTime(2024, 1, 1).toIso8601String(),
    });

    await engine.reconcile();

    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals('remote-clip-1'))).getSingle();
    expect(row.textContent, 'from another device');
    expect(row.dirty, isFalse);
  });

  test('reconcile deletes a clean local clip missing from the remote set', () async {
    final clip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'will be removed remotely',
      x: 0,
      y: 0,
    );
    // Simulate this device having already pushed it successfully: clear
    // dirty and the outbox entry, as the drainer would after a real push.
    await (db.delete(db.syncQueueEntries)).go();
    await (db.update(db.clips)..where((c) => c.id.equals(clip.id))).write(
      const ClipsCompanion(dirty: Value(false)),
    );

    // No matching row in the fake remote's fetchAll() result - simulates
    // another device having deleted it while this one was offline.
    await engine.reconcile();

    final remaining = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingleOrNull();
    expect(remaining, isNull);
  });

  test('reconcile keeps a dirty local clip even though it is missing remotely', () async {
    final clip = await clipsRepo.addTextNote(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      textContent: 'not yet pushed',
      x: 0,
      y: 0,
    );
    // addTextNote already leaves it dirty=true with a pending outbox entry
    // (this is the "brand new, never pushed yet" case).

    await engine.reconcile();

    final row = await (db.select(
      db.clips,
    )..where((c) => c.id.equals(clip.id))).getSingleOrNull();
    expect(row, isNotNull, reason: 'a dirty/pending row must not be deleted');
  });

  test('reconcile inserts a remote frame missing locally', () async {
    fakeFrames.remoteRows.add({
      'id': 'remote-frame-1',
      'board_id': kLocalBoardId,
      'name': 'Section from another device',
      'x': 10.0,
      'y': 20.0,
      'width': 400.0,
      'height': 300.0,
      'created_at': DateTime(2024, 1, 1).toIso8601String(),
      'updated_at': DateTime(2024, 1, 1).toIso8601String(),
    });

    await engine.reconcile();

    final row = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('remote-frame-1'))).getSingle();
    expect(row.name, 'Section from another device');
    expect(row.dirty, isFalse);
  });

  test('reconcile deletes a clean local frame missing from the remote set', () async {
    final framesRepo = FramesRepository(db);
    await framesRepo.createFrame(
      id: 'frame-2',
      boardId: kLocalBoardId,
      name: 'Will be removed remotely',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );
    await (db.delete(db.syncQueueEntries)).go();
    await (db.update(db.frames)..where((f) => f.id.equals('frame-2'))).write(
      const FramesCompanion(dirty: Value(false)),
    );

    await engine.reconcile();

    final remaining = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-2'))).getSingleOrNull();
    expect(remaining, isNull);
  });

  test('reconcile keeps a dirty local frame even though it is missing remotely', () async {
    final framesRepo = FramesRepository(db);
    await framesRepo.createFrame(
      id: 'frame-3',
      boardId: kLocalBoardId,
      name: 'Not yet pushed',
      x: 0,
      y: 0,
      width: 400,
      height: 300,
    );

    await engine.reconcile();

    final row = await (db.select(
      db.frames,
    )..where((f) => f.id.equals('frame-3'))).getSingleOrNull();
    expect(row, isNotNull, reason: 'a dirty/pending row must not be deleted');
  });
}
