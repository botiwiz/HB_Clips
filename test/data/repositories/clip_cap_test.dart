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

  test('allows adding up to kMaxImageClips image clips', () async {
    for (var i = 0; i < kMaxImageClips; i++) {
      await repo.addImageClip(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        localFilePath: '/tmp/fake_$i.png',
        x: 0,
        y: 0,
      );
    }

    final remaining = await repo.watchImageSlotsRemaining(kLocalBoardId).first;
    expect(remaining, 0);
  });

  test('rejects the 31st image clip with ClipCapExceededException', () async {
    for (var i = 0; i < kMaxImageClips; i++) {
      await repo.addImageClip(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        localFilePath: '/tmp/fake_$i.png',
        x: 0,
        y: 0,
      );
    }

    expect(
      () => repo.addImageClip(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        localFilePath: '/tmp/one_too_many.png',
        x: 0,
        y: 0,
      ),
      throwsA(isA<ClipCapExceededException>()),
    );
  });

  test('binned images still count toward the cap', () async {
    final ids = <String>[];
    for (var i = 0; i < kMaxImageClips; i++) {
      final id = _uuid.v4();
      ids.add(id);
      await repo.addImageClip(
        id: id,
        boardId: kLocalBoardId,
        localFilePath: '/tmp/fake_$i.png',
        x: 0,
        y: 0,
      );
    }

    await repo.binClip(ids.first);

    expect(
      () => repo.addImageClip(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        localFilePath: '/tmp/still_over.png',
        x: 0,
        y: 0,
      ),
      throwsA(isA<ClipCapExceededException>()),
    );
  });

  test('permanently deleting a clip frees a slot', () async {
    final ids = <String>[];
    for (var i = 0; i < kMaxImageClips; i++) {
      final id = _uuid.v4();
      ids.add(id);
      await repo.addImageClip(
        id: id,
        boardId: kLocalBoardId,
        localFilePath: '/tmp/fake_$i.png',
        x: 0,
        y: 0,
      );
    }

    await repo.deleteForever(ids.first);

    final clip = await repo.addImageClip(
      id: _uuid.v4(),
      boardId: kLocalBoardId,
      localFilePath: '/tmp/fits_now.png',
      x: 0,
      y: 0,
    );
    expect(clip.id, isNotEmpty);
  });

  test('text notes are never capped', () async {
    for (var i = 0; i < kMaxImageClips + 10; i++) {
      await repo.addTextNote(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        textContent: 'note $i',
        x: 0,
        y: 0,
      );
    }

    final remaining = await repo.watchImageSlotsRemaining(kLocalBoardId).first;
    expect(remaining, kMaxImageClips);
  });

  test('binClip moves a clip out of active into binned', () async {
    final id = _uuid.v4();
    await repo.addTextNote(
      id: id,
      boardId: kLocalBoardId,
      textContent: 'note',
      x: 0,
      y: 0,
    );

    await repo.binClip(id);

    final active = await repo.watchActiveClips(kLocalBoardId).first;
    final binned = await repo.watchBinnedClips(kLocalBoardId).first;
    expect(active.where((c) => c.id == id), isEmpty);
    expect(binned.where((c) => c.id == id), hasLength(1));

    await repo.restoreClip(id);
    final activeAfterRestore = await repo.watchActiveClips(kLocalBoardId).first;
    expect(activeAfterRestore.where((c) => c.id == id), hasLength(1));
  });
}
