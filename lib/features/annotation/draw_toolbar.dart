import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hsv_color_picker.dart';
import '../../data/providers.dart';
import '../board/widgets/board_toolbar.dart';
import 'controllers/annotation_controller.dart';
import 'stroke_painter.dart';

/// Floating pill toolbar shown while draw mode is active: color swatches,
/// a width slider, and an undo-last-stroke button. The swatch colors are
/// the app's one deliberate exception to "grayscale + red only" - they're
/// content the user picks (a stroke color), not chrome.
///
/// The color swatch opens an anchored [InlineHsvPickerBar] below the pill
/// - the same "stays open until you click elsewhere, live-updates as you
/// drag" pattern `TextClipEditOverlay`'s highlight-color picker uses -
/// instead of a modal dialog.
class DrawToolbar extends ConsumerWidget {
  const DrawToolbar({super.key});

  static const double pillWidth = 610;
  static const double pillHeight = 48;
  // Matches the fixed `top: 76` board_screen.dart positions this toolbar
  // at - duplicated here (not read from there) so board_canvas.dart's
  // click-through guard can compute this toolbar's screen rect without a
  // dependency on board_screen.dart's own layout code.
  static const double pillTop = 76;
  static const double pickerHeight = 44;
  static const double _pickerGap = 8;

  /// Screen-space bounds of the pill itself, given the full canvas size -
  /// same click-through-guard role `ShapeStylePopover.screenRectFor` plays,
  /// just centered horizontally instead of clip-anchored.
  static Rect pillRectFor(Size canvasSize) {
    final left = (canvasSize.width - pillWidth) / 2;
    return Rect.fromLTWH(left, pillTop, pillWidth, pillHeight);
  }

  /// Screen-space bounds of the anchored stroke-color picker bar, shown
  /// directly below the pill while open.
  static Rect pickerRectFor(Size canvasSize) {
    final pill = pillRectFor(canvasSize);
    return Rect.fromLTWH(
      pill.left,
      pill.bottom + _pickerGap,
      pillWidth,
      pickerHeight,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(strokeColorHexProvider);
    final width = ref.watch(strokeWidthValueProvider);
    final tool = ref.watch(drawToolProvider);
    final dashed = ref.watch(strokeDashedProvider);
    final arrowEnd = ref.watch(strokeArrowProvider);
    final pickerOpen = ref.watch(drawStrokeColorPickerOpenProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          elevation: 6,
          shadowColor: Colors.black54,
          child: Container(
            height: pillHeight,
            width: pillWidth,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                PillIconButton(
                  tooltip: 'Pen',
                  icon: Icons.edit,
                  color: tool == DrawTool.pen ? AppTheme.red : null,
                  onPressed: () =>
                      ref.read(drawToolProvider.notifier).state = DrawTool.pen,
                ),
                PillIconButton(
                  tooltip: 'Eraser',
                  icon: Icons.auto_fix_off_outlined,
                  color: tool == DrawTool.eraser ? AppTheme.red : null,
                  onPressed: () => ref.read(drawToolProvider.notifier).state =
                      DrawTool.eraser,
                ),
                PillIconButton(
                  tooltip: 'Eyedropper',
                  icon: Icons.colorize,
                  color: tool == DrawTool.eyedropper ? AppTheme.red : null,
                  onPressed: () => ref.read(drawToolProvider.notifier).state =
                      DrawTool.eyedropper,
                ),
                const SizedBox(width: 8),
                const VerticalDivider(color: AppTheme.border, width: 1),
                const SizedBox(width: 8),
                InlineColorPickerSwatch(
                  color: hexToColor(selectedColor),
                  open: pickerOpen,
                  onTap: () =>
                      ref
                              .read(drawStrokeColorPickerOpenProvider.notifier)
                              .state =
                          !pickerOpen,
                ),
                const SizedBox(width: 8),
                const VerticalDivider(color: AppTheme.border, width: 1),
                const SizedBox(width: 8),
                PillIconButton(
                  tooltip: 'Dashed line',
                  icon: Icons.more_horiz,
                  color: dashed ? AppTheme.red : null,
                  onPressed: () => ref
                      .read(strokeDashedProvider.notifier)
                      .update((value) => !value),
                ),
                PillIconButton(
                  tooltip: 'Arrow end',
                  icon: Icons.arrow_right_alt,
                  color: arrowEnd ? AppTheme.red : null,
                  onPressed: () => ref
                      .read(strokeArrowProvider.notifier)
                      .update((value) => !value),
                ),
                const SizedBox(width: 8),
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
                        ref.read(strokeWidthValueProvider.notifier).state =
                            value,
                  ),
                ),
                PillIconButton(
                  tooltip: 'Undo last stroke',
                  icon: Icons.undo,
                  onPressed: () => ref
                      .read(strokesRepositoryProvider)
                      .deleteMostRecentStroke(ref.read(currentBoardIdProvider)),
                ),
              ],
            ),
          ),
        ),
        if (pickerOpen) ...[
          const SizedBox(height: _pickerGap),
          Material(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            elevation: 6,
            shadowColor: Colors.black54,
            child: SizedBox(
              height: pickerHeight,
              width: pillWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: InlineHsvPickerBar(
                  initialColor: hexToColor(selectedColor),
                  onChanged: (color) =>
                      ref.read(strokeColorHexProvider.notifier).state =
                          colorToHex(color),
                  onDone: () =>
                      ref
                              .read(drawStrokeColorPickerOpenProvider.notifier)
                              .state =
                          false,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
