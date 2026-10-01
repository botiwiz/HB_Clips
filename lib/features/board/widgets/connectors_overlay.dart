import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/board_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/selection_geometry.dart';
import 'connector_painter.dart';

/// Paints every persisted connector on the board as a curved line always
/// on top of every clip (see `board_canvas.dart`'s Stack ordering - this
/// sits right after the clip loop, so a connector stays visible crossing
/// over an image instead of being occluded by it). Resolves each
/// connector's two clips against the live clip list,
/// overriding with in-progress drag state the same way `SelectionHandles`
/// does, so a connector visibly follows a clip mid-drag, not just after
/// the drag commits. Skips (does not render) any connector whose endpoint
/// clip can't currently be found - e.g. it's been binned - or whose id
/// matches an in-progress endpoint-retarget drag (`ConnectorDraftOverlay`'s
/// dashed preview stands in for it while that drag is live). The selected
/// connector (`selectedConnectorIdProvider`) renders in the accent color.
class ConnectorsOverlay extends ConsumerWidget {
  const ConnectorsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectors = ref.watch(activeConnectorsProvider).valueOrNull ?? [];
    if (connectors.isEmpty) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final dragging = ref.watch(groupDragProvider);
    final view = ref.watch(boardViewProvider);
    final retargetingId = ref
        .watch(connectorDraftProvider)
        ?.existingConnectorId;
    final selectedId = ref.watch(selectedConnectorIdProvider);

    Offset toScreen(Offset boardPoint) =>
        boardPoint * view.scale + view.panOffset;

    final specs = <ConnectorSpec>[];
    for (final connector in connectors) {
      if (connector.id == retargetingId) continue;
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

      final route = ConnectorGeometry.routeBoard(
        fromClip: fromClip,
        fromSide: connector.fromSide,
        toClip: toClip,
        toRelX: connector.toRelX,
        toRelY: connector.toRelY,
      );
      final selected = connector.id == selectedId;
      specs.add(
        ConnectorSpec(
          points: [for (final point in route) toScreen(point)],
          color: selected ? AppTheme.red : hexToColor(connector.colorHex),
          width: connector.strokeWidth * view.scale,
          cornerRadius: kConnectorCornerRadius * view.scale,
        ),
      );
    }

    return IgnorePointer(
      child: CustomPaint(painter: ConnectorPainter(specs), size: Size.infinite),
    );
  }
}
