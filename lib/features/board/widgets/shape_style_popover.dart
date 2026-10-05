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
import '../geometry/frame_geometry.dart';
import '../geometry/selection_geometry.dart';
import 'board_canvas.dart';

/// Floating style pill for the sole selected shape clip - fill color (+ a
/// "no fill" option), stroke color, and stroke width. Same "floating pill
/// anchored to the selected clip's screen rect" idiom every per-selection
/// overlay in this app uses (`TextClipEditOverlay`'s toolbar,
/// `ArrangeSelectionButton`), gated on exactly one selected clip of
/// `ClipType.shape`, same single-selection gating `ConnectorHandles`/
/// `GroupScaleHandles` use. Each control pushes its own `UndoableAction`
/// (not one combined "update style" action), matching this app's
/// established per-action undo pattern.
///
/// The fill/stroke swatches open an anchored [InlineHsvPickerBar] above
/// the pill - the same "stays open until you click elsewhere, live-updates
/// as you drag" pattern `TextClipEditOverlay`'s highlight-color picker
/// uses - instead of a modal dialog.
class ShapeStylePopover extends ConsumerStatefulWidget {
  const ShapeStylePopover({super.key});

  static const double _height = 48;
  static const double _gapAboveCorner = 12;
  static const double _width = 272;
  static const double _pickerHeight = 44;

  static Rect screenRectFor(BoardClip clip, BoardViewState view) {
    final topRightBoard = Offset(clip.x + clip.width, clip.y);
    final topRightScreen = topRightBoard * view.scale + view.panOffset;
    final left = topRightScreen.dx - _width;
    final top = topRightScreen.dy - _height - _gapAboveCorner;
    return Rect.fromLTWH(left, top < 8 ? 8 : top, _width, _height);
  }

  /// Screen-space bounds of the anchored fill/stroke color-picker bar,
  /// shown directly above the pill while either swatch is toggled open -
  /// same click-through-guard role [screenRectFor] plays for the pill
  /// itself (see `board_canvas.dart`'s use of this, gated on either
  /// picker-open provider since the bar only exists while one is open).
  static Rect pickerRectFor(BoardClip clip, BoardViewState view) {
    final pillRect = screenRectFor(clip, view);
    final top = pillRect.top - 8 - _pickerHeight;
    return Rect.fromLTWH(
      pillRect.left,
      top < 8 ? 8 : top,
      _width,
      _pickerHeight,
    );
  }

  @override
  ConsumerState<ShapeStylePopover> createState() => _ShapeStylePopoverState();
}

class _ShapeStylePopoverState extends ConsumerState<ShapeStylePopover> {
  // Which clip the two picker-open providers (and the *before* snapshots
  // below) currently refer to - lets build() detect a selection change
  // (a different shape selected, or none) and close/commit any picker
  // left open for the PREVIOUS clip, instead of carrying stale open
  // state over onto whichever shape is selected next (this State object
  // is reused across rebuilds regardless of which clip is selected).
  String? _boundClipId;
  String? _fillColorBeforePicker;
  String? _strokeColorBeforePicker;

