import 'package:drift/drift.dart';

/// A board: an independent infinite canvas of clips. Multiple boards let
/// the user keep separate collections (e.g. one per project) without them
/// all sharing one canvas. `id` is a client-generated UUID (matches
/// [Clips.boardId] and the future `boards` table in
/// `supabase/migrations/0001_init.sql`).
@DataClassName('BoardRow')
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant('My Board'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// True when this row has local changes not yet pushed to the remote
  /// backend. Same "local pending write wins over a realtime echo" role
  /// that `Clips.dirty`/`Strokes.dirty` already play.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
