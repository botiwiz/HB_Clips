import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/kanban_card_geometry.dart';

BoardClip _card({
  double x = 0,
  double y = 0,
  double width = 240,
  double height = 200,
}) {
  final now = DateTime(2024);
  return BoardClip(
    id: 'card',
    boardId: 'board',
    type: ClipType.kanbanCard,
    x: x,
    y: y,
    width: width,
    height: height,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('KanbanCardGeometry row stacking', () {
    test('title band starts at the card padding inset', () {
      final clip = _card();
      final title = KanbanCardGeometry.titleRectLocal(clip);
      expect(title.left, KanbanCardGeometry.padding);
      expect(title.top, KanbanCardGeometry.padding);
      expect(title.height, KanbanCardGeometry.titleBandHeight);
    });

    test('checklist row 0 starts immediately below the title band, no gap '
        'or overlap', () {
      final clip = _card();
      final title = KanbanCardGeometry.titleRectLocal(clip);
      final row0 = KanbanCardGeometry.checklistRowRectLocal(clip, 0);
      expect(row0.top, title.bottom);
    });

    test('consecutive checklist rows stack with no gap or overlap', () {
      final clip = _card();
      for (var i = 0; i < 4; i++) {
        final row = KanbanCardGeometry.checklistRowRectLocal(clip, i);
        final next = KanbanCardGeometry.checklistRowRectLocal(clip, i + 1);
        expect(next.top, row.bottom);
      }
    });

    test('the "+ Add item" row sits immediately after the last checklist '
        'row', () {
      final clip = _card();
      const itemCount = 3;
      final lastRow = KanbanCardGeometry.checklistRowRectLocal(
        clip,
        itemCount - 1,
      );
      final addItemRow = KanbanCardGeometry.addItemRowRectLocal(
        clip,
        itemCount,
      );
      expect(addItemRow.top, lastRow.bottom);
    });

    test('the checkbox rect is a narrower leading slice of its full row', () {
      final clip = _card();
      final row = KanbanCardGeometry.checklistRowRectLocal(clip, 0);
      final checkbox = KanbanCardGeometry.checklistCheckboxRectLocal(clip, 0);
      expect(checkbox.left, row.left);
      expect(checkbox.top, row.top);
      expect(checkbox.height, row.height);
      expect(checkbox.width, lessThan(row.width));
    });

    test('the link button sits inside the title band, flush to the '
        'card\'s trailing edge', () {
      final clip = _card();
      final title = KanbanCardGeometry.titleRectLocal(clip);
      final linkButton = KanbanCardGeometry.linkButtonRectLocal(clip);
      expect(linkButton.top, greaterThanOrEqualTo(title.top));
      expect(linkButton.bottom, lessThanOrEqualTo(title.bottom));
      expect(
        linkButton.right,
        clip.width - KanbanCardGeometry.padding,
      );
    });
  });

  group('KanbanCardGeometry.toBoardRect', () {
    test('shifts a local rect by the clip\'s board-space origin', () {
      final clip = _card(x: 100, y: 50);
      final local = KanbanCardGeometry.titleRectLocal(clip);
      final board = KanbanCardGeometry.toBoardRect(clip, local);
      expect(board.left, local.left + 100);
      expect(board.top, local.top + 50);
      expect(board.width, local.width);
      expect(board.height, local.height);
    });
  });
}
