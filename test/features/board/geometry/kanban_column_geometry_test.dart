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
    scale: 1.0,
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

    test('addColumnButtonRect stays fully inside the element\'s own '
        'outer/content bounds, so it is neither clipped out of view nor '
        'unreachable by the kanban element\'s own hit-test', () {
      for (final columnCount in [0, 1, 3]) {
        final element = _element(
          width: KanbanElementGeometry.widthForColumnCount(columnCount),
        );
        final content = KanbanElementGeometry.contentRect(element);
        final addButton = KanbanColumnGeometry.addColumnButtonRect(
          element,
          columnCount,
        );
        expect(addButton.left, greaterThanOrEqualTo(content.left));
        expect(addButton.right, lessThanOrEqualTo(content.right));
      }
    });

    test('dividerRect is null after the last column, and inset within '
        'every other column\'s own vertical extent at the midpoint of its '
        'gap with the next one', () {
      final element = _element(
        width: KanbanElementGeometry.widthForColumnCount(3),
      );

      expect(KanbanColumnGeometry.dividerRect(element, 2, 3), isNull);

      for (final index in [0, 1]) {
        final col = KanbanColumnGeometry.columnRect(element, index);
        final next = KanbanColumnGeometry.columnRect(element, index + 1);
        final divider = KanbanColumnGeometry.dividerRect(element, index, 3);
        expect(divider, isNotNull);
        expect(divider!.left, (col.right + next.left) / 2);
        expect(divider.top, greaterThan(col.top));
        expect(divider.bottom, lessThan(col.bottom));
      }
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

    test('colorSwatchRect sits inside the header, right of center, for '
        'every column index', () {
      final element = _element(
        width: KanbanElementGeometry.widthForColumnCount(3),
      );
      for (final index in [0, 1, 2]) {
        final header = KanbanColumnGeometry.headerRect(element, index);
        final swatch = KanbanColumnGeometry.colorSwatchRect(element, index);
        expect(header.contains(swatch.center), isTrue);
        expect(swatch.right, lessThanOrEqualTo(header.right));
        expect(swatch.center.dx, greaterThan(header.center.dx));
      }
    });

    test('columnIndexForPoint with zero columns returns 0', () {
      final element = _element();
      expect(
        KanbanColumnGeometry.columnIndexForPoint(element, 0, Offset.zero),
        0,
      );
    });

    test(
      'deleteColumnButtonRect/moveColumnRightButtonRect/'
      'moveColumnLeftButtonRect form a left-to-right chain inside the '
      'header, all left of the (unchanged) color swatch',
      () {
        final element = _element(
          width: KanbanElementGeometry.widthForColumnCount(3),
        );
        for (final index in [0, 1, 2]) {
          final header = KanbanColumnGeometry.headerRect(element, index);
          final swatch = KanbanColumnGeometry.colorSwatchRect(element, index);
          final bin = KanbanColumnGeometry.deleteColumnButtonRect(
            element,
            index,
          );
          final right = KanbanColumnGeometry.moveColumnRightButtonRect(
            element,
            index,
          );
          final left = KanbanColumnGeometry.moveColumnLeftButtonRect(
            element,
            index,
          );

          expect(bin.right, lessThanOrEqualTo(swatch.left));
          expect(right.right, lessThanOrEqualTo(bin.left));
          expect(left.right, lessThanOrEqualTo(right.left));

          expect(header.contains(left.center), isTrue);
          expect(header.contains(right.center), isTrue);
          expect(header.contains(bin.center), isTrue);
          expect(left.left, greaterThanOrEqualTo(header.left));
        }
      },
    );
  });
}
