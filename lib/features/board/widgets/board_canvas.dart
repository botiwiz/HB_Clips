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
import '../geometry/connector_geometry.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/image_pan_zoom_geometry.dart';
import '../geometry/selection_geometry.dart';
import '../geometry/snap_geometry.dart';
import '../geometry/view_focus_geometry.dart';
import '../services/add_image_service.dart';
import '../services/eyedropper_service.dart';
import '../services/image_file_formats.dart';
import '../services/remote_image_fetch_service.dart';
import 'arrange_selection_button.dart';
import 'bin_drop_target.dart';
import 'board_minimap.dart';
import 'clip_style_popover.dart';
import 'clip_widget.dart';
import 'connector_draft_overlay.dart';
import 'connector_handles.dart';
import 'connectors_overlay.dart';
import 'define_frame_overlay.dart';
import 'dot_grid_background.dart';
import 'frame_widget.dart';
import 'frames_panel.dart';
import 'group_scale_handles.dart';
import 'marquee_overlay.dart';
import 'selection_handles.dart';
import 'snap_guides_overlay.dart';
import 'text_clip_edit_overlay.dart';
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
  String? _groupDragPrimaryId;
  bool _groupDragMoved = false;
  String? _pendingCollapseId;

  // Shared by handle-drag, group-drag and rotate: board-space pointer
  // position at gesture start.
  Offset? _gestureStartPointerBoard;

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

  // Debug diagnostic (see _handleDropOver/_handlePerformDrop): the last
  // drag session whose platform formats were already logged, so a
  // repeated hover tick over the same drag doesn't spam the console.
  Object? _lastLoggedDropSession;

  Size _canvasSize = Size.zero;

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

  Rect get _binRectScreen => Rect.fromLTWH(
    _canvasSize.width - 24 - kBinTargetSize,
    _canvasSize.height - 24 - kBinTargetSize,
    kBinTargetSize,
    kBinTargetSize,
  );

  BoardClip? _hitTestClip(List<BoardClip> clips, Offset boardPoint) {
    final sorted = [...clips]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    for (final clip in sorted) {
      if (ClipGeometry.pointInClip(boardPoint, clip)) return clip;
    }
    return null;
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
  FrameRow? _hitTestFrameForSelection(List<FrameRow> frames, Offset boardPoint) {
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
    _groupDragPrimaryId = null;
    _groupDragMoved = false;
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
    _arrangeAnchor = null;
    _arrangeStartCorner = null;
    _arrangeImages = null;
    _connectorFromClipId = null;
    _connectorFromSide = null;
    _panZoomDragClip = null;
    _panZoomDragStartPan = null;
    _panZoomGestureStartBoard = null;
    _defineFrameClip = null;
    _defineFrameStartBoard = null;
    _textToolStartBoard = null;
    _textToolMoved = false;
    ref.read(groupDragProvider.notifier).state = null;
    ref.read(marqueeRectProvider.notifier).state = null;
    ref.read(frameDragRectProvider.notifier).state = null;
    ref.read(arrangeDragRectProvider.notifier).state = null;
    ref.read(panZoomLiveProvider.notifier).state = null;
    ref.read(defineFrameRectProvider.notifier).state = null;
    ref.read(snapGuidesProvider.notifier).state = (x: null, y: null);
    ref.read(textToolDragRectProvider.notifier).state = null;
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

    final selectedFrameId = ref.read(selectedFrameIdProvider);
    if (selectedFrameId == null) return null;
    final frame = _findFrameById(
      ref.read(boardFramesProvider).valueOrNull ?? [],
      selectedFrameId,
    );
    return frame == null ? null : FrameGeometry.boardRect(frame);
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

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (ref.read(isTextToolActiveProvider)) {
      _handleTextToolPointerDown(event);
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
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyC) &&
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

    // 0. A click landing on the floating clip-style popover (opacity
    // slider / text-note color swatches) or the Arrange-selection button is
    // left entirely to that widget's own tap/drag handling - otherwise this
    // canvas would see it as an empty-canvas click and clear the very
    // selection those widgets depend on to render at all.
    if (selection.length == 1) {
      final selectedClip = ClipGeometry.findById(clips, selection.first);
      if (selectedClip != null &&
          ClipStylePopover.screenRectFor(
            selectedClip,
            view,
          ).contains(event.localPosition)) {
        return;
      }
    }
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
          final images = [
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
            ref.read(groupDragProvider.notifier).state = {
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
          ref.read(groupDragProvider.notifier).state = {
            selectedClip.id: DraggingClip(
              id: selectedClip.id,
              x: selectedClip.x,
              y: selectedClip.y,
              width: selectedClip.width,
              height: selectedClip.height,
              rotation: selectedClip.rotation,
            ),
          };
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
          _groupScaleStartClips = {
            for (final c in selectedClips) c.id: c,
          };
          _groupScaleStartRect = groupRect;
          _gestureStartPointerBoard = boardPos;
          ref.read(groupDragProvider.notifier).state = {
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
          return;
        }
      }
    }

    // 2. Clip body hit-test.
    final hit = _hitTestClip(clips, boardPos);
    if (hit != null) {
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

      ref
          .read(clipsRepositoryProvider)
          .bringToFront(hit.id, ref.read(currentBoardIdProvider));

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
      _groupDragPrimaryId = hit.id;
      _gestureStartPointerBoard = boardPos;
      ref.read(groupDragProvider.notifier).state = dragMap;
      return;
    }

    // 2.5. Frames sit behind clips - only checked once no clip was hit.
    // A resize-handle hit only applies to the already-selected frame.
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameId = ref.read(selectedFrameIdProvider);
    if (selectedFrameId != null) {
      final selectedFrame = _findFrameById(frames, selectedFrameId);
      if (selectedFrame != null &&
          FrameGeometry.hitTestResizeHandle(
            selectedFrame,
            view,
            event.localPosition,
          )) {
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
          _frameResizeChildStart = {
            for (final c in resizingChildren) c.id: c,
          };
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
      ref.read(selectedFrameIdProvider.notifier).state = hitFrame.id;
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
    if (selectedFrameId != null) {
      ref.read(selectedFrameIdProvider.notifier).state = null;
    }

    // 3. Empty canvas: always a marquee now (pan was already handled above,
    // before any hit-testing even started).
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
        ref.read(groupDragProvider.notifier).state = {
          id: current.copyWith(
            x: snap
                ? ClipGeometry.snap(result.x, kBoardGridSpacing)
                : result.x,
            y: snap
                ? ClipGeometry.snap(result.y, kBoardGridSpacing)
                : result.y,
            width: snap
                ? ClipGeometry.snap(result.width, kBoardGridSpacing)
                : result.width,
            height: snap
                ? ClipGeometry.snap(result.height, kBoardGridSpacing)
                : result.height,
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

      final primary = updated[_groupDragPrimaryId];
      if (primary != null) {
        final center = Offset(
          primary.x + primary.width / 2,
          primary.y + primary.height / 2,
        );
        final centerScreen = _boardToScreen(center, view);
        final overBin = _binRectScreen.inflate(16).contains(centerScreen);
        if (ref.read(isDraggingOverBinProvider) != overBin) {
          ref.read(isDraggingOverBinProvider.notifier).state = overBin;
        }
      }
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
      if (_frameResizeChildStart != null && _frameResizeChildStart!.isNotEmpty) {
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
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerUp(event);
      return;
    }
    if (_panZoomDragClip != null) {
      final drag = ref.read(panZoomLiveProvider);
      if (drag != null) {
        ref
            .read(clipsRepositoryProvider)
            .updateTransform(drag.clipId, panX: drag.panX, panY: drag.panY);
      }
      ref.read(panZoomLiveProvider.notifier).state = null;
      _panZoomDragClip = null;
      _panZoomDragStartPan = null;
      _panZoomGestureStartBoard = null;
      return;
    }
    final repo = ref.read(clipsRepositoryProvider);

    if (_connectorFromClipId != null && _connectorFromSide != null) {
      final view = ref.read(boardViewProvider);
      final boardPos = _screenToBoard(event.localPosition, view);
      final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
      final target = _hitTestClip(clipsNow, boardPos);
      if (target != null &&
          target.type == ClipType.image &&
          target.id != _connectorFromClipId) {
        await ref
            .read(connectorsRepositoryProvider)
            .addConnector(
              id: _uuid.v4(),
              boardId: ref.read(currentBoardIdProvider),
              fromClipId: _connectorFromClipId!,
              fromSide: _connectorFromSide!,
              toClipId: target.id,
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
        // Awaited before clearing the live rect - see the comment on the
        // arrange branch below for why: otherwise activeClipsProvider's
        // stream can still be showing the pre-gesture value for a frame or
        // two after the preview disappears, flashing the stale state.
        await repo.updateTransform(
          _defineFrameClip!.id,
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
          panX: 0.0,
          panY: 0.0,
          zoom: 1.0,
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
      final overBin = ref.read(isDraggingOverBinProvider);
      if (_groupDragMoved && dragMap != null) {
        if (overBin) {
          await Future.wait([for (final id in dragMap.keys) repo.binClip(id)]);
          if (!mounted) return;
          ref.read(selectedClipIdsProvider.notifier).state = {};
        } else {
          final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
          final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
          final writes = <Future<void>>[];
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
            }
          }
          await Future.wait(writes);
          if (!mounted) return;
        }
      } else if (!_groupDragMoved && _pendingCollapseId != null) {
        ref.read(selectedClipIdsProvider.notifier).state = {
          _pendingCollapseId!,
        };
      }
      ref.read(groupDragProvider.notifier).state = null;
      ref.read(isDraggingOverBinProvider.notifier).state = false;
      ref.read(snapGuidesProvider.notifier).state = (x: null, y: null);
      _groupDragStartPositions = null;
      _groupDragPrimaryId = null;
      _pendingCollapseId = null;
      _groupDragMoved = false;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_marqueeStartBoard != null) {
      if (_marqueeMoved) {
        final rect = ref.read(marqueeRectProvider);
        final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
        if (rect != null) {
          final hits = clips
              .where((c) => ClipGeometry.marqueeIntersects(rect, c))
              .map((c) => c.id)
              .toSet();
          ref.read(selectedClipIdsProvider.notifier).state = hits;
        }
      } else {
        // A plain click-no-drag on empty canvas clears the current
        // selection - this used to live on the pan-up branch below, back
        // when plain left-click started a pan; now plain left-click starts
        // a marquee, so the click-clears-selection behavior moved here.
        ref.read(selectedClipIdsProvider.notifier).state = {};
      }
      ref.read(marqueeRectProvider.notifier).state = null;
      _marqueeStartBoard = null;
      _marqueeMoved = false;
      return;
    }

    if (_frameDragId != null) {
      final rect = ref.read(frameDragRectProvider);
      if (rect != null) {
        await ref
            .read(framesRepositoryProvider)
            .updateTransform(
              _frameDragId!,
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
          await Future.wait([
            for (final entry in dragMap.entries)
              if (_frameChildStartPositions!.containsKey(entry.key))
                repo.updateTransform(entry.key, x: entry.value.x, y: entry.value.y),
          ]);
          if (!mounted) return;
        }
        ref.read(groupDragProvider.notifier).state = null;
      }
      if (_frameResizeChildStart != null) {
        final dragMap = ref.read(groupDragProvider);
        if (dragMap != null) {
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
      ref.read(frameDragRectProvider.notifier).state = null;
      _frameDragId = null;
      _frameResizing = false;
      _frameDragStartRect = null;
      _frameGestureStartPointerBoard = null;
      _frameChildStartPositions = null;
      _frameResizeChildStart = null;
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
          now.difference(_lastZoomSignalTime!) > const Duration(milliseconds: 150);
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
    ref.read(liveStrokePointsProvider.notifier).state = [
      ...current,
      boardPos,
    ];
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
    ref.read(localBlobStoreProvider).readBytes(clip.localFilePath!).then((
      bytes,
    ) {
      if (bytes == null || !mounted) return null;
      return sampleColorAt(bytes, fractional);
    }).then((hex) {
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

    ref.read(isTextToolActiveProvider.notifier).state = false;
    ref.read(selectedClipIdsProvider.notifier).state = {id};
    ref.read(editingTextClipIdProvider.notifier).state = id;
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
        ref.read(isTextToolActiveProvider)) {
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

      final center = dropCenter + Offset(cascadeStep, cascadeStep) * placed.toDouble();
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
    final overBin = ref.watch(isDraggingOverBinProvider);
    final isDrawMode = ref.watch(isDrawModeProvider);
    final isTextToolActive = ref.watch(isTextToolActiveProvider);
    final panZoomClipId = ref.watch(panZoomClipIdProvider);
    final panZoomLive = ref.watch(panZoomLiveProvider);
    final defineFrameRect = ref.watch(defineFrameRectProvider);
    final textToolDragRect = ref.watch(textToolDragRectProvider);
    final connectorDraft = ref.watch(connectorDraftProvider);
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameId = ref.watch(selectedFrameIdProvider);
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
                          frame.id == selectedFrameId ? frameDragRect : null,
                          frame.id == selectedFrameId,
                          view,
                        ),
                      const Positioned.fill(child: ConnectorsOverlay()),
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
                      const Positioned.fill(child: DrawingOverlay()),
                      if (defineFrameRect != null) const DefineFrameOverlay(),
                      if (textToolDragRect != null) const TextToolDragOverlay(),
                      if (connectorDraft != null) const ConnectorDraftOverlay(),
                      const SnapGuidesOverlay(),
                      const TextClipEditOverlay(),
                      if (panZoomClipId == null &&
                          !isDrawMode &&
                          !isTextToolActive) ...[
                        const MarqueeOverlay(),
                        const SelectionHandles(),
                        const ConnectorHandles(),
                        const GroupScaleHandles(),
                        const ClipStylePopover(),
                        const ArrangeSelectionButton(),
                      ],
                      Positioned(
                        right: 24,
                        bottom: 24,
                        child: BinDropTarget(
                          highlighted: overBin,
                          onTap: () {},
                        ),
                      ),
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
                              (p) => Offset(
                                p.dx * boxWidth,
                                p.dy * boxHeight,
                              ),
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
