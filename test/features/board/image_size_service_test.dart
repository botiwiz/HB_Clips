import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/image_size_service.dart';
import 'package:image/image.dart' as img;

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height);
  return img.encodePng(image);
}

void main() {
  test('a wide image gets capped on width, height scales proportionally', () {
    final size = clipSizeForImageBytes(_pngBytes(400, 100), maxEdge: 240);
    expect(size.width, 240);
    expect(size.height, closeTo(60, 0.01)); // 400:100 == 240:60
  });

  test('a tall image gets capped on height, width scales proportionally', () {
    final size = clipSizeForImageBytes(_pngBytes(100, 400), maxEdge: 240);
    expect(size.height, 240);
    expect(size.width, closeTo(60, 0.01));
  });

  test('a square image keeps its default square size', () {
    final size = clipSizeForImageBytes(_pngBytes(300, 300), maxEdge: 240);
    expect(size.width, 240);
    expect(size.height, 240);
  });

  test('an extremely thin image is floored to the minimum edge', () {
    final size = clipSizeForImageBytes(
      _pngBytes(4000, 20),
      maxEdge: 240,
      minEdge: 40,
    );
    expect(size.width, 240);
    expect(size.height, 40); // 240 * 20/4000 = 1.2, floored to 40
  });

  test('undecodable bytes fall back to a square maxEdge box', () {
    final badBytes = Uint8List.fromList(List.filled(32, 9));
    final size = clipSizeForImageBytes(badBytes, maxEdge: 240);
    expect(size.width, 240);
    expect(size.height, 240);
  });
}
