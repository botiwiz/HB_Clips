import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import 'bin_drop_target.dart';
import 'clip_widget.dart';

/// The infinite pan/zoom board. Deliberately hand-rolled with a raw
/// [Listener] instead of `InteractiveViewer` + per-clip `GestureDetector`s:
/// with those, a pointer landing on a clip would register with *both* the
/// clip's drag recognizer and the canvas's pan/scale recognizer, and Flutter's
/// gesture arena resolves that contest by touch-slop timing, not by "which
/// widget is on top" - unreliable for exactly the interactions this board
/// needs (pan empty space vs. drag a clip vs, later, marquee-select).
/// Handling pointer events directly and hit-testing the clip list ourselves
/// makes canvas-pan-vs-clip-drag deterministic instead of arena-dependent.
class BoardCanvas extends ConsumerStatefulWidget {
  const BoardCanvas({super.key});

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
  String? _dragTargetId;
  Offset? _dragPointerOffsetInClip;
  Offset? _panPointerStart;
  Offset? _panOffsetStart;
  bool _didPanMove = false;
  Size _canvasSize = Size.zero;

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
      final rect = Rect.fromLTWH(clip.x, clip.y, clip.width, clip.height);
      if (rect.contains(boardPoint)) return clip;
    }
    return null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    final view = ref.read(boardViewProvider);
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final boardPos = _screenToBoard(event.localPosition, view);
    final hit = _hitTestClip(clips, boardPos);

    _didPanMove = false;
    if (hit != null) {
      ref.read(selectedClipIdProvider.notifier).state = hit.id;
      ref.read(clipsRepositoryProvider).bringToFront(hit.id, kLocalBoardId);
      _dragTargetId = hit.id;
      _dragPointerOffsetInClip = boardPos - Offset(hit.x, hit.y);
      ref.read(draggingClipProvider.notifier).state = DraggingClip(
        id: hit.id,
        x: hit.x,
        y: hit.y,
        width: hit.width,
        height: hit.height,
      );
    } else {
      _dragTargetId = null;
      _panPointerStart = event.localPosition;
      _panOffsetStart = view.panOffset;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final view = ref.read(boardViewProvider);
    if (_dragTargetId != null) {
      final boardPos = _screenToBoard(event.localPosition, view);
      final newTopLeft = boardPos - _dragPointerOffsetInClip!;
      final current = ref.read(draggingClipProvider);
      if (current == null) return;
      ref.read(draggingClipProvider.notifier).state = current.copyWith(
        x: newTopLeft.dx,
        y: newTopLeft.dy,
      );

      final center = Offset(
        newTopLeft.dx + current.width / 2,
        newTopLeft.dy + current.height / 2,
      );
      final centerScreen = _boardToScreen(center, view);
      final overBin = _binRectScreen.inflate(16).contains(centerScreen);
      if (ref.read(isDraggingOverBinProvider) != overBin) {
        ref.read(isDraggingOverBinProvider.notifier).state = overBin;
      }
    } else if (_panPointerStart != null) {
      final delta = event.localPosition - _panPointerStart!;
      if (delta.distance > 2) _didPanMove = true;
      ref.read(boardViewProvider.notifier).setPan(_panOffsetStart! + delta);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dragTargetId != null) {
      final id = _dragTargetId!;
      final dragging = ref.read(draggingClipProvider);
      final overBin = ref.read(isDraggingOverBinProvider);
      final repo = ref.read(clipsRepositoryProvider);
      if (overBin) {
        repo.binClip(id);
        ref.read(selectedClipIdProvider.notifier).state = null;
      } else if (dragging != null) {
        repo.updateTransform(id, x: dragging.x, y: dragging.y);
      }
      ref.read(draggingClipProvider.notifier).state = null;
      ref.read(isDraggingOverBinProvider.notifier).state = false;
      _dragTargetId = null;
    } else {
      if (!_didPanMove) {
        ref.read(selectedClipIdProvider.notifier).state = null;
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

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(activeClipsProvider);
    final view = ref.watch(boardViewProvider);
    final dragging = ref.watch(draggingClipProvider);
    final selectedId = ref.watch(selectedClipIdProvider);
    final overBin = ref.watch(isDraggingOverBinProvider);

    final clips = clipsAsync.valueOrNull ?? [];
    final sorted = [...clips]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = constraints.biggest;
        return Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerSignal: _handlePointerSignal,
          child: Container(
            color: AppTheme.boardBackground,
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final clip in sorted)
                  _positionedClip(clip, dragging, selectedId, view),
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
        );
      },
    );
  }

  Widget _positionedClip(
    BoardClip clip,
    DraggingClip? dragging,
    String? selectedId,
    BoardViewState view,
  ) {
    final isDragging = dragging?.id == clip.id;
    final x = isDragging ? dragging!.x : clip.x;
    final y = isDragging ? dragging!.y : clip.y;
    final topLeft = _boardToScreen(Offset(x, y), view);

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: clip.width * view.scale,
      height: clip.height * view.scale,
      child: IgnorePointer(
        child: ClipWidget(clip: clip, selected: clip.id == selectedId),
      ),
    );
  }
}
