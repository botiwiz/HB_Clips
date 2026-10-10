import 'package:flutter/material.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';

/// A floating rounded-pill cluster of icon buttons - the Miro-style
/// "grouped toolbar island" shape used throughout `board_screen.dart`
/// instead of a full-width Material `AppBar`.
class PillGroup extends StatelessWidget {
  final List<Widget> children;

  const PillGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(kCornerRadius),
      elevation: 6,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        // The number of icons here grows with app state (selection,
        // frame-selected, etc.) and has no fixed upper bound - without
        // this, a pill wide enough to exceed the available window width
        // just gets silently clipped by the outer Stack, making trailing
        // buttons (e.g. "Add text note") invisible with no error and no
        // way to reach them. Scrolling instead of wrapping/shrinking keeps
        // every icon at a constant, predictable size.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// A compact icon button sized to sit comfortably inside a [PillGroup].
class PillIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  /// [VisualDensity.compact] (the default everywhere else) renders about
  /// 8px shorter than the File/Board-switcher pills next to it - those
  /// get their height from their own 10px vertical content padding, not
  /// from an IconButton at all. Standalone single-row pill groups (e.g.
  /// Bin/About) sit right next to those taller pills with nothing else to
  /// visually average the mismatch away, so they opt into
  /// [VisualDensity.standard] here to match exactly; every other
  /// `PillIconButton` call site keeps the compact default unchanged.
  final VisualDensity visualDensity;

  const PillIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.visualDensity = VisualDensity.compact,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color),
      iconSize: 20,
      visualDensity: visualDensity,
      onPressed: onPressed,
    );
  }
}
