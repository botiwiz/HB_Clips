import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart' show BoardClip, ShapeKind;
import '../../../data/models/connector.dart';

/// Camera transform for the infinite board: screenPoint = boardPoint *
/// scale + panOffset.
class BoardViewState {
  final Offset panOffset;
  final double scale;

  const BoardViewState({this.panOffset = Offset.zero, this.scale = 1});

  BoardViewState copyWith({Offset? panOffset, double? scale}) {
    return BoardViewState(
      panOffset: panOffset ?? this.panOffset,
      scale: scale ?? this.scale,
    );
  }
}

class BoardViewNotifier extends StateNotifier<BoardViewState> {
  BoardViewNotifier() : super(const BoardViewState());

  // Wide enough to feel unbounded in practice (pixel-level image
  // inspection needs far more than the old 4.0 cap - a 4000px photo
  // dropped into a 400px-wide clip already needs 10x zoom just to reach
  // native resolution) while staying comfortably inside double precision.
  static const double minScale = 0.001;
  static const double maxScale = 10000.0;

  void setPan(Offset panOffset) {
    state = state.copyWith(panOffset: panOffset);
  }

  void panBy(Offset delta) {
    state = state.copyWith(panOffset: state.panOffset + delta);
  }

  /// Zooms so that the board point under [focalScreenPoint] stays under the
  /// cursor - the usual "zoom towards the mouse" desktop behaviour.
  void zoomAt(Offset focalScreenPoint, double scaleFactor) {
    final newScale = (state.scale * scaleFactor).clamp(minScale, maxScale);
    final boardPoint = (focalScreenPoint - state.panOffset) / state.scale;
    final newPanOffset = focalScreenPoint - boardPoint * newScale;
    state = BoardViewState(panOffset: newPanOffset, scale: newScale);
  }

  /// Sets pan and scale together in one update - used by the inertial-pan
  /// and eased-zoom animations in `board_canvas.dart`, which need to drive
  /// both values directly from their own simulation/tween rather than
  /// through [setPan]/[zoomAt]'s incremental-from-current-state math.
  void setView(Offset panOffset, double scale) {
    state = BoardViewState(
      panOffset: panOffset,
      scale: scale.clamp(minScale, maxScale),
    );
  }

  void reset() => state = const BoardViewState();

  /// Pans and zooms so [boardRect] fills [screenSize] with [padding] screen
  /// pixels of margin on every side ("frame it to fit the screen/window").
  /// Padding is in screen pixels rather than board units, so the visual
  /// margin stays constant regardless of zoom level.
  void fitRect(Rect boardRect, Size screenSize, {double padding = 40}) {
    final availableWidth = math.max(screenSize.width - padding * 2, 1.0);
    final availableHeight = math.max(screenSize.height - padding * 2, 1.0);
    final fitScale = math.min(
      availableWidth / boardRect.width,
      availableHeight / boardRect.height,
    );
    final scale = fitScale.clamp(minScale, maxScale);
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final panOffset = screenCenter - boardRect.center * scale;
    setView(panOffset, scale);
  }
}

final boardViewProvider =
    StateNotifierProvider<BoardViewNotifier, BoardViewState>(
      (ref) => BoardViewNotifier(),
    );

/// Board-space position of the most recent pointer-down on the canvas (any
/// button, any hit target) - lets paste/drop land where the user was last
/// working instead of always the viewport center.
final lastClickBoardPositionProvider = StateProvider<Offset?>((ref) => null);

/// Ids of the currently selected clips. A plain click collapses this to a
/// single id; shift/ctrl-click toggles membership; a marquee drag replaces
/// it with everything the marquee overlapped.
final selectedClipIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Ephemeral, not-yet-persisted transform of a clip currently being dragged,
/// resized, or rotated. The board renders this instead of the DB value for
/// that clip while the gesture is in progress, and the repository is only
/// written to on pointer-up - this keeps drags smooth and avoids spamming
/// sqlite writes on every pointer-move frame.
class DraggingClip {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;

  const DraggingClip({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
  });

  DraggingClip copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) => DraggingClip(
    id: id,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
  );
}

/// Ephemeral transforms for every clip involved in the gesture currently in
/// progress: one entry per clip during a group move, always exactly one
/// entry during a resize/rotate (those are single-select only).
final groupDragProvider = StateProvider<Map<String, DraggingClip>?>(
  (ref) => null,
);

