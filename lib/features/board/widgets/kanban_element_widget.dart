import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart';
import '../../../data/models/kanban.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../controllers/kanban_controller.dart';
import '../geometry/kanban_column_geometry.dart';
import '../geometry/kanban_element_geometry.dart';
import '../geometry/kanban_task_geometry.dart';

/// Renders one rigid, self-contained kanban element: its opaque outer
/// panel, every column's header + task rows + add-task row, the
/// add-column affordance, and (when selected) its single bottom-edge
/// resize handle - the Trello-parity replacement for the old free-
/// floating `KanbanBoardsRepository`+tagged-`Frames` composite. Purely
/// presentational - all pointer handling/hit-testing happens in
/// `board_canvas.dart`'s Listener against the exact same geometry classes
/// this widget draws from, same architecture `FrameWidget`/`ClipWidget`
/// already follow.
///
/// Unlike a Frame (`clipBehavior: Clip.none`), this widget DOES clip its
/// content to its own rect (`ClipRect`) - the mechanical half of
/// "rigid/opaque, cards can't escape it": the data model already makes a
/// committed task's position incapable of meaning "outside the element"
/// (see `KanbanTaskGeometry`'s doc comment), and this clip means it can't
/// even be glimpsed rendering outside the panel mid-drag either.
class KanbanElementWidget extends StatelessWidget {
  final KanbanElementRow element;
  final List<KanbanColumnRow> columns;
  final List<KanbanTask> tasks;
  final bool selected;
  final Map<String, double> columnScrollOffsets;
  final DraggingTask? draggingTask;
  final double viewScale;

  /// Id of the column whose color-picker popover is currently open, if
  /// any - purely cosmetic (shows an accent ring on that column's
  /// swatch); the popover itself is a separate widget `board_canvas.dart`
  /// renders, this is just read-and-pass-down like every other field
  /// here.
  final String? openColorPickerColumnId;

  const KanbanElementWidget({
    super.key,
    required this.element,
    required this.columns,
    required this.tasks,
    required this.selected,
    required this.columnScrollOffsets,
    required this.viewScale,
    this.draggingTask,
    this.openColorPickerColumnId,
  });

