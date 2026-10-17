import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/models/kanban.dart';
import 'package:hb_clips/data/repositories/kanban_columns_repository.dart';
import 'package:hb_clips/data/repositories/kanban_elements_repository.dart';
import 'package:hb_clips/data/repositories/kanban_task_links_repository.dart';
import 'package:hb_clips/data/repositories/kanban_tasks_repository.dart';

void main() {
  late AppDatabase db;
  late KanbanElementsRepository elementsRepo;
  late KanbanColumnsRepository columnsRepo;
  late KanbanTasksRepository tasksRepo;
  late KanbanTaskLinksRepository linksRepo;

  late KanbanColumnRow columnA;
  late KanbanColumnRow columnB;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    elementsRepo = KanbanElementsRepository(db);
    columnsRepo = KanbanColumnsRepository(db);
    tasksRepo = KanbanTasksRepository(db);
    linksRepo = KanbanTaskLinksRepository(db);

    await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );
    columnA = await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
    );
    columnB = await columnsRepo.createColumn(
      id: 'col-b',
      kanbanElementId: 'el-1',
      name: 'In Progress',
    );
  });

  tearDown(() => db.close());

  test('addTask appends to the end of its column', () async {
    final first = await tasksRepo.addTask(
      id: 'task-1',
      columnId: columnA.id,
      title: 'First',
    );
    final second = await tasksRepo.addTask(
      id: 'task-2',
      columnId: columnA.id,
      title: 'Second',
    );
    expect(second.sortOrder, greaterThan(first.sortOrder));
    expect(first.checklist.items, isEmpty);
  });

  test('updateChecklist round-trips a non-empty checklist', () async {
    await tasksRepo.addTask(id: 'task-1', columnId: columnA.id, title: 'A');
    const checklist = Checklist(
      items: [ChecklistItem(id: 'a', label: 'Step 1', done: true)],
    );
    await tasksRepo.updateChecklist('task-1', checklist);

    final row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    final decoded = KanbanTask.fromRow(row);
    expect(decoded.checklist.items, hasLength(1));
    expect(decoded.checklist.items.single.label, 'Step 1');
    expect(decoded.checklist.items.single.done, isTrue);
  });

  test('moveTask across columns updates both columnId and sortOrder', () async {
    await tasksRepo.addTask(id: 'task-1', columnId: columnA.id, title: 'A');

    await tasksRepo.moveTask('task-1', columnId: columnB.id, sortOrder: 5.0);

    final row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    expect(row.columnId, columnB.id);
    expect(row.sortOrder, 5.0);
  });

  test('recreateTask persists a non-null colorHex', () async {
    await tasksRepo.recreateTask(
      id: 'task-1',
      columnId: columnA.id,
      title: 'Recreated',
      checklist: Checklist.empty,
      sortOrder: 1.0,
      colorHex: '#FF8800',
    );

    final row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    expect(row.colorHex, '#FF8800');
  });

  test('recreateTask persists a null colorHex', () async {
    await tasksRepo.recreateTask(
      id: 'task-1',
      columnId: columnA.id,
      title: 'Recreated',
      checklist: Checklist.empty,
      sortOrder: 1.0,
      colorHex: null,
    );

    final row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    expect(row.colorHex, isNull);
  });

  test('updateColor sets then clears a task\'s color', () async {
    await tasksRepo.addTask(id: 'task-1', columnId: columnA.id, title: 'A');

    await tasksRepo.updateColor('task-1', '#00FF00');
    var row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    expect(row.colorHex, '#00FF00');

    await tasksRepo.updateColor('task-1', null);
    row = await (db.select(
      db.kanbanTasks,
    )..where((t) => t.id.equals('task-1'))).getSingle();
    expect(row.colorHex, isNull);
  });

  test('deleteTask cascades to its links', () async {
    await tasksRepo.addTask(id: 'task-1', columnId: columnA.id, title: 'A');
    await linksRepo.addLink(id: 'link-1', taskId: 'task-1', clipId: 'clip-1');

    await tasksRepo.deleteTask('task-1');

    expect(await (db.select(db.kanbanTasks)).get(), isEmpty);
    expect(await (db.select(db.kanbanTaskLinks)).get(), isEmpty);
  });

  test('watchTasksForBoard returns tasks across every column of the '
      'board\'s elements', () async {
    await tasksRepo.addTask(id: 'task-1', columnId: columnA.id, title: 'A');
    await tasksRepo.addTask(id: 'task-2', columnId: columnB.id, title: 'B');

    final tasks = await tasksRepo.watchTasksForBoard(kLocalBoardId).first;
    expect(tasks.map((t) => t.id).toSet(), {'task-1', 'task-2'});
  });
}
