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
import '../../../data/models/stroke.dart';
import '../../../data/providers.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../../annotation/drawing_overlay.dart';
import '../../annotation/geometry/eraser_geometry.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart';
import '../controllers/crop_controller.dart';
import '../geometry/crop_geometry.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/selection_geometry.dart';
import '../services/add_image_service.dart';
import '../services/eyedropper_service.dart';
import '../services/image_file_formats.dart';
import 'arrange_selection_button.dart';
import 'bin_drop_target.dart';
import 'board_minimap.dart';
import 'clip_style_popover.dart';
import 'clip_widget.dart';
import 'crop_overlay.dart';
import 'dot_grid_background.dart';
import 'frame_widget.dart';
import 'marquee_overlay.dart';
import 'selection_handles.dart';

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
/// (1) a handle on the sole selected clip, (2) a clip body (rotation-aware),
/// (3) empty canvas starts a marquee.
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

  // Crop mode: the clip being cropped and its crop rect at gesture-start,
  // captured once per drag so repeated CropGeometry.updateCropRect calls
  // stay stable (same convention as the resize-handle drag above).
  CropHandleKind? _activeCropHandle;
  BoardClip? _cropModeClip;
  Rect? _cropDragStartRect;

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

  Size _canvasSize = Size.zero;

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
  /// absent an explicit z-index concept for frames.
  FrameRow? _hitTestFrame(List<FrameRow> frames, Offset boardPoint) {
    for (final frame in frames.reversed) {
      if (FrameGeometry.pointInFrame(boardPoint, frame)) return frame;
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
    ref.read(groupDragProvider.notifier).state = null;
    ref.read(marqueeRectProvider.notifier).state = null;
    ref.read(frameDragRectProvider.notifier).state = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetGestureState();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerDown(event);
      return;
    }
    if (ref.read(isCropModeProvider)) {
      _handleCropPointerDown(event);
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);

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

    // A plain right-click isn't wired to anything yet (reserved for a
    // future context menu) - it shouldn't select or drag whatever's
    // underneath it either.
    if (event.buttons & kPrimaryMouseButton == 0) return;

    final selection = ref.read(selectedClipIdsProvider);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];

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

    // 2. Clip body hit-test.
    final hit = _hitTestClip(clips, boardPos);
    if (hit != null) {
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
        return;
      }
    }
    final hitFrame = _hitTestFrame(frames, boardPos);
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
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerMove(event);
      return;
    }
    if (ref.read(isCropModeProvider)) {
      _handleCropPointerMove(event);
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);

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
        final result = ClipGeometry.resize(
          startClip: _handleStartClip!,
          corner: _activeHandle!,
          pointerBoard: boardPos,
        );
        final snap = ref.read(snapToGridProvider);
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

    if (_groupDragStartPositions != null) {
      final delta = boardPos - _gestureStartPointerBoard!;
      if (delta.distance > 2) _groupDragMoved = true;
      final snap = ref.read(snapToGridProvider);
      final newPositions = ClipGeometry.applyGroupDelta(
        _groupDragStartPositions!,
        delta,
      );
      final currentMap = ref.read(groupDragProvider);
      if (currentMap == null) return;
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
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerUp(event);
      return;
    }
    if (ref.read(isCropModeProvider)) {
      _handleCropPointerUp(event);
      return;
    }
    final repo = ref.read(clipsRepositoryProvider);

    if (_activeHandle != null && _handleStartClip != null) {
      final id = _handleStartClip!.id;
      final drag = ref.read(groupDragProvider)?[id];
      if (drag != null) {
        repo.updateTransform(
          id,
          x: drag.x,
          y: drag.y,
          width: drag.width,
          height: drag.height,
          rotation: drag.rotation,
        );
      }
      ref.read(groupDragProvider.notifier).state = null;
      _activeHandle = null;
      _handleStartClip = null;
      _gestureStartPointerBoard = null;
      return;
    }

    if (_groupDragStartPositions != null) {
      final dragMap = ref.read(groupDragProvider);
      final overBin = ref.read(isDraggingOverBinProvider);
      if (_groupDragMoved && dragMap != null) {
        if (overBin) {
          for (final id in dragMap.keys) {
            repo.binClip(id);
          }
          ref.read(selectedClipIdsProvider.notifier).state = {};
        } else {
          final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
          final clipsNow = ref.read(activeClipsProvider).valueOrNull ?? [];
          for (final entry in dragMap.entries) {
            repo.updateTransform(entry.key, x: entry.value.x, y: entry.value.y);

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
              repo.setFrameId(entry.key, containingFrame?.id);
            }
          }
        }
      } else if (!_groupDragMoved && _pendingCollapseId != null) {
        ref.read(selectedClipIdsProvider.notifier).state = {
          _pendingCollapseId!,
        };
      }
      ref.read(groupDragProvider.notifier).state = null;
      ref.read(isDraggingOverBinProvider.notifier).state = false;
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
        ref
            .read(framesRepositoryProvider)
            .updateTransform(
              _frameDragId!,
              x: rect.left,
              y: rect.top,
              width: rect.width,
              height: rect.height,
            );
      }
      if (_frameChildStartPositions != null) {
        final dragMap = ref.read(groupDragProvider);
        if (dragMap != null) {
          for (final entry in dragMap.entries) {
            if (_frameChildStartPositions!.containsKey(entry.key)) {
              repo.updateTransform(entry.key, x: entry.value.x, y: entry.value.y);
            }
          }
        }
        ref.read(groupDragProvider.notifier).state = null;
      }
      ref.read(frameDragRectProvider.notifier).state = null;
      _frameDragId = null;
      _frameResizing = false;
      _frameDragStartRect = null;
      _frameGestureStartPointerBoard = null;
      _frameChildStartPositions = null;
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

  void _handleCropPointerDown(PointerDownEvent event) {
    // Unconditionally clear any previous drag state first - a miss here
    // (e.g. a tap on the crop toolbar's own confirm/cancel buttons, which
    // this canvas's raw Listener also receives since it's a full-screen
    // sibling) must not leave a stale handle/rect around for the next
    // pointer-move to misinterpret as a continuing drag.
    _activeCropHandle = null;
    _cropModeClip = null;
    _cropDragStartRect = null;

    final selection = ref.read(selectedClipIdsProvider);
    if (selection.length != 1) return;
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null) return;
    final view = ref.read(boardViewProvider);
    final cropRect = ref.read(cropRectProvider) ?? const Rect.fromLTWH(0, 0, 1, 1);
    final handle = CropGeometry.hitTestHandle(
      clip,
      view,
      cropRect,
      event.localPosition,
    );
    if (handle != null) {
      _activeCropHandle = handle;
      _cropModeClip = clip;
      _cropDragStartRect = cropRect;
    }
  }

  void _handleCropPointerMove(PointerMoveEvent event) {
    if (_activeCropHandle == null ||
        _cropModeClip == null ||
        _cropDragStartRect == null) {
      return;
    }
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final clip = _cropModeClip!;
    final center = ClipGeometry.clipCenter(clip);
    final local = ClipGeometry.rotatePoint(boardPos, center, -clip.rotation);
    final fractional = Offset(
      (local.dx - clip.x) / clip.width,
      (local.dy - clip.y) / clip.height,
    );
    ref.read(cropRectProvider.notifier).state = CropGeometry.updateCropRect(
      _cropDragStartRect!,
      _activeCropHandle!,
      fractional,
    );
  }

  void _handleCropPointerUp(PointerUpEvent event) {
    _activeCropHandle = null;
    _cropModeClip = null;
    _cropDragStartRect = null;
  }

  // ---- Drag-and-drop (Explorer files, or an image dragged out of a
  // browser) -----------------------------------------------------------

  /// Accepts the drop only once at least one dragged item's reader can
  /// actually provide one of the image formats this app knows how to read -
  /// `dataReader` is "gradually populated" on desktop per super_clipboard's
  /// own docs, so this re-checks on every hover tick rather than only once.
  DropOperation _handleDropOver(DropOverEvent event) {
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader != null && matchImageFormat(reader) != null) {
        return DropOperation.copy;
      }
    }
    return DropOperation.none;
  }

  /// Reads every recognizably-image item in the drop and adds each as a
  /// clip, centered on where it landed - a second (or third...) item in the
  /// same drop cascades a little further down-right so a multi-file drop
  /// (selecting several files in Explorer and dragging them together)
  /// doesn't stack every clip exactly on top of the others.
  Future<void> _handlePerformDrop(PerformDropEvent event) async {
    if (ref.read(isDrawModeProvider) || ref.read(isCropModeProvider)) return;
    final view = ref.read(boardViewProvider);
    final dropCenter = _screenToBoard(event.position.local, view);

    const cascadeStep = 24.0;
    var placed = 0;
    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;
      final format = matchImageFormat(reader);
      if (format == null) continue;
      final bytes = await readImageFileBytes(reader, format);
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) continue;

      final center = dropCenter + Offset(cascadeStep, cascadeStep) * placed.toDouble();
      final ok = await addImageClipFromBytes(
        context,
        ref,
        bytes: bytes,
        extension: imageFileFormats[format]!,
        boardCenter: center,
      );
      if (!mounted) return;
      if (!ok) return; // hit the image cap - a snackbar was already shown.
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
    final isCropMode = ref.watch(isCropModeProvider);
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameId = ref.watch(selectedFrameIdProvider);
    final frameDragRect = ref.watch(frameDragRectProvider);

    final clips = clipsAsync.valueOrNull ?? [];
    final sorted = [...clips]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final strokesByClip = <String, List<Stroke>>{};
    for (final stroke in ref.watch(boardStrokesProvider).valueOrNull ?? []) {
      final clipId = stroke.clipId;
      if (clipId == null) continue;
      strokesByClip.putIfAbsent(clipId, () => []).add(stroke);
    }

    return DropRegion(
      formats: [...imageFileFormats.keys],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _handleDropOver,
      onPerformDrop: _handlePerformDrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = constraints.biggest;
          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: MouseRegion(
              cursor: isDrawMode
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
                      for (final clip in sorted)
                        _positionedClip(
                          clip,
                          dragging,
                          selection,
                          view,
                          strokesByClip[clip.id] ?? const [],
                        ),
                      const Positioned.fill(child: DrawingOverlay()),
                      if (isCropMode) ...[
                        const CropOverlay(),
                      ] else if (!isDrawMode) ...[
                        const MarqueeOverlay(),
                        const SelectionHandles(),
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
  ) {
    final drag = dragging?[clip.id];
    final x = drag?.x ?? clip.x;
    final y = drag?.y ?? clip.y;
    final width = drag?.width ?? clip.width;
    final height = drag?.height ?? clip.height;
    final rotation = drag?.rotation ?? clip.rotation;
    final topLeft = _boardToScreen(Offset(x, y), view);
    final boxWidth = width * view.scale;
    final boxHeight = height * view.scale;

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: boxWidth,
      height: boxHeight,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          alignment: Alignment.center,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipWidget(
                  clip: clip,
                  selected: selection.contains(clip.id),
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
                          width: stroke.strokeWidth * view.scale,
                          dashed: stroke.dashed,
                          arrowEnd: stroke.arrowEnd,
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