/// Board-space rectangle of an in-progress marquee-select drag, or null when
/// no marquee is active. Selection is only recomputed on pointer-up.
final marqueeRectProvider = StateProvider<Rect?>((ref) => null);

/// When true, drag/resize positions and sizes snap to [kBoardGridSpacing] -
/// a per-session UI preference, not persisted.
final snapToGridProvider = StateProvider<bool>((ref) => false);

/// Ids of every currently-selected frame - mirrors
/// [selectedClipIdsProvider]'s multi-select shape (a plain click
/// replaces the set with one id, a shift/ctrl-click toggles membership,
/// a marquee replaces it with every overlapping frame). A handful of
/// frame actions stay single-frame-only even with this model in place -
/// renaming, the color/preset dialogs, Ctrl+C/paste, and starting a
/// resize/move/duplicate drag all require (or collapse down to) exactly
/// one selected frame; see `board_screen.dart`'s build method and
/// `board_canvas.dart`'s frame-hit-test branch for where that's
/// enforced.
final selectedFrameIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Id of the frame currently showing an inline rename `TextField` over
/// its title band, or null - set on a double-click of a frame's title
/// (see `board_canvas.dart`'s frame-hit-test branch), cleared by
/// `FrameRenameOverlay` once it commits/cancels.
final renamingFrameIdProvider = StateProvider<String?>((ref) => null);

/// Ephemeral, not-yet-persisted rect of the frame currently being dragged
/// or resized - same "render this instead of the DB value, write on
/// pointer-up" role [groupDragProvider] plays for clips.
final frameDragRectProvider = StateProvider<Rect?>((ref) => null);

/// Whether the frames-list navigation panel is docked open over the canvas.
final framesPanelOpenProvider = StateProvider<bool>((ref) => false);

/// Ephemeral, live target rect for an in-progress arrange-drag - null when
/// not dragging. Lets ArrangeSelectionButton track the drag instead of
/// snapping back to the plain selection bounding box mid-gesture.
final arrangeDragRectProvider = StateProvider<Rect?>((ref) => null);

/// Id of the image clip currently in per-clip pan/zoom mode (entered via
/// double-click), or null. Per-clip - unlike the old crop tool's single
/// global on/off toggle - since a double-click already identifies exactly
/// which clip, with no "sole selection" side-channel needed.
final panZoomClipIdProvider = StateProvider<String?>((ref) => null);

/// Ephemeral pan/zoom values for the clip named by [panZoomClipIdProvider]
/// while a drag or wheel-zoom is in progress - same "render this instead of
/// the DB value, commit on release" role [DraggingClip]/[groupDragProvider]
/// play for position/size.
class ImagePanZoomLive {
  final String clipId;
  final double panX;
  final double panY;
  final double zoom;

  const ImagePanZoomLive({
    required this.clipId,
    required this.panX,
    required this.panY,
    required this.zoom,
  });
}

final panZoomLiveProvider = StateProvider<ImagePanZoomLive?>((ref) => null);

/// Live board-space rect of an in-progress "C"+drag frame redefinition -
/// same ephemeral-preview role as [marqueeRectProvider]/[frameDragRectProvider].
final defineFrameRectProvider = StateProvider<Rect?>((ref) => null);

/// Board-space coordinates of the "smart guide" edge-alignment lines
/// currently active during a group drag - see `SnapGeometry`. Null on an
/// axis means no edge is snapped on that axis; both null means no guide
/// line should be drawn at all. Rendered by `SnapGuidesOverlay`.
final snapGuidesProvider = StateProvider<({double? x, double? y})>(
  (ref) => (x: null, y: null),
);

/// Whether the one-shot text tool is armed: a click or click-drag on the
/// canvas creates a new text-note clip, then this flips back to false
/// automatically - same "arm, use once, auto-revert" contract as the draw
/// mode's eyedropper sub-tool.
final isTextToolActiveProvider = StateProvider<bool>((ref) => false);

/// Live board-space rect of an in-progress text-tool click-drag - same
/// ephemeral-preview role as [defineFrameRectProvider]/[marqueeRectProvider].
final textToolDragRectProvider = StateProvider<Rect?>((ref) => null);