  /// Closes whichever of the two pickers is open for [id], pushing one
  /// undo step per picker that actually changed color while open - mirrors
  /// `TextClipEditOverlay._closeHighlightPicker` exactly. Safe to call
  /// with a since-deleted/deselected clip id (the repository write below
  /// just no-ops against zero rows).
  void _closePickers(String id) {
    final fillOpen = ref.read(shapeFillPickerOpenProvider);
    final strokeOpen = ref.read(shapeStrokePickerOpenProvider);
    if (!fillOpen && !strokeOpen) return;
    final repo = ref.read(clipsRepositoryProvider);
    final liveClip = ClipGeometry.findById(
      ref.read(activeClipsProvider).valueOrNull ?? [],
      id,
    );
    if (fillOpen) {
      final before = _fillColorBeforePicker;
      _fillColorBeforePicker = null;
      ref.read(shapeFillPickerOpenProvider.notifier).state = false;
      final after = liveClip?.shapeFillColorHex;
      if (before != after) {
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => repo.updateShapeFillColor(id, before),
                redo: () => repo.updateShapeFillColor(id, after),
              ),
            );
      }
    }
    if (strokeOpen) {
      final before = _strokeColorBeforePicker;
      _strokeColorBeforePicker = null;
      ref.read(shapeStrokePickerOpenProvider.notifier).state = false;
      final after = liveClip?.shapeStrokeColorHex;
      if (before != after) {
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => repo.updateShapeStrokeColor(id, before),
                redo: () => repo.updateShapeStrokeColor(id, after),
              ),
            );
      }
    }
  }

  void _toggleFillPicker(BoardClip clip) {
    if (ref.read(shapeFillPickerOpenProvider)) {
      _closePickers(clip.id);
      return;
    }
    if (ref.read(shapeStrokePickerOpenProvider)) _closePickers(clip.id);
    _fillColorBeforePicker = clip.shapeFillColorHex;
    ref.read(shapeFillPickerOpenProvider.notifier).state = true;
  }

  void _toggleStrokePicker(BoardClip clip) {
    if (ref.read(shapeStrokePickerOpenProvider)) {
      _closePickers(clip.id);
      return;
    }
    if (ref.read(shapeFillPickerOpenProvider)) _closePickers(clip.id);
    _strokeColorBeforePicker = clip.shapeStrokeColorHex;
    ref.read(shapeStrokePickerOpenProvider.notifier).state = true;
  }

  /// Drop handler for dragging either swatch onto a shape (sets its fill)
  /// or a frame (sets its background) - always the target's dominant
  /// color, regardless of whether the dragged swatch was fill or stroke.
  /// A no-op if dropped on empty canvas, a non-shape clip, or nothing at
  /// all - same "invalid drop does nothing" convention every other drag
  /// in this app already uses (connector creation/retarget, etc.).
  void _handleSwatchDrop(String? colorHex, Offset globalOffset) {
    if (colorHex == null) return;
    final box =
        BoardCanvas.canvasBoxKey.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null) return;
    final view = ref.read(boardViewProvider);
    final boardPoint = ClipGeometry.screenToBoard(
      box.globalToLocal(globalOffset),
      view,
    );

    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final shapeHit = ClipGeometry.topmostAt(
      clips,
      boardPoint,
      where: (c) => c.type == ClipType.shape,
    );
    if (shapeHit != null) {
      final before = shapeHit.shapeFillColorHex;
      if (before != colorHex) {
        final repo = ref.read(clipsRepositoryProvider);
        repo.updateShapeFillColor(shapeHit.id, colorHex);
        ref.read(lastShapeFillColorHexProvider.notifier).state = colorHex;
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => repo.updateShapeFillColor(shapeHit.id, before),
                redo: () => repo.updateShapeFillColor(shapeHit.id, colorHex),
              ),
            );
      }
      return;
    }

    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    for (final f in frames) {
      if (!FrameGeometry.pointInFrame(boardPoint, f)) continue;
      final before = f.backgroundColorHex;
      if (before != colorHex) {
        final repo = ref.read(framesRepositoryProvider);
        repo.updateColor(f.id, colorHex);
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => repo.updateColor(f.id, before),
                redo: () => repo.updateColor(f.id, colorHex),
              ),
            );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectedClipIdsProvider);
    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    BoardClip? clip;
    if (selection.length == 1) {
      final found = ClipGeometry.findById(clips, selection.first);
      if (found != null && found.type == ClipType.shape) clip = found;
    }

    if (clip == null) {
      if (_boundClipId != null) {
        _closePickers(_boundClipId!);
        _boundClipId = null;
      }
      return const SizedBox.shrink();
    }
    final boundClip = clip;

    if (_boundClipId != boundClip.id) {
      if (_boundClipId != null) _closePickers(_boundClipId!);
      _boundClipId = boundClip.id;
    }

    final view = ref.watch(boardViewProvider);
    final rect = ShapeStylePopover.screenRectFor(boundClip, view);
    final repo = ref.read(clipsRepositoryProvider);
    final fillOpen = ref.watch(shapeFillPickerOpenProvider);
    final strokeOpen = ref.watch(shapeStrokePickerOpenProvider);

    void pushFillUndo(String? before, String? after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateShapeFillColor(boundClip.id, before),
              redo: () => repo.updateShapeFillColor(boundClip.id, after),
            ),
          );
    }

    void pushStrokeWidthUndo(double? before, double? after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateShapeStrokeWidth(boundClip.id, before),
              redo: () => repo.updateShapeStrokeWidth(boundClip.id, after),
            ),
          );
    }

    final pickerRect = ShapeStylePopover.pickerRectFor(boundClip, view);

    return Positioned.fill(
      child: Stack(
        children: [
          if (fillOpen || strokeOpen)
            Positioned(
              left: pickerRect.left,
              top: pickerRect.top,
              child: Material(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                elevation: 6,
                shadowColor: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: SizedBox(
                    width: pickerRect.width - 16,
                    child: InlineHsvPickerBar(
                      initialColor: fillOpen
                          ? (boundClip.shapeFillColorHex != null
                                ? hexToColor(boundClip.shapeFillColorHex!)
                                : AppTheme.surfaceCard)
                          : (boundClip.shapeStrokeColorHex != null
                                ? hexToColor(boundClip.shapeStrokeColorHex!)
                                : AppTheme.border),
                      onChanged: (color) {
                        final hex = colorToHex(color);
                        if (fillOpen) {
                          repo.updateShapeFillColor(boundClip.id, hex);
                          ref
                                  .read(lastShapeFillColorHexProvider.notifier)
                                  .state =
                              hex;
                        } else {
                          repo.updateShapeStrokeColor(boundClip.id, hex);
                          ref
                                  .read(
                                    lastShapeStrokeColorHexProvider.notifier,
                                  )
                                  .state =
                              hex;
                        }
                      },
                      onDone: () => fillOpen
                          ? _toggleFillPicker(boundClip)
                          : _toggleStrokePicker(boundClip),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
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
                        selected: boundClip.shapeFillColorHex == null,
                        onTap: () {
                          final before = boundClip.shapeFillColorHex;
                          if (fillOpen) {
                            // The upcoming "clear fill" undo below already
                            // covers this whole change in one step - don't
                            // also push the picker's own pending undo.
                            _fillColorBeforePicker = null;
                            ref
                                    .read(shapeFillPickerOpenProvider.notifier)
                                    .state =
                                false;
                          }
                          if (before == null) return;
                          repo.updateShapeFillColor(boundClip.id, null);
                          ref
                                  .read(lastShapeFillColorHexProvider.notifier)
                                  .state =
                              null;
                          pushFillUndo(before, null);
                        },
                      ),
                      Draggable<Object>(
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: _SwatchDragFeedback(
                          color: boundClip.shapeFillColorHex != null
                              ? hexToColor(boundClip.shapeFillColorHex!)
                              : AppTheme.surfaceCard,
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: InlineColorPickerSwatch(
                            color: boundClip.shapeFillColorHex != null
                                ? hexToColor(boundClip.shapeFillColorHex!)
                                : AppTheme.surfaceCard,
                            open: fillOpen,
                            onTap: () {},
                          ),
                        ),
                        onDragEnd: (details) => _handleSwatchDrop(
                          boundClip.shapeFillColorHex,
                          details.offset,
                        ),
                        child: InlineColorPickerSwatch(
                          color: boundClip.shapeFillColorHex != null
                              ? hexToColor(boundClip.shapeFillColorHex!)
                              : AppTheme.surfaceCard,
                          open: fillOpen,
                          onTap: () => _toggleFillPicker(boundClip),
                        ),
                      ),
                      const _Divider(),
                      Draggable<Object>(
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: _SwatchDragFeedback(
                          color: boundClip.shapeStrokeColorHex != null
                              ? hexToColor(boundClip.shapeStrokeColorHex!)
                              : AppTheme.border,
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: InlineColorPickerSwatch(
                            color: boundClip.shapeStrokeColorHex != null
                                ? hexToColor(boundClip.shapeStrokeColorHex!)
                                : AppTheme.border,
                            open: strokeOpen,
                            onTap: () {},
                          ),
                        ),
                        onDragEnd: (details) => _handleSwatchDrop(
                          boundClip.shapeStrokeColorHex,
                          details.offset,
                        ),
                        child: InlineColorPickerSwatch(
                          color: boundClip.shapeStrokeColorHex != null
                              ? hexToColor(boundClip.shapeStrokeColorHex!)
                              : AppTheme.border,
                          open: strokeOpen,
                          onTap: () => _toggleStrokePicker(boundClip),
                        ),
                      ),
                      const _Divider(),
                      SizedBox(
                        width: 110,
                        child: _StrokeWidthSlider(
                          clipId: boundClip.id,
                          value:
                              boundClip.shapeStrokeWidth ?? kDefaultStrokeWidth,
                          onCommit: pushStrokeWidthUndo,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

/// Purely cosmetic "something is being carried" cue shown while dragging
/// a fill/stroke swatch onto a shape or frame - wrapped in a transparent
/// [Material] so it doesn't pick up an ambient Material background from
/// wherever `Draggable` paints it (the root [Overlay]).
class _SwatchDragFeedback extends StatelessWidget {
  final Color color;

  const _SwatchDragFeedback({required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
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
        // Min is 0, not kMinStrokeWidth (used for the freehand draw tool,
        // where a 0-width pen stroke makes no sense) - dragging a shape's
        // stroke all the way down removes its outline entirely, which
        // ShapePainter already does for any strokeWidth <= 0.
        value: widget.value.clamp(0, kMaxStrokeWidth),
        min: 0,
        max: kMaxStrokeWidth,
        activeColor: AppTheme.textPrimary,
        onChangeStart: (v) => _dragStartValue = widget.value,
        onChanged: (v) {
          ref
              .read(clipsRepositoryProvider)
              .updateShapeStrokeWidth(widget.clipId, v);
          ref.read(lastShapeStrokeWidthProvider.notifier).state = v;
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
