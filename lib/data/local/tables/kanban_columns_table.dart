import 'package:drift/drift.dart';

/// One Trello-style list inside a `KanbanElements` row - NOT a Frame (see
/// the Kanban-rebuild plan's architectural decision: columns are owned,
/// structured child data, never a spatially-reparentable board object).
/// Has no x/y of its own - its horizontal position is always
/// `columnIndex * (columnWidth + gap)` within its parent element, derived
/// live by `KanbanColumnGeometry`, and its vertical extent always matches
/// the parent element's content height.
@DataClassName('KanbanColumnRow')
class KanbanColumns extends Table {
  TextColumn get id => text()();
  TextColumn get kanbanElementId => text()();
  TextColumn get name => text().withDefault(const Constant('List'))();

  /// Fractional left-to-right display order among one element's columns -
  /// see the Kanban-rebuild plan's "ordering: fractional indexing"
  /// section. Reordering (or inserting a new column anywhere but the end)
  /// only ever rewrites this one row's value.
  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
