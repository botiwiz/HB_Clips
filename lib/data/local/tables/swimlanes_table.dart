import 'package:drift/drift.dart';

/// A horizontal row band within one specific kanban board's column
/// extent - NOT an independent rectangle the way Frame is: it has no
/// x/width of its own (always the full span of [kanbanBoardId]'s
/// columns, derived live - see `SwimlaneGeometry`), only its own
/// vertical range (`y`/`height`) and display order (`sortOrder`).
@DataClassName('SwimlaneRow')
class Swimlanes extends Table {
  TextColumn get id => text()();

  /// NOT NULL, unlike `Frames.kanbanBoardId` - a swimlane has no
  /// standalone meaning without a parent board (see
  /// `KanbanBoardsRepository.deleteKanbanBoard`'s cascade-delete, not
  /// cascade-unparent, for this row's children-of-a-deletion treatment).
  TextColumn get kanbanBoardId => text()();
  TextColumn get name => text().withDefault(const Constant('Lane'))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get height => real().withDefault(const Constant(200))();

  /// Top-to-bottom display order among one board's lanes - same role
  /// `Frames.sortOrder` plays, kept alongside `y` rather than derived
  /// from it so a user can reorder lanes without necessarily having them
  /// stack contiguously (e.g. a gap between two lanes).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Same null-means-default convention as `Frames.backgroundColorHex`.
  TextColumn get colorHex => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
