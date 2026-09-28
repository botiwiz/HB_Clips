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
}
