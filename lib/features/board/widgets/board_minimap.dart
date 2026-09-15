import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';

/// A small bird's-eye view of the whole board in a fixed panel: every
/// active clip as a plain rectangle (no image rendering - stays cheap
/// regardless of clip count), plus an outline for the current viewport.
/// Click or drag inside it to re-center the main view there.
class BoardMinimap extends ConsumerWidget {
  const BoardMinimap({super.key});

  static const double _panelWidth = 180;
  static const double _panelHeight = 120;

  /// Board-space margin added around the content/viewport union so clips
  /// and the viewport outline never sit flush against the panel's edge.
  static const double _boardPadding = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final view = ref.watch(boardViewProvider);
    final screenSize = MediaQuery.sizeOf(context);

    final viewportRect = _viewportBoardRect(view, screenSize);
    final contentRect = _contentRect(clips, viewportRect);
    final transform = _MinimapTransform(
      contentRect: contentRect,
      panelSize: const Size(_panelWidth, _panelHeight),
    );

    return GestureDetector(
      onTapDown: (details) => _jumpTo(ref, transform, details.localPosition, screenSize),
      onPanUpdate: (details) => _jumpTo(ref, transform, details.localPosition, screenSize),
      child: Container(
        width: _panelWidth,
        height: _panelHeight,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _MinimapPainter(
            clips: clips,
            viewportRect: viewportRect,
            transform: transform,
          ),
        ),
      ),
    );
  }

  static Rect _viewportBoardRect(BoardViewState view, Size screenSize) {
    final topLeft = -view.panOffset / view.scale;
    final bottomRight =
        (Offset(screenSize.width, screenSize.height) - view.panOffset) / view.scale;
    return Rect.fromPoints(topLeft, bottomRight);
  }

  static Rect _contentRect(List<BoardClip> clips, Rect viewportRect) {
    var minX = viewportRect.left;
    var minY = viewportRect.top;
    var maxX = viewportRect.right;
    var maxY = viewportRect.bottom;
    for (final clip in clips) {
      minX = min(minX, clip.x);
      minY = min(minY, clip.y);
      maxX = max(maxX, clip.x + clip.width);
      maxY = max(maxY, clip.y + clip.height);
    }
    return Rect.fromLTRB(
      minX - _boardPadding,
      minY - _boardPadding,
      maxX + _boardPadding,
      maxY + _boardPadding,
    );
  }

  void _jumpTo(
    WidgetRef ref,
    _MinimapTransform transform,
    Offset localPosition,
    Size screenSize,
  ) {
    final boardPoint = transform.panelToBoard(localPosition);
    final view = ref.read(boardViewProvider);
    final newPan =
        Offset(screenSize.width / 2, screenSize.height / 2) - boardPoint * view.scale;
    ref.read(boardViewProvider.notifier).setPan(newPan);
  }
}

/// Uniform-scale, letterboxed mapping between board space and the minimap
/// panel's local pixel space - shared by the painter and the tap handler
/// so "what you see is where you jump to" stays exact.
class _MinimapTransform {
  final Rect contentRect;
  final Size panelSize;
  final double scale;
  final double offsetX;
  final double offsetY;

  _MinimapTransform._(
    this.contentRect,
    this.panelSize,
    this.scale,
    this.offsetX,
    this.offsetY,
  );

  // Centers the (likely non-matching-aspect-ratio) content within the
  // panel rather than stretching it, so clip proportions stay true.
  factory _MinimapTransform({required Rect contentRect, required Size panelSize}) {
    final scale = min(
      panelSize.width / contentRect.width,
      panelSize.height / contentRect.height,
    );
    final offsetX = (panelSize.width - contentRect.width * scale) / 2;
    final offsetY = (panelSize.height - contentRect.height * scale) / 2;
    return _MinimapTransform._(contentRect, panelSize, scale, offsetX, offsetY);
  }

  Offset boardToPanel(Offset boardPoint) {
    return Offset(
      (boardPoint.dx - contentRect.left) * scale + offsetX,
      (boardPoint.dy - contentRect.top) * scale + offsetY,
    );
  }

  Offset panelToBoard(Offset panelPoint) {
    return Offset(
      contentRect.left + (panelPoint.dx - offsetX) / scale,
      contentRect.top + (panelPoint.dy - offsetY) / scale,
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final List<BoardClip> clips;
  final Rect viewportRect;
  final _MinimapTransform transform;

  _MinimapPainter({
    required this.clips,
    required this.viewportRect,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipPaint = Paint()..color = AppTheme.textSecondary.withValues(alpha: 0.7);
    for (final clip in clips) {
      final topLeft = transform.boardToPanel(Offset(clip.x, clip.y));
      final bottomRight = transform.boardToPanel(
        Offset(clip.x + clip.width, clip.y + clip.height),
      );
      canvas.drawRect(Rect.fromPoints(topLeft, bottomRight), clipPaint);
    }

    final viewportPaint = Paint()
      ..color = AppTheme.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final vTopLeft = transform.boardToPanel(viewportRect.topLeft);
    final vBottomRight = transform.boardToPanel(viewportRect.bottomRight);
    canvas.drawRect(Rect.fromPoints(vTopLeft, vBottomRight), viewportPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.clips != clips ||
        oldDelegate.viewportRect != viewportRect ||
        oldDelegate.transform.contentRect != transform.contentRect;
  }
}
