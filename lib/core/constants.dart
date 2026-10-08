/// Default size (logical pixels, in board space) for a newly added clip.
const double kDefaultClipWidth = 240;
const double kDefaultClipHeight = 240;
const double kDefaultTextNoteWidth = 220;
const double kDefaultTextNoteHeight = 140;
const double kDefaultShapeWidth = 160;
const double kDefaultShapeHeight = 120;

/// Placeholder board id used before auth/multi-board support (Phase 5+)
/// exists. Every local clip belongs to this single implicit board.
const String kLocalBoardId = 'local-board';

/// Board-space spacing (logical pixels) of both the dot-grid background and
/// the optional snap-to-grid behavior - kept as one constant so the visual
/// grid and what dragging/resizing snaps to always agree.
const double kBoardGridSpacing = 32;

/// Maximum zoom multiplier for panning/zooming an image within its fixed
/// on-board frame (double-click a clip to enter this mode). Never below
/// 1.0 - see `ImagePanZoomGeometry`.
const double kMaxImageZoom = 8.0;

/// Screen-space distance (logical pixels, regardless of zoom) within which
/// a dragged selection's edge snaps to align with a nearby clip's or
/// frame's edge - see `SnapGeometry`. Converted to board units by the
/// caller (dividing by the current view scale) before comparing against
/// board-space positions.
const double kEdgeSnapThresholdPx = 8;

/// Connector/spline line thickness on screen, in logical pixels - fixed
/// regardless of zoom (like the grid dots), not derived from the per-
/// connector `strokeWidth` DB column, which PDF export still uses directly
/// for paper-space line width (see `pdf_writer.dart`).
const double kConnectorStrokeWidth = 1.5;

/// Fixed angle increment (degrees) that every clip's rotate-handle drag
/// snaps to - see `ClipGeometry.rotate`. 15 degrees matches the common
/// design-tool default (Figma, Miro) for this exact gesture.
const double kRotationSnapIncrementDegrees = 15;

/// Board-space (world) font size for text-note clips, converted to screen
/// pixels via `* view.scale` at render time - the same "world unit ->
/// screen pixels" pattern already used for stroke width, so text visually
/// grows/shrinks with zoom like every other clip's content, instead of
/// staying a constant screen size.
const double kTextNoteFontSize = 14;

/// Board-space (world) padding around a text note's content on every side,
/// converted to screen pixels via `* viewScale` at render time, same
/// pattern as [kTextNoteFontSize].
const double kTextNotePadding = 1;

/// Line-height multiplier for text-note content - the single source of
/// truth shared by `TextNoteGeometry.baseStyle` (and therefore every
/// place that measures or renders text-note content), replacing what
/// used to be 3 independent `height: 1.3` literals that had to be kept
/// in sync by hand.
const double kTextNoteLineHeight = 1.3;

/// Screen-space corner radius for every piece of rectangular app chrome -
/// cards, toolbars/pills, dialogs, menus, panels, buttons. The single
/// source of truth so no call site has to guess a number; set to 0.0 for
/// the app's current sharp-corner design. Deliberately NOT shared with
/// `kHighlightCornerRadius` below, which is a board-space geometry
/// constant in a different unit system (multiplied by `view.scale` at
/// paint time) rather than a screen-space pixel radius - it's
/// independently zeroed for the same visual effect, not tied to this
/// constant. Connector corners are sharp by construction (a mitered
/// stroke join in `ConnectorPainter`, not a radius), so there's no
/// equivalent connector constant here.
const double kCornerRadius = 0.0;

/// Starting highlight color (a standard highlighter yellow) for a text
/// note before its color has ever been customized via the toolbar's
/// swatch - `BoardClip.highlightColorHex` falls back to this at render
/// time, same "nullable override, constant fallback" pattern as
/// `kTextNoteFontSize`/`fontSize`.
const String kDefaultHighlightColorHex = '#FFEB3B';

/// Fixed screen-space pixels reserved for the live `TextField`'s cursor,
/// matching Flutter's own internal `RenderEditable` caret-margin
/// reservation (`_kCaretGap` (1px, a private Flutter constant) plus the
/// `cursorWidth` pinned on the TextField in `text_clip_edit_overlay
/// .dart` - verified against the Flutter SDK source). `RenderEditable`
/// lays its text out this many pixels narrower than the box it's given
/// (to leave room for a cursor drawn after the last character of a full
/// line) - `RenderParagraph` (what `Text`/`Text.rich` uses) and a bare
/// `TextPainter` (what `HighlightGeometry` uses) do not reserve this
/// margin, so every text-note rendering/measurement path that needs to
/// agree with the live editor's real wrapping must subtract this from
/// its own available width, or it wraps a line later than the live
/// editor actually does - the root cause of text appearing to shift
/// when entering/exiting edit mode, and of highlight rects landing
/// where the un-corrected (wider) layout would have put that text
/// rather than where the live editor's real, narrower layout does.
/// Not board-space - this is a fixed screen-pixel Flutter mechanism,
/// unrelated to the app's own board/zoom scale.
const double kTextCaretReservedWidth = 3.0;

/// Board-space (world) radius for rounding a text highlight's corners,
/// converted to screen pixels via `* viewScale` at paint time - same
/// "world unit -> screen pixels" pattern used elsewhere for board-space
/// sizes (e.g. stroke width). Set to 0.0 for the app's sharp-corner
/// design - see `kCornerRadius`'s doc comment.
const double kHighlightCornerRadius = 0.0;

/// Format version written into every `.hbbackup` file's manifest -
/// bumped only if the manifest's own JSON shape changes incompatibly.
/// `importBoardBackup` refuses to import a version newer than this.
const int kBoardBackupFormatVersion = 1;

/// File extension (no leading dot) for a board backup file - a
/// proprietary, self-contained zip container (manifest.json + embedded
/// image bytes) distinct from this app's `.pur` import/export format.
const String kBoardBackupExtension = 'hbbackup';

/// How often AutoBackupScheduler writes a fresh backup of every board
/// while the app is running (plus once a few minutes after startup, and
/// once more right before the app is backgrounded/closed - see that
/// class). Backups are cheap (same bytes `.hbbackup` export already
/// produces) so this can be fairly frequent without real cost.
const Duration kAutoBackupInterval = Duration(minutes: 30);

/// Delay before the very first automatic backup after the app starts -
/// short enough to protect a session the user closes quickly, long
/// enough not to add disk I/O to the app's own startup.
const Duration kAutoBackupInitialDelay = Duration(minutes: 2);

/// A background-triggered backup (app pause/close) is skipped if the
/// last one ran more recently than this - avoids redundant writes from
/// e.g. frequent alt-tabbing.
const Duration kAutoBackupMinGap = Duration(minutes: 5);

/// How many past backup runs (each its own timestamped folder) to keep
/// before pruning the oldest - bounds disk usage from an otherwise
/// ever-growing backups folder.
const int kAutoBackupRetentionCount = 10;
