import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/frames_repository.dart';
import 'package:hb_clips/data/repositories/kanban_boards_repository.dart';
import 'package:hb_clips/data/repositories/swimlanes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late KanbanBoardsRepository repo;
  late FramesRepository framesRepo;
  late SwimlanesRepository swimlanesRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = KanbanBoardsRepository(db);
    framesRepo = FramesRepository(db);
    swimlanesRepo = SwimlanesRepository(db);
  });

  tearDown(() => db.close());

  test(
    'deleteKanbanBoard cascade-deletes its swimlanes but only unparents '
    '(not deletes) its tagged Frames - an easy-to-get-backwards asymmetry: '
    'Frames survive as plain untagged Frames, Swimlanes vanish entirely',
    () async {
      final boardId = _uuid.v4();
      await repo.createKanbanBoard(
        id: boardId,
        boardId: kLocalBoardId,
        name: 'Kanban Board',
        x: 0,
        y: 0,
        width: 600,
        height: 420,
      );

      final frameId = _uuid.v4();
      await framesRepo.createFrame(
        id: frameId,
        boardId: kLocalBoardId,
        name: 'To Do',
        x: 0,
        y: 0,
        width: 280,
        height: 420,
        kanbanBoardId: boardId,
      );

      final laneId = _uuid.v4();
      await swimlanesRepo.createSwimlane(
        id: laneId,
        kanbanBoardId: boardId,
        name: 'General',
        y: 0,
        height: 420,
        sortOrder: 0,
      );

      await repo.deleteKanbanBoard(boardId);

      final boards = await repo.watchKanbanBoards(kLocalBoardId).first;
      expect(boards.where((b) => b.id == boardId), isEmpty);

      final lanes = await swimlanesRepo.watchSwimlanes(kLocalBoardId).first;
      expect(lanes.where((l) => l.id == laneId), isEmpty);

      final frames = await framesRepo.watchFrames(kLocalBoardId).first;
      final survivingFrame = frames.firstWhere((f) => f.id == frameId);
      expect(survivingFrame.kanbanBoardId, isNull);
    },
  );
}
