import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small tappable color circle, selected-ring highlighted in red. Shared
/// by the draw toolbar's stroke-color palette and the clip style popover's
/// text-note background palette - both are "pick one of a fixed set of
/// colors" UI, just for different targets.
class ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppTheme.red : AppTheme.border,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
