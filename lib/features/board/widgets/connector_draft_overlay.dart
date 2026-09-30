import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart';
import '../geometry/connector_geometry.dart';
import '../geometry/selection_geometry.dart';

/// Draws the dashed in-progress connector line while a connector-drag is
/// active (see `board_canvas.dart`'s `_connectorFromClipId` handling) -
/// from the fixed source anchor to the live cursor position. No arrowhead,
/// since nothing's confirmed as the target yet. Reuses `StrokePainter`'s
/// existing dashed-line path (feeding it a plain 2-point `StrokeSpec`)
/// rather than duplicating dash logic for what is, visually, just a
/// straight dashed segment.
class ConnectorDraftOverlay extends ConsumerWidget {
  const ConnectorDraftOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(connectorDraftProvider);
    if (draft == null) return const SizedBox.shrink();

    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final fromClip = ClipGeometry.findById(clips, draft.fromClipId);
    if (fromClip == null) return const SizedBox.shrink();

    final view = ref.watch(boardViewProvider);
    final startBoard = ConnectorGeometry.sideMidpointBoard(
      fromClip,
      draft.fromSide,
    );
    final startScreen = startBoard * view.scale + view.panOffset;
    final endScreen = draft.cursorBoard * view.scale + view.panOffset;

    return IgnorePointer(
      child: CustomPaint(
        painter: StrokePainter([
          StrokeSpec(
            points: [startScreen, endScreen],
            color: AppTheme.textSecondary,
            width: 2,
            dashed: true,
          ),
        ]),
        size: Size.infinite,
      ),
    );
  }
}
