import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/boards_repository.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/kanban_columns_repository.dart';
import 'package:hb_clips/data/repositories/kanban_elements_repository.dart';
import 'package:hb_clips/data/repositories/kanban_task_links_repository.dart';
import 'package:hb_clips/data/repositories/kanban_tasks_repository.dart';
import 'package:hb_clips/data/repositories/strokes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late BoardsRepository boards;
  late ClipsRepository clips;
  late StrokesRepository strokes;
  late KanbanElementsRepository kanbanElements;
  late KanbanColumnsRepository kanbanColumns;
  late KanbanTasksRepository kanbanTasks;
  late KanbanTaskLinksRepository kanbanTaskLinks;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    boards = BoardsRepository(db);
    clips = ClipsRepository(db);
    strokes = StrokesRepository(db);
    kanbanElements = KanbanElementsRepository(db);
    kanbanColumns = KanbanColumnsRepository(db);
    kanbanTasks = KanbanTasksRepository(db);
    kanbanTaskLinks = KanbanTaskLinksRepository(db);
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

  test("updateBackupFilePath records which file a board was opened from/"
      'saved to, and null clears it back to "no known file"', () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.updateBackupFilePath('board-2', '/tmp/my-board.hbbackup');
    var rows = await boards.watchBoards().first;
    expect(
      rows.firstWhere((b) => b.id == 'board-2').backupFilePath,
      '/tmp/my-board.hbbackup',
    );

    await boards.updateBackupFilePath('board-2', null);
    rows = await boards.watchBoards().first;
    expect(rows.firstWhere((b) => b.id == 'board-2').backupFilePath, isNull);
  });

  test('createBoard assigns strictly increasing sortOrder', () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.createBoard('board-3', 'Third board');
    final rows = await boards.watchBoards().first;
    final byId = {for (final b in rows) b.id: b.sortOrder};
    expect(byId[kLocalBoardId]! < byId['board-2']!, isTrue);
    expect(byId['board-2']! < byId['board-3']!, isTrue);
  });

  test('updateColor round-trips a hex value and clears back to null', () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.updateColor('board-2', '#FF00FF');
    var rows = await boards.watchBoards().first;
    expect(rows.firstWhere((b) => b.id == 'board-2').colorHex, '#FF00FF');

    await boards.updateColor('board-2', null);
    rows = await boards.watchBoards().first;
    expect(rows.firstWhere((b) => b.id == 'board-2').colorHex, isNull);
  });

  test("a freshly created board's view fields all start null", () async {
    await boards.createBoard('board-2', 'Second board');
    final rows = await boards.watchBoards().first;
    final board = rows.firstWhere((b) => b.id == 'board-2');
    expect(board.viewPanX, isNull);
    expect(board.viewPanY, isNull);
    expect(board.viewScale, isNull);
  });

  test('updateViewState round-trips panX/panY/scale', () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.updateViewState('board-2', panX: 12.5, panY: -7.0, scale: 2.0);
    final rows = await boards.watchBoards().first;
    final board = rows.firstWhere((b) => b.id == 'board-2');
    expect(board.viewPanX, 12.5);
    expect(board.viewPanY, -7.0);
    expect(board.viewScale, 2.0);
  });

  test("reorderBoards changes watchBoards()'s emitted order to match the new "
      "arrangement, independent of createdAt", () async {
    await boards.createBoard('board-2', 'Second board');
    await boards.createBoard('board-3', 'Third board');

    await boards.reorderBoards(['board-3', kLocalBoardId, 'board-2']);

    final rows = await boards.watchBoards().first;
    expect(rows.map((b) => b.id).toList(), [
      'board-3',
      kLocalBoardId,
      'board-2',
    ]);
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

  test(
    'getBoard returns the matching row, or null for an unknown id',
    () async {
      await boards.createBoard('board-2', 'Second board');
      final found = await boards.getBoard('board-2');
      expect(found?.name, 'Second board');
      expect(await boards.getBoard('nonexistent'), isNull);
    },
  );

  test(
    'deleteBoard cascades to a kanban element and its columns/tasks/links',
    () async {
      await boards.createBoard('board-2', 'Second board');
      final element = await kanbanElements.createKanbanElement(
        id: _uuid.v4(),
        boardId: 'board-2',
        name: 'Kanban',
        x: 0,
        y: 0,
        width: 300,
        height: 480,
      );
      final column = await kanbanColumns.createColumn(
        id: _uuid.v4(),
        kanbanElementId: element.id,
        name: 'To do',
      );
      final task = await kanbanTasks.addTask(
        id: _uuid.v4(),
        columnId: column.id,
        title: 'Task',
      );
      final clip = await clips.addTextNote(
        id: _uuid.v4(),
        boardId: 'board-2',
        textContent: 'hello',
        x: 0,
        y: 0,
      );
      await kanbanTaskLinks.addLink(
        id: _uuid.v4(),
        taskId: task.id,
        clipId: clip.id,
      );

      await boards.deleteBoard('board-2');

      expect(await kanbanElements.watchKanbanElements('board-2').first, isEmpty);
      expect(await kanbanColumns.watchColumnsForBoard('board-2').first, isEmpty);
      expect(await kanbanTasks.watchTasksForBoard('board-2').first, isEmpty);
      expect(
        await kanbanTaskLinks.watchLinksForBoard('board-2').first,
        isEmpty,
      );
    },
  );

  test('wipeBoardContents clears frames/clips/strokes but leaves the board '
      'row itself (and its id) untouched', () async {
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

    await boards.wipeBoardContents('board-2');

    final stillThere = await boards.getBoard('board-2');
    expect(stillThere, isNotNull);
    expect(stillThere!.name, 'Second board');
    final remainingClips = await clips.watchActiveClips('board-2').first;
    expect(remainingClips, isEmpty);
    final remainingStrokes = await strokes.watchStrokes('board-2').first;
    expect(remainingStrokes, isEmpty);
  });
}
