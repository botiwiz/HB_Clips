import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart' show FrameRow;
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/stroke.dart';
import 'package:hb_clips/data/pdf/pdf_writer.dart';
import 'package:image/image.dart' as img;

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
    backgroundColorHex: backgroundColorHex,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _imageClip({
  required String id,
  String? frameId,
  required String localFilePath,
  required double x,
  required double y,
  required double width,
  required double height,
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
    localFilePath: localFilePath,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _textClip({
  required String id,
  String? frameId,
  required String text,
  required double x,
  required double y,
}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.text,
    frameId: frameId,
    x: x,
    y: y,
    width: 220,
    height: 140,
    textContent: text,
    createdAt: now,
    updatedAt: now,
  );
}

/// Small in-memory PNG bytes, keyed by clip localFilePath - a fake
/// `readBytes` never touches real disk, mirroring `pur_writer_test.dart`'s
/// own fixture style but without needing a temp directory.
Future<Uint8List?> _fakeReadBytes(String key) async {
  final image = img.Image(width: 40, height: 20);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return img.encodePng(image);
}

/// `MediaBox` dictionary entries stay plain ASCII text in the output bytes
/// even though content streams are deflated - confirmed directly against
/// the installed `pdf` package before writing this test. Used to verify
/// page count and each page's exact PDF point dimensions without needing a
/// PDF reader, matching this codebase's pure-fixture testing convention.
List<String> _mediaBoxes(Uint8List bytes) {
  final text = String.fromCharCodes(bytes.where((b) => b < 256));
  return RegExp(
    r'/MediaBox\s*\[([^\]]+)\]',
  ).allMatches(text).map((m) => m.group(1)!.trim()).toList();
}

void main() {
  test('empty board returns null', () async {
    final result = await writePdfFile(
      frames: const [],
      clips: const [],
      strokes: const [],
      readBytes: _fakeReadBytes,
    );
    expect(result, isNull);
  });

  test('one page per frame, sized exactly to that frame', () async {
    final frames = [
      _frame(id: 'f1', x: 0, y: 0, width: 400, height: 300),
      _frame(id: 'f2', x: 1000, y: 0, width: 595.28, height: 841.89),
    ];
    final clips = [
      _imageClip(
        id: 'c1',
        frameId: 'f1',
        localFilePath: 'fake.png',
        x: 10,
        y: 10,
        width: 50,
        height: 30,
      ),
    ];

    final result = await writePdfFile(
      frames: frames,
      clips: clips,
      strokes: const [],
      readBytes: _fakeReadBytes,
    );

    expect(result, isNotNull);
    expect(result!.summary.framePages, 2);
    expect(result.summary.hasOverviewPage, isFalse);
    expect(result.summary.imagesDrawn, 1);
    expect(result.summary.imagesSkipped, 0);

    final boxes = _mediaBoxes(result.bytes);
    expect(boxes.length, 2);
    expect(boxes[0], '0 0 400 300');
    expect(boxes[1], '0 0 595.28 841.89');
  });

  test('loose (unparented) clips get one leading overview page', () async {
    final clips = [
      _textClip(id: 't1', text: 'loose note', x: 0, y: 0),
      _textClip(id: 't2', text: 'another', x: 300, y: 100),
    ];

    final result = await writePdfFile(
      frames: const [],
      clips: clips,
      strokes: const [],
      readBytes: _fakeReadBytes,
    );

    expect(result, isNotNull);
    expect(result!.summary.framePages, 0);
    expect(result.summary.hasOverviewPage, isTrue);
    expect(_mediaBoxes(result.bytes).length, 1);
  });

  test('an image clip whose file cannot be read is skipped, not fatal', () async {
    final frames = [_frame(id: 'f1', x: 0, y: 0, width: 200, height: 200)];
    final clips = [
      _imageClip(
        id: 'missing',
        frameId: 'f1',
        localFilePath: 'does-not-exist.png',
        x: 0,
        y: 0,
        width: 50,
        height: 50,
      ),
    ];

    final result = await writePdfFile(
      frames: frames,
      clips: clips,
      strokes: const [],
      readBytes: (key) async => null,
    );

    expect(result, isNotNull);
    expect(result!.summary.imagesDrawn, 0);
    expect(result.summary.imagesSkipped, 1);
    // The frame's own page is still produced even though its only child
    // was skipped.
    expect(_mediaBoxes(result.bytes).length, 1);
  });

  test('freestanding strokes intersecting no page are dropped silently', () async {
    final frames = [_frame(id: 'f1', x: 0, y: 0, width: 200, height: 200)];
    final now = DateTime.now();
    final strokes = [
      Stroke(
        id: 's1',
        boardId: 'board-1',
        colorHex: '#FF0000',
        strokeWidth: 2,
        points: const [Offset(5000, 5000), Offset(5010, 5010)],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final result = await writePdfFile(
      frames: frames,
      clips: const [],
      strokes: strokes,
      readBytes: _fakeReadBytes,
    );

    expect(result, isNotNull);
    // Doesn't throw, and the frame's page is still produced.
    expect(_mediaBoxes(result!.bytes).length, 1);
  });
}
