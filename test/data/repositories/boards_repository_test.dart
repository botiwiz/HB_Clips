import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/boards_repository.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/strokes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late BoardsRepository boards;
  late ClipsRepository clips;
  late StrokesRepository strokes;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    boards = BoardsRepository(db);
    clips = ClipsRepository(db);
    strokes = StrokesRepository(db);
  });

  tearDown(() => db.close());

  test('a fresh database is seeded with exactly the default board', () async {
    final rows = await boards.watchBoards().first;
    expect(rows, hasLength(1));
    expect(rows.single.id, kLocalBoardId);
  });

  test('createBoard adds a new board alongside the default one', () async {
    await boards.createBoard('board-2', 'Second board');
    final rows = await boards.watchBoards().first;
    expect(rows, hasLength(2));
    expect(rows.map((b) => b.name), containsAll(['My Board', 'Second board']));
  });

  test('renameBoard updates just that board\'s name', () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.renameBoard('board-2', 'Renamed');
    final rows = await boards.watchBoards().first;
    final renamed = rows.firstWhere((b) => b.id == 'board-2');
    expect(renamed.name, 'Renamed');
  });

  test('deleteBoard refuses to delete the only remaining board', () async {
    expect(
      () => boards.deleteBoard(kLocalBoardId),
      throwsA(isA<LastBoardException>()),
    );
  });

  test(
    'deleteBoard removes the board and cascades to its clips and strokes',
    () async {
      await boards.createBoard('board-2', 'Second board');
      final clip = await clips.addTextNote(
        id: _uuid.v4(),
        boardId: 'board-2',
        textContent: 'hello',
        x: 0,
        y: 0,
      );
      await strokes.addStroke(
        id: _uuid.v4(),
        boardId: 'board-2',
        clipId: clip.id,
        colorHex: '#FF3B30',
        strokeWidth: 3,
        points: const [Offset(0, 0), Offset(1, 1)],
      );
      await strokes.addStroke(
        id: _uuid.v4(),
        boardId: 'board-2',
        colorHex: '#FF3B30',
        strokeWidth: 3,
        points: const [Offset(0, 0), Offset(1, 1)],
      );

      await boards.deleteBoard('board-2');

      final remainingBoards = await boards.watchBoards().first;
      expect(remainingBoards.map((b) => b.id), [kLocalBoardId]);
      final remainingClips = await clips.watchActiveClips('board-2').first;
      expect(remainingClips, isEmpty);
      final remainingStrokes = await strokes.watchStrokes('board-2').first;
      expect(remainingStrokes, isEmpty);
    },
  );
}
