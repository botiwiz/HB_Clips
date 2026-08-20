import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import 'controllers/annotation_controller.dart';
import 'stroke_painter.dart';

/// Compact toolbar shown under the AppBar while draw mode is active: color
/// swatches, a width slider, and an undo-last-stroke button.
class DrawToolbar extends ConsumerWidget {
  const DrawToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(strokeColorHexProvider);
    final width = ref.watch(strokeWidthValueProvider);

    return Container(
      height: 48,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final colorHex in kStrokeColorPalette)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () =>
                    ref.read(strokeColorHexProvider.notifier).state =
                        colorHex,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: hexToColor(colorHex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == colorHex
                          ? AppTheme.accent
                          : Colors.black54,
                      width: selectedColor == colorHex ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          const Icon(Icons.line_weight, size: 16, color: Colors.white54),
          Expanded(
            child: Slider(
              value: width,
              min: kMinStrokeWidth,
              max: kMaxStrokeWidth,
              onChanged: (value) =>
                  ref.read(strokeWidthValueProvider.notifier).state = value,
            ),
          ),
          IconButton(
            tooltip: 'Undo last stroke',
            icon: const Icon(Icons.undo),
            onPressed: () => ref
                .read(strokesRepositoryProvider)
                .deleteMostRecentStroke(kLocalBoardId),
          ),
        ],
      ),
    );
  }
}
