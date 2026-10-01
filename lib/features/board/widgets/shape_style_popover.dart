import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hsv_color_picker.dart';
import '../../../data/models/clip.dart';
import '../../../data/providers.dart';
import '../../annotation/controllers/annotation_controller.dart';
import '../../annotation/stroke_painter.dart' show colorToHex, hexToColor;
import '../controllers/board_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/selection_geometry.dart';

/// Floating style pill for the sole selected shape clip - fill color (+ a
/// "no fill" option), stroke color, and stroke width. Same "floating pill
/// anchored to the selected clip's screen rect" idiom every per-selection
/// overlay in this app uses (`TextClipEditOverlay`'s toolbar,
/// `ArrangeSelectionButton`), gated on exactly one selected clip of
/// `ClipType.shape`, same single-selection gating `ConnectorHandles`/
/// `GroupScaleHandles` use. Each control pushes its own `UndoableAction`
/// (not one combined "update style" action), matching this app's
/// established per-action undo pattern.
class ShapeStylePopover extends ConsumerWidget {
  const ShapeStylePopover({super.key});

  static const double _height = 48;
  static const double _gapAboveCorner = 12;
  static const double _width = 272;

  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final topRightBoard = Offset(clip.x + clip.width, clip.y);
    final topRightScreen = topRightBoard * view.scale + view.panOffset;
    final left = topRightScreen.dx - _width;
    final top = topRightScreen.dy - _height - _gapAboveCorner;
    return Rect.fromLTWH(left, top < 8 ? 8 : top, _width, _height);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    if (selection.length != 1) return const SizedBox.shrink();
    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final clip = ClipGeometry.findById(clips, selection.first);
    if (clip == null || clip.type != ClipType.shape) {
      return const SizedBox.shrink();
    }

    final view = ref.watch(boardViewProvider);
    final rect = screenRectFor(clip, view);
    final repo = ref.read(clipsRepositoryProvider);

    void pushFillUndo(String? before, String? after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateShapeFillColor(clip.id, before),
              redo: () => repo.updateShapeFillColor(clip.id, after),
            ),
          );
    }

    void pushStrokeColorUndo(String? before, String? after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateShapeStrokeColor(clip.id, before),
              redo: () => repo.updateShapeStrokeColor(clip.id, after),
            ),
          );
    }

    void pushStrokeWidthUndo(double? before, double? after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateShapeStrokeWidth(clip.id, before),
              redo: () => repo.updateShapeStrokeWidth(clip.id, after),
            ),
          );
    }

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        elevation: 6,
        shadowColor: Colors.black54,
        child: SizedBox(
          height: rect.height,
          width: rect.width,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 6),
                _NoFillButton(
                  selected: clip.shapeFillColorHex == null,
                  onTap: () {
                    final before = clip.shapeFillColorHex;
                    if (before == null) return;
                    repo.updateShapeFillColor(clip.id, null);
                    pushFillUndo(before, null);
                  },
                ),
                ColorPickerSwatch(
                  color: clip.shapeFillColorHex != null
                      ? hexToColor(clip.shapeFillColorHex!)
                      : AppTheme.surfaceCard,
                  onColorSelected: (color) {
                    final before = clip.shapeFillColorHex;
                    final after = colorToHex(color);
                    if (before == after) return;
                    repo.updateShapeFillColor(clip.id, after);
                    pushFillUndo(before, after);
                  },
                ),
                const _Divider(),
                ColorPickerSwatch(
                  color: clip.shapeStrokeColorHex != null
                      ? hexToColor(clip.shapeStrokeColorHex!)
                      : AppTheme.border,
                  onColorSelected: (color) {
                    final before = clip.shapeStrokeColorHex;
                    final after = colorToHex(color);
                    if (before == after) return;
                    repo.updateShapeStrokeColor(clip.id, after);
                    pushStrokeColorUndo(before, after);
                  },
                ),
                const _Divider(),
                SizedBox(
                  width: 110,
                  child: _StrokeWidthSlider(
                    clipId: clip.id,
                    value: clip.shapeStrokeWidth ?? kDefaultStrokeWidth,
                    onCommit: pushStrokeWidthUndo,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.border,
    );
  }
}

/// A swatch-sized "clear fill" button, styled like [ColorSwatchButton] but
/// showing a slash-through icon instead of a solid color.
class _NoFillButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _NoFillButton({required this.selected, required this.onTap});

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
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppTheme.red : AppTheme.border,
              width: selected ? 3 : 1,
            ),
          ),
          child: const Icon(
            Icons.format_color_reset,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The stroke-width slider pushes exactly one `UndoableAction` per drag
/// (on `onChangeEnd`), not per intermediate frame - same convention
/// `TextClipEditOverlay`'s font-size chevrons use (one action per
/// adjustment, not one per keystroke-equivalent).
class _StrokeWidthSlider extends ConsumerStatefulWidget {
  final String clipId;
  final double value;
  final void Function(double before, double after) onCommit;

  const _StrokeWidthSlider({
    required this.clipId,
    required this.value,
    required this.onCommit,
  });

  @override
  ConsumerState<_StrokeWidthSlider> createState() => _StrokeWidthSliderState();
}

class _StrokeWidthSliderState extends ConsumerState<_StrokeWidthSlider> {
  double? _dragStartValue;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: widget.value.clamp(kMinStrokeWidth, kMaxStrokeWidth),
        min: kMinStrokeWidth,
        max: kMaxStrokeWidth,
        activeColor: AppTheme.textPrimary,
        onChangeStart: (v) => _dragStartValue = widget.value,
        onChanged: (v) {
          ref
              .read(clipsRepositoryProvider)
              .updateShapeStrokeWidth(widget.clipId, v);
        },
        onChangeEnd: (v) {
          final before = _dragStartValue;
          _dragStartValue = null;
          if (before != null && before != v) {
            widget.onCommit(before, v);
          }
        },
      ),
    );
  }
}
