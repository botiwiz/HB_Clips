import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart' show FrameRow;
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/features/board/geometry/page_crop_settings.dart'
    show kOverviewPageCropKey;
import 'package:hb_clips/features/board/geometry/pdf_page_grouping.dart';

FrameRow _frame({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  String? backgroundColorHex,
}) {
  final now = DateTime.now();
  return FrameRow(
    id: id,
    boardId: 'board-1',
    name: id,
    x: x,
    y: y,
    width: width,
    height: height,
    sortOrder: 0,
    backgroundColorHex: backgroundColorHex,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _clip({
  required String id,
  String? frameId,
  required double x,
  required double y,
  double width = 50,
  double height = 50,
  int zIndex = 0,
}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.image,
    frameId: frameId,
    x: x,
    y: y,
    width: width,
    height: height,
    zIndex: zIndex,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('a loose clip whose rect overlaps a frame is swept onto that '
      "frame's page, not a separate overview page", () {
    final frame = _frame(id: 'f1', x: 0, y: 0, width: 300, height: 200);
    // Never parented (frameId: null), but its rect (50,50,100,100)
    // overlaps the frame's rect (0,0,300,200).
    final overlapping = _clip(id: 'c1', x: 50, y: 50, width: 100, height: 100);

    final pages = buildPdfExportPages(frames: [frame], clips: [overlapping]);

    expect(pages, hasLength(1));
    expect(pages.single.cropKey, 'f1');
    expect(pages.single.clips, [overlapping]);
  });

  test('a loose clip far from every frame still becomes its own leading '
      'overview page', () {
    final frame = _frame(id: 'f1', x: 0, y: 0, width: 300, height: 200);
    final farAway = _clip(id: 'c1', x: 5000, y: 5000);

    final pages = buildPdfExportPages(frames: [frame], clips: [farAway]);

    expect(pages, hasLength(2));
    expect(pages[0].cropKey, kOverviewPageCropKey);
    expect(pages[0].clips, [farAway]);
    expect(pages[1].cropKey, 'f1');
    expect(pages[1].clips, isEmpty);
  });

  test('clips within a page are sorted by zIndex', () {
    final frame = _frame(id: 'f1', x: 0, y: 0, width: 300, height: 300);
    final back = _clip(id: 'back', x: 10, y: 10, zIndex: 0);
    final front = _clip(id: 'front', x: 20, y: 20, zIndex: 5);
    final middle = _clip(id: 'middle', x: 30, y: 30, zIndex: 2);

    final pages = buildPdfExportPages(
      frames: [frame],
      clips: [front, back, middle],
    );

    expect(pages.single.clips.map((c) => c.id), ['back', 'middle', 'front']);
  });

  test("a clip overlapping two different frames' rects appears on both "
      'pages', () {
    final f1 = _frame(id: 'f1', x: 0, y: 0, width: 200, height: 200);
    final f2 = _frame(id: 'f2', x: 150, y: 0, width: 200, height: 200);
    // Rect (160,10,50,50) overlaps both f1 (0,0,200,200) and
    // f2 (150,0,200,200).
    final shared = _clip(id: 'shared', x: 160, y: 10, width: 50, height: 50);

    final pages = buildPdfExportPages(frames: [f1, f2], clips: [shared]);

    expect(pages, hasLength(2));
    expect(
      pages.every((p) => p.clips.map((c) => c.id).contains('shared')),
      isTrue,
    );
  });

  test('zero frames: every clip becomes one leading overview page covering '
      'their shared bounding box', () {
    final a = _clip(id: 'a', x: 0, y: 0);
    final b = _clip(id: 'b', x: 300, y: 300);

    final pages = buildPdfExportPages(frames: const [], clips: [a, b]);

    expect(pages, hasLength(1));
    expect(pages.single.cropKey, kOverviewPageCropKey);
    expect(pages.single.clips, [a, b]);
    expect(pages.single.rect, const Rect.fromLTWH(0, 0, 350, 350));
  });

  test('no overview page is produced when every clip is captured by some '
      "frame's page", () {
    final frame = _frame(id: 'f1', x: 0, y: 0, width: 300, height: 300);
    final inside = _clip(id: 'c1', x: 10, y: 10);

    final pages = buildPdfExportPages(frames: [frame], clips: [inside]);

    expect(pages, hasLength(1));
    expect(pages.single.cropKey, 'f1');
  });

  test('page order: overview (if present) first, then frames in order', () {
    final f1 = _frame(id: 'f1', x: 0, y: 0, width: 100, height: 100);
    final f2 = _frame(id: 'f2', x: 1000, y: 0, width: 100, height: 100);
    final loose = _clip(id: 'loose', x: 5000, y: 5000);

    final pages = buildPdfExportPages(frames: [f1, f2], clips: [loose]);

    expect(pages.map((p) => p.cropKey), [kOverviewPageCropKey, 'f1', 'f2']);
  });

  test("a frame page's backgroundColorHex comes from the frame itself", () {
    final frame = _frame(
      id: 'f1',
      x: 0,
      y: 0,
      width: 100,
      height: 100,
      backgroundColorHex: '#112233',
    );

    final pages = buildPdfExportPages(frames: [frame], clips: const []);

    expect(pages.single.backgroundColorHex, '#112233');
  });
}
