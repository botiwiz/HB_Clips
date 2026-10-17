import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/features/board/geometry/kanban_task_geometry.dart';

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
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('KanbanTaskGeometry.clampGhostCenter', () {
    const content = Rect.fromLTWH(0, 0, 300, 400);

    test('a point already inside the rect passes through unchanged', () {
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(150, 200)),
        const Offset(150, 200),
      );
    });

    test('every edge and corner clamps onto the rect\'s own boundary', () {
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(-500, 200)),
        const Offset(0, 200),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(900, 200)),
        const Offset(300, 200),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(150, -500)),
        const Offset(150, 0),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(150, 900)),
        const Offset(150, 400),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(-500, -500)),
        const Offset(0, 0),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(900, 900)),
        const Offset(300, 400),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(900, -500)),
        const Offset(300, 0),
      );
      expect(
        KanbanTaskGeometry.clampGhostCenter(content, const Offset(-500, 900)),
        const Offset(0, 400),
      );
    });
  });

  group('KanbanTaskGeometry.insertionIndexForPoint', () {
    test('a point above the first row resolves to index 0', () {
      final element = _element();
      final index = KanbanTaskGeometry.insertionIndexForPoint(
        element,
        0,
        5,
        0,
        const Offset(150, -1000),
      );
      expect(index, 0);
    });

    test('a point below every existing row resolves to the end', () {
      final element = _element();
      final index = KanbanTaskGeometry.insertionIndexForPoint(
        element,
        0,
        5,
        0,
        const Offset(150, 10000),
      );
      expect(index, 5);
    });
  });

  group('KanbanTaskGeometry.sortOrderForInsertion', () {
    test('an empty column starts at 0', () {
      expect(KanbanTaskGeometry.sortOrderForInsertion([], 0), 0);
    });

    test('inserting before the first existing task is first - 1.0', () {
      expect(
        KanbanTaskGeometry.sortOrderForInsertion([5.0, 10.0, 20.0], 0),
        4.0,
      );
    });

    test('appending past the end is last + 1.0', () {
      expect(
        KanbanTaskGeometry.sortOrderForInsertion([5.0, 10.0, 20.0], 3),
        21.0,
      );
    });

    test('inserting between two existing tasks is their midpoint', () {
      expect(
        KanbanTaskGeometry.sortOrderForInsertion([5.0, 10.0, 20.0], 1),
        7.5,
      );
      expect(
        KanbanTaskGeometry.sortOrderForInsertion([5.0, 10.0, 20.0], 2),
        15.0,
      );
    });
  });
}
