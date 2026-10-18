import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
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

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    elementsRepo = KanbanElementsRepository(db);
    columnsRepo = KanbanColumnsRepository(db);
    tasksRepo = KanbanTasksRepository(db);
    linksRepo = KanbanTaskLinksRepository(db);
  });

  tearDown(() => db.close());

  test('createKanbanElement persists the given geometry', () async {
    final element = await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 10,
      y: 20,
      width: 300,
      height: 480,
    );
    expect(element.x, 10);
    expect(element.y, 20);
    expect(element.width, 300);
    expect(element.height, 480);
  });

  test(
    'deleteKanbanElement cascades through columns, tasks, and links',
    () async {
      await elementsRepo.createKanbanElement(
        id: 'el-1',
        boardId: kLocalBoardId,
        name: 'Kanban Board',
        x: 0,
        y: 0,
        width: 300,
        height: 480,
      );
      final column = await columnsRepo.createColumn(
        id: 'col-1',
        kanbanElementId: 'el-1',
        name: 'To Do',
      );
      final task = await tasksRepo.addTask(
        id: 'task-1',
        columnId: column.id,
        title: 'Ship it',
      );
      await linksRepo.addLink(
        id: _uuid.v4(),
        taskId: task.id,
        clipId: 'clip-1',
      );

      await elementsRepo.deleteKanbanElement('el-1');

      expect(await (db.select(db.kanbanElements)).get(), isEmpty);
      expect(await (db.select(db.kanbanColumns)).get(), isEmpty);
      expect(await (db.select(db.kanbanTasks)).get(), isEmpty);
      expect(await (db.select(db.kanbanTaskLinks)).get(), isEmpty);
    },
  );

  test('updateTransform only writes the fields given', () async {
    await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );

    await elementsRepo.updateTransform('el-1', height: 600);

    final row = await (db.select(
      db.kanbanElements,
    )..where((e) => e.id.equals('el-1'))).getSingle();
    expect(row.height, 600);
    expect(row.x, 0);
    expect(row.width, 300);
  });

  test('updateTransform persists scale', () async {
    await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );

    await elementsRepo.updateTransform('el-1', scale: 1.5);

    final row = await (db.select(
      db.kanbanElements,
    )..where((e) => e.id.equals('el-1'))).getSingle();
    expect(row.scale, 1.5);
  });

  test('recreateKanbanElement carries scale through a round trip', () async {
    await elementsRepo.recreateKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 10,
      y: 20,
      width: 300,
      height: 480,
      screenPinned: false,
      scale: 2.0,
    );

    final row = await (db.select(
      db.kanbanElements,
    )..where((e) => e.id.equals('el-1'))).getSingle();
    expect(row.scale, 2.0);
  });
}
