import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/frames_repository.dart';
import 'package:hb_clips/data/repositories/kanban_columns_repository.dart';
import 'package:hb_clips/data/repositories/kanban_elements_repository.dart';
import 'package:hb_clips/data/repositories/kanban_task_links_repository.dart';
import 'package:hb_clips/data/repositories/kanban_tasks_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late KanbanElementsRepository elementsRepo;
  late KanbanColumnsRepository columnsRepo;
  late KanbanTasksRepository tasksRepo;
  late KanbanTaskLinksRepository linksRepo;
  late ClipsRepository clipsRepo;
  late FramesRepository framesRepo;

  late KanbanColumnRow column;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    elementsRepo = KanbanElementsRepository(db);
    columnsRepo = KanbanColumnsRepository(db);
    tasksRepo = KanbanTasksRepository(db);
    linksRepo = KanbanTaskLinksRepository(db);
    clipsRepo = ClipsRepository(db);
    framesRepo = FramesRepository(db);

    await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );
    column = await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
    );
    await tasksRepo.addTask(id: 'task-1', columnId: column.id, title: 'A');
  });

  tearDown(() => db.close());

  test('addLink creates a clip-linked row', () async {
    await linksRepo.addLink(id: 'link-1', taskId: 'task-1', clipId: 'clip-1');

    final rows = await (db.select(db.kanbanTaskLinks)).get();
    expect(rows, hasLength(1));
    expect(rows.single.clipId, 'clip-1');
    expect(rows.single.frameId, isNull);
  });

  test('addLinks creates several links in one transaction', () async {
    await linksRepo.addLinks([
      (id: 'link-1', taskId: 'task-1', clipId: 'clip-1', frameId: null),
      (id: 'link-2', taskId: 'task-1', clipId: 'clip-2', frameId: null),
    ]);

    final rows = await (db.select(db.kanbanTaskLinks)).get();
    expect(rows, hasLength(2));
  });

  test('deleteLink removes exactly that row', () async {
    await linksRepo.addLink(id: 'link-1', taskId: 'task-1', clipId: 'clip-1');
    await linksRepo.addLink(id: 'link-2', taskId: 'task-1', clipId: 'clip-2');

    await linksRepo.deleteLink('link-1');

    final rows = await (db.select(db.kanbanTaskLinks)).get();
    expect(rows.map((r) => r.id), ['link-2']);
  });

  test(
    'ClipsRepository.deleteForever cascades to that clip\'s links',
    () async {
      final clip = await clipsRepo.addTextNote(
        id: _uuid.v4(),
        boardId: kLocalBoardId,
        textContent: 'linked clip',
        x: 0,
        y: 0,
      );
      await linksRepo.addLink(id: 'link-1', taskId: 'task-1', clipId: clip.id);

      await clipsRepo.deleteForever(clip.id);

      expect(await (db.select(db.kanbanTaskLinks)).get(), isEmpty);
    },
  );

  test(
    'FramesRepository.deleteFrame cascades to that frame\'s links',
    () async {
      await framesRepo.createFrame(
        id: 'frame-1',
        boardId: kLocalBoardId,
        name: 'Section',
        x: 0,
        y: 0,
        width: 400,
        height: 300,
      );
      await linksRepo.addLink(
        id: 'link-1',
        taskId: 'task-1',
        frameId: 'frame-1',
      );

      await framesRepo.deleteFrame('frame-1');

      expect(await (db.select(db.kanbanTaskLinks)).get(), isEmpty);
    },
  );

  test(
    'watchLinksForBoard only returns links for that board\'s elements',
    () async {
      await elementsRepo.createKanbanElement(
        id: 'el-other',
        boardId: 'other-board',
        name: 'Other',
        x: 0,
        y: 0,
        width: 300,
        height: 480,
      );
      final otherColumn = await columnsRepo.createColumn(
        id: 'col-other',
        kanbanElementId: 'el-other',
        name: 'Elsewhere',
      );
      await tasksRepo.addTask(id: 'task-other', columnId: otherColumn.id);

      await linksRepo.addLink(id: 'link-1', taskId: 'task-1', clipId: 'clip-1');
      await linksRepo.addLink(
        id: 'link-other',
        taskId: 'task-other',
        clipId: 'clip-other',
      );

      final links = await linksRepo.watchLinksForBoard(kLocalBoardId).first;
      expect(links.map((l) => l.id), ['link-1']);
    },
  );
}
