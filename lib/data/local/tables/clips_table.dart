import 'package:drift/drift.dart';

/// A clip on the board: an image/screenshot, a text note, or a vector
/// shape primitive.
///
/// Named `ClipRow` (via [DataClassName]) so it doesn't collide with the
/// domain-level `Clip` model in `data/models/clip.dart`.
@DataClassName('ClipRow')
class Clips extends Table {
  /// Client-generated UUID so offline creation works without a round trip.
  TextColumn get id => text()();
  TextColumn get boardId => text()();

  /// 'image', 'text', or 'shape'.
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

  /// Pan/zoom of the image content within this clip's fixed on-board frame
  /// (double-click a clip to enter this mode) - Flutter `Alignment`
  /// convention, -1..1 per axis, 0 = centered. Ignored for text notes.
  RealColumn get imagePanX => real().withDefault(const Constant(0.0))();
  RealColumn get imagePanY => real().withDefault(const Constant(0.0))();

  /// Multiplier on top of the frame's own base "cover" scale; always >= 1.0
  /// so the image can never show a gap inside its frame.
  RealColumn get imageZoom => real().withDefault(const Constant(1.0))();

  /// The source image's native width/height ratio - null for legacy rows
  /// or text notes, treated as "matches the frame's own aspect" (renders
  /// identically to a plain cover-fit with no pan/zoom available yet).
  RealColumn get imageAspectRatio => real().nullable()();

  /// JSON-encoded bold/italic/strikethrough ranges over [textContent] - see
  /// `TextFormatting`. Null/empty means no rich formatting. Ignored for
  /// image clips.
  TextColumn get textFormattingJson => text().nullable()();

  /// Board-space (world) font size override for a text note - null means
  /// use the app default (`kTextNoteFontSize`). Whole-note scope, not
  /// per-character-range. Ignored for image clips.
  RealColumn get fontSize => real().nullable()();

  /// When non-null, the board-view scale this text note's on-screen size
  /// was pinned to (see the edit toolbar's "constant size" toggle) - the
  /// clip renders at `width/height * sizeLockScale` regardless of the
  /// current live zoom, instead of the usual `* view.scale`. Null means
  /// normal world-space scaling. Ignored for image clips.
  RealColumn get sizeLockScale => real().nullable()();

  /// Which flowchart-style vector primitive a shape clip renders as, as
  /// `ShapeKindStorage.storageValue` ('rectangle'/'ellipse'/'triangle'/
  /// 'trapezoid'/'parallelogram'). Null for every non-shape clip.
  TextColumn get shapeKind => text().nullable()();

  /// Fill color as `#RRGGBB`, or null for no fill (outline-only shape).
  /// Ignored for non-shape clips.
  TextColumn get shapeFillColorHex => text().nullable()();

  /// Stroke/outline color as `#RRGGBB`. Null falls back to a neutral
  /// default at render time rather than at write time, so the default can
  /// change later without a migration. Ignored for non-shape clips.
  TextColumn get shapeStrokeColorHex => text().nullable()();

  /// Stroke width in board-space pixels. Null falls back to
  /// `kDefaultStrokeWidth`. Ignored for non-shape clips.
  RealColumn get shapeStrokeWidth => real().nullable()();

  BoolColumn get isBinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get binnedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
