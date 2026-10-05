import 'package:flutter/material.dart';

import '../constants.dart' show kCornerRadius;
import '../theme/app_theme.dart';

/// A solid-color circular swatch button that toggles an external
/// open/closed flag instead of opening a modal dialog - the "trigger"
/// half of the anchored, stays-open-until-click-elsewhere
/// [InlineHsvPickerBar] pattern (see that class's doc comment). Callers
/// own the open/closed state (typically a
/// `StateProvider<bool>`) and are responsible for actually rendering an
/// [InlineHsvPickerBar] somewhere when [open] is true, plus a
/// click-through guard wherever a raw canvas gesture listener could
/// otherwise steal the tap/drag meant for that bar's sliders - same
/// requirement `TextClipEditOverlay`'s highlight-color picker already
/// has. [open] drives a red highlight ring so it's visually clear which
/// swatch's picker (if any) is currently showing.
class InlineColorPickerSwatch extends StatelessWidget {
  final Color color;
  final bool open;
  final VoidCallback onTap;
  final double size;

  const InlineColorPickerSwatch({
    super.key,
    required this.color,
    required this.open,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: open ? AppTheme.red : AppTheme.border,
              width: open ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// A draggable horizontal gradient bar - the shared building block behind
/// every Hue/Saturation/Value slider in this app's [InlineHsvPickerBar].
/// [value] is normalized 0..1 along the bar's width.
class GradientBar extends StatelessWidget {
  final List<Color> colors;
  final double value;
  final ValueChanged<double> onChanged;
  static const double _height = 32;

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
        void handle(Offset localPosition) {
          final t = (localPosition.dx / width).clamp(0.0, 1.0);
          onChanged(t);
        }

        return GestureDetector(
          onPanDown: (details) => handle(details.localPosition),
          onPanUpdate: (details) => handle(details.localPosition),
          child: Container(
            height: _height,
            decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: value.clamp(0.0, 1.0) * width - 1.5,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(kCornerRadius),
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
/// Cancel. Every in-progress change is reported live via [onChanged]
/// (commit-as-you-drag, not commit-only-on-Done), so a caller that
/// already shows its own live-updating swatch elsewhere (e.g. a toolbar
/// button, via [InlineColorPickerSwatch]) doesn't need a second,
/// redundant preview here - and since there's no separate "working"
/// color to discard, there's nothing for a Cancel button to revert.
/// Callers anchor this directly above/below their own trigger swatch and
/// close it on a click elsewhere (see [InlineColorPickerSwatch]'s doc
/// comment for the full pattern), rather than it appearing as a centered
/// modal dialog.
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
        const SizedBox(width: 6),
        Expanded(
          flex: 1,
          child: GradientBar(
            colors: saturationColors,
            value: _hsv.saturation,
            onChanged: (t) => _update(_hsv.withSaturation(t)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 1,
          child: GradientBar(
            colors: valueColors,
            value: _hsv.value,
            onChanged: (t) => _update(_hsv.withValue(t)),
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: widget.onDone,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
