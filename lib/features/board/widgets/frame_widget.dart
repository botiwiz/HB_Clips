import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;

/// Renders one frame's rectangle, name label, and (when selected) its
/// single bottom-right resize handle. Purely presentational - all pointer
/// handling/hit-testing happens in `board_canvas.dart`'s Listener, same
/// architecture as clips. Frames are always painted behind clips
/// regardless of z-index (background/grouping elements, not peer
/// objects), so the caller positions this before the clip loop.
class FrameWidget extends StatelessWidget {
  final FrameRow frame;
  final bool selected;

  const FrameWidget({super.key, required this.frame, required this.selected});

  @override
  Widget build(BuildContext context) {
    final accentColor = selected ? AppTheme.red : AppTheme.textSecondary;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppTheme.red : AppTheme.border,
                  width: selected ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: -22,
            child: Text(
              frame.name,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.red,
                  border: Border.all(
                    color: AppTheme.canvasBackground,
                    width: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
