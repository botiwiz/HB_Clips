import 'package:drift/drift.dart';

/// A board: an independent infinite canvas of clips. Multiple boards let
/// the user keep separate collections (e.g. one per project) without them
/// all sharing one canvas. `id` is a client-generated UUID (matches
/// [Clips.boardId]).
@DataClassName('BoardRow')
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant('My Board'))();

  /// Filesystem path this board was last opened from or saved to as a
  /// `.hbbackup` file, or null if it's never been associated with one
  /// (e.g. the seeded default board, or one built from scratch). Lets
  /// "Save" write back to this exact file with no dialog, instead of
  /// always behaving like "Save As" - see `board_backup_service.dart`.
  /// Always null on web (no ambient filesystem path exists there).
  TextColumn get backupFilePath => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
