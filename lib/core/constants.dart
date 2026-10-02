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

/// Board-space (world) font size for text-note clips, converted to screen
/// pixels via `* view.scale` at render time - the same "world unit ->
/// screen pixels" pattern already used for stroke width, so text visually
/// grows/shrinks with zoom like every other clip's content, instead of
/// staying a constant screen size.
const double kTextNoteFontSize = 14;

/// Board-space (world) padding around a text note's content, converted to
/// screen pixels via `* viewScale` at render time, same pattern as
/// [kTextNoteFontSize]. Horizontal is larger than vertical - text already
/// has natural vertical breathing room from its own line-height
/// (ascenders/descenders), so a flush left/right edge reads as visibly
/// tighter than a flush top/bottom one unless the sides get more inset.
const double kTextNoteHorizontalPadding = 8;
const double kTextNoteVerticalPadding = 2;

/// Line-height multiplier for text-note content - the single source of
/// truth shared by `TextNoteGeometry.baseStyle` (and therefore every
/// place that measures or renders text-note content), replacing what
/// used to be 3 independent `height: 1.3` literals that had to be kept
/// in sync by hand.
const double kTextNoteLineHeight = 1.3;

/// Board-space (world) radius for rounding a connector's 90-degree turns,
/// converted to screen pixels via `* view.scale` at paint time - same
/// "world unit -> screen pixels" pattern as everything else about a
/// connector's rendered size (`strokeWidth * view.scale`).
const double kConnectorCornerRadius = 10;

/// Starting highlight color (a standard highlighter yellow) for a text
/// note before its color has ever been customized via the toolbar's
/// swatch - `BoardClip.highlightColorHex` falls back to this at render
/// time, same "nullable override, constant fallback" pattern as
/// `kTextNoteFontSize`/`fontSize`.
const String kDefaultHighlightColorHex = '#FFEB3B';

/// Board-space (world) radius for rounding a text highlight's corners,
/// converted to screen pixels via `* viewScale` at paint time - same
/// "world unit -> screen pixels" pattern as `kConnectorCornerRadius`.
const double kHighlightCornerRadius = 3.5;
