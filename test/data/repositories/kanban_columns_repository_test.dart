import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/kanban_columns_repository.dart';
import 'package:hb_clips/data/repositories/kanban_elements_repository.dart';
import 'package:hb_clips/data/repositories/kanban_tasks_repository.dart';

void main() {
  late AppDatabase db;
  late KanbanElementsRepository elementsRepo;
  late KanbanColumnsRepository columnsRepo;
  late KanbanTasksRepository tasksRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    elementsRepo = KanbanElementsRepository(db);
    columnsRepo = KanbanColumnsRepository(db);
    tasksRepo = KanbanTasksRepository(db);
    await elementsRepo.createKanbanElement(
      id: 'el-1',
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );
  });

  tearDown(() => db.close());

  test('createColumn appends to the end unless sortOrder is given', () async {
    final a = await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
    );
    final b = await columnsRepo.createColumn(
      id: 'col-b',
      kanbanElementId: 'el-1',
      name: 'In Progress',
    );
    expect(b.sortOrder, greaterThan(a.sortOrder));
  });

  test('createColumn honors an explicit sortOrder for seeding several at '
      'once', () async {
    await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
      sortOrder: 0,
    );
    await columnsRepo.createColumn(
      id: 'col-b',
      kanbanElementId: 'el-1',
      name: 'Done',
      sortOrder: 1,
    );
    final rows = await (db.select(
      db.kanbanColumns,
    )..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
    expect(rows.map((r) => r.name), ['To Do', 'Done']);
  });

  test('deleteColumn cascades to its tasks', () async {
    final column = await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
    );
    await tasksRepo.addTask(id: 'task-1', columnId: column.id);

    await columnsRepo.deleteColumn(column.id);

    expect(await (db.select(db.kanbanTasks)).get(), isEmpty);
    expect(await (db.select(db.kanbanColumns)).get(), isEmpty);
  });

  test('watchColumnsForBoard only returns columns for that board', () async {
    await elementsRepo.createKanbanElement(
      id: 'el-other-board',
      boardId: 'other-board',
      name: 'Other',
      x: 0,
      y: 0,
      width: 300,
      height: 480,
    );
    await columnsRepo.createColumn(
      id: 'col-a',
      kanbanElementId: 'el-1',
      name: 'To Do',
    );
    await columnsRepo.createColumn(
      id: 'col-other',
      kanbanElementId: 'el-other-board',
      name: 'Elsewhere',
    );

    final columns = await columnsRepo.watchColumnsForBoard(kLocalBoardId).first;
    expect(columns.map((c) => c.id), ['col-a']);
  });
}
