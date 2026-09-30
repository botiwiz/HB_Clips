import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Draws two kinds of connector handle dots, purely presentational (same
/// architecture as `SelectionHandles` - actual hit-testing/dragging is done
/// manually in `board_canvas.dart`'s `Listener`, not by these widgets):
/// the 4 edge-midpoint dots a selected *text clip* gets (draggable to
/// start a brand-new connector to an image clip elsewhere), and the
/// draggable endpoint circle of the currently *selected connector*
/// (draggable to reposition/retarget it) - drawn in the accent color to
/// match that connector's highlighted curve.
class ConnectorHandles extends ConsumerWidget {
  const ConnectorHandles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final view = ref.watch(boardViewProvider);
    final dragging = ref.watch(groupDragProvider);

    final children = <Widget>[];

    final selection = ref.watch(selectedClipIdsProvider);
    final editingId = ref.watch(editingTextClipIdProvider);
    if (selection.length == 1 && selection.first != editingId) {
      var clip = ClipGeometry.findById(clips, selection.first);
      final clipDrag = dragging?[selection.first];
      if (clip != null && clip.type == ClipType.text) {
        if (clipDrag != null) {
          clip = clip.copyWith(
            x: clipDrag.x,
            y: clipDrag.y,
            width: clipDrag.width,
            height: clipDrag.height,
            rotation: clipDrag.rotation,
          );
        }
        final positions = ConnectorGeometry.handleScreenPositions(clip, view);
        children.addAll([
          for (final entry in positions.values)
            _handle(entry, ConnectorGeometry.handleVisualSize, AppTheme.textSecondary),
        ]);
      }
    }

    final selectedConnectorId = ref.watch(selectedConnectorIdProvider);
    final retargetingId = ref.watch(connectorDraftProvider)?.existingConnectorId;
    if (selectedConnectorId != null && selectedConnectorId != retargetingId) {
      final connectors = ref.watch(activeConnectorsProvider).valueOrNull ?? [];
      Connector? connector;
      for (final c in connectors) {
        if (c.id == selectedConnectorId) {
          connector = c;
          break;
        }
      }
      if (connector != null) {
        var fromClip = ClipGeometry.findById(clips, connector.fromClipId);
        var toClip = ClipGeometry.findById(clips, connector.toClipId);
        if (fromClip != null && toClip != null) {
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
            toRelX: connector.toRelX,
            toRelY: connector.toRelY,
          );
          final p3Screen = bezier.p3 * view.scale + view.panOffset;
          children.add(
            _handle(p3Screen, ConnectorGeometry.handleVisualSize + 4, AppTheme.red),
          );
        }
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(children: children);
  }

  Widget _handle(Offset screenPosition, double size, Color color) {
    return Positioned(
      left: screenPosition.dx - size / 2,
      top: screenPosition.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.canvasBackground, width: 1),
          ),
        ),
      ),
    );
  }
}
