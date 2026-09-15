import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/eyedropper_service.dart';
import 'package:image/image.dart' as img;

void main() {
  late Uint8List imageBytes;

  setUpAll(() {
    final image = img.Image(width: 4, height: 4);
    // Left half red, right half blue.
    for (var y = 0; y < 4; y++) {
      for (var x = 0; x < 4; x++) {
        image.setPixelRgb(x, y, x < 2 ? 255 : 0, 0, x < 2 ? 0 : 255);
      }
    }
    imageBytes = img.encodePng(image);
  });

  test('samples the pixel color at the given fraction', () async {
    final red = await sampleColorAt(imageBytes, const Offset(0.1, 0.5));
    expect(red, '#FF0000');

    final blue = await sampleColorAt(imageBytes, const Offset(0.9, 0.5));
    expect(blue, '#0000FF');
  });

  test('returns null for bytes that are not a valid image', () async {
    final badBytes = Uint8List.fromList(List.filled(64, 7));
    final result = await sampleColorAt(badBytes, const Offset(0, 0));
    expect(result, isNull);
  });
}
