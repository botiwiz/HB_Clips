import 'package:drift/drift.dart';

/// One Trello-style card inside a `KanbanColumns` row. A task's position
/// is *only* `(columnId, sortOrder)` - deliberately no board-space x/y at
/// all, so there is no coordinate a committed task could ever hold that
/// means "outside its Kanban element." See the Kanban-rebuild plan's
/// "rigidity" section - only the live drag ghost needs clamping, the data
/// model itself cannot represent an escaped card.
@DataClassName('KanbanTaskRow')
class KanbanTasks extends Table {
  TextColumn get id => text()();
  TextColumn get columnId => text()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// JSON-encoded checklist items, reusing `Checklist`'s existing
  /// one-TEXT-column convention verbatim (relocated from the old
  /// kanban-card clip to here). Null/empty means no checklist yet.
  TextColumn get checklistJson => text().nullable()();

  /// Fractional top-to-bottom display order within [columnId] - same
  /// convention as `KanbanColumns.sortOrder`, just one level down.
  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  /// Optional user-assigned accent color (e.g. `#FF8800`) - null means no
  /// custom color, same null-means-default convention as
  /// `Frames.backgroundColorHex`/`KanbanColumns.colorHex`.
  TextColumn get colorHex => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
