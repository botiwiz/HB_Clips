import 'package:drift/drift.dart';

/// A named, resizable rectangle drawn behind clips, used purely to
/// visually group and label a region of the board (Miro's Frame concept).
/// `id` is a client-generated UUID, same convention as boards/clips.
/// Synced through the exact same outbox/realtime/reconciliation pattern
/// as boards/clips/strokes - nothing frame-specific about sync itself.
@DataClassName('FrameRow')
class Frames extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get name => text().withDefault(const Constant('Frame'))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(320))();
  RealColumn get height => real().withDefault(const Constant(240))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Same "local pending write wins over a realtime echo" role as
  /// `Clips.dirty`/`Strokes.dirty`/`Boards.dirty`.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
