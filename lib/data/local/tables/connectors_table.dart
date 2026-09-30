import 'package:drift/drift.dart';

/// A curved connector line pinned between a text-note clip's edge (fixed
/// [fromSide] midpoint) and an image clip ([toClipId]) - v1 scope is
/// text-source/image-target only, enforced by callers (this table/repo
/// doesn't validate clip types itself, same "repository trusts its caller"
/// convention as Strokes). Unlimited count.
@DataClassName('ConnectorRow')
class Connectors extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get fromClipId => text()();
  TextColumn get fromSide => text()(); // 'top'/'right'/'bottom'/'left'
  TextColumn get toClipId => text()();

  /// The target anchor's position as a fraction (0-1) of [toClipId]'s own
  /// width/height, in its local unrotated frame - lets a connector land on
  /// any specific spot on the target's surface, not just its boundary.
  /// Null (legacy rows, or any row this session's migration didn't touch)
  /// falls back to the original behavior: the anchor is recomputed live
  /// every frame as the nearest point on the target clip's (rotated)
  /// boundary to the source anchor, so it stays correct as either clip
  /// moves/resizes/rotates without a stale stored value.
  RealColumn get toRelX => real().nullable()();
  RealColumn get toRelY => real().nullable()();

  TextColumn get color => text().withDefault(const Constant('#9B9BA1'))();
  RealColumn get strokeWidth => real().withDefault(const Constant(2))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
