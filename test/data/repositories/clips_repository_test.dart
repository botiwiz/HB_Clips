import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/clip.dart';
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

  test('addLinkClip persists linkUrl and type == link', () async {
    final id = _uuid.v4();
    await repo.addLinkClip(
      id: id,
      boardId: kLocalBoardId,
      linkUrl: 'https://example.com/article',
      x: 0,
      y: 0,
    );

    final clips = await repo.watchActiveClips(kLocalBoardId).first;
    final clip = clips.firstWhere((c) => c.id == id);
    expect(clip.type, ClipType.link);
    expect(clip.linkUrl, 'https://example.com/article');
    expect(clip.linkTitle, isNull);
    expect(clip.localFilePath, isNull);
  });

  test('updateLinkMetadata with only a title leaves localFilePath untouched '
      'and vice versa', () async {
    final id = _uuid.v4();
    await repo.addLinkClip(
      id: id,
      boardId: kLocalBoardId,
      linkUrl: 'https://example.com',
      x: 0,
      y: 0,
    );

    await repo.updateLinkMetadata(id, title: 'Example Site');
    var clip = (await repo.watchActiveClips(kLocalBoardId).first).firstWhere(
      (c) => c.id == id,
    );
    expect(clip.linkTitle, 'Example Site');
    expect(clip.localFilePath, isNull);

    await repo.updateLinkMetadata(id, thumbnailPath: '/tmp/thumb.png');
    clip = (await repo.watchActiveClips(kLocalBoardId).first).firstWhere(
      (c) => c.id == id,
    );
    expect(clip.linkTitle, 'Example Site');
    expect(clip.localFilePath, '/tmp/thumb.png');
  });

  test('duplicateClip on a link clip carries linkUrl/linkTitle over', () async {
    final sourceId = _uuid.v4();
    await repo.addLinkClip(
      id: sourceId,
      boardId: kLocalBoardId,
      linkUrl: 'https://example.com',
      x: 0,
      y: 0,
    );
    await repo.updateLinkMetadata(sourceId, title: 'Example Site');
    final source = (await repo.watchActiveClips(kLocalBoardId).first)
        .firstWhere((c) => c.id == sourceId);

    final duplicate = await repo.duplicateClip(
      source,
      newId: _uuid.v4(),
      groupId: null,
      frameId: null,
    );

    expect(duplicate.type, ClipType.link);
    expect(duplicate.linkUrl, 'https://example.com');
    expect(duplicate.linkTitle, 'Example Site');
  });
}
