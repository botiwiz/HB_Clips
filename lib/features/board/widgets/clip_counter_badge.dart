import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';

/// "N of 30 image slots remaining" badge. Text notes and strokes are
/// unlimited and never affect this count.
class ClipCounterBadge extends ConsumerWidget {
  const ClipCounterBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(imageSlotsRemainingProvider).valueOrNull;
    if (remaining == null) return const SizedBox.shrink();

    // Brightness-based urgency instead of a second hue: only the truly
    // critical tier gets the app's one red accent.
    final Color color;
    if (remaining <= 3) {
      color = AppTheme.red;
    } else if (remaining <= 10) {
      color = AppTheme.textPrimary;
    } else {
      color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$remaining of $kMaxImageClips image slots left',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
