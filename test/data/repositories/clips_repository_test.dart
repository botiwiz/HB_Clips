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

  test('duplicateClip with an explicit boardId lands the duplicate on that '
      'board instead of the source clip\'s own board, with z-order computed '
      'against the target board\'s existing clips', () async {
    const otherBoardId = 'other-board';
    final sourceId = _uuid.v4();
    await repo.addTextNote(
      id: sourceId,
      boardId: kLocalBoardId,
      textContent: 'source',
      x: 0,
      y: 0,
    );
    final source = (await repo.watchActiveClips(kLocalBoardId).first)
        .firstWhere((c) => c.id == sourceId);

    // Give the target board a clip with a high zIndex first, so a
    // duplicate landing there should sort above it - not above whatever
    // the source board's own highest zIndex happens to be.
    final existingOnOtherBoardId = _uuid.v4();
    await repo.addTextNote(
      id: existingOnOtherBoardId,
      boardId: otherBoardId,
      textContent: 'already on the other board',
      x: 0,
      y: 0,
    );
    final existingOnOtherBoard =
        (await repo.watchActiveClips(otherBoardId).first).firstWhere(
          (c) => c.id == existingOnOtherBoardId,
        );

    final duplicate = await repo.duplicateClip(
      source,
      newId: _uuid.v4(),
      groupId: null,
      frameId: null,
      boardId: otherBoardId,
    );

    expect(duplicate.boardId, otherBoardId);
    final onSourceBoard = await repo.watchActiveClips(kLocalBoardId).first;
    expect(onSourceBoard.where((c) => c.id == duplicate.id), isEmpty);
    final onTargetBoard = await repo.watchActiveClips(otherBoardId).first;
    expect(onTargetBoard.where((c) => c.id == duplicate.id), hasLength(1));
    expect(duplicate.zIndex, greaterThan(existingOnOtherBoard.zIndex));
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

  test(
    'countActiveClips counts only active (non-binned) clips on that board',
    () async {
      final activeId = _uuid.v4();
      final binnedId = _uuid.v4();
      await repo.addTextNote(
        id: activeId,
        boardId: kLocalBoardId,
        textContent: 'active',
        x: 0,
        y: 0,
      );
      await repo.addTextNote(
        id: binnedId,
        boardId: kLocalBoardId,
        textContent: 'binned',
        x: 0,
        y: 0,
      );
      await repo.binClip(binnedId);
      await repo.addTextNote(
        id: _uuid.v4(),
        boardId: 'other-board',
        textContent: 'elsewhere',
        x: 0,
        y: 0,
      );

      expect(await repo.countActiveClips(kLocalBoardId), 1);
      expect(await repo.countActiveClips('other-board'), 1);
      expect(await repo.countActiveClips('nonexistent'), 0);
    },
  );
}
