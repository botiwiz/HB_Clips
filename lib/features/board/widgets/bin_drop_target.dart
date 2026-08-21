import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';

/// Fixed-position drop target rendered in screen space (not affected by
/// board pan/zoom) that clips get dragged onto to bin them.
class BinDropTarget extends StatelessWidget {
  final bool highlighted;
  final VoidCallback onTap;

  const BinDropTarget({
    super.key,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppTheme.red : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: kBinTargetSize,
        height: kBinTargetSize,
        decoration: BoxDecoration(
          color: highlighted
              ? AppTheme.red.withValues(alpha: 0.25)
              : AppTheme.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(Icons.delete_outline, color: color, size: 28),
      ),
    );
  }
}
