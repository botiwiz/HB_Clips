import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../board/controllers/board_controller.dart';
import 'controllers/annotation_controller.dart';
import 'stroke_painter.dart';

/// Draws freestanding strokes (not attached to any clip) plus the stroke
/// currently being drawn, in screen space. Per-clip strokes are rendered
/// separately, inline with their clip in `board_canvas.dart`, so they move
/// with it.
class DrawingOverlay extends ConsumerWidget {
  const DrawingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allStrokes = ref.watch(boardStrokesProvider).valueOrNull ?? [];
    final view = ref.watch(boardViewProvider);
    final liveBoardPoints = ref.watch(liveStrokePointsProvider);

    Offset toScreen(Offset boardPoint) =>
        boardPoint * view.scale + view.panOffset;

    final specs = <StrokeSpec>[
      for (final stroke in allStrokes)
        if (stroke.clipId == null)
          StrokeSpec(
            points: stroke.points.map(toScreen).toList(),
            color: hexToColor(stroke.colorHex),
            width: stroke.strokeWidth * view.scale,
            dashed: stroke.dashed,
            arrowEnd: stroke.arrowEnd,
          ),
      if (liveBoardPoints != null && liveBoardPoints.length > 1)
        StrokeSpec(
          points: liveBoardPoints.map(toScreen).toList(),
          color: hexToColor(ref.watch(strokeColorHexProvider)),
          width: ref.watch(strokeWidthValueProvider) * view.scale,
          dashed: ref.watch(strokeDashedProvider),
          arrowEnd: ref.watch(strokeArrowProvider),
        ),
    ];

    return IgnorePointer(
      child: CustomPaint(painter: StrokePainter(specs), size: Size.infinite),
    );
  }
}