  @override
  Widget build(BuildContext context) {
    final outer = KanbanElementGeometry.outerRect(element);
    Rect local(Rect boardRect) {
      final shifted = boardRect.shift(-outer.topLeft);
      return Rect.fromLTWH(
        shifted.left * viewScale,
        shifted.top * viewScale,
        shifted.width * viewScale,
        shifted.height * viewScale,
      );
    }

    final sortedColumns = [...columns]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final tasksByColumn = <String, List<KanbanTask>>{};
    for (final task in tasks) {
      (tasksByColumn[task.columnId] ??= []).add(task);
    }
    for (final list in tasksByColumn.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    KanbanTask? ghostTask;
    if (draggingTask != null) {
      for (final t in tasks) {
        if (t.id == draggingTask!.taskId) {
          ghostTask = t;
          break;
        }
      }
    }

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border.all(
                  color: selected ? AppTheme.accent : AppTheme.border,
                  width: selected ? 2 : 1.5,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: local(KanbanElementGeometry.headerRect(element)),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 8 * viewScale,
                  right: 32 * viewScale,
                ),
                child: Text(
                  element.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * viewScale,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: local(KanbanElementGeometry.pinToggleRect(element)),
            child: Tooltip(
              message: element.screenPinned
                  ? 'Unpin from screen'
                  : 'Pin to screen',
              child: Icon(
                element.screenPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                size: 16 * viewScale,
                color: element.screenPinned
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          for (var i = 0; i < sortedColumns.length; i++)
            ..._buildColumn(
              local,
              sortedColumns[i],
              i,
              tasksByColumn[sortedColumns[i].id] ?? const [],
              ghostTask?.columnId == sortedColumns[i].id ? ghostTask : null,
            ),
          for (var i = 0; i < sortedColumns.length - 1; i++)
            if (KanbanColumnGeometry.dividerRect(
                  element,
                  i,
                  sortedColumns.length,
                )
                case final dividerRect?)
              Positioned(
                left: local(dividerRect).left,
                top: local(dividerRect).top,
                width: 1,
                height: local(dividerRect).height,
                child: IgnorePointer(
                  child: ColoredBox(color: AppTheme.border),
                ),
              ),
          Positioned.fromRect(
            rect: local(
              KanbanColumnGeometry.addColumnButtonRect(
                element,
                sortedColumns.length,
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 8 * viewScale),
                child: Icon(
                  Icons.add,
                  size: 18 * viewScale,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          if (selected)
            Positioned.fromRect(
              rect: local(KanbanElementGeometry.resizeHandleRect(element)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  border: Border.all(
                    color: AppTheme.canvasBackground,
                    width: 1,
                  ),
                ),
              ),
            ),
          if (draggingTask != null && ghostTask != null)
            _buildGhost(local, draggingTask!, ghostTask),
        ],
      ),
    );
  }

  List<Widget> _buildColumn(
    Rect Function(Rect) local,
    KanbanColumnRow column,
    int index,
    List<KanbanTask> columnTasks,
    KanbanTask? excludeDragging,
  ) {
    final scrollOffset = columnScrollOffsets[column.id] ?? 0.0;
    final columnColor = column.colorHex != null
        ? hexToColor(column.colorHex!)
        : null;
    final rows = <Widget>[
      if (columnColor != null)
        Positioned.fromRect(
          rect: local(KanbanColumnGeometry.columnRect(element, index)),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: columnColor.withValues(alpha: 0.08),
                border: Border.all(color: columnColor, width: 1.5),
              ),
            ),
          ),
        ),
      Positioned.fromRect(
        rect: local(KanbanColumnGeometry.headerRect(element, index)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: 6 * viewScale,
              right: 24 * viewScale,
            ),
            child: Text(
              column.name,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11 * viewScale,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: local(KanbanColumnGeometry.colorSwatchRect(element, index)),
        child: Tooltip(
          message: 'Set column color',
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: columnColor ?? Colors.transparent,
              border: Border.all(
                color: column.id == openColorPickerColumnId
                    ? AppTheme.accent
                    : (columnColor ?? AppTheme.textSecondary),
                width: column.id == openColorPickerColumnId ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    ];

    for (var rowIndex = 0; rowIndex < columnTasks.length; rowIndex++) {
      final task = columnTasks[rowIndex];
      if (excludeDragging != null && task.id == excludeDragging.id) continue;
      rows.add(
        Positioned.fromRect(
          rect: local(
            KanbanTaskGeometry.taskRowRect(
              element,
              index,
              rowIndex,
              scrollOffset,
            ),
          ),
          child: _TaskRowChrome(
            title: task.title,
            colorHex: task.colorHex,
            viewScale: viewScale,
          ),
        ),
      );
    }

    rows.add(
      Positioned.fromRect(
        rect: local(KanbanColumnGeometry.addTaskButtonRect(element, index)),
        child: Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.add,
            size: 16 * viewScale,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );

    return rows;
  }

  Widget _buildGhost(
    Rect Function(Rect) local,
    DraggingTask dragging,
    KanbanTask task,
  ) {
    const ghostWidth = 200.0;
    const ghostHeight = 40.0;
    final boardRect = Rect.fromCenter(
      center: dragging.clampedCenter,
      width: ghostWidth,
      height: ghostHeight,
    );
    return Positioned.fromRect(
      rect: local(boardRect),
      child: IgnorePointer(
        child: Material(
          elevation: 6,
          color: AppTheme.surfaceElevated,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * viewScale),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.title.isEmpty ? 'Untitled' : task.title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12 * viewScale,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskRowChrome extends StatelessWidget {
  final String title;
  final String? colorHex;
  final double viewScale;

  const _TaskRowChrome({
    required this.title,
    this.colorHex,
    required this.viewScale,
  });

  @override
  Widget build(BuildContext context) {
    final customColor = colorHex != null ? hexToColor(colorHex!) : null;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4 * viewScale,
        vertical: 2 * viewScale,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: customColor != null
              ? Color.alphaBlend(
                  customColor.withValues(alpha: 0.18),
                  AppTheme.surfaceElevated,
                )
              : AppTheme.surfaceElevated,
          border: Border.all(color: customColor ?? AppTheme.border, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 6 * viewScale),
        alignment: Alignment.centerLeft,
        child: Text(
          title.isEmpty ? 'Untitled' : title,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12 * viewScale),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
