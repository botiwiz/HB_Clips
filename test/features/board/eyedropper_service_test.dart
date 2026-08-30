import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/eyedropper_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String imagePath;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('eyedropper_test');
    final image = img.Image(width: 4, height: 4);
    // Left half red, right half blue.
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        image.setPixelRgb(x, y, x < 2 ? 255 : 0, 0, x < 2 ? 0 : 255);
      }
    }
    imagePath = p.join(tempDir.path, 'sample.png');
    await File(imagePath).writeAsBytes(img.encodePng(image));
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('samples the pixel color at the given fraction', () async {
    final red = await sampleColorAt(imagePath, const Offset(0.1, 0.5));
    expect(red, '#FF0000');

    final blue = await sampleColorAt(imagePath, const Offset(0.9, 0.5));
    expect(blue, '#0000FF');
  });

  test('returns null for a file that is not a valid image', () async {
    final badPath = p.join(tempDir.path, 'not_an_image.txt');
    await File(badPath).writeAsBytes(List.filled(64, 7));
    final result = await sampleColorAt(badPath, const Offset(0, 0));
    expect(result, isNull);
  });
}
