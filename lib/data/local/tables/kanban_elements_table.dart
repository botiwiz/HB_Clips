import 'package:drift/drift.dart';

/// A rigid, self-contained Kanban board element living on the canvas as
/// one unit - the Trello-parity replacement for the old free-floating
/// `KanbanBoards`+tagged-`Frames` composite. Unlike that predecessor's
/// x/y/width/height (a stale creation-time snapshot never read back as
/// authoritative), this row's geometry IS authoritative - the element
/// owns its own rect directly, there is nothing live to derive it from.
@DataClassName('KanbanElementRow')
class KanbanElements extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get name => text().withDefault(const Constant('Kanban Board'))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();

  /// Derived from column count * column width + gaps, recomputed whenever
  /// a column is added/removed - not independently user-resizable (see
  /// [height]).
  RealColumn get width => real().withDefault(const Constant(0))();

  /// The one interactively user-resizable dimension (one bottom-edge
  /// handle) - columns are a fixed width, Trello-style, so only the
  /// element's vertical extent is a drag gesture.
  RealColumn get height => real().withDefault(const Constant(480))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
