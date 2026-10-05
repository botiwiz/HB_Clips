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
