import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/features/board/geometry/swimlane_geometry.dart';

final _now = DateTime(2024);

FrameRow _frame({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  String? kanbanBoardId,
}) => FrameRow(
  id: id,
  boardId: 'board',
  name: id,
  x: x,
  y: y,
  width: width,
  height: height,
  sortOrder: 0,
  kanbanBoardId: kanbanBoardId,
  createdAt: _now,
  updatedAt: _now,
);

SwimlaneRow _lane({
  required String kanbanBoardId,
  required double y,
  required double height,
}) => SwimlaneRow(
  id: 'lane',
  kanbanBoardId: kanbanBoardId,
  name: 'Lane',
  y: y,
  height: height,
  sortOrder: 0,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('SwimlaneGeometry.columnSpanBoardRect', () {
    test('null for an empty column list', () {
      expect(SwimlaneGeometry.columnSpanBoardRect([]), isNull);
    });

    test('exactly the single column\'s rect for one column', () {
      final column = _frame(id: 'a', x: 10, y: 20, width: 100, height: 200);
      final span = SwimlaneGeometry.columnSpanBoardRect([column]);
      expect(span, isNotNull);
      expect(span!.left, 10);
      expect(span.top, 20);
      expect(span.width, 100);
      expect(span.height, 200);
    });

    test('bounding union across 3 columns', () {
      final columns = [
        _frame(id: 'a', x: 0, y: 0, width: 100, height: 400),
        _frame(id: 'b', x: 132, y: 0, width: 100, height: 420),
        _frame(id: 'c', x: 264, y: 10, width: 100, height: 400),
      ];
      final span = SwimlaneGeometry.columnSpanBoardRect(columns);
      expect(span, isNotNull);
      expect(span!.left, 0);
      expect(span.top, 0);
      expect(span.right, 364);
      // The union's bottom follows the tallest+lowest-reaching column (b).
      expect(span.bottom, 420);
    });
  });

  group('SwimlaneGeometry.pointInSwimlane', () {
    final columnSpan = SwimlaneGeometry.columnSpanBoardRect([
      _frame(id: 'a', x: 0, y: 0, width: 280, height: 420),
      _frame(id: 'b', x: 312, y: 0, width: 280, height: 420),
    ])!;
    final lane = _lane(kanbanBoardId: 'board-1', y: 0, height: 200);

    test('true when inside both the lane\'s y-range and the column span\'s '
        'x-range', () {
      expect(
        SwimlaneGeometry.pointInSwimlane(
          const Offset(100, 100),
          lane,
          columnSpan,
        ),
        isTrue,
      );
    });

    test('false outside the lane\'s y-range, even inside the x-range', () {
      expect(
        SwimlaneGeometry.pointInSwimlane(
          const Offset(100, 300),
          lane,
          columnSpan,
        ),
        isFalse,
      );
    });

    test('false outside the column span\'s x-range despite a correct '
        'y-range - the specific false-positive this two-axis check exists '
        'to prevent (a bare y-range test alone would wrongly match across '
        'unrelated kanban boards sharing a y-band)', () {
      expect(
        SwimlaneGeometry.pointInSwimlane(
          const Offset(1000, 100),
          lane,
          columnSpan,
        ),
        isFalse,
      );
    });
  });
}
