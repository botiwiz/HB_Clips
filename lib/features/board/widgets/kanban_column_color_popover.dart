import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hsv_color_picker.dart';
import '../../../data/local/database.dart';
import '../../../data/providers.dart';
import '../../annotation/stroke_painter.dart' show colorToHex, hexToColor;
import '../controllers/board_controller.dart';
import '../controllers/kanban_controller.dart';
import '../controllers/undo_controller.dart';
import '../geometry/kanban_column_geometry.dart';

/// Floating color-picker popover for a kanban column's swatch - a
/// single-swatch sibling of `ShapeStylePopover` (which handles a shape's
/// fill+stroke pair). Anchored off the column's own header rect,
/// gated on `kanbanColumnColorPickerOpenForProvider`, same "stays open
/// until you click elsewhere, live-updates as you drag" `InlineHsvPickerBar`
/// pattern every other per-selection color control in this app uses.
class KanbanColumnColorPopover extends ConsumerStatefulWidget {
  const KanbanColumnColorPopover({super.key});

  static const double _width = 220;
  static const double _pickerHeight = 44;
  static const double _gapAboveHeader = 8;

  static Rect screenRectFor(
    KanbanElementRow element,
    int columnIndex,
    BoardViewState view,
  ) {
    final header = KanbanColumnGeometry.headerRect(element, columnIndex);
    final topRightBoard = Offset(header.right, header.top);
    final topRightScreen = topRightBoard * view.scale + view.panOffset;
    final left = topRightScreen.dx - _width;
    final top = topRightScreen.dy - _pickerHeight - _gapAboveHeader;
    return Rect.fromLTWH(left, top < 8 ? 8 : top, _width, _pickerHeight);
  }

  @override
  ConsumerState<KanbanColumnColorPopover> createState() =>
      _KanbanColumnColorPopoverState();
}

class _KanbanColumnColorPopoverState
    extends ConsumerState<KanbanColumnColorPopover> {
  String? _boundColumnId;
  String? _colorBeforePicker;

  /// Closes the picker for [id] (if it's the one currently open), pushing
  /// one undo step if the color actually changed while it was open -
  /// mirrors `ShapeStylePopover._closePickers`'s single-picker case. Safe
  /// to call with a since-deleted column id.
  void _closePicker(String id) {
    if (ref.read(kanbanColumnColorPickerOpenForProvider) != id) return;
    final before = _colorBeforePicker;
    _colorBeforePicker = null;
    ref.read(kanbanColumnColorPickerOpenForProvider.notifier).state = null;
    final columns = ref.read(boardKanbanColumnsProvider).valueOrNull ?? [];
    String? after;
    for (final c in columns) {
      if (c.id == id) {
        after = c.colorHex;
        break;
      }
    }
    if (before == after) return;
    final repo = ref.read(kanbanColumnsRepositoryProvider);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => repo.updateColor(id, before),
            redo: () => repo.updateColor(id, after),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final openForColumnId = ref.watch(kanbanColumnColorPickerOpenForProvider);
    if (openForColumnId == null) {
      if (_boundColumnId != null) {
        _closePicker(_boundColumnId!);
        _boundColumnId = null;
      }
      return const SizedBox.shrink();
    }

    final columns = ref.watch(boardKanbanColumnsProvider).valueOrNull ?? [];
    KanbanColumnRow? column;
    for (final c in columns) {
      if (c.id == openForColumnId) {
        column = c;
        break;
      }
    }
    if (column == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(kanbanColumnColorPickerOpenForProvider.notifier).state =
              null;
        }
      });
      return const SizedBox.shrink();
    }
    final boundColumn = column;

    if (_boundColumnId != boundColumn.id) {
      if (_boundColumnId != null) _closePicker(_boundColumnId!);
      _boundColumnId = boundColumn.id;
      _colorBeforePicker = boundColumn.colorHex;
    }

    final elements = ref.watch(boardKanbanElementsProvider).valueOrNull ?? [];
    KanbanElementRow? element;
    for (final e in elements) {
      if (e.id == boundColumn.kanbanElementId) {
        element = e;
        break;
      }
    }
    if (element == null) return const SizedBox.shrink();
    final sortedSiblings =
        columns.where((c) => c.kanbanElementId == element!.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final columnIndex = sortedSiblings.indexWhere((c) => c.id == boundColumn.id);
    if (columnIndex < 0) return const SizedBox.shrink();

    final view = ref.watch(boardViewProvider);
    final rect = KanbanColumnColorPopover.screenRectFor(
      element,
      columnIndex,
      view,
    );
    final repo = ref.read(kanbanColumnsRepositoryProvider);

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: Material(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(kCornerRadius),
        elevation: 6,
        shadowColor: Colors.black54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SizedBox(
            width: rect.width - 16,
            child: InlineHsvPickerBar(
              initialColor: boundColumn.colorHex != null
                  ? hexToColor(boundColumn.colorHex!)
                  : AppTheme.surfaceCard,
              onChanged: (color) {
                repo.updateColor(boundColumn.id, colorToHex(color));
              },
              onDone: () => _closePicker(boundColumn.id),
            ),
          ),
        ),
      ),
    );
  }
}
