import 'package:drift/drift.dart';

/// A vector annotation stroke, either attached to a clip ([clipId] set) or
/// freestanding on the board ([clipId] null). Unlimited count. Mirrors the
/// `strokes` table in `supabase/migrations/0001_init.sql`. The annotation
/// tool (Phase 3) is what actually reads/writes this table.
@DataClassName('StrokeRow')
class Strokes extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get clipId => text().nullable()();

  TextColumn get color => text().withDefault(const Constant('#FF3B30'))();
  RealColumn get strokeWidth => real().withDefault(const Constant(3))();

  /// JSON-encoded list of [x, y] board-space points.
  TextColumn get pointsJson => text()();

  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
