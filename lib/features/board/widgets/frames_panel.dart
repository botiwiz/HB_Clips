import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/board_controller.dart';
import '../geometry/frame_geometry.dart';

/// Miro-style frames list: click a frame's name and the viewport pans/zooms
/// so that frame fills the window. Purely a navigation aid over frames,
/// which already exist as a full feature elsewhere (`frame_widget.dart`,
/// `FramesRepository`) - this adds no new frame data, just a way to jump to
/// one.
class FramesPanel extends ConsumerWidget {
  const FramesPanel({super.key});

  static const double _panelWidth = 220;
  static const double _maxPanelHeight = 360;

  void _selectAndFit(WidgetRef ref, BuildContext context, FrameRow frame) {
    ref.read(selectedFrameIdsProvider.notifier).state = {frame.id};
    ref
        .read(boardViewProvider.notifier)
        .fitRect(FrameGeometry.boardRect(frame), MediaQuery.sizeOf(context));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrameIds = ref.watch(selectedFrameIdsProvider);

    return Container(
      width: _panelWidth,
      constraints: const BoxConstraints(maxHeight: _maxPanelHeight),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(kCornerRadius),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: frames.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No frames yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: frames.length,
              itemBuilder: (context, index) {
                final frame = frames[index];
                final selected = selectedFrameIds.contains(frame.id);
                final swatchColor = frame.backgroundColorHex != null
                    ? hexToColor(frame.backgroundColorHex!)
                    : AppTheme.textSecondary;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: AppTheme.red.withValues(alpha: 0.12),
                  leading: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    frame.name,
                    style: TextStyle(
                      color: selected ? AppTheme.red : AppTheme.textPrimary,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => _selectAndFit(ref, context, frame),
                );
              },
            ),
    );
  }
}
