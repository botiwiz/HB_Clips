import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/clips_repository.dart';
import 'package:hb_clips/data/repositories/kanban_boards_repository.dart';
import 'package:hb_clips/data/repositories/swimlanes_repository.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late SwimlanesRepository repo;
  late KanbanBoardsRepository kanbanBoardsRepo;
  late ClipsRepository clipsRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SwimlanesRepository(db);
    kanbanBoardsRepo = KanbanBoardsRepository(db);
    clipsRepo = ClipsRepository(db);
  });

  tearDown(() => db.close());

  Future<String> seedKanbanBoard() async {
    final boardId = _uuid.v4();
    await kanbanBoardsRepo.createKanbanBoard(
      id: boardId,
      boardId: kLocalBoardId,
      name: 'Kanban Board',
      x: 0,
      y: 0,
      width: 600,
      height: 420,
    );
    return boardId;
  }

  test('watchSwimlanes only returns lanes whose parent kanban board is on '
      'the given board', () async {
    final boardId = await seedKanbanBoard();
    final laneId = _uuid.v4();
    await repo.createSwimlane(
      id: laneId,
      kanbanBoardId: boardId,
      name: 'General',
      y: 0,
      height: 420,
      sortOrder: 0,
    );

    final lanes = await repo.watchSwimlanes(kLocalBoardId).first;
    expect(lanes.where((l) => l.id == laneId), hasLength(1));

    final lanesOnOtherBoard = await repo.watchSwimlanes('other-board').first;
    expect(lanesOnOtherBoard.where((l) => l.id == laneId), isEmpty);
  });

  test('updateTransform changes y/height independently', () async {
    final boardId = await seedKanbanBoard();
    final laneId = _uuid.v4();
    await repo.createSwimlane(
      id: laneId,
      kanbanBoardId: boardId,
      name: 'General',
      y: 0,
      height: 200,
      sortOrder: 0,
    );

    await repo.updateTransform(laneId, y: 50);
    var lane = (await repo.watchSwimlanes(kLocalBoardId).first).firstWhere(
      (l) => l.id == laneId,
    );
    expect(lane.y, 50);
    expect(lane.height, 200);

    await repo.updateTransform(laneId, height: 300);
    lane = (await repo.watchSwimlanes(kLocalBoardId).first).firstWhere(
      (l) => l.id == laneId,
    );
    expect(lane.y, 50);
    expect(lane.height, 300);
  });

  test('deleteSwimlane clears swimlaneId on its member clips instead of '
      'deleting them', () async {
    final boardId = await seedKanbanBoard();
    final laneId = _uuid.v4();
    await repo.createSwimlane(
      id: laneId,
      kanbanBoardId: boardId,
      name: 'General',
      y: 0,
      height: 420,
      sortOrder: 0,
    );

    final cardId = _uuid.v4();
    await clipsRepo.addKanbanCard(id: cardId, boardId: kLocalBoardId, x: 0, y: 0);
    await clipsRepo.setSwimlaneId(cardId, laneId);

    await repo.deleteSwimlane(laneId);

    final lanes = await repo.watchSwimlanes(kLocalBoardId).first;
    expect(lanes.where((l) => l.id == laneId), isEmpty);

    final clips = await clipsRepo.watchActiveClips(kLocalBoardId).first;
    final survivingCard = clips.firstWhere((c) => c.id == cardId);
    expect(survivingCard.swimlaneId, isNull);
  });
}
