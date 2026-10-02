import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A solid-color circular swatch button - shows the current color and, on
/// tap, opens [showHsvColorPicker]. Replaces the fixed-palette
/// [ColorSwatchButton] wherever a free-form color choice is wanted instead
/// of a small preset list.
class ColorPickerSwatch extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorSelected;
  final double size;

  const ColorPickerSwatch({
    super.key,
    required this.color,
    required this.onColorSelected,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () async {
          final picked = await showHsvColorPicker(context, initialColor: color);
          if (picked != null) onColorSelected(picked);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border, width: 1),
          ),
        ),
      ),
    );
  }
}

/// Opens a Hue/Saturation/Value color-picker dialog seeded at
/// [initialColor]. Returns the picked color on "Done", or null if
/// cancelled/dismissed without choosing.
Future<Color?> showHsvColorPicker(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _HsvColorPickerDialog(initialColor: initialColor),
  );
}

class _HsvColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _HsvColorPickerDialog({required this.initialColor});

  @override
  State<_HsvColorPickerDialog> createState() => _HsvColorPickerDialogState();
}

class _HsvColorPickerDialogState extends State<_HsvColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);

  @override
  Widget build(BuildContext context) {
    final hueColors = [
      for (var i = 0; i <= 6; i++)
        HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    ];
    final saturationColors = [
      HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
      HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
    ];
    final valueColors = [
      HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
      HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
    ];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 560,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hsv.toColor(),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _LabeledGradientBar(
                  label: 'Hue',
                  colors: hueColors,
                  value: _hsv.hue / 360,
                  onChanged: (t) =>
                      setState(() => _hsv = _hsv.withHue(t * 360)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _LabeledGradientBar(
                  label: 'Saturation',
                  colors: saturationColors,
                  value: _hsv.saturation,
                  onChanged: (t) =>
                      setState(() => _hsv = _hsv.withSaturation(t)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _LabeledGradientBar(
                  label: 'Value',
                  colors: valueColors,
                  value: _hsv.value,
                  onChanged: (t) => setState(() => _hsv = _hsv.withValue(t)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_hsv.toColor()),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [GradientBar] with its small secondary-colored label directly
/// underneath - the repeated shape all 3 sliders (Hue/Saturation/Value)
/// share when laid out side by side on one row.
class _LabeledGradientBar extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;

  const _LabeledGradientBar({
    required this.label,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradientBar(colors: colors, value: value, onChanged: onChanged),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// A draggable horizontal gradient bar - the shared building block behind
/// every Hue/Saturation/Value slider in this app (the modal
/// [showHsvColorPicker] dialog and [InlineHsvPickerBar] alike). [value] is
/// normalized 0..1 along the bar's width.
class GradientBar extends StatelessWidget {
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;
  static const double _height = 32;
  // The bar is a fully-rounded pill (borderRadius = _height / 2), so its
  // flat, draggable middle section only starts/ends this many pixels in
  // from each edge - letting the indicator travel all the way to 0/width
  // would let it slide out into the rounded cap, where a straight vertical
  // bar reads as visually wrong (not following the pill's curve). Clamping
  // the indicator's travel range to [capRadius, width - capRadius] keeps
  // it within the cap's center at the extremes instead.
  static const double _capRadius = _height / 2;

  const GradientBar({
    super.key,
    required this.colors,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = (width - 2 * _capRadius).clamp(0.0, width);
        void handle(Offset localPosition) {
          final t = ((localPosition.dx - _capRadius) / travel).clamp(0.0, 1.0);
          onChanged(t);
        }

        return GestureDetector(
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_height / 2),
              gradient: LinearGradient(colors: colors),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _capRadius + value.clamp(0.0, 1.0) * travel - 1.5,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An inline, non-modal HSV picker bar - just the Hue/Saturation/Value
/// [GradientBar] sliders and a "Done" button, no swatch preview and no
/// Cancel. Every in-progress change is reported live via [onChanged] (vs.
/// the modal [showHsvColorPicker]'s commit-only-on-Done flow), so a
/// caller that already shows its own live-updating swatch elsewhere (e.g.
/// a toolbar button) doesn't need a second, redundant preview here - and
/// since there's no separate "working" color to discard, there's nothing
/// for a Cancel button to revert. Used by `TextClipEditOverlay`'s
/// highlight-color picker, anchored above its toolbar instead of
/// appearing as a centered dialog.
class InlineHsvPickerBar extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;
  final VoidCallback onDone;

  const InlineHsvPickerBar({
    super.key,
    required this.initialColor,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<InlineHsvPickerBar> createState() => _InlineHsvPickerBarState();
}

class _InlineHsvPickerBarState extends State<InlineHsvPickerBar> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);

  void _update(HSVColor next) {
    setState(() => _hsv = next);
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final hueColors = [
      for (var i = 0; i <= 6; i++)
        HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    ];
    final saturationColors = [
      HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
      HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
    ];
    final valueColors = [
      HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
      HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: GradientBar(
            colors: hueColors,
            value: _hsv.hue / 360,
            onChanged: (t) => _update(_hsv.withHue(t * 360)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: GradientBar(
            colors: saturationColors,
            value: _hsv.saturation,
            onChanged: (t) => _update(_hsv.withSaturation(t)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: GradientBar(
            colors: valueColors,
            value: _hsv.value,
            onChanged: (t) => _update(_hsv.withValue(t)),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: widget.onDone, child: const Text('Done')),
      ],
    );
  }
}
