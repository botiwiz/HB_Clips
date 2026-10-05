import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../../data/models/stroke.dart';
import '../../../data/providers.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../../annotation/drawing_overlay.dart';
import '../../annotation/geometry/eraser_geometry.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/image_pan_zoom_geometry.dart';
import '../geometry/selection_geometry.dart';
import '../geometry/snap_geometry.dart';
import '../geometry/text_note_geometry.dart';
import '../geometry/view_focus_geometry.dart';
import '../services/add_image_service.dart';
import '../services/eyedropper_service.dart';
import '../services/image_file_formats.dart';
import '../services/remote_image_fetch_service.dart';
import 'arrange_selection_button.dart';
import 'board_minimap.dart';
import 'clip_widget.dart';
import 'connector_draft_overlay.dart';
import 'connector_handles.dart';
import 'connectors_overlay.dart';
import 'define_frame_overlay.dart';
import 'dot_grid_background.dart';
import 'frame_rename_overlay.dart';
import 'frame_widget.dart';
import 'frames_panel.dart';
import 'group_scale_handles.dart';
import 'marquee_overlay.dart';
import 'selection_handles.dart';
import 'snap_guides_overlay.dart';
import 'text_clip_edit_overlay.dart';
import 'shape_style_popover.dart';
import 'shape_tool_drag_overlay.dart';
import 'text_tool_drag_overlay.dart';

const _uuid = Uuid();

/// The infinite pan/zoom board. Deliberately hand-rolled with a raw
/// [Listener] instead of `InteractiveViewer` + per-clip `GestureDetector`s:
/// with those, a pointer landing on a clip would register with *both* the
/// clip's drag recognizer and the canvas's pan/scale recognizer, and Flutter's
/// gesture arena resolves that contest by touch-slop timing, not by "which
/// widget is on top" - unreliable for exactly the interactions this board
/// needs (pan empty space vs. drag/resize/rotate a clip vs. marquee-select).
/// Handling pointer events directly and hit-testing the clip list (and now
/// its resize/rotate handles) ourselves keeps every one of those gestures
/// deterministic instead of arena-dependent.
///
/// Gesture priority per pointer-down, most specific first: (0) MMB or
/// Space+drag always pans, regardless of what's underneath the cursor, and
/// a plain right-click is a no-op (reserved for a future context menu) -
/// both checked before any hit-testing; then, for an ordinary left-click,
/// (1) a handle on the sole selected clip, (1.5) a handle on a multi-clip
/// selection's bounding box (group scale - only when every selected clip
/// is unrotated), (2) a clip body (rotation-aware), (3) empty canvas
/// starts a marquee.
class BoardCanvas extends ConsumerStatefulWidget {
  const BoardCanvas({super.key});

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode(debugLabel: 'BoardCanvas');

  // Resize/rotate handle drag.
  HandleKind? _activeHandle;
  BoardClip? _handleStartClip;

  // Group scale (multi-select resize) drag.
  HandleKind? _activeGroupScaleHandle;
  Map<String, BoardClip>? _groupScaleStartClips;
  Rect? _groupScaleStartRect;

  // Group move drag.
  Map<String, Offset>? _groupDragStartPositions;
  bool _groupDragMoved = false;
  String? _pendingCollapseId;

  // Set true only when the current group-drag session is dragging
  // clips just created by Alt-drag-duplicate (see the clip-body
  // hit-test branch) - the pointer-up commit branch still writes their
  // final position/frame as usual, but skips _commitTransformUndo for
  // them, since their undo is the creation-undo (pushAddClipsUndo)
  // already pushed at pointer-down, not a position-undo (they never had
  // a "before" position to restore).
  bool _groupDragIsDuplicate = false;

  // Shared by handle-drag, group-drag and rotate: board-space pointer
  // position at gesture start.
  Offset? _gestureStartPointerBoard;

  // Undo support for whichever clip-transform gesture is in progress
  // (resize/rotate handle, group-scale handle, arrange-pack, plain
  // move) - captured via _captureTransformUndo right when groupDragProvider
  // is first seeded with a gesture's starting values, consumed via
  // _commitTransformUndo right after that gesture's final repo write.
  Map<String, DraggingClip>? _undoTransformBefore;

  // Marquee select.
  Offset? _marqueeStartBoard;
  bool _marqueeMoved = false;

  // Canvas pan.
  Offset? _panPointerStart;
  Offset? _panOffsetStart;

  // Debounces wheel-zoom steps: an isolated tick (gap since the last one
  // exceeds the threshold) gets an eased transition; a rapid stream of
  // ticks (trackpad pinch/scroll, which is already continuous input) is
  // applied directly so animations don't pile up and fight each other.
  DateTime? _lastZoomSignalTime;
  AnimationController? _zoomEaseController;

  // Draw mode: the clip (if any) under the pointer when a stroke gesture
  // started - the whole stroke stays attached to it, per-clip strokes are
  // stored in that clip's local frame.
  BoardClip? _drawingClip;

  // Per-clip pan/zoom mode (double-click an image clip to enter): drag
  // repositions the image content within its fixed frame, wheel zooms it.
  DateTime? _lastClickTime;
  Offset? _lastClickPosition;
  String? _lastClickedClipId;
  BoardClip? _panZoomDragClip;
  Offset? _panZoomDragStartPan;
  Offset? _panZoomGestureStartBoard;

  // "C"+drag frame redefinition: draws a brand-new rect (marquee-style,
  // not anchored-corner resize) that becomes the selected image clip's new
  // on-board frame, resetting its pan/zoom since the old values are no
  // longer meaningful once the frame's own aspect has changed.
  BoardClip? _defineFrameClip;
  Offset? _defineFrameStartBoard;

  // Text tool: a click or click-drag while armed places a new text-note
  // clip - default size on a plain click, sized to the dragged rect
  // otherwise (see _textToolMoved, the same >2px moved-flag pattern
  // _groupDragMoved/_marqueeMoved use elsewhere in this file).
  Offset? _textToolStartBoard;
  bool _textToolMoved = false;

  // Shape tool: identical click-or-drag placement contract as the text
  // tool above, for placing a new vector shape clip instead.
  Offset? _shapeToolStartBoard;
  bool _shapeToolMoved = false;

  // Frame move/resize - only checked once a pointer-down misses every
  // clip (frames sit behind clips, see FrameGeometry's doc comment).
  String? _frameDragId;
  bool _frameResizing = false;
  Rect? _frameDragStartRect;
  Offset? _frameGestureStartPointerBoard;

  // Board-space start position of every clip nested inside the frame being
  // dragged (Miro's "contents move with the frame") - null during a resize
  // or when the dragged frame has no children. Populated at frame-drag
  // start, applied by the same delta as the frame on every move, and
  // committed to the repository on pointer-up alongside the frame itself.
  Map<String, Offset>? _frameChildStartPositions;

  // Same idea as _frameChildStartPositions, but for a frame resize: full
  // start-of-gesture snapshots (width/height too, not just position) so
  // FrameGeometry.scaleChildren can scale each child to match the frame's
  // new size. Null during a move or when the resized frame has no children.
  Map<String, BoardClip>? _frameResizeChildStart;

  // Set true only when the current frame-drag session is dragging a
  // frame + children just created by Alt-drag-duplicate (see the
  // frame hit-test branch) - the pointer-up commit branch still writes
  // the final frame/child positions as usual, but skips pushing the
  // ordinary frame-move undo entry for this session, since its undo is
  // the creation-undo (delete frame + bin children) already pushed at
  // pointer-down.
  bool _frameDragIsDuplicate = false;

  // Drag-to-arrange: dragging the ArrangeSelectionButton live-repacks the
  // selected images into whatever target rect the drag defines, anchored
  // at the selection's fixed bottom-left (the button itself sits at the
  // opposite, top-right corner). Delta-tracked from _gestureStartPointerBoard
  // (shared field, reused here) rather than snapping the corner straight to
  // the pointer, so a zero-movement click reproduces the original "pack to
  // fit the current selection" behavior exactly.
  Offset? _arrangeAnchor;
  Offset? _arrangeStartCorner;
  List<BoardClip>? _arrangeImages;

  // Connector-drag (text-clip edge handle -> image clip): started only
  // when the sole selected clip is a text clip and pointer-down hits one
  // of its 4 edge-midpoint handles (ConnectorGeometry.hitTestHandle). Live
  // preview is entirely provider-driven (connectorDraftProvider) - no
  // local Offset field needed since pointer-move just overwrites the
  // provider's state.
  String? _connectorFromClipId;
  ConnectorSide? _connectorFromSide;

  // Endpoint-retarget drag on an *existing* connector (started by grabbing
  // its endpoint circle while it's the selected connector) - set instead
  // of `_connectorFromClipId` when repositioning rather than creating.
  String? _retargetingConnectorId;

  // The connector's target before a retarget-drag started, for undo.
  ({String toClipId, double? toRelX, double? toRelY})? _retargetBefore;

  // Debug diagnostic (see _handleDropOver/_handlePerformDrop): the last
  // drag session whose platform formats were already logged, so a
  // repeated hover tick over the same drag doesn't spam the console.
  Object? _lastLoggedDropSession;

  Size _canvasSize = Size.zero;

  /// Screen-space rect of the minimap panel (mirrors its own fixed
  /// `left: 24, bottom: 24` Positioned in build()) - used as a
  /// click-through guard so a drag on the minimap doesn't also start a
  /// marquee-select on the canvas underneath it.
  Rect get _minimapRectScreen => Rect.fromLTWH(
    24,
    _canvasSize.height - 24 - BoardMinimap.panelHeight,
    BoardMinimap.panelWidth,
    BoardMinimap.panelHeight,
  );

  // Space-tap-to-focus: distinguishes a plain tap (fit the viewport to the
  // selection) from Space held through a pan-drag (the existing
  // hand-tool behavior, unaffected) - see _handleKeyEvent.
  bool _spaceKeyDown = false;
  bool _spacePanMoved = false;

  // Space-tap toggle: pressing Space again right after focusing (with the
  // same thing still selected and no manual pan/zoom in between) snaps back
  // to the view from before that focus - see _focusOnSelection.
  Rect? _focusedRect;
  BoardViewState? _preFocusView;
  BoardViewState? _postFocusView;

  @override
  void initState() {
    super.initState();
    // A real right-click's native browser context menu can steal pointer
    // capture mid-gesture (the browser never sends this canvas a matching
    // pointer-up), which is exactly the scenario that used to leave stale
    // gesture state around to hijack the next drag - right-click isn't
    // wired to anything in this app yet, so there's nothing lost by
    // suppressing the browser's own menu for it.
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      BrowserContextMenu.enableContextMenu();
    }
    _zoomEaseController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Offset _screenToBoard(Offset screenPoint, BoardViewState view) {
    return (screenPoint - view.panOffset) / view.scale;
  }

  Offset _boardToScreen(Offset boardPoint, BoardViewState view) {
    return boardPoint * view.scale + view.panOffset;
  }

