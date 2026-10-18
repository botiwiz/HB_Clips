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

  /// When true, the element renders (and hit-tests) at the fixed
  /// on-screen rect `(pinnedScreenX, pinnedScreenY, width, height)` -
  /// literal logical pixels, unaffected by pan or zoom - the same way
  /// the minimap/toolbars already behave in this app, instead of a board
  /// object whose screen position is always `boardToScreen(x, y)`.
  /// [x]/[y] are left untouched (stale) while pinned and become
  /// authoritative again the moment the element is unpinned (the toggle
  /// converts the current pinned screen position back into board
  /// coordinates under the then-current view, so it un-pins exactly
  /// where it visually was) - keeping two separate coordinate pairs
  /// rather than reinterpreting x/y means [width]/[height] never need
  /// adjusting for pinning either, so the column-count<->width invariant
  /// in [KanbanElementGeometry.widthForColumnCount] holds unconditionally.
  BoolColumn get screenPinned => boolean().withDefault(const Constant(false))();
  RealColumn get pinnedScreenX => real().nullable()();
  RealColumn get pinnedScreenY => real().nullable()();

  /// Per-element zoom multiplier layered on top of whatever the element's
  /// own pin state already contributes to its on-screen size - unpinned,
  /// `effectiveScale = view.scale * scale` (board zoom times this); pinned,
  /// `effectiveScale = scale` alone (position is already frozen screen
  /// pixels). Folded/unfolded by the pin toggle itself so the element's
  /// apparent on-screen size never jumps at the pin/unpin instant - see
  /// `_toggleKanbanElementPin` in `board_canvas.dart`.
  RealColumn get scale => real().withDefault(const Constant(1.0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
