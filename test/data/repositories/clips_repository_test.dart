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
