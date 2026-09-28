import 'package:drift/drift.dart';

/// A vector annotation stroke, either attached to a clip ([clipId] set) or
/// freestanding on the board ([clipId] null). Unlimited count.
@DataClassName('StrokeRow')
class Strokes extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get clipId => text().nullable()();

  TextColumn get color => text().withDefault(const Constant('#FF3B30'))();
  RealColumn get strokeWidth => real().withDefault(const Constant(3))();

  /// JSON-encoded list of [x, y] board-space points.
  TextColumn get pointsJson => text()();

  BoolColumn get dashed => boolean().withDefault(const Constant(false))();
  BoolColumn get arrowEnd => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
