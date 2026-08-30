import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/color_swatch_button.dart';
import '../../data/providers.dart';
import 'controllers/annotation_controller.dart';
import 'stroke_painter.dart';

/// Floating pill toolbar shown while draw mode is active: color swatches,
/// a width slider, and an undo-last-stroke button. The swatch colors are
/// the app's one deliberate exception to "grayscale + red only" - they're
/// content the user picks (a stroke color), not chrome.
class DrawToolbar extends ConsumerWidget {
  const DrawToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(strokeColorHexProvider);
    final width = ref.watch(strokeWidthValueProvider);
    final tool = ref.watch(drawToolProvider);

    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: Colors.black54,
      child: Container(
        height: 48,
        width: 490,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Pen',
              icon: const Icon(Icons.edit),
              color: tool == DrawTool.pen ? AppTheme.red : null,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(drawToolProvider.notifier).state = DrawTool.pen,
            ),
            IconButton(
              tooltip: 'Eraser',
              icon: const Icon(Icons.auto_fix_off_outlined),
              color: tool == DrawTool.eraser ? AppTheme.red : null,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(drawToolProvider.notifier).state = DrawTool.eraser,
            ),
            const SizedBox(width: 8),
            const VerticalDivider(color: AppTheme.border, width: 1),
            const SizedBox(width: 8),
            for (final colorHex in kStrokeColorPalette)
              ColorSwatchButton(
                color: hexToColor(colorHex),
                selected: selectedColor == colorHex,
                onTap: () =>
                    ref.read(strokeColorHexProvider.notifier).state =
                        colorHex,
              ),
            const SizedBox(width: 16),
            const Icon(
              Icons.line_weight,
              size: 16,
              color: AppTheme.textSecondary,
            ),
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
      ),
    );
  }
}
