import 'package:drift/drift.dart';

/// A clip on the board: either an image/screenshot or a text note.
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

  /// Shared by every clip in a group; null when ungrouped. Clicking any
  /// clip in a group selects (and then drags) every clip sharing this id.
  TextColumn get groupId => text().nullable()();

  /// The frame this clip is currently nested inside, or null. Set/cleared
  /// automatically when a clip is dragged into/out of a frame's bounds
  /// (Miro's frame-containment behavior) - moving a frame moves every clip
  /// with a matching `frameId` along with it.
  TextColumn get frameId => text().nullable()();

  TextColumn get textContent => text().nullable()();

  /// Custom background color for a text note, as `#RRGGBB`. Null uses the
  /// app's default text-note surface color.
  TextColumn get backgroundColorHex => text().nullable()();

  /// Key into [LocalBlobStore] for this image clip's bytes.
  TextColumn get localFilePath => text().nullable()();

  BoolColumn get isBinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get binnedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
