import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/models/stroke.dart';
import '../../../data/providers.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../../annotation/drawing_overlay.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart';
import '../geometry/selection_geometry.dart';
import 'bin_drop_target.dart';
import 'clip_widget.dart';
import 'dot_grid_background.dart';
import 'clip_style_popover.dart';
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
/// Gesture priority per pointer-down, most specific first: (1) a handle on
/// the sole selected clip, (2) a clip body (rotation-aware), (3) empty
/// canvas - Shift-held starts a marquee, otherwise pans.
class BoardCanvas extends ConsumerStatefulWidget {
  const BoardCanvas({super.key});

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
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
  bool _didPanMove = false;

  // Draw mode: the clip (if any) under the pointer when a stroke gesture
  // started - the whole stroke stays attached to it, per-clip strokes are
  // stored in that clip's local frame.
  BoardClip? _drawingClip;

  Size _canvasSize = Size.zero;

  @override
  void dispose() {
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

  bool get _multiSelectModifierHeld =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerDown(event);
      return;
    }
    final view = ref.read(boardViewProvider);
    final selection = ref.read(selectedClipIdsProvider);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final boardPos = _screenToBoard(event.localPosition, view);

    // 0. A click landing on the floating clip-style popover (opacity
    // slider / text-note color swatches) is left entirely to that widget's
    // own tap/drag handling - otherwise this canvas would see it as an
    // empty-canvas click and clear the very selection the popover depends
    // on to render at all.
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

    _didPanMove = false;
    _marqueeMoved = false;
    _groupDragMoved = false;

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
      if (selection.contains(hit.id) && selection.length > 1) {
        activeSelection = selection;
        _pendingCollapseId = hit.id;
      } else {
        activeSelection = {hit.id};
        ref.read(selectedClipIdsProvider.notifier).state = activeSelection;
        _pendingCollapseId = null;
      }

      ref.read(clipsRepositoryProvider).bringToFront(hit.id, kLocalBoardId);

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

    // 3. Empty canvas: Shift starts a marquee, otherwise pan (unchanged).
    if (HardwareKeyboard.instance.isShiftPressed) {
      _marqueeStartBoard = boardPos;
      ref.read(marqueeRectProvider.notifier).state = Rect.fromPoints(
        boardPos,
        boardPos,
      );
    } else {
      _panPointerStart = event.localPosition;
      _panOffsetStart = view.panOffset;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerMove(event);
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

    if (_panPointerStart != null) {
      final delta = event.localPosition - _panPointerStart!;
      if (delta.distance > 2) _didPanMove = true;
      ref.read(boardViewProvider.notifier).setPan(_panOffsetStart! + delta);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (ref.read(isDrawModeProvider)) {
      _handleDrawPointerUp(event);
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
          for (final entry in dragMap.entries) {
            repo.updateTransform(entry.key, x: entry.value.x, y: entry.value.y);
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
      }
      ref.read(marqueeRectProvider.notifier).state = null;
      _marqueeStartBoard = null;
      _marqueeMoved = false;
      return;
    }

    if (_panPointerStart != null) {
      if (!_didPanMove) {
        ref.read(selectedClipIdsProvider.notifier).state = {};
      }
      _panPointerStart = null;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
      ref
          .read(boardViewProvider.notifier)
          .zoomAt(event.localPosition, factor);
    }
  }

  void _handleDrawPointerDown(PointerDownEvent event) {
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    _drawingClip = _hitTestClip(clips, boardPos);
    ref.read(liveStrokePointsProvider.notifier).state = [boardPos];
  }

  void _handleDrawPointerMove(PointerMoveEvent event) {
    final current = ref.read(liveStrokePointsProvider);
    if (current == null) return;
    final view = ref.read(boardViewProvider);
    final boardPos = _screenToBoard(event.localPosition, view);
    ref.read(liveStrokePointsProvider.notifier).state = [
      ...current,
      boardPos,
    ];
  }

  void _handleDrawPointerUp(PointerUpEvent event) {
    final points = ref.read(liveStrokePointsProvider);
    ref.read(liveStrokePointsProvider.notifier).state = null;
    final clip = _drawingClip;
    _drawingClip = null;
    if (points == null || points.length < 2) return;

    final colorHex = ref.read(strokeColorHexProvider);
    final width = ref.read(strokeWidthValueProvider);
    final repo = ref.read(strokesRepositoryProvider);
    final id = _uuid.v4();

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
        boardId: kLocalBoardId,
        clipId: clip.id,
        colorHex: colorHex,
        strokeWidth: width,
        points: localPoints,
      );
    } else {
      repo.addStroke(
        id: id,
        boardId: kLocalBoardId,
        colorHex: colorHex,
        strokeWidth: width,
        points: points,
      );
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

    final clips = clipsAsync.valueOrNull ?? [];
    final sorted = [...clips]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final strokesByClip = <String, List<Stroke>>{};
    for (final stroke in ref.watch(boardStrokesProvider).valueOrNull ?? []) {
      final clipId = stroke.clipId;
      if (clipId == null) continue;
      strokesByClip.putIfAbsent(clipId, () => []).add(stroke);
    }

    return LayoutBuilder(
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
                    for (final clip in sorted)
                      _positionedClip(
                        clip,
                        dragging,
                        selection,
                        view,
                        strokesByClip[clip.id] ?? const [],
                      ),
                    const Positioned.fill(child: DrawingOverlay()),
                    if (!isDrawMode) ...[
                      const MarqueeOverlay(),
                      const SelectionHandles(),
                      const ClipStylePopover(),
                    ],
                    Positioned(
                      right: 24,
                      bottom: 24,
                      child: BinDropTarget(
                        highlighted: overBin,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
