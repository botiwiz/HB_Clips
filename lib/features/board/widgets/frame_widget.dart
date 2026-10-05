import 'package:flutter/material.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../annotation/stroke_painter.dart' show hexToColor;

/// Renders one frame's rectangle, name label, and (when selected, and
/// exactly one frame is selected) its two resize handles: the existing
/// bottom-right one (which also scales/moves children) and a second,
/// top-right one (which only ever changes the frame's own rect, see
/// `FrameGeometry.resizeFrameOnly`). Purely presentational - all pointer
/// handling/hit-testing happens in `board_canvas.dart`'s Listener, same
/// architecture as clips. Frames are always painted behind clips
/// regardless of z-index (background/grouping elements, not peer
/// objects), so the caller positions this before the clip loop.
class FrameWidget extends StatelessWidget {
  final FrameRow frame;
  final bool selected;
  // Only true alongside `selected` when exactly one frame is selected -
  // both handles are single-frame-only mechanisms (2+-frame resize goes
  // through FrameGroupScaleHandles instead), so showing them during a
  // multi-selection would be non-functional dead chrome.
  final bool showResizeHandles;

  const FrameWidget({
    super.key,
    required this.frame,
    required this.selected,
    required this.showResizeHandles,
  });

  @override
  Widget build(BuildContext context) {
    final customColor = frame.backgroundColorHex != null
        ? hexToColor(frame.backgroundColorHex!)
        : null;
    // Selection always reads as red, matching every other selectable object
    // on the board - a custom frame color only shows up while unselected.
    final accentColor = selected
        ? AppTheme.red
        : (customColor ?? AppTheme.textSecondary);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: !selected && customColor != null
                    ? customColor.withValues(alpha: 0.08)
                    : null,
                border: Border.all(
                  color: selected
                      ? AppTheme.red
                      : (customColor ?? AppTheme.border),
                  width: selected ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(kCornerRadius),
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
          if (showResizeHandles)
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
          // Frame-only resize handle (top-right) - a different corner and
          // color from the one above so the two are never confused: this
          // one never touches child clips, see FrameGeometry.resizeFrameOnly.
          if (showResizeHandles)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimary,
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
