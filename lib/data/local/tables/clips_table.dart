import 'package:drift/drift.dart';

/// A clip on the board: either an image/screenshot (capped at
/// [kMaxImageClips]) or a text note (unlimited). Mirrors the `clips` table
/// in `supabase/migrations/0001_init.sql`.
///
/// Named `ClipRow` (via [DataClassName]) so it doesn't collide with the
/// domain-level `Clip` model in `data/models/clip.dart`.
@DataClassName('ClipRow')
class Clips extends Table {
  /// Client-generated UUID so offline creation works without a round trip.
  TextColumn get id => text()();
  TextColumn get boardId => text()();

  /// 'image' or 'text'.
  TextColumn get type => text()();

  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(200))();
  RealColumn get height => real().withDefault(const Constant(200))();
  RealColumn get rotation => real().withDefault(const Constant(0))();
  IntColumn get zIndex => integer().withDefault(const Constant(0))();

  /// 0.0 (fully transparent) to 1.0 (fully opaque, the default).
  RealColumn get opacity => real().withDefault(const Constant(1.0))();

  TextColumn get textContent => text().nullable()();

  /// Custom background color for a text note, as `#RRGGBB`. Null uses the
  /// app's default text-note surface color.
  TextColumn get backgroundColorHex => text().nullable()();

  /// Path in Supabase Storage once uploaded (Phase 6). Null until synced.
  TextColumn get storagePath => text().nullable()();

  /// On-device cached file for an image clip. Never synced directly - other
  /// devices download their own copy via [storagePath].
  TextColumn get localFilePath => text().nullable()();

  BoolColumn get isBinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get binnedAt => dateTime().nullable()();

  /// True when this row has local changes not yet pushed (Phase 6).
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
