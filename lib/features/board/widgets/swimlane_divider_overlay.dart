import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow, SwimlaneRow;
import '../../../data/providers.dart';
import '../controllers/board_controller.dart';
import '../geometry/swimlane_geometry.dart';

/// Renders every visible swimlane's horizontal divider line + left-
/// margin name label, spanning the full board-space width of its parent
/// kanban board's columns (`SwimlaneGeometry.columnSpanBoardRect`) - one
/// `Positioned` per lane, same "floating decoration computed from a
/// known board-space rect" role `FrameRenameOverlay`'s title band plays,
/// not an interactive widget (dividers/labels aren't clickable in v1).
class SwimlaneDividerOverlay extends ConsumerWidget {
  const SwimlaneDividerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(boardViewProvider);
    final swimlanes = ref.watch(boardSwimlanesProvider).valueOrNull ?? [];
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final byBoard = <String, List<FrameRow>>{};
    for (final f in frames) {
      if (f.kanbanBoardId != null) {
        (byBoard[f.kanbanBoardId!] ??= []).add(f);
      }
    }
    return IgnorePointer(
      child: Stack(
        children: [
          for (final lane in swimlanes)
            if (SwimlaneGeometry.columnSpanBoardRect(
                  byBoard[lane.kanbanBoardId] ?? const [],
                )
                case final span?)
              _laneDivider(lane, span, view),
        ],
      ),
    );
  }

  Widget _laneDivider(SwimlaneRow lane, Rect columnSpan, BoardViewState view) {
    final topLeftScreen =
        Offset(columnSpan.left, lane.y) * view.scale + view.panOffset;
    final widthScreen = columnSpan.width * view.scale;
    return Positioned(
      left: topLeftScreen.dx,
      top: topLeftScreen.dy,
      width: widthScreen,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(width: widthScreen, height: 1, color: AppTheme.border),
          Positioned(
            left: 0,
            top: -18,
            child: Text(
              lane.name,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