  BoardClip? _hitTestClip(List<BoardClip> clips, Offset boardPoint) {
    final sorted = [...clips]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final clip in sorted) {
      if (ClipGeometry.pointInClip(boardPoint, clip)) return clip;
    }
    return null;
  }

  Connector? _findConnector(List<Connector> connectors, String id) {
    for (final connector in connectors) {
      if (connector.id == id) return connector;
    }
    return null;
  }

  /// Explicitly exits text-edit mode when a click resolves onto anything
  /// other than the clip named by [keepEditingClipId] - a deliberate,
  /// traceable "click elsewhere" action taken at the point this canvas
  /// already decides what a click hit, rather than an emergent side
  /// effect of whichever widget happens to steal Flutter's focus (that
  /// approach proved unreliable - see TextClipEditOverlay's own
  /// TextFieldTapRegion wrapper for the fix to the actual unfocus bug).
  /// A no-op if nothing is currently being edited, or if the click landed
  /// back on the very clip already being edited (e.g. repositioning the
  /// cursor inside it).
  void _exitTextEditUnlessClip(String? keepEditingClipId) {
    final editing = ref.read(editingTextClipIdProvider);
    if (editing != null && editing != keepEditingClipId) {
      ref.read(editingTextClipIdProvider.notifier).state = null;
    }
  }

  /// The connector's board-space orthogonal route, honoring its stored
  /// relative surface point when set (falls back to the nearest-boundary
  /// anchor otherwise) - shared by the endpoint-drag hit-test and the
  /// click-to-select route hit-test so both agree with what
  /// `ConnectorsOverlay` actually paints.
  List<Offset>? _connectorRoute(Connector connector, List<BoardClip> clips) {
    final fromClip = ClipGeometry.findById(clips, connector.fromClipId);
    final toClip = ClipGeometry.findById(clips, connector.toClipId);
    if (fromClip == null || toClip == null) return null;
    return ConnectorGeometry.routeBoard(
      fromClip: fromClip,
      fromSide: connector.fromSide,
      toClip: toClip,
      toRelX: connector.toRelX,
      toRelY: connector.toRelY,
    );
  }

  /// Last-created-on-top, mirroring how clips default to insertion order
  /// absent an explicit z-index concept for frames. Used for the clip-drop
  /// containment check, which must test a frame's exact body rect only.
  FrameRow? _hitTestFrame(List<FrameRow> frames, Offset boardPoint) {
    for (final frame in frames.reversed) {
      if (FrameGeometry.pointInFrame(boardPoint, frame)) return frame;
    }
    return null;
  }

  /// Same as [_hitTestFrame] but also matches a frame's title band - used
  /// only for starting a frame selection/drag, so clicking near a frame's
  /// name label (which floats above its body, often the only part not
  /// covered by child clips) reliably grabs the frame itself.
  FrameRow? _hitTestFrameForSelection(
    List<FrameRow> frames,
    Offset boardPoint,
  ) {
    for (final frame in frames.reversed) {
      if (FrameGeometry.pointInFrameOrTitleBand(boardPoint, frame)) {
        return frame;
      }
    }
    return null;
  }

  FrameRow? _findFrameById(List<FrameRow> frames, String id) {
    for (final frame in frames) {
      if (frame.id == id) return frame;
    }
    return null;
  }

  bool get _multiSelectModifierHeld =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  /// Unconditionally clears every gesture-tracking field, plus the
  /// ephemeral Riverpod state that mirrors them - called at the start of
  /// every pointer-down (so a leftover field from a gesture whose
  /// pointer-up never arrived can't hijack the next one, regardless of
  /// which button/key it uses) and from [_handlePointerCancel] (the
  /// browser can cancel a pointer sequence outright - e.g. a right-click's
  /// native context menu stealing capture mid-drag - and unlike a normal
  /// pointer-up, nothing was clearing state for that case at all).
  void _resetGestureState() {
    _activeHandle = null;
    _handleStartClip = null;
    _activeGroupScaleHandle = null;
    _groupScaleStartClips = null;
    _groupScaleStartRect = null;
    _groupDragStartPositions = null;
    _groupDragMoved = false;
    _groupDragIsDuplicate = false;
    _pendingCollapseId = null;
    _gestureStartPointerBoard = null;
    _marqueeStartBoard = null;
    _marqueeMoved = false;
    _panPointerStart = null;
    _panOffsetStart = null;
    _frameDragId = null;
    _frameResizing = false;
    _frameDragStartRect = null;
    _frameGestureStartPointerBoard = null;
    _frameChildStartPositions = null;
    _frameResizeChildStart = null;
    _frameDragIsDuplicate = false;
    _arrangeAnchor = null;
    _arrangeStartCorner = null;
    _arrangeImages = null;
    _connectorFromClipId = null;
    _connectorFromSide = null;
    _retargetingConnectorId = null;
    _retargetBefore = null;
    _panZoomDragClip = null;
    _panZoomDragStartPan = null;
    _panZoomGestureStartBoard = null;
    _defineFrameClip = null;
    _defineFrameStartBoard = null;
    _textToolStartBoard = null;
    _textToolMoved = false;
    _shapeToolStartBoard = null;
    _shapeToolMoved = false;
    _undoTransformBefore = null;
    ref.read(groupDragProvider.notifier).state = null;
    ref.read(marqueeRectProvider.notifier).state = null;
    ref.read(frameDragRectProvider.notifier).state = null;
    ref.read(arrangeDragRectProvider.notifier).state = null;
    ref.read(panZoomLiveProvider.notifier).state = null;
    ref.read(defineFrameRectProvider.notifier).state = null;
    ref.read(snapGuidesProvider.notifier).state = (x: null, y: null);
    ref.read(textToolDragRectProvider.notifier).state = null;
    ref.read(shapeToolDragRectProvider.notifier).state = null;
    ref.read(connectorDraftProvider.notifier).state = null;
  }

  /// Updates [snapGuidesProvider] only when it actually changed, avoiding a
  /// rebuild of [SnapGuidesOverlay] on every pointer-move frame where the
  /// snapped edge (or lack of one) hasn't moved.
  void _setSnapGuides(({double? x, double? y}) guides) {
    if (ref.read(snapGuidesProvider) != guides) {
      ref.read(snapGuidesProvider.notifier).state = guides;
    }
  }

  /// Captures each affected clip's pre-gesture transform for undo - call
  /// once, right when a drag/resize/rotate/scale gesture seeds
  /// [groupDragProvider] with its starting (pre-drag) values, before any
  /// pointer-move mutates them.
  void _captureTransformUndo(Map<String, DraggingClip> startMap) {
    _undoTransformBefore = Map<String, DraggingClip>.of(startMap);
  }

  /// Pushes one undo/redo entry for a just-committed drag/resize/rotate/
  /// scale gesture, pairing [after] (exactly what was just written to the
  /// DB) against the snapshot [_captureTransformUndo] took at gesture
  /// start. A no-op if nothing was captured (a gesture kind that doesn't
  /// support undo - this app has several) or nothing actually changed
  /// (e.g. a click with no drag).
  ///
  /// [frameIdBefore]/[frameIdAfter] optionally fold a same-gesture
  /// frame-reparent (clip dragged into/out of a frame) into this exact
  /// same undo entry, so undoing the drag also restores frame membership
  /// atomically instead of leaving the clip parented wherever it landed.
  void _commitTransformUndo(
    Map<String, DraggingClip> after, {
    Map<String, String?>? frameIdBefore,
    Map<String, String?>? frameIdAfter,
  }) {
    final before = _undoTransformBefore;
    _undoTransformBefore = null;
    if (before == null) return;
    final afterSnapshot = Map<String, DraggingClip>.of(after);
    final changed = afterSnapshot.entries.any((entry) {
      final b = before[entry.key];
      final a = entry.value;
      return b == null ||
          b.x != a.x ||
          b.y != a.y ||
          b.width != a.width ||
          b.height != a.height ||
          b.rotation != a.rotation;
    });
    final frameIdChanged =
        frameIdBefore != null &&
        frameIdAfter != null &&
        frameIdAfter.entries.any((e) => frameIdBefore[e.key] != e.value);
    if (!changed && !frameIdChanged) return;
    final repo = ref.read(clipsRepositoryProvider);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              for (final entry in before.entries)
                if (afterSnapshot.containsKey(entry.key))
                  repo.updateTransform(
                    entry.key,
                    x: entry.value.x,
                    y: entry.value.y,
                    width: entry.value.width,
                    height: entry.value.height,
                    rotation: entry.value.rotation,
                  ),
              if (frameIdBefore != null)
                for (final entry in frameIdBefore.entries)
                  repo.setFrameId(entry.key, entry.value),
            ]),
            redo: () => Future.wait([
              for (final entry in afterSnapshot.entries)
                repo.updateTransform(
                  entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                  width: entry.value.width,
                  height: entry.value.height,
                  rotation: entry.value.rotation,
                ),
              if (frameIdAfter != null)
                for (final entry in frameIdAfter.entries)
                  repo.setFrameId(entry.key, entry.value),
            ]),
          ),
        );
  }

  /// Alt+drag on a frame: duplicates the frame and every clip nested
  /// inside it (so the duplicate isn't a de-populated husk sitting next
  /// to a still-full original), selects the new frame, pushes one
  /// combined creation-undo covering the frame + all its duplicated
  /// children, then seeds the same frame-drag state the plain frame-move
  /// branch uses - so the rest of this gesture (pointer-move/pointer-up)
  /// drives the duplicate through the exact same generic frame-drag
  /// machinery as any other frame.
  Future<void> _startFrameDuplicateDrag(
    FrameRow source,
    List<BoardClip> clips,
    Offset boardPos,
  ) async {
    final framesRepo = ref.read(framesRepositoryProvider);
    final clipsRepo = ref.read(clipsRepositoryProvider);
    final newFrameId = _uuid.v4();
    final newFrame = await framesRepo.duplicateFrame(source, newId: newFrameId);
    if (!mounted) return;

    final children = clips.where((c) => c.frameId == source.id).toList();
    final newChildIds = <String>[];
    final childDrag = <String, DraggingClip>{};
    final childStartPositions = <String, Offset>{};
    for (final child in children) {
      final newChildId = _uuid.v4();
      final duplicate = await clipsRepo.duplicateClip(
        child,
        newId: newChildId,
        groupId: null,
        frameId: newFrameId,
      );
      if (!mounted) return;
      newChildIds.add(newChildId);
      childStartPositions[newChildId] = Offset(duplicate.x, duplicate.y);
      childDrag[newChildId] = DraggingClip(
        id: newChildId,
        x: duplicate.x,
        y: duplicate.y,
        width: duplicate.width,
        height: duplicate.height,
        rotation: duplicate.rotation,
      );
    }

    ref.read(selectedFrameIdsProvider.notifier).state = {newFrameId};
    ref.read(selectedClipIdsProvider.notifier).state = {};
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              framesRepo.deleteFrame(newFrameId),
              for (final id in newChildIds) clipsRepo.binClip(id),
            ]),
            redo: () => Future.wait([
              framesRepo.duplicateFrame(source, newId: newFrameId),
              for (final id in newChildIds) clipsRepo.restoreClip(id),
            ]),
          ),
        );

    _frameDragId = newFrameId;
    _frameDragStartRect = FrameGeometry.boardRect(newFrame);
    _frameGestureStartPointerBoard = boardPos;
    _frameDragIsDuplicate = true;
    ref.read(frameDragRectProvider.notifier).state = _frameDragStartRect;
    if (childStartPositions.isNotEmpty) {
      _frameChildStartPositions = childStartPositions;
      ref.read(groupDragProvider.notifier).state = childDrag;
    } else {
      _frameChildStartPositions = null;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetGestureState();
  }

  /// Distinguishes a plain tap of Space (fit the viewport to the current
  /// selection) from Space held through a pan-drag (the existing hand-tool
  /// behavior, unaffected - see the `_spacePanMoved = true` line in the
  /// pan branch of `_handlePointerMove`). Returned `ignored` always: this
  /// only observes the event, it never needs to consume it -
  /// `HardwareKeyboard.instance`'s pressed-key bookkeeping (what the
  /// existing space-to-pan check reads) is engine-level global state,
  /// unaffected by whether a widget "handles" the key event.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // While a note is being edited, this handler does nothing at all - no
    // `_spaceKeyDown` bookkeeping, no `_focusOnSelection()` call on key-up
    // - rather than trying to block the raw key event somewhere upstream
    // (which previously suppressed Space from reaching the platform text-
    // input channel entirely, breaking character insertion for it).
    if (ref.read(editingTextClipIdProvider) != null) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _spaceKeyDown = true;
      _spacePanMoved = false;
    } else if (event is KeyUpEvent) {
      if (_spaceKeyDown && !_spacePanMoved) {
        _focusOnSelection();
      }
      _spaceKeyDown = false;
      _spacePanMoved = false;
    }
    return KeyEventResult.ignored;
  }

  Rect? _computeFocusTargetRect() {
    final selection = ref.read(selectedClipIdsProvider);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final selectedClips = [
      for (final c in clips)
        if (selection.contains(c.id)) c,
    ];
    if (selectedClips.isNotEmpty) {
      return ClipGeometry.boardBoundingBox(selectedClips);
    }

    final selectedFrameIds = ref.read(selectedFrameIdsProvider);
    if (selectedFrameIds.isEmpty) return null;
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    Rect? union;
    for (final frame in frames) {
      if (!selectedFrameIds.contains(frame.id)) continue;
      final rect = FrameGeometry.boardRect(frame);
      union = union == null ? rect : union.expandToInclude(rect);
    }
    return union;
  }

  /// Pans/zooms the viewport to fit the current clip selection, or - if no
  /// clips are selected - the selected frame, if any (a no-op if neither is
  /// selected). Pressing Space again right after - with the same thing
  /// still selected and no manual pan/zoom in between - snaps back to the
  /// view from before the focus instead of re-fitting, via
  /// [ViewFocusGeometry.isReturningToSameFocus].
  void _focusOnSelection() {
    final targetRect = _computeFocusTargetRect();
    if (targetRect == null) return;

    final currentView = ref.read(boardViewProvider);
    if (ViewFocusGeometry.isReturningToSameFocus(
      lastFocusedRect: _focusedRect,
      lastPostFocusView: _postFocusView,
      targetRect: targetRect,
      currentView: currentView,
    )) {
      final preFocus = _preFocusView!;
      ref
          .read(boardViewProvider.notifier)
          .setView(preFocus.panOffset, preFocus.scale);
      _focusedRect = null;
      _preFocusView = null;
      _postFocusView = null;
      return;
    }

    _preFocusView = currentView;
    _focusedRect = targetRect;
    ref.read(boardViewProvider.notifier).fitRect(targetRect, _canvasSize);
    _postFocusView = ref.read(boardViewProvider);
  }

  Future<void> _handlePointerDown(PointerDownEvent event) async {
    // A click landing on the text-edit toolbar must not steal focus away
    // from the TextField before the toolbar's own button gets a chance to
    // handle the tap - checked before anything else in this function
    // touches focus (see TextClipEditOverlay.screenRectFor's doc comment;
    // same click-through-guard role the image opacity slider's own check
    // plays further down, just needed earlier here since focus, not
    // selection, is what's at stake).
    final editingTextClipId = ref.read(editingTextClipIdProvider);
    if (editingTextClipId != null) {
      final editingClip = ClipGeometry.findById(
        ref.read(activeClipsProvider).valueOrNull ?? [],
        editingTextClipId,
      );
      if (editingClip != null) {
        final view = ref.read(boardViewProvider);
        if (TextClipEditOverlay.screenRectFor(
          editingClip,
          view,
        ).contains(event.localPosition)) {
          return;
        }
        // Same guard, for the anchored highlight-color picker bar (only
        // present above the toolbar while open) - without this, dragging
        // one of its sliders would also steal focus away from the
        // TextField on every pointer-down.
        if (ref.read(highlightPickerOpenProvider) &&
            TextClipEditOverlay.highlightPickerRectFor(
              editingClip,
              view,
            ).contains(event.localPosition)) {
          return;
        }
        // Same reasoning, for the note's own box: a click/drag meant to
        // place the caret or drag-select text must never let this
        // canvas-level focus node steal focus away from the TextField
        // first - checked here, before _focusNode.requestFocus() below,
        // rather than relying solely on the later clip-body hit-test's
        // own "defer to the TextField" branch, which runs too late (after
        // focus has already moved).
        if (TextClipEditOverlay.noteRectFor(
          editingClip,
          view,
        ).contains(event.localPosition)) {
          return;
        }
      }
    }

    // A click landing on the frame-title inline-rename TextField must not
    // fall through to this canvas's own frame-selection/drag logic -
    // same click-through-guard role the text-edit toolbar's own guard
    // plays just above. Unlike that one, nothing else needs to happen
    // here when the click lands outside this rect: clicking elsewhere
    // steals focus the same way it always does, which is exactly what
    // commits/exits the rename via the overlay's own focus-loss handler.
    final renamingFrameId = ref.read(renamingFrameIdProvider);
    if (renamingFrameId != null) {
      final renamingFrame = _findFrameById(
        ref.read(boardFramesProvider).valueOrNull ?? [],
        renamingFrameId,
      );
      if (renamingFrame != null &&
          FrameRenameOverlay.screenRectFor(
            renamingFrame,
            ref.read(boardViewProvider),
          ).contains(event.localPosition)) {
        return;
      }
    }

    // A click/drag landing on the minimap is navigation only - it must
    // never also start a marquee-select on the real canvas underneath it
    // (this raw Listener sees every pointer event regardless of what the
    // minimap's own nested GestureDetector decides). Exiting an active
    // text edit still applies here, same as any other "click elsewhere".
    if (_minimapRectScreen.contains(event.localPosition)) {
      _exitTextEditUnlessClip(null);
      return;
    }

    // A click landing on the shape style popover must not fall through to
    // the canvas (which would deselect/drag) - same click-through-guard
    // role every other per-selection floating overlay in this app needs.
    final preSelection = ref.read(selectedClipIdsProvider);
    if (preSelection.length == 1) {
      final preClips = ref.read(activeClipsProvider).valueOrNull ?? [];
      final selectedClip = ClipGeometry.findById(preClips, preSelection.first);
      if (selectedClip != null && selectedClip.type == ClipType.shape) {
        final view = ref.read(boardViewProvider);
        if (ShapeStylePopover.screenRectFor(
          selectedClip,
          view,
        ).contains(event.localPosition)) {
          return;
        }
      }
    }

    _focusNode.requestFocus();
    if (ref.read(isTextToolActiveProvider)) {
      _handleTextToolPointerDown(event);
      return;
    }
    if (ref.read(isShapeToolActiveProvider)) {
      _handleShapeToolPointerDown(event);
      return;
    }
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerDown(event);
      return;
    }
    final panZoomClipId = ref.read(panZoomClipIdProvider);
    if (panZoomClipId != null) {
      _handlePanZoomPointerDown(event, panZoomClipId);
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);

    // Unconditional - any click anywhere (selecting a clip, empty canvas,
    // right-click, a pan-drag's start) counts as "where I last clicked" for
    // paste to land at.
    ref.read(lastClickBoardPositionProvider.notifier).state = boardPos;

    // Unconditional so a stale field from a gesture that never got a
    // pointer-up (dropped event, cancelled pointer) can't leak into this
    // new one no matter which button/key started it.
    _resetGestureState();

    // Middle-mouse-button or Space+drag always pans, regardless of what's
    // under the cursor - checked before any hit-testing so it takes
    // priority over grabbing a clip/handle/frame underneath the cursor
    // (previously this lived down in step 3, empty-canvas-only, so a
    // pan-drag starting on top of a clip fell through to dragging it).
    final isPanGesture =
        (event.buttons & kMiddleMouseButton != 0) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);
    if (isPanGesture) {
      _panPointerStart = event.localPosition;
      _panOffsetStart = view.panOffset;
      return;
    }

    final selection = ref.read(selectedClipIdsProvider);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];

    // "C" held + left-drag draws a brand-new rectangle that becomes the
    // sole selected image clip's on-board frame (replacing the old crop
    // tool's "click a button, then resize the pre-seeded full rect" flow).
    // Same "wins over whatever's under the cursor" priority as Space+drag.
    final isDefineFrameGesture =
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.keyC,
        ) &&
        (event.buttons & kPrimaryMouseButton != 0);
    if (isDefineFrameGesture) {
      if (selection.length == 1) {
        final clip = ClipGeometry.findById(clips, selection.first);
        if (clip != null && clip.type == ClipType.image) {
          _defineFrameClip = clip;
          _defineFrameStartBoard = boardPos;
          ref.read(defineFrameRectProvider.notifier).state = Rect.fromPoints(
            boardPos,
            boardPos,
          );
        }
      }
      return;
    }

    // A plain right-click isn't wired to anything yet (reserved for a
    // future context menu) - it shouldn't select or drag whatever's
    // underneath it either.
    if (event.buttons & kPrimaryMouseButton == 0) return;

    // 0.3. The endpoint handle of the currently-selected connector, if
    // any - checked early since it's a small, precise target the user
    // needs to be able to grab reliably to reposition/retarget it. A miss
    // here clears the connector selection (any other branch below - a
    // clip, a frame, empty canvas - implicitly means "not this connector"
    // too, except step 2.4 below, which re-selects a different connector
    // if its own curve gets clicked instead).
    final selectedConnectorId = ref.read(selectedConnectorIdProvider);
    if (selectedConnectorId != null) {
      final connectors = ref.read(activeConnectorsProvider).valueOrNull ?? [];
      final connector = _findConnector(connectors, selectedConnectorId);
      final route = connector == null
          ? null
          : _connectorRoute(connector, clips);
      if (route != null) {
        final p3Screen = route.last * view.scale + view.panOffset;
        if ((p3Screen - event.localPosition).distance <=
            ConnectorGeometry.handleHitRadius) {
          _retargetingConnectorId = connector!.id;
          _retargetBefore = (
            toClipId: connector.toClipId,
            toRelX: connector.toRelX,
            toRelY: connector.toRelY,
          );
          ref.read(connectorDraftProvider.notifier).state = ConnectorDraft(
            fromClipId: connector.fromClipId,
            fromSide: connector.fromSide,
            cursorBoard: boardPos,
            existingConnectorId: connector.id,
          );
          return;
        }
      }
      ref.read(selectedConnectorIdProvider.notifier).state = null;
    }

    // 0. A click landing on the Arrange-selection button is left entirely
    // to that widget's own tap/drag handling - otherwise this canvas would
    // see it as an empty-canvas click and clear the very selection that
    // widget depends on to render at all.
    if (selection.length >= 2) {
      final selectedClips = [
        for (final c in clips)
          if (selection.contains(c.id)) c,
      ];
      if (selectedClips.length >= 2) {
        final boardRect = ClipGeometry.boardBoundingBox(selectedClips);
        if (ArrangeSelectionButton.screenRectFor(
          boardRect,
          view,
        ).contains(event.localPosition)) {
          final images =
              [
                for (final c in selectedClips)
                  if (c.type == ClipType.image) c,
              ]..sort((a, b) {
                final byY = a.y.compareTo(b.y);
                return byY != 0 ? byY : a.x.compareTo(b.x);
              });
          if (images.length >= 2) {
            _arrangeAnchor = boardRect.bottomLeft;
            _arrangeStartCorner = boardRect.topRight;
            _arrangeImages = images;
            _gestureStartPointerBoard = boardPos;
            ref.read(arrangeDragRectProvider.notifier).state = boardRect;
            final startMap = {
              for (final c in images)
                c.id: DraggingClip(
                  id: c.id,
                  x: c.x,
                  y: c.y,
                  width: c.width,
                  height: c.height,
                  rotation: c.rotation,
                ),
            };
            ref.read(groupDragProvider.notifier).state = startMap;
            _captureTransformUndo(startMap);
          }
          return;
        }
      }
    }

    // 1. A handle on the sole selected clip takes priority over everything.
    if (selection.length == 1) {
      final selectedClip = ClipGeometry.findById(clips, selection.first);
      if (selectedClip != null) {
        final handle = ClipGeometry.hitTestHandle(
          selectedClip,
          view,
          event.localPosition,
        );
        if (handle != null) {
          _activeHandle = handle;
          _handleStartClip = selectedClip;
          _gestureStartPointerBoard = boardPos;
          final startMap = {
            selectedClip.id: DraggingClip(
              id: selectedClip.id,
              x: selectedClip.x,
              y: selectedClip.y,
              width: selectedClip.width,
              height: selectedClip.height,
              rotation: selectedClip.rotation,
            ),
          };
          ref.read(groupDragProvider.notifier).state = startMap;
          _captureTransformUndo(startMap);
          return;
        }
      }
    }

    // 1.2. A connector-drag handle at one of the sole selected clip's 4
    // edge midpoints - offered only for a text clip, checked after step
    // 1's resize/rotate hit-test has already missed (so the rotate handle,
    // which can sit close to the top-edge midpoint on small/rotated
    // clips, still wins when the pointer is nearer to it).
    if (selection.length == 1) {
      final selectedClip = ClipGeometry.findById(clips, selection.first);
      if (selectedClip != null && selectedClip.type == ClipType.text) {
        final side = ConnectorGeometry.hitTestHandle(
          selectedClip,
          view,
          event.localPosition,
        );
        if (side != null) {
          _connectorFromClipId = selectedClip.id;
          _connectorFromSide = side;
          ref.read(connectorDraftProvider.notifier).state = ConnectorDraft(
            fromClipId: selectedClip.id,
            fromSide: side,
            cursorBoard: boardPos,
          );
          return;
        }
      }
    }

    // 1.5. A handle on a multi-clip selection's bounding box (group scale)
    // - only offered when every selected clip is currently unrotated (see
    // GroupScaleHandles's doc comment for why).
    if (selection.length >= 2) {
      final selectedClips = [
        for (final c in clips)
          if (selection.contains(c.id)) c,
      ];
      if (selectedClips.length >= 2 &&
          selectedClips.every((c) => c.rotation == 0)) {
        final groupRect = ClipGeometry.boardBoundingBox(selectedClips);
        final handle = ClipGeometry.hitTestRectHandle(
          groupRect,
          view,
          event.localPosition,
        );
        if (handle != null) {
          _activeGroupScaleHandle = handle;
          _groupScaleStartClips = {for (final c in selectedClips) c.id: c};
          _groupScaleStartRect = groupRect;
          _gestureStartPointerBoard = boardPos;
          final startMap = {
            for (final c in selectedClips)
              c.id: DraggingClip(
                id: c.id,
                x: c.x,
                y: c.y,
                width: c.width,
                height: c.height,
                rotation: c.rotation,
              ),
          };
          ref.read(groupDragProvider.notifier).state = startMap;
          _captureTransformUndo(startMap);
          return;
        }
      }
    }

    // 1.8. A connector's curve - checked before the clip-body hit-test
    // since connectors now paint on top of every clip in the Stack, so a
    // click precisely on a connector line crossing an image selects the
    // connector, not the image underneath it (the curve's hit tolerance is
    // narrow - see `ConnectorGeometry.handleHitRadius` - so this doesn't
    // meaningfully shrink the clickable area of the image itself).
    final connectorsList = ref.read(activeConnectorsProvider).valueOrNull ?? [];
    for (final connector in connectorsList) {
      final route = _connectorRoute(connector, clips);
      if (route == null) continue;
      final screenRoute = [
        for (final point in route) point * view.scale + view.panOffset,
      ];
      if (ConnectorGeometry.hitTestRoute(screenRoute, event.localPosition)) {
        _exitTextEditUnlessClip(null);
        ref.read(selectedConnectorIdProvider.notifier).state = connector.id;
        ref.read(selectedClipIdsProvider.notifier).state = {};
        ref.read(selectedFrameIdsProvider.notifier).state = {};
        return;
      }
    }

    // 2. Clip body hit-test.
    final hit = _hitTestClip(clips, boardPos);
    if (hit != null) {
      // A click resolving to this clip either continues editing it
      // (matches) or explicitly exits edit mode for whatever else was
      // being edited (doesn't match) - covers every branch below.
      _exitTextEditUnlessClip(hit.id);
      // A click/drag landing on the clip currently being text-edited is
      // left entirely to the TextField's own gesture handling (caret
      // placement, click-drag-to-select, double-click-to-select-word) -
      // this app's own clip-selection/drag logic below would otherwise
      // start a clip-drag on the very same gesture (this raw Listener
      // sees every pointer event regardless of what a descendant
      // GestureDetector's gesture arena decides), moving the note instead
      // of letting a text-selection drag actually select text.
      if (hit.id == ref.read(editingTextClipIdProvider)) return;
      if (hit.type == ClipType.image &&
          _isDoubleClickOn(hit.id, event.localPosition)) {
        ref.read(selectedClipIdsProvider.notifier).state = {hit.id};
        ref.read(panZoomClipIdProvider.notifier).state = hit.id;
        return;
      }
      if (hit.type == ClipType.text &&
          _isDoubleClickOn(hit.id, event.localPosition)) {
        ref.read(selectedClipIdsProvider.notifier).state = {hit.id};
        ref.read(editingTextClipIdProvider.notifier).state = hit.id;
        return;
      }
      if (_multiSelectModifierHeld) {
        final newSelection = {...selection};
        if (!newSelection.remove(hit.id)) newSelection.add(hit.id);
        ref.read(selectedClipIdsProvider.notifier).state = newSelection;
        return;
      }

      // Alt+drag duplicates whatever would normally be dragged together
      // (the whole group if grouped, the whole existing multi-selection
      // if hit is already part of one, else just this one clip) - same
      // 3-way "what moves together" decision the plain-drag branch below
      // makes, just producing new clips instead of moving the existing
      // ones. The duplicates start exactly where their sources sit (so
      // they keep the source's frameId for now - the generic
      // frame-containment check in the pointer-up commit branch
      // reconciles it once the drag actually moves them), get selected,
      // and get pushed onto _groupDragStartPositions/groupDragProvider
      // so the rest of this gesture (pointer-move/pointer-up) drives them
      // through the exact same generic drag machinery as any other clip.
      if (HardwareKeyboard.instance.isAltPressed) {
        final Set<String> sourceIds;
        if (hit.groupId != null) {
          sourceIds = clips
              .where((c) => c.groupId == hit.groupId)
              .map((c) => c.id)
              .toSet();
        } else if (selection.contains(hit.id) && selection.length > 1) {
          sourceIds = selection;
        } else {
          sourceIds = {hit.id};
        }
        final sources = [
          for (final id in sourceIds) ClipGeometry.findById(clips, id),
        ].whereType<BoardClip>().toList();
        if (sources.isEmpty) return;
        final repo = ref.read(clipsRepositoryProvider);
        final sourceGroupIds = sources.map((c) => c.groupId).toSet();
        final duplicateGroupId =
            sources.length > 1 &&
                sourceGroupIds.length == 1 &&
                sourceGroupIds.first != null
            ? _uuid.v4()
            : null;
        final newIds = <String>[];
        final startPositions = <String, Offset>{};
        final dragMap = <String, DraggingClip>{};
        for (final source in sources) {
          final newId = _uuid.v4();
          final duplicate = await repo.duplicateClip(
            source,
            newId: newId,
            groupId: duplicateGroupId,
            frameId: source.frameId,
          );
          newIds.add(newId);
          startPositions[newId] = Offset(duplicate.x, duplicate.y);
          dragMap[newId] = DraggingClip(
            id: newId,
            x: duplicate.x,
            y: duplicate.y,
            width: duplicate.width,
            height: duplicate.height,
            rotation: duplicate.rotation,
          );
        }
        if (!mounted) return;
        ref.read(selectedClipIdsProvider.notifier).state = newIds.toSet();
        pushAddClipsUndo(ref, newIds);
        _groupDragStartPositions = startPositions;
        _groupDragIsDuplicate = true;
        _gestureStartPointerBoard = boardPos;
        ref.read(groupDragProvider.notifier).state = dragMap;
        return;
      }

      final Set<String> activeSelection;
      if (hit.groupId != null) {
        // A plain click on a grouped clip always selects the whole group -
        // only a modifier-click (handled above) picks one member out.
        activeSelection = clips
            .where((c) => c.groupId == hit.groupId)
            .map((c) => c.id)
            .toSet();
        ref.read(selectedClipIdsProvider.notifier).state = activeSelection;
        _pendingCollapseId = null;
      } else if (selection.contains(hit.id) && selection.length > 1) {
        activeSelection = selection;
        _pendingCollapseId = hit.id;
      } else {
        activeSelection = {hit.id};
        ref.read(selectedClipIdsProvider.notifier).state = activeSelection;
        _pendingCollapseId = null;
      }

      final startPositions = <String, Offset>{};
      final dragMap = <String, DraggingClip>{};
      for (final id in activeSelection) {
        final c = ClipGeometry.findById(clips, id);
        if (c == null) continue;
        startPositions[id] = Offset(c.x, c.y);
        dragMap[id] = DraggingClip(
          id: id,
          x: c.x,
          y: c.y,
          width: c.width,
          height: c.height,
          rotation: c.rotation,
        );
      }
      _groupDragStartPositions = startPositions;
      _gestureStartPointerBoard = boardPos;
      ref.read(groupDragProvider.notifier).state = dragMap;
      _captureTransformUndo(dragMap);
      return;
    }

    // 2.5. Frames sit behind clips - only checked once no clip was hit.
    // A resize-handle hit only applies when exactly one frame is
    // selected - resize (like a plain move) is deliberately kept
    // single-frame-only even though selection itself can hold several.
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameIds = ref.read(selectedFrameIdsProvider);
    if (selectedFrameIds.length == 1) {
      final selectedFrame = _findFrameById(frames, selectedFrameIds.first);
      if (selectedFrame != null &&
          FrameGeometry.hitTestResizeHandle(
            selectedFrame,
            view,
            event.localPosition,
          )) {
        _exitTextEditUnlessClip(null);
        _frameResizing = true;
        _frameDragId = selectedFrame.id;
        _frameDragStartRect = FrameGeometry.boardRect(selectedFrame);
        ref.read(frameDragRectProvider.notifier).state = _frameDragStartRect;

        // Same "contents follow the frame" contract as a plain frame move
        // (see below), but the resize branch needs each child's full
        // width/height too so FrameGeometry.scaleChildren can scale them.
        final resizingChildren = clips
            .where((c) => c.frameId == selectedFrame.id)
            .toList();
        if (resizingChildren.isNotEmpty) {
          _frameResizeChildStart = {for (final c in resizingChildren) c.id: c};
          ref.read(groupDragProvider.notifier).state = {
            for (final c in resizingChildren)
              c.id: DraggingClip(
                id: c.id,
                x: c.x,
                y: c.y,
                width: c.width,
                height: c.height,
                rotation: c.rotation,
              ),
          };
        } else {
          _frameResizeChildStart = null;
        }
        return;
      }
    }
    final hitFrame = _hitTestFrameForSelection(frames, boardPos);
    if (hitFrame != null) {
      _exitTextEditUnlessClip(null);
      if (FrameGeometry.pointInTitleBand(boardPos, hitFrame) &&
          _isDoubleClickOn(hitFrame.id, event.localPosition)) {
        ref.read(selectedFrameIdsProvider.notifier).state = {hitFrame.id};
        ref.read(renamingFrameIdProvider.notifier).state = hitFrame.id;
        return;
      }
      if (HardwareKeyboard.instance.isAltPressed) {
        await _startFrameDuplicateDrag(hitFrame, clips, boardPos);
        return;
      }
      if (_multiSelectModifierHeld) {
        final newSelection = {...selectedFrameIds};
        if (!newSelection.remove(hitFrame.id)) newSelection.add(hitFrame.id);
        ref.read(selectedFrameIdsProvider.notifier).state = newSelection;
        return;
      }
      ref.read(selectedFrameIdsProvider.notifier).state = {hitFrame.id};
      _frameDragId = hitFrame.id;
      _frameDragStartRect = FrameGeometry.boardRect(hitFrame);
      _frameGestureStartPointerBoard = boardPos;
      ref.read(frameDragRectProvider.notifier).state = _frameDragStartRect;

      // Every clip currently nested in this frame moves with it - seed the
      // same ephemeral drag map clip-drags use, keyed by each child's own
      // start position so the per-move delta below is additive per-clip.
      final children = clips.where((c) => c.frameId == hitFrame.id).toList();
      if (children.isNotEmpty) {
        _frameChildStartPositions = {
          for (final c in children) c.id: Offset(c.x, c.y),
        };
        ref.read(groupDragProvider.notifier).state = {
          for (final c in children)
            c.id: DraggingClip(
              id: c.id,
              x: c.x,
              y: c.y,
              width: c.width,
              height: c.height,
              rotation: c.rotation,
            ),
        };
      } else {
        _frameChildStartPositions = null;
      }
      return;
    }
    if (selectedFrameIds.isNotEmpty) {
      ref.read(selectedFrameIdsProvider.notifier).state = {};
    }

    // 3. Empty canvas: always a marquee now (pan was already handled above,
    // before any hit-testing even started).
    _exitTextEditUnlessClip(null);
    _marqueeStartBoard = boardPos;
    ref.read(marqueeRectProvider.notifier).state = Rect.fromPoints(
      boardPos,
      boardPos,
    );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_textToolStartBoard != null) {
      _handleTextToolPointerMove(event);
      return;
    }
    if (_shapeToolStartBoard != null) {
      _handleShapeToolPointerMove(event);
      return;
    }
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerMove(event);
      return;
    }
    if (_panZoomDragClip != null) {
      _handlePanZoomPointerMove(event);
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);

    if (_connectorFromClipId != null && _connectorFromSide != null) {
      ref.read(connectorDraftProvider.notifier).state = ConnectorDraft(
        fromClipId: _connectorFromClipId!,
        fromSide: _connectorFromSide!,
        cursorBoard: boardPos,
      );
      return;
    }

    if (_retargetingConnectorId != null) {
      final draft = ref.read(connectorDraftProvider);
      if (draft != null) {
        ref.read(connectorDraftProvider.notifier).state = ConnectorDraft(
          fromClipId: draft.fromClipId,
          fromSide: draft.fromSide,
          cursorBoard: boardPos,
          existingConnectorId: draft.existingConnectorId,
        );
      }
      return;
    }

    if (_defineFrameClip != null && _defineFrameStartBoard != null) {
      ref.read(defineFrameRectProvider.notifier).state = Rect.fromPoints(
        _defineFrameStartBoard!,
        boardPos,
      );
      return;
    }

    if (_activeHandle != null && _handleStartClip != null) {
      final id = _handleStartClip!.id;
      final current = ref.read(groupDragProvider)?[id];
      if (current == null) return;
      if (_activeHandle == HandleKind.rotate) {
        final newRotation = ClipGeometry.rotate(
          rotation0: _handleStartClip!.rotation,
          center: ClipGeometry.clipCenter(_handleStartClip!),
          startPointerBoard: _gestureStartPointerBoard!,
          currentPointerBoard: boardPos,
        );
        ref.read(groupDragProvider.notifier).state = {
          id: current.copyWith(rotation: newRotation),
        };
      } else {
        final snap = ref.read(snapToGridProvider);
        var resizePointer = boardPos;
        if (!snap) {
          final others = [
            for (final c in ref.read(activeClipsProvider).valueOrNull ?? [])
              if (c.id != id) Rect.fromLTWH(c.x, c.y, c.width, c.height),
            for (final f in ref.read(boardFramesProvider).valueOrNull ?? [])
              FrameGeometry.boardRect(f),
          ];
          final pointSnap = SnapGeometry.snapPoint(
            point: boardPos,
            others: others,
            threshold: kEdgeSnapThresholdPx / view.scale,
          );
          resizePointer = pointSnap.point;
          _setSnapGuides((x: pointSnap.guideX, y: pointSnap.guideY));
        } else {
          _setSnapGuides((x: null, y: null));
        }
        final result = ClipGeometry.resize(
          startClip: _handleStartClip!,
          corner: _activeHandle!,
          pointerBoard: resizePointer,
        );
        final resultX = snap
            ? ClipGeometry.snap(result.x, kBoardGridSpacing)
            : result.x;
        final resultWidth = snap
            ? ClipGeometry.snap(result.width, kBoardGridSpacing)
            : result.width;
        double resultY;
        double resultHeight;
        if (_handleStartClip!.type == ClipType.text) {
          // A text note's height is always an exact fit for its content
          // (see TextClipEditOverlay's _liveHeight/onChanged) - dragging a
          // handle only changes width (and x, following the normal
          // opposite-corner pivot above); height re-fits live to whatever
          // width is being dragged to, and y never moves, so the box's
          // top edge stays put regardless of which corner is grabbed.
          resultY = _handleStartClip!.y;
          resultHeight = TextNoteGeometry.requiredHeight(
            text: _handleStartClip!.textContent ?? '',
            formatting: _handleStartClip!.textFormatting,
            fontSize: _handleStartClip!.fontSize ?? kTextNoteFontSize,
            width: resultWidth,
          );
        } else {
          resultY = snap
              ? ClipGeometry.snap(result.y, kBoardGridSpacing)
              : result.y;
          resultHeight = snap
              ? ClipGeometry.snap(result.height, kBoardGridSpacing)
              : result.height;
        }
        ref.read(groupDragProvider.notifier).state = {
          id: current.copyWith(
            x: resultX,
            y: resultY,
            width: resultWidth,
            height: resultHeight,
          ),
        };
      }
      return;
    }

    if (_arrangeAnchor != null &&
        _arrangeStartCorner != null &&
        _arrangeImages != null) {
      final delta = boardPos - _gestureStartPointerBoard!;
      final draggedCorner = _arrangeStartCorner! + delta;
      final newRect = Rect.fromPoints(_arrangeAnchor!, draggedCorner);
      final results = ArrangeSelectionButton.packImages(
        _arrangeImages!,
        newRect,
      );
      if (results != null) {
        ref.read(groupDragProvider.notifier).state = {
          for (final entry in results.entries)
            entry.key: DraggingClip(
              id: entry.key,
              x: entry.value.x,
              y: entry.value.y,
              width: entry.value.width,
              height: entry.value.height,
              rotation: 0,
            ),
        };
      }
      ref.read(arrangeDragRectProvider.notifier).state = newRect;
      return;
    }

    if (_activeGroupScaleHandle != null &&
        _groupScaleStartClips != null &&
        _groupScaleStartRect != null) {
      final snap = ref.read(snapToGridProvider);
      var scalePointer = boardPos;
      if (!snap) {
        final groupIds = _groupScaleStartClips!.keys.toSet();
        final others = [
          for (final c in ref.read(activeClipsProvider).valueOrNull ?? [])
            if (!groupIds.contains(c.id))
              Rect.fromLTWH(c.x, c.y, c.width, c.height),
          for (final f in ref.read(boardFramesProvider).valueOrNull ?? [])
            FrameGeometry.boardRect(f),
        ];
        final pointSnap = SnapGeometry.snapPoint(
          point: boardPos,
          others: others,
          threshold: kEdgeSnapThresholdPx / view.scale,
        );
        scalePointer = pointSnap.point;
        _setSnapGuides((x: pointSnap.guideX, y: pointSnap.guideY));
      } else {
        _setSnapGuides((x: null, y: null));
      }
      final results = ClipGeometry.scaleGroup(
        startClips: _groupScaleStartClips!,
        startGroupRect: _groupScaleStartRect!,
        corner: _activeGroupScaleHandle!,
        pointerBoard: scalePointer,
      );
      final currentMap = ref.read(groupDragProvider);
      if (currentMap == null) return;
      final updated = <String, DraggingClip>{
        for (final entry in currentMap.entries)
          entry.key: results.containsKey(entry.key)
              ? entry.value.copyWith(
                  x: snap
                      ? ClipGeometry.snap(
                          results[entry.key]!.x,
                          kBoardGridSpacing,
                        )
                      : results[entry.key]!.x,
                  y: snap
                      ? ClipGeometry.snap(
                          results[entry.key]!.y,
                          kBoardGridSpacing,
                        )
                      : results[entry.key]!.y,
                  width: snap
                      ? ClipGeometry.snap(
                          results[entry.key]!.width,
                          kBoardGridSpacing,
                        )
                      : results[entry.key]!.width,
                  height: snap
                      ? ClipGeometry.snap(
                          results[entry.key]!.height,
                          kBoardGridSpacing,
                        )
                      : results[entry.key]!.height,
                )
              : entry.value,
      };
      ref.read(groupDragProvider.notifier).state = updated;
      return;
    }

    if (_groupDragStartPositions != null) {
      final delta = boardPos - _gestureStartPointerBoard!;
      if (delta.distance > 2) _groupDragMoved = true;
      final snap = ref.read(snapToGridProvider);
      final currentMap = ref.read(groupDragProvider);
      if (currentMap == null) return;

      // Smart-guide edge snapping (Figma/Miro-style) is a distinct concern
      // from grid-snap and mutually exclusive with it - only active when
      // the grid-snap toggle is off.
      var effectiveDelta = delta;
      ({double? x, double? y}) guides = (x: null, y: null);
      if (!snap) {
        final draggedIds = _groupDragStartPositions!.keys.toSet();
        final startRects = [
          for (final entry in _groupDragStartPositions!.entries)
            if (currentMap[entry.key] != null)
              Rect.fromLTWH(
                entry.value.dx,
                entry.value.dy,
                currentMap[entry.key]!.width,
                currentMap[entry.key]!.height,
              ),
        ];
        if (startRects.isNotEmpty) {
          final draggedBounds = startRects.reduce(
            (a, b) => a.expandToInclude(b),
          );
          final others = [
            for (final c in ref.read(activeClipsProvider).valueOrNull ?? [])
              if (!draggedIds.contains(c.id))
                Rect.fromLTWH(c.x, c.y, c.width, c.height),
            for (final f in ref.read(boardFramesProvider).valueOrNull ?? [])
              FrameGeometry.boardRect(f),
          ];
          final snapResult = SnapGeometry.snap(
            draggedBoundsBeforeDelta: draggedBounds,
            delta: delta,
            others: others,
            threshold: kEdgeSnapThresholdPx / view.scale,
          );
          effectiveDelta = snapResult.delta;
          guides = (x: snapResult.guideX, y: snapResult.guideY);
        }
      }
      _setSnapGuides(guides);

      final newPositions = ClipGeometry.applyGroupDelta(
        _groupDragStartPositions!,
        effectiveDelta,
      );
      final updated = <String, DraggingClip>{
        for (final entry in currentMap.entries)
          entry.key: newPositions.containsKey(entry.key)
              ? entry.value.copyWith(
                  x: snap
                      ? ClipGeometry.snap(
                          newPositions[entry.key]!.dx,
                          kBoardGridSpacing,
                        )
                      : newPositions[entry.key]!.dx,
                  y: snap
                      ? ClipGeometry.snap(
                          newPositions[entry.key]!.dy,
                          kBoardGridSpacing,
                        )
                      : newPositions[entry.key]!.dy,
                )
              : entry.value,
      };
      ref.read(groupDragProvider.notifier).state = updated;
      return;
    }

    if (_marqueeStartBoard != null) {
      final delta = boardPos - _marqueeStartBoard!;
      if (delta.distance > 2) _marqueeMoved = true;
      ref.read(marqueeRectProvider.notifier).state = Rect.fromPoints(
        _marqueeStartBoard!,
        boardPos,
      );
      return;
    }

    if (_frameResizing && _frameDragStartRect != null) {
      final resized = FrameGeometry.resize(
        startRect: _frameDragStartRect!,
        pointerBoard: boardPos,
      );
      ref.read(frameDragRectProvider.notifier).state = resized;
      if (_frameResizeChildStart != null &&
          _frameResizeChildStart!.isNotEmpty) {
        final results = FrameGeometry.scaleChildren(
          startClips: _frameResizeChildStart!,
          startRect: _frameDragStartRect!,
          newRect: resized,
        );
        ref.read(groupDragProvider.notifier).state = {
          for (final entry in results.entries)
            entry.key: DraggingClip(
              id: entry.key,
              x: entry.value.x,
              y: entry.value.y,
              width: entry.value.width,
              height: entry.value.height,
              rotation: _frameResizeChildStart![entry.key]!.rotation,
            ),
        };
      }
      return;
    }

    if (_frameDragId != null &&
        _frameDragStartRect != null &&
        _frameGestureStartPointerBoard != null) {
      final delta = boardPos - _frameGestureStartPointerBoard!;
      ref.read(frameDragRectProvider.notifier).state = _frameDragStartRect!
          .shift(delta);
      if (_frameChildStartPositions != null) {
        final currentMap = ref.read(groupDragProvider);
        if (currentMap != null) {
          final updated = <String, DraggingClip>{
            for (final entry in currentMap.entries)
              entry.key: _frameChildStartPositions!.containsKey(entry.key)
                  ? entry.value.copyWith(
                      x: _frameChildStartPositions![entry.key]!.dx + delta.dx,
                      y: _frameChildStartPositions![entry.key]!.dy + delta.dy,
                    )
                  : entry.value,
          };
          ref.read(groupDragProvider.notifier).state = updated;
        }
      }
      return;
    }

    if (_panPointerStart != null) {
      final delta = event.localPosition - _panPointerStart!;
      ref.read(boardViewProvider.notifier).setPan(_panOffsetStart! + delta);
      _spacePanMoved = true;
    }
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    if (_textToolStartBoard != null) {
      await _handleTextToolPointerUp(event);
      return;
    }
    if (_shapeToolStartBoard != null) {
      await _handleShapeToolPointerUp(event);
      return;
    }
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerUp(event);
      return;
    }
    if (_panZoomDragClip != null) {
      final drag = ref.read(panZoomLiveProvider);
      if (drag != null) {
        final panZoomRepo = ref.read(clipsRepositoryProvider);
        panZoomRepo.updateTransform(
          drag.clipId,
          panX: drag.panX,
          panY: drag.panY,
        );
        final before = _panZoomDragStartPan;
        if (before != null &&
            (before.dx != drag.panX || before.dy != drag.panY)) {
          final clipId = drag.clipId;
          final afterPan = Offset(drag.panX, drag.panY);
          ref
              .read(undoManagerProvider.notifier)
              .push(
                UndoableAction(
                  undo: () => panZoomRepo.updateTransform(
                    clipId,
                    panX: before.dx,
                    panY: before.dy,
                  ),
                  redo: () => panZoomRepo.updateTransform(
                    clipId,
                    panX: afterPan.dx,
                    panY: afterPan.dy,
                  ),
                ),
              );
        }
      }
      ref.read(panZoomLiveProvider.notifier).state = null;
      _panZoomDragClip = null;
      _panZoomDragStartPan = null;
      _panZoomGestureStartBoard = null;
      return;
    }
    final repo = ref.read(clipsRepositoryProvider);

    if (_retargetingConnectorId != null) {
      final view = ref.read(boardViewProvider);
      final boardPos = _screenToBoard(event.localPosition, view);
      final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
      final target = _hitTestClip(clipsNow, boardPos);
      if (target != null &&
          (target.type == ClipType.image || target.type == ClipType.shape)) {
        final rel = ConnectorGeometry.relativePointInClip(target, boardPos);
        final connId = _retargetingConnectorId!;
        final before = _retargetBefore;
        final connRepo = ref.read(connectorsRepositoryProvider);
        await connRepo.updateConnectorTarget(
          connId,
          toClipId: target.id,
          toRelX: rel.dx,
          toRelY: rel.dy,
        );
        if (!mounted) return;
        if (before != null &&
            (before.toClipId != target.id ||
                before.toRelX != rel.dx ||
                before.toRelY != rel.dy)) {
          ref
              .read(undoManagerProvider.notifier)
              .push(
                UndoableAction(
                  undo: () => connRepo.updateConnectorTarget(
                    connId,
                    toClipId: before.toClipId,
                    toRelX: before.toRelX,
                    toRelY: before.toRelY,
                  ),
                  redo: () => connRepo.updateConnectorTarget(
                    connId,
                    toClipId: target.id,
                    toRelX: rel.dx,
                    toRelY: rel.dy,
                  ),
                ),
              );
        }
      }
      if (!mounted) return;
      ref.read(connectorDraftProvider.notifier).state = null;
      _retargetingConnectorId = null;
      _retargetBefore = null;
      return;
    }

    if (_connectorFromClipId != null && _connectorFromSide != null) {
      final view = ref.read(boardViewProvider);
      final boardPos = _screenToBoard(event.localPosition, view);
      final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
      final target = _hitTestClip(clipsNow, boardPos);
      if (target != null &&
          (target.type == ClipType.image || target.type == ClipType.shape) &&
          target.id != _connectorFromClipId) {
        final rel = ConnectorGeometry.relativePointInClip(target, boardPos);
        final newId = _uuid.v4();
        final boardId = ref.read(currentBoardIdProvider);
        final fromClipId = _connectorFromClipId!;
        final fromSide = _connectorFromSide!;
        final toClipId = target.id;
        final connRepo = ref.read(connectorsRepositoryProvider);
        await connRepo.addConnector(
          id: newId,
          boardId: boardId,
          fromClipId: fromClipId,
          fromSide: fromSide,
          toClipId: toClipId,
          toRelX: rel.dx,
          toRelY: rel.dy,
        );
        if (!mounted) return;
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => connRepo.deleteConnector(newId),
                redo: () => connRepo.addConnector(
                  id: newId,
                  boardId: boardId,
                  fromClipId: fromClipId,
                  fromSide: fromSide,
                  toClipId: toClipId,
                  toRelX: rel.dx,
                  toRelY: rel.dy,
                ),
              ),
            );
      }
      if (!mounted) return;
      ref.read(connectorDraftProvider.notifier).state = null;
      _connectorFromClipId = null;
      _connectorFromSide = null;
      return;
    }

    if (_defineFrameClip != null) {
      final rect = ref.read(defineFrameRectProvider);
      if (rect != null &&
          rect.width >= ClipGeometry.minClipSize &&
          rect.height >= ClipGeometry.minClipSize) {
        final beforeClip = _defineFrameClip!;
        // Awaited before clearing the live rect - see the comment on the
        // arrange branch below for why: otherwise activeClipsProvider's
        // stream can still be showing the pre-gesture value for a frame or
        // two after the preview disappears, flashing the stale state.
        await repo.updateTransform(
          beforeClip.id,
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
          panX: 0.0,
          panY: 0.0,
          zoom: 1.0,
        );
        if (!mounted) return;
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => repo.updateTransform(
                  beforeClip.id,
                  x: beforeClip.x,
                  y: beforeClip.y,
                  width: beforeClip.width,
                  height: beforeClip.height,
                  panX: beforeClip.imagePanX,
                  panY: beforeClip.imagePanY,
                  zoom: beforeClip.imageZoom,
                ),
                redo: () => repo.updateTransform(
                  beforeClip.id,
                  x: rect.left,
                  y: rect.top,
                  width: rect.width,
                  height: rect.height,
                  panX: 0.0,
                  panY: 0.0,
                  zoom: 1.0,
                ),
              ),
            );
      }
      if (!mounted) return;
      ref.read(defineFrameRectProvider.notifier).state = null;
      _defineFrameClip = null;
      _defineFrameStartBoard = null;
      return;
    }

    if (_activeHandle != null && _handleStartClip != null) {
      final id = _handleStartClip!.id;
      final drag = ref.read(groupDragProvider)?[id];
      if (drag != null) {
        await repo.updateTransform(
          id,
          x: drag.x,
          y: drag.y,
          width: drag.width,
          height: drag.height,
          rotation: drag.rotation,
        );
        _commitTransformUndo({id: drag});
      }
      if (!mounted) return;
      ref.read(groupDragProvider.notifier).state = null;
      _setSnapGuides((x: null, y: null));
      _activeHandle = null;
      _handleStartClip = null;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_activeGroupScaleHandle != null && _groupScaleStartClips != null) {
      final dragMap = ref.read(groupDragProvider);
      if (dragMap != null) {
        await Future.wait([
          for (final entry in dragMap.entries)
            repo.updateTransform(
              entry.key,
              x: entry.value.x,
              y: entry.value.y,
              width: entry.value.width,
              height: entry.value.height,
            ),
        ]);
        _commitTransformUndo(dragMap);
      }
      if (!mounted) return;
      ref.read(groupDragProvider.notifier).state = null;
      _setSnapGuides((x: null, y: null));
      _activeGroupScaleHandle = null;
      _groupScaleStartClips = null;
      _groupScaleStartRect = null;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_arrangeAnchor != null) {
      final dragMap = ref.read(groupDragProvider);
      if (dragMap != null) {
        // Awaited so the live preview (still showing these exact final
        // values) isn't cleared until the write is actually committed -
        // clearing it first left a gap where activeClipsProvider's stream
        // hadn't caught up yet, flashing the stale pre-drag layout for a
        // few frames before snapping to the real final state.
        await Future.wait([
          for (final entry in dragMap.entries)
            repo.updateTransform(
              entry.key,
              x: entry.value.x,
              y: entry.value.y,
              width: entry.value.width,
              height: entry.value.height,
              rotation: 0,
            ),
        ]);
        _commitTransformUndo({
          for (final entry in dragMap.entries)
            entry.key: entry.value.copyWith(rotation: 0),
        });
      }
      if (!mounted) return;
      ref.read(groupDragProvider.notifier).state = null;
      ref.read(arrangeDragRectProvider.notifier).state = null;
      _arrangeAnchor = null;
      _arrangeStartCorner = null;
      _arrangeImages = null;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_groupDragStartPositions != null) {
      final dragMap = ref.read(groupDragProvider);
      if (_groupDragMoved && dragMap != null) {
        final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
        final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
        final writes = <Future<void>>[];
        final frameIdBefore = <String, String?>{};
        final frameIdAfter = <String, String?>{};
        for (final entry in dragMap.entries) {
          writes.add(
            repo.updateTransform(entry.key, x: entry.value.x, y: entry.value.y),
          );

          // Miro-style frame containment: whichever frame now contains
          // this clip's center becomes its parent (moving with the frame
          // from here on); dragging it out clears that back to null.
          final center = Offset(
            entry.value.x + entry.value.width / 2,
            entry.value.y + entry.value.height / 2,
          );
          final containingFrame = _hitTestFrame(frames, center);
          final currentFrameId = ClipGeometry.findById(
            clipsNow,
            entry.key,
          )?.frameId;
          if (containingFrame?.id != currentFrameId) {
            writes.add(repo.setFrameId(entry.key, containingFrame?.id));
            frameIdBefore[entry.key] = currentFrameId;
            frameIdAfter[entry.key] = containingFrame?.id;
          }
        }
        await Future.wait(writes);
        if (!mounted) return;
        // A duplicate-drag session's undo is the creation-undo already
        // pushed at pointer-down (pushAddClipsUndo, bin the duplicates) -
        // pushing a transform-undo too would be wrong, since these clips
        // never had a "before" position to restore (undoing would move
        // the duplicate back instead of removing it).
        if (!_groupDragIsDuplicate) {
          _commitTransformUndo(
            dragMap,
            frameIdBefore: frameIdBefore.isEmpty ? null : frameIdBefore,
            frameIdAfter: frameIdAfter.isEmpty ? null : frameIdAfter,
          );
        }
      } else if (!_groupDragMoved && _pendingCollapseId != null) {
        ref.read(selectedClipIdsProvider.notifier).state = {
          _pendingCollapseId!,
        };
        _undoTransformBefore = null;
      } else {
        _undoTransformBefore = null;
      }
      ref.read(groupDragProvider.notifier).state = null;
      ref.read(snapGuidesProvider.notifier).state = (x: null, y: null);
      _groupDragStartPositions = null;
      _groupDragIsDuplicate = false;
      _pendingCollapseId = null;
      _groupDragMoved = false;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_marqueeStartBoard != null) {
      if (_marqueeMoved) {
        final rect = ref.read(marqueeRectProvider);
        final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
        final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
        if (rect != null) {
          final hits = clips
              .where((c) => ClipGeometry.marqueeIntersects(rect, c))
              .map((c) => c.id)
              .toSet();
          ref.read(selectedClipIdsProvider.notifier).state = hits;
          final frameHits = frames
              .where((f) => FrameGeometry.marqueeIntersects(rect, f))
              .map((f) => f.id)
              .toSet();
          ref.read(selectedFrameIdsProvider.notifier).state = frameHits;
        }
      } else {
        // A plain click-no-drag on empty canvas clears the current
        // selection - this used to live on the pan-up branch below, back
        // when plain left-click started a pan; now plain left-click starts
        // a marquee, so the click-clears-selection behavior moved here.
        ref.read(selectedClipIdsProvider.notifier).state = {};
        ref.read(selectedFrameIdsProvider.notifier).state = {};
      }
      ref.read(marqueeRectProvider.notifier).state = null;
      _marqueeStartBoard = null;
      _marqueeMoved = false;
      return;
    }

    if (_frameDragId != null) {
      final frameId = _frameDragId!;
      final beforeRect = _frameDragStartRect;
      final beforeMove = _frameChildStartPositions == null
          ? null
          : Map<String, Offset>.of(_frameChildStartPositions!);
      final beforeResize = _frameResizeChildStart == null
          ? null
          : Map<String, BoardClip>.of(_frameResizeChildStart!);
      final framesRepo = ref.read(framesRepositoryProvider);
      final rect = ref.read(frameDragRectProvider);
      Map<String, DraggingClip>? afterChildren;
      if (rect != null) {
        await framesRepo.updateTransform(
          frameId,
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
        );
        if (!mounted) return;
      }
      if (_frameChildStartPositions != null) {
        final dragMap = ref.read(groupDragProvider);
        if (dragMap != null) {
          afterChildren = Map<String, DraggingClip>.of(dragMap);
          await Future.wait([
            for (final entry in dragMap.entries)
              if (_frameChildStartPositions!.containsKey(entry.key))
                repo.updateTransform(
                  entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                ),
          ]);
          if (!mounted) return;
        }
        ref.read(groupDragProvider.notifier).state = null;
      }
      if (_frameResizeChildStart != null) {
        final dragMap = ref.read(groupDragProvider);
        if (dragMap != null) {
          afterChildren = Map<String, DraggingClip>.of(dragMap);
          await Future.wait([
            for (final entry in dragMap.entries)
              if (_frameResizeChildStart!.containsKey(entry.key))
                repo.updateTransform(
                  entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                  width: entry.value.width,
                  height: entry.value.height,
                ),
          ]);
          if (!mounted) return;
        }
        ref.read(groupDragProvider.notifier).state = null;
      }
      // A duplicate-drag session's undo is the creation-undo already
      // pushed at pointer-down (delete the frame + bin its duplicated
      // children) - pushing a move-undo too would be wrong, since this
      // frame/its children never had a "before" state to restore.
      if (!_frameDragIsDuplicate &&
          beforeRect != null &&
          rect != null &&
          beforeRect != rect) {
        final afterRect = rect;
        final afterChildrenSnapshot = afterChildren;
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => Future.wait([
                  framesRepo.updateTransform(
                    frameId,
                    x: beforeRect.left,
                    y: beforeRect.top,
                    width: beforeRect.width,
                    height: beforeRect.height,
                  ),
                  if (beforeMove != null)
                    for (final entry in beforeMove.entries)
                      repo.updateTransform(
                        entry.key,
                        x: entry.value.dx,
                        y: entry.value.dy,
                      ),
                  if (beforeResize != null)
                    for (final entry in beforeResize.entries)
                      repo.updateTransform(
                        entry.key,
                        x: entry.value.x,
                        y: entry.value.y,
                        width: entry.value.width,
                        height: entry.value.height,
                      ),
                ]),
                redo: () => Future.wait([
                  framesRepo.updateTransform(
                    frameId,
                    x: afterRect.left,
                    y: afterRect.top,
                    width: afterRect.width,
                    height: afterRect.height,
                  ),
                  if (afterChildrenSnapshot != null)
                    for (final entry in afterChildrenSnapshot.entries)
                      repo.updateTransform(
                        entry.key,
                        x: entry.value.x,
                        y: entry.value.y,
                        width: entry.value.width,
                        height: entry.value.height,
                      ),
                ]),
              ),
            );
      }
      ref.read(frameDragRectProvider.notifier).state = null;
      _frameDragId = null;
      _frameResizing = false;
      _frameDragStartRect = null;
      _frameGestureStartPointerBoard = null;
      _frameChildStartPositions = null;
      _frameResizeChildStart = null;
      _frameDragIsDuplicate = false;
      return;
    }

    if (_panPointerStart != null) {
      // A middle-click/Space-click with no drag is a non-primary-button
      // "click" and shouldn't clear an unrelated selection - see the
      // marquee-up branch above for where that deselect-on-no-move case
      // lives instead.
      _panPointerStart = null;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;

      final panZoomClipId = ref.read(panZoomClipIdProvider);
      if (panZoomClipId != null) {
        final clip = ClipGeometry.findById(
          ref.read(activeClipsProvider).valueOrNull ?? [],
          panZoomClipId,
        );
        if (clip != null) {
          final newZoom = ImagePanZoomGeometry.clampZoom(
            clip.imageZoom * factor,
          );
          ref
              .read(clipsRepositoryProvider)
              .updateTransform(clip.id, zoom: newZoom);
        }
        return;
      }

      final now = DateTime.now();
      final isIsolatedStep =
          _lastZoomSignalTime == null ||
          now.difference(_lastZoomSignalTime!) >
              const Duration(milliseconds: 150);
      _lastZoomSignalTime = now;

      if (isIsolatedStep) {
        _animateZoomStep(event.localPosition, factor);
      } else {
        // A rapid stream of ticks (trackpad pinch/scroll) is already
        // continuous input - apply directly, an eased transition per tick
        // would just pile up and lag behind the gesture.
        _zoomEaseController?.stop();
        ref
            .read(boardViewProvider.notifier)
            .zoomAt(event.localPosition, factor);
      }
    }
  }

  /// Eases a single, isolated zoom step (e.g. one physical mouse-wheel
  /// click) over a short tween instead of snapping the scale instantly,
  /// keeping the same focal point under the cursor throughout.
  void _animateZoomStep(Offset focalPoint, double factor) {
    final startView = ref.read(boardViewProvider);
    final targetScale = (startView.scale * factor).clamp(
      BoardViewNotifier.minScale,
      BoardViewNotifier.maxScale,
    );
    final boardPointUnderCursor =
        (focalPoint - startView.panOffset) / startView.scale;

    _zoomEaseController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _zoomEaseController = controller;
    final scaleTween = Tween<double>(
      begin: startView.scale,
      end: targetScale,
    ).chain(CurveTween(curve: Curves.easeOut));

    controller.addListener(() {
      final scale = scaleTween.evaluate(controller);
      final newPan = focalPoint - boardPointUnderCursor * scale;
      ref.read(boardViewProvider.notifier).setView(newPan, scale);
    });
    controller.forward();
  }

  void _handleDrawPointerDown(PointerDownEvent event) {
    final tool = ref.read(drawToolProvider);
    if (tool == DrawTool.eraser) {
      _eraseAt(event.localPosition);
      return;
    }
    if (tool == DrawTool.eyedropper) {
      _pickColorAt(event.localPosition);
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    _drawingClip = _hitTestClip(clips, boardPos);
    ref.read(liveStrokePointsProvider.notifier).state = [boardPos];
  }

  void _handleDrawPointerMove(PointerMoveEvent event) {
    if (ref.read(drawToolProvider) == DrawTool.eraser) {
      _eraseAt(event.localPosition);
      return;
    }
    final current = ref.read(liveStrokePointsProvider);
    if (current == null) return;
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    ref.read(liveStrokePointsProvider.notifier).state = [...current, boardPos];
  }

  /// Deletes every stroke (freestanding or clip-attached) that passes near
  /// [screenPosition] - the eraser tool's hit-test, run on both pointer-down
  /// and pointer-move so dragging the eraser across several strokes erases
  /// all of them, not just the first one touched.
  void _eraseAt(Offset screenPosition) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(screenPosition, view);
    final strokes = ref.read(boardStrokesProvider).valueOrNull ?? [];
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final repo = ref.read(strokesRepositoryProvider);
    final thresholdBoard = kEraserHitRadius / view.scale;

    for (final stroke in strokes) {
      if (stroke.clipId == null) {
        if (EraserGeometry.strokeNearPoint(
          stroke.points,
          boardPos,
          thresholdBoard,
        )) {
          repo.deleteStroke(stroke.id);
        }
        continue;
      }
      final clip = ClipGeometry.findById(clips, stroke.clipId!);
      if (clip == null) continue;
      final center = ClipGeometry.clipCenter(clip);
      final local = ClipGeometry.rotatePoint(boardPos, center, -clip.rotation);
      final fractional = Offset(
        (local.dx - clip.x) / clip.width,
        (local.dy - clip.y) / clip.height,
      );
      // A fractional-space threshold that approximates the screen-constant
      // eraser radius - using clip width as the reference axis is a
      // deliberate simplification (exact would be an ellipse for
      // non-square clips), consistent with this app's other "close enough"
      // hit-test tolerances.
      final fractionalThreshold = thresholdBoard / clip.width;
      if (EraserGeometry.strokeNearPoint(
        stroke.points,
        fractional,
        fractionalThreshold,
      )) {
        repo.deleteStroke(stroke.id);
      }
    }
  }

  /// Eyedropper: samples the color of whichever image clip is under
  /// [screenPosition] and writes it into the active stroke color, then
  /// switches back to the pen tool (one-shot-then-return, standard
  /// eyedropper UX). A no-op if the pointer isn't over an image clip.
  void _pickColorAt(Offset screenPosition) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(screenPosition, view);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final clip = _hitTestClip(clips, boardPos);
    if (clip == null ||
        clip.type != ClipType.image ||
        clip.localFilePath == null) {
      return;
    }
    final center = ClipGeometry.clipCenter(clip);
    final local = ClipGeometry.rotatePoint(boardPos, center, -clip.rotation);
    final fractional = Offset(
      (local.dx - clip.x) / clip.width,
      (local.dy - clip.y) / clip.height,
    );
    ref
        .read(localBlobStoreProvider)
        .readBytes(clip.localFilePath!)
        .then((bytes) {
          if (bytes == null || !mounted) return null;
          return sampleColorAt(bytes, fractional);
        })
        .then((hex) {
          if (hex == null || !mounted) return;
          ref.read(strokeColorHexProvider.notifier).state = hex;
          ref.read(drawToolProvider.notifier).state = DrawTool.pen;
        });
  }

  void _handleDrawPointerUp(PointerUpEvent event) {
    if (ref.read(drawToolProvider) == DrawTool.eraser) return;
    final points = ref.read(liveStrokePointsProvider);
    ref.read(liveStrokePointsProvider.notifier).state = null;
    final clip = _drawingClip;
    _drawingClip = null;
    if (points == null || points.length < 2) return;

    final colorHex = ref.read(strokeColorHexProvider);
    final width = ref.read(strokeWidthValueProvider);
    final dashed = ref.read(strokeDashedProvider);
    final arrowEnd = ref.read(strokeArrowProvider);
    final repo = ref.read(strokesRepositoryProvider);
    final id = _uuid.v4();
    final boardId = ref.read(currentBoardIdProvider);

    if (clip != null) {
      final center = ClipGeometry.clipCenter(clip);
      final localPoints = points.map((point) {
        final local = ClipGeometry.rotatePoint(point, center, -clip.rotation);
        return Offset(
          (local.dx - clip.x) / clip.width,
          (local.dy - clip.y) / clip.height,
        );
      }).toList();
      repo.addStroke(
        id: id,
        boardId: boardId,
        clipId: clip.id,
        colorHex: colorHex,
        strokeWidth: width,
        points: localPoints,
        dashed: dashed,
        arrowEnd: arrowEnd,
      );
    } else {
      repo.addStroke(
        id: id,
        boardId: boardId,
        colorHex: colorHex,
        strokeWidth: width,
        points: points,
        dashed: dashed,
        arrowEnd: arrowEnd,
      );
    }
  }

  /// Reuses Flutter's own double-click timing/slop constants rather than
  /// inventing new thresholds. Consumes the match on a hit (sets the
  /// tracking fields to null) so a third click in quick succession isn't
  /// misread as yet another double-click toggling back.
  bool _isDoubleClickOn(String clipId, Offset screenPos) {
    final now = DateTime.now();
    final isDouble =
        _lastClickTime != null &&
        now.difference(_lastClickTime!) <= kDoubleTapTimeout &&
        (screenPos - _lastClickPosition!).distance <= kDoubleTapSlop &&
        _lastClickedClipId == clipId;
    _lastClickTime = isDouble ? null : now;
    _lastClickPosition = screenPos;
    _lastClickedClipId = isDouble ? null : clipId;
    return isDouble;
  }

  /// Entry point while [isTextToolActiveProvider] is armed: seeds gesture
  /// state for a click-or-drag text-note placement, committed in
  /// [_handleTextToolPointerUp]. Deliberately doesn't go through
  /// _resetGestureState() - only this tool's own fields matter while it's
  /// active, same as the draw-mode/pan-zoom short-circuits above it in
  /// _handlePointerDown, which return before reaching that call too.
  void _handleTextToolPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton == 0) return;
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    _textToolStartBoard = boardPos;
    _textToolMoved = false;
    ref.read(textToolDragRectProvider.notifier).state = Rect.fromPoints(
      boardPos,
      boardPos,
    );
  }

  void _handleTextToolPointerMove(PointerMoveEvent event) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final delta = boardPos - _textToolStartBoard!;
    if (delta.distance > 2) _textToolMoved = true;
    ref.read(textToolDragRectProvider.notifier).state = Rect.fromPoints(
      _textToolStartBoard!,
      boardPos,
    );
  }

  /// Commits the placement: a plain click (never exceeded the 2px moved
  /// threshold) creates a clip at the default text-note size centered on
  /// the click point; a drag creates one sized to the dragged rect. Either
  /// way: one-shot, so the tool deactivates and the new clip immediately
  /// enters inline-edit mode.
  Future<void> _handleTextToolPointerUp(PointerUpEvent event) async {
    final startBoard = _textToolStartBoard!;
    final moved = _textToolMoved;
    _textToolStartBoard = null;
    _textToolMoved = false;
    ref.read(textToolDragRectProvider.notifier).state = null;

    final view = ref.read(boardViewProvider);
    final endBoard = _screenToBoard(event.localPosition, view);
    final rect = ClipGeometry.textToolPlacementRect(
      start: startBoard,
      end: endBoard,
      moved: moved,
      defaultWidth: kDefaultTextNoteWidth,
      defaultHeight: kDefaultTextNoteHeight,
    );

    final id = _uuid.v4();
    await ref
        .read(clipsRepositoryProvider)
        .addTextNote(
          id: id,
          boardId: ref.read(currentBoardIdProvider),
          textContent: '',
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
        );
    if (!mounted) return;
    pushAddClipUndo(ref, id);

    ref.read(isTextToolActiveProvider.notifier).state = false;
    ref.read(selectedClipIdsProvider.notifier).state = {id};
    ref.read(editingTextClipIdProvider.notifier).state = id;
  }

  /// Entry point while [isShapeToolActiveProvider] is armed - identical
  /// click-or-drag placement contract as [_handleTextToolPointerDown].
  void _handleShapeToolPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton == 0) return;
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    _shapeToolStartBoard = boardPos;
    _shapeToolMoved = false;
    ref.read(shapeToolDragRectProvider.notifier).state = Rect.fromPoints(
      boardPos,
      boardPos,
    );
  }

  void _handleShapeToolPointerMove(PointerMoveEvent event) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final delta = boardPos - _shapeToolStartBoard!;
    if (delta.distance > 2) _shapeToolMoved = true;
    ref.read(shapeToolDragRectProvider.notifier).state = Rect.fromPoints(
      _shapeToolStartBoard!,
      boardPos,
    );
  }

  /// Commits the placement: a plain click places a shape at the default
  /// size centered on the click point; a drag sizes it to the dragged
  /// rect - same contract as [_handleTextToolPointerUp], reusing the same
  /// generic rect-from-two-points helper.
  Future<void> _handleShapeToolPointerUp(PointerUpEvent event) async {
    final startBoard = _shapeToolStartBoard!;
    final moved = _shapeToolMoved;
    _shapeToolStartBoard = null;
    _shapeToolMoved = false;
    ref.read(shapeToolDragRectProvider.notifier).state = null;

    final view = ref.read(boardViewProvider);
    final endBoard = _screenToBoard(event.localPosition, view);
    final rect = ClipGeometry.textToolPlacementRect(
      start: startBoard,
      end: endBoard,
      moved: moved,
      defaultWidth: kDefaultShapeWidth,
      defaultHeight: kDefaultShapeHeight,
    );

    final id = _uuid.v4();
    await ref
        .read(clipsRepositoryProvider)
        .addShapeClip(
          id: id,
          boardId: ref.read(currentBoardIdProvider),
          shapeKind: ref.read(selectedShapeKindProvider),
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
        );
    if (!mounted) return;
    pushAddClipUndo(ref, id);

    ref.read(isShapeToolActiveProvider.notifier).state = false;
    ref.read(selectedClipIdsProvider.notifier).state = {id};
  }

  /// Entry point while [panZoomClipIdProvider] names an active clip:
  /// a hit on that same clip starts a pan/zoom drag; a double-click on it
  /// or a click anywhere else exits the mode (a click on the floating
  /// toolbar never reaches this Listener at all - a separate widget higher
  /// in the Stack - so "outside" here means whatever this canvas itself
  /// can observe: empty canvas, another clip, a frame).
  void _handlePanZoomPointerDown(PointerDownEvent event, String activeId) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, activeId);
    if (clip == null) {
      ref.read(panZoomClipIdProvider.notifier).state = null;
      return;
    }

    final hitSameClip = ClipGeometry.pointInClip(boardPos, clip);
    final isDouble = _isDoubleClickOn(activeId, event.localPosition);

    if (!hitSameClip || isDouble) {
      ref.read(panZoomClipIdProvider.notifier).state = null;
      return;
    }

    _panZoomDragClip = clip;
    _panZoomDragStartPan = Offset(clip.imagePanX, clip.imagePanY);
    _panZoomGestureStartBoard = boardPos;
    ref.read(panZoomLiveProvider.notifier).state = ImagePanZoomLive(
      clipId: clip.id,
      panX: clip.imagePanX,
      panY: clip.imagePanY,
      zoom: clip.imageZoom,
    );
  }

  void _handlePanZoomPointerMove(PointerMoveEvent event) {
    final clip = _panZoomDragClip;
    if (clip == null) return;
    final boardPos = _screenToBoard(
      event.localPosition,
      ref.read(boardViewProvider),
    );
    final localDelta = ClipGeometry.rotatePoint(
      boardPos - _panZoomGestureStartBoard!,
      Offset.zero,
      -clip.rotation,
    );

    final r = clip.imageAspectRatio ?? (clip.width / clip.height);
    final cover = ImagePanZoomGeometry.coverSize(clip.width, clip.height, r);
    final scaled = ImagePanZoomGeometry.scaledSize(cover, clip.imageZoom);
    final overflow = ImagePanZoomGeometry.overflow(
      clip.width,
      clip.height,
      scaled,
    );
    final newPan = ImagePanZoomGeometry.applyPanDelta(
      _panZoomDragStartPan!,
      localDelta,
      overflow,
    );

    ref.read(panZoomLiveProvider.notifier).state = ImagePanZoomLive(
      clipId: clip.id,
      panX: newPan.dx,
      panY: newPan.dy,
      zoom: clip.imageZoom,
    );
  }

  // ---- Drag-and-drop (Explorer files, or an image dragged out of a
  // browser) -----------------------------------------------------------

  /// Accepts the drop once at least one dragged item's reader can either
  /// provide one of the image formats this app knows how to read directly,
  /// or offers a URL/HTML snippet a cross-origin web image (Pinterest,
  /// Instagram, any page's hover/preview image) is fetched from instead -
  /// `dataReader` is "gradually populated" on desktop per super_clipboard's
  /// own docs, so this re-checks on every hover tick rather than only once.
  DropOperation _handleDropOver(DropOverEvent event) {
    // Temporary diagnostic: logs once per drag session (not every hover
    // tick) so we can see exactly which platform formats Windows/the
    // browser is actually offering, even if the drop never ends up being
    // accepted at all.
    if (!identical(event.session, _lastLoggedDropSession)) {
      _lastLoggedDropSession = event.session;
      for (final item in event.session.items) {
        debugPrint(
          'Drag hover - item formats: ${item.dataReader?.platformFormats}',
        );
      }
    }
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      if (matchImageFormat(reader) != null) return DropOperation.copy;
      if (reader.canProvide(Formats.uri) ||
          reader.canProvide(Formats.htmlText)) {
        return DropOperation.copy;
      }
    }
    return DropOperation.none;
  }

  /// Reads every recognizably-image item in the drop and adds each as a
  /// clip, centered on where it landed - a second (or third...) item in the
  /// same drop cascades a little further down-right so a multi-file drop
  /// (selecting several files in Explorer and dragging them together)
  /// doesn't stack every clip exactly on top of the others. An item with no
  /// direct image bytes (the common case for an image dragged out of a
  /// browser tab) falls back to resolving a URL off the drag and fetching
  /// it over HTTP.
  Future<void> _handlePerformDrop(PerformDropEvent event) async {
    if (ref.read(isDrawModeProvider) ||
        ref.read(panZoomClipIdProvider) != null ||
        ref.read(isTextToolActiveProvider) ||
        ref.read(isShapeToolActiveProvider)) {
      return;
    }
    final view = ref.read(boardViewProvider);
    final dropCenter = _screenToBoard(event.position.local, view);

    const cascadeStep = 24.0;
    var placed = 0;
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      debugPrint('Drop performed - item formats: ${reader.platformFormats}');

      Uint8List? bytes;
      var extension = '.png';
      final format = matchImageFormat(reader);
      if (format != null) {
        bytes = await readImageFileBytes(reader, format);
        if (!mounted) return;
        extension = imageFileFormats[format]!;
      }
      if (bytes == null || bytes.isEmpty) {
        final uri = await matchImageUrl(reader);
        if (!mounted) return;
        if (uri != null) {
          final fetched = await fetchImageBytes(uri);
          if (!mounted) return;
          if (fetched != null) {
            bytes = fetched.bytes;
            extension = fetched.extension;
          }
        }
      }
      if (bytes == null || bytes.isEmpty) continue;

      final center =
          dropCenter + Offset(cascadeStep, cascadeStep) * placed.toDouble();
      await addImageClipFromBytes(
        ref,
        bytes: bytes,
        extension: extension,
        boardCenter: center,
      );
      if (!mounted) return;
      placed++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(activeClipsProvider);
    final view = ref.watch(boardViewProvider);
    final dragging = ref.watch(groupDragProvider);
    final selection = ref.watch(selectedClipIdsProvider);
    final isDrawMode = ref.watch(isDrawModeProvider);
    final isTextToolActive = ref.watch(isTextToolActiveProvider);
    final panZoomClipId = ref.watch(panZoomClipIdProvider);
    final panZoomLive = ref.watch(panZoomLiveProvider);
    final defineFrameRect = ref.watch(defineFrameRectProvider);
    final textToolDragRect = ref.watch(textToolDragRectProvider);
    final shapeToolDragRect = ref.watch(shapeToolDragRectProvider);
    final connectorDraft = ref.watch(connectorDraftProvider);
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameIds = ref.watch(selectedFrameIdsProvider);
    final frameDragRect = ref.watch(frameDragRectProvider);
    final framesPanelOpen = ref.watch(framesPanelOpenProvider);
    final arrangeDragRect = ref.watch(arrangeDragRectProvider);

    final clips = clipsAsync.valueOrNull ?? [];
    final sorted = [...clips]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final strokesByClip = <String, List<Stroke>>{};
    for (final stroke in ref.watch(boardStrokesProvider).valueOrNull ?? []) {
      final clipId = stroke.clipId;
      if (clipId == null) continue;
      strokesByClip.putIfAbsent(clipId, () => []).add(stroke);
    }

    return DropRegion(
      formats: [...imageFileFormats.keys, Formats.uri, Formats.htmlText],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _handleDropOver,
      onPerformDrop: _handlePerformDrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = constraints.biggest;
          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              cursor: isTextToolActive
                  ? SystemMouseCursors.text
                  : isDrawMode
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              child: Listener(
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                onPointerSignal: _handlePointerSignal,
                child: Container(
                  color: AppTheme.canvasBackground,
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: DotGridPainter(view)),
                      ),
                      for (final frame in frames)
                        _positionedFrame(
                          frame,
                          selectedFrameIds.contains(frame.id)
                              ? frameDragRect
                              : null,
                          selectedFrameIds.contains(frame.id),
                          view,
                        ),
                      for (final clip in sorted)
                        _positionedClip(
                          clip,
                          dragging,
                          selection,
                          view,
                          strokesByClip[clip.id] ?? const [],
                          panZoomLive?.clipId == clip.id ? panZoomLive : null,
                          arrangeDragRect != null,
                        ),
                      const Positioned.fill(child: ConnectorsOverlay()),
                      const Positioned.fill(child: DrawingOverlay()),
                      if (defineFrameRect != null) const DefineFrameOverlay(),
                      if (textToolDragRect != null) const TextToolDragOverlay(),
                      if (shapeToolDragRect != null)
                        const ShapeToolDragOverlay(),
                      if (connectorDraft != null) const ConnectorDraftOverlay(),
                      const SnapGuidesOverlay(),
                      const TextClipEditOverlay(),
                      const FrameRenameOverlay(),
                      if (panZoomClipId == null &&
                          !isDrawMode &&
                          !isTextToolActive) ...[
                        const MarqueeOverlay(),
                        const SelectionHandles(),
                        const ConnectorHandles(),
                        const GroupScaleHandles(),
                        const ArrangeSelectionButton(),
                        const ShapeStylePopover(),
                      ],
                      const Positioned(
                        left: 24,
                        bottom: 24,
                        child: BoardMinimap(),
                      ),
                      if (framesPanelOpen)
                        const Positioned(
                          top: 76,
                          right: 24,
                          child: FramesPanel(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _positionedFrame(
    FrameRow frame,
    Rect? dragRect,
    bool selected,
    BoardViewState view,
  ) {
    final rect = dragRect ?? FrameGeometry.boardRect(frame);
    final topLeft = _boardToScreen(rect.topLeft, view);
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: rect.width * view.scale,
      height: rect.height * view.scale,
      child: FrameWidget(frame: frame, selected: selected),
    );
  }

  Widget _positionedClip(
    BoardClip clip,
    Map<String, DraggingClip>? dragging,
    Set<String> selection,
    BoardViewState view,
    List<Stroke> strokes,
    ImagePanZoomLive? panZoomLive,
    bool arranging,
  ) {
    final drag = dragging?[clip.id];
    final x = drag?.x ?? clip.x;
    final y = drag?.y ?? clip.y;
    final width = drag?.width ?? clip.width;
    final height = drag?.height ?? clip.height;
    final rotation = drag?.rotation ?? clip.rotation;
    final topLeft = _boardToScreen(Offset(x, y), view);
    // The "constant size" edit-toolbar toggle pins a text clip's on-screen
    // size to whatever the view scale was when it was switched on, instead
    // of the usual live view.scale - position still tracks the true view
    // (panning/zooming moves the box around as normal), only its size
    // freezes. Unset (null) for every clip except a locked text note.
    final effectiveScale = clip.sizeLockScale ?? view.scale;
    final boxWidth = width * effectiveScale;
    final boxHeight = height * effectiveScale;

    final child = IgnorePointer(
      child: Transform.rotate(
        angle: rotation,
        alignment: Alignment.center,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipWidget(
                clip: clip,
                selected: selection.contains(clip.id),
                viewScale: effectiveScale,
                panZoomLive: panZoomLive,
              ),
            ),
            if (strokes.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: StrokePainter([
                    for (final stroke in strokes)
                      StrokeSpec(
                        points: stroke.points
                            .map(
                              (p) => Offset(p.dx * boxWidth, p.dy * boxHeight),
                            )
                            .toList(),
                        color: hexToColor(stroke.colorHex),
                        width: stroke.strokeWidth * effectiveScale,
                        dashed: stroke.dashed,
                        arrowEnd: stroke.arrowEnd,
                      ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );

    // Arrange repacks the selection into a masonry grid on every pointer
    // move, which can discontinuously reassign a clip to a different
    // column (and resize others) as the target rect changes (see
    // MasonryLayout). Animating just the clips actively being arranged
    // turns that pop into a smooth slide; every other gesture (plain drag,
    // resize, frame-drag, ...) keeps a zero-lag plain Positioned - direct
    // manipulation should never lag behind the cursor.
    if (arranging && drag != null) {
      return AnimatedPositioned(
        key: ValueKey(clip.id),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        left: topLeft.dx,
        top: topLeft.dy,
        width: boxWidth,
        height: boxHeight,
        child: child,
      );
    }

    return Positioned(
      key: ValueKey(clip.id),
      left: topLeft.dx,
      top: topLeft.dy,
      width: boxWidth,
      height: boxHeight,
      child: child,
    );
  }
}
