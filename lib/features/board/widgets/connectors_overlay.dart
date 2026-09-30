import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/board_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/selection_geometry.dart';
import 'connector_painter.dart';

/// Paints every persisted connector on the board as a curved line under
/// the clips (see `board_canvas.dart`'s Stack ordering - this sits right
/// after the frame loop and before the clip loop, so each clip's own
/// opaque box naturally occludes the segment that would otherwise "enter"
/// it). Resolves each connector's two clips against the live clip list,
/// overriding with in-progress drag state the same way `SelectionHandles`
/// does, so a connector visibly follows a clip mid-drag, not just after
/// the drag commits. Skips (does not render) any connector whose endpoint
/// clip can't currently be found - e.g. it's been binned.
class ConnectorsOverlay extends ConsumerWidget {
  const ConnectorsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectors = ref.watch(activeConnectorsProvider).valueOrNull ?? [];
    if (connectors.isEmpty) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final dragging = ref.watch(groupDragProvider);
    final view = ref.watch(boardViewProvider);

    Offset toScreen(Offset boardPoint) =>
        boardPoint * view.scale + view.panOffset;

    final specs = <ConnectorSpec>[];
    for (final connector in connectors) {
      var fromClip = ClipGeometry.findById(clips, connector.fromClipId);
      var toClip = ClipGeometry.findById(clips, connector.toClipId);
      if (fromClip == null || toClip == null) continue;

      final fromDrag = dragging?[fromClip.id];
      if (fromDrag != null) {
        fromClip = fromClip.copyWith(
          x: fromDrag.x,
          y: fromDrag.y,
          width: fromDrag.width,
          height: fromDrag.height,
          rotation: fromDrag.rotation,
        );
      }
      final toDrag = dragging?[toClip.id];
      if (toDrag != null) {
        toClip = toClip.copyWith(
          x: toDrag.x,
          y: toDrag.y,
          width: toDrag.width,
          height: toDrag.height,
          rotation: toDrag.rotation,
        );
      }

      final bezier = ConnectorGeometry.bezierBoard(
        fromClip: fromClip,
        fromSide: connector.fromSide,
        toClip: toClip,
      );
      specs.add(
        ConnectorSpec(
          p0: toScreen(bezier.p0),
          c1: toScreen(bezier.c1),
          c2: toScreen(bezier.c2),
          p3: toScreen(bezier.p3),
          color: hexToColor(connector.colorHex),
          width: connector.strokeWidth * view.scale,
        ),
      );
    }

    return IgnorePointer(
      child: CustomPaint(painter: ConnectorPainter(specs), size: Size.infinite),
    );
  }
}
