import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/pureref/pur_reader.dart';
import 'package:hb_clips/data/pureref/pur_writer.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

BoardClip _imageClip({
  required String id,
  required String localFilePath,
  required double x,
  required double y,
  required double width,
  required double height,
  double rotation = 0,
}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.image,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    localFilePath: localFilePath,
    createdAt: now,
    updatedAt: now,
  );
}

BoardClip _textClip({
  required String id,
  required String text,
  required double x,
  required double y,
  String? backgroundColorHex,
}) {
  final now = DateTime.now();
  return BoardClip(
    id: id,
    boardId: 'board-1',
    type: ClipType.text,
    x: x,
    y: y,
    width: 220,
    height: 140,
    textContent: text,
    backgroundColorHex: backgroundColorHex,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pur_writer_test');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> writeTestPng(String name, int width, int height) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 50, 50));
    final path = p.join(tempDir.path, name);
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }

  test('round-trips an unrotated image, a rotated image, and a text note', () async {
    final squarePath = await writeTestPng('square.png', 64, 64);
    final rectPath = await writeTestPng('rect.png', 32, 48);

    final clips = [
      _imageClip(
        id: 'img-1',
        localFilePath: squarePath,
        x: 100 - 32,
        y: 200 - 32,
        width: 64,
        height: 64,
      ),
      _imageClip(
        id: 'img-2',
        localFilePath: rectPath,
        x: -50 - 16,
        y: 300 - 24,
        width: 32,
        height: 48,
        rotation: pi / 6,
      ),
      _textClip(
        id: 'text-1',
        text: 'Hello PureRef',
        x: 10 - 110,
        y: 20 - 70,
        backgroundColorHex: '#112233',
      ),
    ];

    final result = await writePurFile(clips);
    expect(result.summary.imagesExported, 2);
    expect(result.summary.textNotesExported, 1);
    expect(result.summary.imagesSkipped, 0);

    final parsed = PurReader(result.bytes).read();
    final transforms = parsed.images.expand((i) => i.transforms).toList();
    expect(transforms.length, 2);
    expect(parsed.text.length, 1);

    final square = transforms.firstWhere((t) => (t.x - 100.0).abs() < 0.01);
    expect(square.width, closeTo(64.0, 0.01));
    expect(square.height, closeTo(64.0, 0.01));
    expect(square.y, closeTo(200.0, 0.01));
    expect(square.rotationRadians, closeTo(0.0, 0.001));
    expect(square.isAxisAlignedRectangle, isTrue);

    final rect = transforms.firstWhere((t) => (t.x - (-50.0)).abs() < 0.01);
    expect(rect.width, closeTo(32.0, 0.01));
    expect(rect.height, closeTo(48.0, 0.01));
    expect(rect.y, closeTo(300.0, 0.01));
    expect(rect.rotationRadians, closeTo(pi / 6, 0.001));

    final text = parsed.text.single;
    expect(text.text, 'Hello PureRef');
    expect(text.x, closeTo(10.0, 0.01));
    expect(text.y, closeTo(20.0, 0.01));
    expect(text.rgbBackground, [0x11 * 257, 0x22 * 257, 0x33 * 257]);
  });

  test('a text note with no custom background exports the default color', () async {
    final clips = [_textClip(id: 'text-1', text: 'plain', x: 0, y: 0)];
    final result = await writePurFile(clips);
    final parsed = PurReader(result.bytes).read();
    expect(
      parsed.text.single.rgbBackground,
      [0xED * 257, 0xED * 257, 0xED * 257],
    );
  });

  test('an image clip with a missing file is skipped, not thrown', () async {
    final clips = [
      _imageClip(
        id: 'missing',
        localFilePath: p.join(tempDir.path, 'does_not_exist.png'),
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
    ];
    final result = await writePurFile(clips);
    expect(result.summary.imagesExported, 0);
    expect(result.summary.imagesSkipped, 1);
  });
}
