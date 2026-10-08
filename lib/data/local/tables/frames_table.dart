import 'package:drift/drift.dart';

/// A named, resizable rectangle drawn behind clips, used purely to
/// visually group and label a region of the board (Miro's Frame concept).
/// `id` is a client-generated UUID, same convention as boards/clips.
@DataClassName('FrameRow')
class Frames extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get name => text().withDefault(const Constant('Frame'))();
  RealColumn get x => real().withDefault(const Constant(0))();
  RealColumn get y => real().withDefault(const Constant(0))();
  RealColumn get width => real().withDefault(const Constant(320))();
  RealColumn get height => real().withDefault(const Constant(240))();

  /// User-controlled display order in the Frames Panel (and on-canvas
  /// stacking order, since both read the same `watchFrames()` list - frames
  /// have no separate z-index concept) - lower sorts first. Not necessarily
  /// contiguous; only relative order matters. Sits alongside `createdAt`
  /// rather than replacing it, since `createdAt` is also kept as a stable,
  /// never-reordered tiebreaker.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Custom accent color for this frame's border/label/subtle fill, as
  /// `#RRGGBB`. Null uses the default neutral gray - same
  /// null-means-default convention as `Clips.backgroundColorHex`.
  TextColumn get backgroundColorHex => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
