import 'package:flutter/material.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../annotation/stroke_painter.dart' show hexToColor;

/// Renders one frame's rectangle, name label, and (when selected, and
/// exactly one frame - with nothing else - is selected) its single
/// bottom-right resize handle, which only ever changes the frame's own
/// rect - never its children's, see `FrameGeometry.resize`'s doc comment.
/// Purely presentational - all pointer handling/hit-testing happens in
/// `board_canvas.dart`'s Listener, same architecture as clips. Frames are
/// always painted behind clips regardless of z-index (background/grouping
/// elements, not peer objects), so the caller positions this before the
/// clip loop.
class FrameWidget extends StatelessWidget {
  final FrameRow frame;
  final bool selected;
  // Only true when this frame is selected AND it's the only thing
  // selected (no other frame, no clip) - a mixed or multi-frame selection
  // scales through FrameGroupScaleHandles's bounding-box handles instead,
  // so showing this one too would be non-functional dead chrome.
  final bool showResizeHandles;

  /// Whether this frame has at least one `kanban_task_links` row pointing
  /// at it - same corner-badge role `ClipWidget.hasKanbanLink` plays for
  /// clips, computed the same way by `BoardCanvas`.
  final bool hasKanbanLink;

  const FrameWidget({
    super.key,
    required this.frame,
    required this.selected,
    required this.showResizeHandles,
    this.hasKanbanLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final customColor = frame.backgroundColorHex != null
        ? hexToColor(frame.backgroundColorHex!)
        : null;
    // Selection always reads as red, matching every other selectable object
    // on the board - a custom frame color only shows up while unselected.
    final accentColor = selected
        ? AppTheme.accent
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
                      ? AppTheme.accent
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
                  color: AppTheme.accent,
                  border: Border.all(
                    color: AppTheme.canvasBackground,
                    width: 1,
                  ),
                ),
              ),
            ),
          if (hasKanbanLink)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.canvasBackground,
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.link, size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
