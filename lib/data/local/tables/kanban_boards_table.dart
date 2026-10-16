import 'package:drift/drift.dart';

/// A named group of column Frames (+ their Swimlanes) treated as one
/// insertable unit - see `SwimlaneGeometry`'s and `KanbanBoardsRepository`'s
/// doc comments for the full "derived, not cached" geometry story.
/// `x`/`y`/`width`/`height` are a creation-time snapshot only, NOT kept
/// live-synced to column drags/resizes - every renderer/hit-test instead
/// derives the real bounding extent from the live union of this board's
/// tagged Frames (`Frames.kanbanBoardId`).
@DataClassName('KanbanBoardRow')
class KanbanBoards extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get name => text().withDefault(const Constant('Kanban Board'))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(0))();
  RealColumn get height => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
