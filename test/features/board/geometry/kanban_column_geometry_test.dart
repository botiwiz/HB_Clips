import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/constants.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/features/board/geometry/kanban_column_geometry.dart';
import 'package:hb_clips/features/board/geometry/kanban_element_geometry.dart';

KanbanElementRow _element({double width = 300, double height = 480}) {
  final now = DateTime(2024);
  return KanbanElementRow(
    id: 'el-1',
    boardId: 'board-1',
    name: 'Kanban Board',
    x: 0,
    y: 0,
    width: width,
    height: height,
    screenPinned: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('KanbanColumnGeometry', () {
    test('columns sit left-to-right in index order, never overlapping', () {
      final element = _element(
        width: KanbanElementGeometry.widthForColumnCount(3),
      );
      final col0 = KanbanColumnGeometry.columnRect(element, 0);
      final col1 = KanbanColumnGeometry.columnRect(element, 1);
      final col2 = KanbanColumnGeometry.columnRect(element, 2);
      expect(col1.left, greaterThan(col0.right));
      expect(col2.left, greaterThan(col1.right));
      expect(col0.top, col1.top);
      expect(col0.height, col1.height);
    });

    test('addColumnButtonRect sits one slot past the last column', () {
      final element = _element(
        width: KanbanElementGeometry.widthForColumnCount(3),
      );
      final lastColumn = KanbanColumnGeometry.columnRect(element, 2);
      final addButton = KanbanColumnGeometry.addColumnButtonRect(element, 3);
      expect(addButton.left, lastColumn.right + kKanbanColumnGap);
    });

    test('clampScrollOffset clamps to [0, overflow] and is 0 when content '
        'already fits', () {
      final element = _element();
      final viewport = KanbanColumnGeometry.taskListViewportRect(element, 0);

      expect(
        KanbanColumnGeometry.clampScrollOffset(
          element,
          0,
          -50,
          viewport.height / 2,
        ),
        0,
      );
      expect(
        KanbanColumnGeometry.clampScrollOffset(
          element,
          0,
          50,
          viewport.height / 2,
        ),
        0,
      );

      final overflowContent = viewport.height + 120;
      expect(
        KanbanColumnGeometry.clampScrollOffset(
          element,
          0,
          1000,
          overflowContent,
        ),
        120,
      );
    });

    test('columnIndexForPoint resolves beyond-first and beyond-last to the '
        'nearest valid column rather than null', () {
      final element = _element(
        width: KanbanElementGeometry.widthForColumnCount(3),
      );
      final content = KanbanElementGeometry.contentRect(element);

      expect(
        KanbanColumnGeometry.columnIndexForPoint(
          element,
          3,
          Offset(content.left - 500, content.top),
        ),
        0,
      );
      expect(
        KanbanColumnGeometry.columnIndexForPoint(
          element,
          3,
          Offset(content.right + 500, content.top),
        ),
        2,
      );

      final col1 = KanbanColumnGeometry.columnRect(element, 1);
      expect(
        KanbanColumnGeometry.columnIndexForPoint(element, 3, col1.center),
        1,
      );
    });

    test('columnIndexForPoint with zero columns returns 0', () {
      final element = _element();
      expect(
        KanbanColumnGeometry.columnIndexForPoint(element, 0, Offset.zero),
        0,
      );
    });
  });
}
