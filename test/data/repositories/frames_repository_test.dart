import 'package:drift/drift.dart' show Value;
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

  test('watchFrames emits in sortOrder order, not creation order', () async {
    await repo.createFrame(
      id: 'frame-a',
      boardId: kLocalBoardId,
      name: 'A',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
    );
    await repo.createFrame(
      id: 'frame-b',
      boardId: kLocalBoardId,
      name: 'B',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
    );
    await repo.createFrame(
      id: 'frame-c',
      boardId: kLocalBoardId,
      name: 'C',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
    );

    await repo.reorderFrames(['frame-c', 'frame-a', 'frame-b']);

    final frames = await repo.watchFrames(kLocalBoardId).first;
    expect(frames.map((f) => f.id).toList(), ['frame-c', 'frame-a', 'frame-b']);
  });

  test(
    'a newly created frame lands after (on top of) all existing frames',
    () async {
      await repo.createFrame(
        id: 'frame-a',
        boardId: kLocalBoardId,
        name: 'A',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      await repo.createFrame(
        id: 'frame-b',
        boardId: kLocalBoardId,
        name: 'B',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      await repo.reorderFrames(['frame-b', 'frame-a']);

      await repo.createFrame(
        id: 'frame-c',
        boardId: kLocalBoardId,
        name: 'C',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );

      final frames = await repo.watchFrames(kLocalBoardId).first;
      expect(frames.last.id, 'frame-c');
    },
  );

  test(
    'a duplicated frame lands after (on top of) all existing frames',
    () async {
      await repo.createFrame(
        id: 'frame-a',
        boardId: kLocalBoardId,
        name: 'A',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      await repo.createFrame(
        id: 'frame-b',
        boardId: kLocalBoardId,
        name: 'B',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      final source = await (db.select(
        db.frames,
      )..where((f) => f.id.equals('frame-b'))).getSingle();
      await repo.reorderFrames(['frame-b', 'frame-a']);

      final duplicate = await repo.duplicateFrame(source, newId: 'frame-dup');

      final frames = await repo.watchFrames(kLocalBoardId).first;
      expect(frames.last.id, duplicate.id);
    },
  );

  test(
    'frames on different boards get independently-ranked sortOrder after migration-style backfill',
    () async {
      const otherBoardId = 'other-board';
      await db
          .into(db.boards)
          .insert(
            BoardsCompanion.insert(
              id: otherBoardId,
              name: const Value('Other'),
            ),
          );

      await repo.createFrame(
        id: 'a1',
        boardId: kLocalBoardId,
        name: 'A1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      await repo.createFrame(
        id: 'a2',
        boardId: kLocalBoardId,
        name: 'A2',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );
      await repo.createFrame(
        id: 'b1',
        boardId: otherBoardId,
        name: 'B1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
      );

      final boardAFrames = await repo.watchFrames(kLocalBoardId).first;
      final boardBFrames = await repo.watchFrames(otherBoardId).first;
      expect(boardAFrames.map((f) => f.id).toList(), ['a1', 'a2']);
      expect(boardBFrames.map((f) => f.id).toList(), ['b1']);
    },
  );
}