/// Whether the one-shot shape tool is armed - same "arm, use once,
/// auto-revert" contract as [isTextToolActiveProvider], for placing a new
/// vector shape clip instead of a text note.
final isShapeToolActiveProvider = StateProvider<bool>((ref) => false);

/// Which [ShapeKind] the shape tool places next - set by the shape picker
/// before arming [isShapeToolActiveProvider].
final selectedShapeKindProvider = StateProvider<ShapeKind>(
  (ref) => ShapeKind.rectangle,
);

/// Live board-space rect of an in-progress shape-tool click-drag - same
/// ephemeral-preview role as [textToolDragRectProvider].
final shapeToolDragRectProvider = StateProvider<Rect?>((ref) => null);

/// Id of the text-note clip that should render as an actively-focused,
/// editable TextField instead of static Text - set the instant a new
/// text-note clip is created and cleared when editing ends (blur, Escape,
/// or a click elsewhere). Single-id: only one clip is ever in inline-edit
/// mode at a time. Same "punch a hole in the board's blanket IgnorePointer
/// for exactly one clip" role [panZoomClipIdProvider] plays for image
/// pan/zoom.
final editingTextClipIdProvider = StateProvider<String?>((ref) => null);

/// Whether the text-edit toolbar's anchored highlight-color picker bar is
/// currently open - read by `board_canvas.dart`'s click-through guard
/// (alongside `TextClipEditOverlay.screenRectFor`/`noteRectFor`) so a
/// click on the picker bar itself doesn't fall through to the canvas and
/// exit edit mode before the picker's own sliders/Done button get a
/// chance to handle it. Reset to false whenever edit mode ends.
final highlightPickerOpenProvider = StateProvider<bool>((ref) => false);

/// Snapshot of an in-progress connector drag - null when no such drag is
/// active. Same ephemeral-preview role [defineFrameRectProvider]/
/// [arrangeDragRectProvider] play elsewhere: `board_canvas.dart` updates it
/// every pointer-move, `ConnectorDraftOverlay` renders a dashed line from
/// the fixed source anchor to [cursorBoard], and nothing is written to the
/// repository until a valid drop on pointer-up.
///
/// [existingConnectorId] is null when this is a brand-new connector being
/// created (started from one of a selected text clip's 4 edge-midpoint
/// handles); when non-null, this instead represents dragging an *existing*
/// connector's endpoint to reposition/retarget it - `fromClipId`/`fromSide`
/// are copied unchanged from that connector's own source side, and
/// `ConnectorsOverlay` skips re-drawing the persisted connector while this
/// draft stands in for it.
class ConnectorDraft {
  final String fromClipId;
  final ConnectorSide fromSide;
  final Offset cursorBoard;
  final String? existingConnectorId;

  const ConnectorDraft({
    required this.fromClipId,
    required this.fromSide,
    required this.cursorBoard,
    this.existingConnectorId,
  });
}

final connectorDraftProvider = StateProvider<ConnectorDraft?>((ref) => null);

/// The connector currently selected by clicking its curve - null when
/// none is selected. Mutually exclusive with clip/frame selection: picking
/// a connector clears [selectedClipIdsProvider]/[selectedFrameIdsProvider]
/// and vice versa. Drives the connector's highlighted-red rendering, its
/// draggable endpoint handle, and Backspace/Delete deleting it instead of
/// binning a clip selection (see `board_screen.dart`'s `_binSelected`).
final selectedConnectorIdProvider = StateProvider<String?>((ref) => null);

/// A frozen, by-value snapshot of whatever was selected at Ctrl+C time -
/// either a frame (plus its children's clip rows) or a set of clips.
/// Independent of any live provider state, so a later move/delete/bin of
/// the originals can't corrupt a pending paste - `board_screen.dart`'s
/// `_copySelection`/`_pasteSelection` are the only read/write sites.
class CopiedSelection {
  final FrameRow? frame;

  /// The frame's children if [frame] is non-null, otherwise the copied
  /// clip selection itself.
  final List<BoardClip> clips;

  const CopiedSelection({this.frame, required this.clips});
}

/// The in-app Ctrl+C/Ctrl+V clipboard - null means nothing's been
/// internally copied yet, in which case Ctrl+V falls back to the
/// existing OS-clipboard image paste (`clipboard_paste_service.dart`).
final copiedSelectionProvider = StateProvider<CopiedSelection?>((ref) => null);
