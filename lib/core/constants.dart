/// Default size (logical pixels, in board space) for a newly added clip.
const double kDefaultClipWidth = 240;
const double kDefaultClipHeight = 240;
const double kDefaultTextNoteWidth = 220;
const double kDefaultTextNoteHeight = 140;

/// Diameter of the fixed bin drop-target shown on the board.
const double kBinTargetSize = 64;

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
