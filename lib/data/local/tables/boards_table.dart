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

  /// Custom background tint for this board's row in "Manage boards", as
  /// `#RRGGBB` - purely a glance-at-a-list organizational aid, no effect
  /// anywhere else. Null uses the dialog's default row background - same
  /// null-means-default convention as `Frames.backgroundColorHex`.
  TextColumn get colorHex => text().nullable()();

  /// User-controlled display order in "Manage boards" (and everywhere
  /// else boards are listed) - lower sorts first. Not necessarily
  /// contiguous; only relative order matters. Sits alongside `createdAt`
  /// rather than replacing it, since `createdAt` is also kept as a
  /// stable, never-reordered tiebreaker.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Last pan/zoom camera this board was viewed at - null means this
  /// board has never had a view saved (brand new, or predates this
  /// column), which falls back to `BoardViewState()`'s own default
  /// (centered, scale 1) - the same view every board already opens to
  /// today. Always written/read together as one (panX, panY, scale)
  /// triple; see `BoardViewPersistenceController`.
  RealColumn get viewPanX => real().nullable()();
  RealColumn get viewPanY => real().nullable()();
  RealColumn get viewScale => real().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
