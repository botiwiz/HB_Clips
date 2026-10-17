import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/features/board/geometry/kanban_element_geometry.dart';

KanbanElementRow _element({
  double x = 0,
  double y = 0,
  double width = 300,
  double height = 480,
}) {
  final now = DateTime(2024);
  return KanbanElementRow(
    id: 'el-1',
    boardId: 'board-1',
    name: 'Kanban Board',
    x: x,
    y: y,
    width: width,
    height: height,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('KanbanElementGeometry', () {
    test('outerRect matches the row\'s own x/y/width/height', () {
      final element = _element(x: 10, y: 20, width: 300, height: 480);
      expect(
        KanbanElementGeometry.outerRect(element),
        const Rect.fromLTWH(10, 20, 300, 480),
      );
    });

    test('headerRect sits at the top, spanning the full width', () {
      final element = _element(x: 10, y: 20, width: 300, height: 480);
      final header = KanbanElementGeometry.headerRect(element);
      expect(header.left, 10);
      expect(header.top, 20);
      expect(header.width, 300);
    });

    test('contentRect is everything below the header', () {
      final element = _element(x: 0, y: 0, width: 300, height: 480);
      final header = KanbanElementGeometry.headerRect(element);
      final content = KanbanElementGeometry.contentRect(element);
      expect(content.top, header.bottom);
      expect(content.height, 480 - header.height);
      expect(content.width, 300);
    });

    test('pointInElement is true only inside the outer rect', () {
      final element = _element(x: 0, y: 0, width: 300, height: 480);
      expect(
        KanbanElementGeometry.pointInElement(const Offset(150, 240), element),
        isTrue,
      );
      expect(
        KanbanElementGeometry.pointInElement(const Offset(-1, 0), element),
        isFalse,
      );
      expect(
        KanbanElementGeometry.pointInElement(const Offset(301, 0), element),
        isFalse,
      );
    });

    test('widthForColumnCount grows with column count, gaps, and padding', () {
      final oneColumn = KanbanElementGeometry.widthForColumnCount(1);
      final threeColumns = KanbanElementGeometry.widthForColumnCount(3);
      expect(threeColumns, greaterThan(oneColumn));
      expect(KanbanElementGeometry.widthForColumnCount(0), greaterThan(0));
    });

    test('resizeHandleRect is centered on the bottom edge', () {
      final element = _element(x: 0, y: 0, width: 300, height: 480);
      final handle = KanbanElementGeometry.resizeHandleRect(element);
      expect(handle.center.dx, 150);
      expect(handle.center.dy, 480);
    });
  });
}
