import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/pureref/pur_file.dart';
import 'package:hb_clips/data/pureref/pur_reader.dart';

/// `sample.pur` is a real, spec-compliant old-format (1.10) file generated
/// with the reference implementation's own writer (github.com/FyorDev/
/// PureRef-format) - not hand-rolled bytes - so this test exercises the
/// reader against genuine format output. It contains:
///   - Image A: 64x64 red square, unrotated, centered at (100, 200)
///   - Image B: 32x48 blue rectangle, rotated 30 degrees, centered at
///     (-50, 300)
///   - Image C: cropped from a 64x64 source down to the central 32x32
///     region, unrotated, centered at (0, -100)
///   - One text note "Hello PureRef", white on semi-opaque black
void main() {
  late PurFile file;

  setUpAll(() {
    final bytes = File(
      'test/data/pureref/fixtures/sample.pur',
    ).readAsBytesSync();
    file = PurReader(bytes).read();
  });

  test('parses the expected number of images and text notes', () {
    final transforms = file.images.expand((image) => image.transforms);
    expect(transforms.length, 3);
    expect(file.text.length, 1);
  });

  test('unrotated square image reports correct size, center and rotation', () {
    final transform = file.images
        .expand((image) => image.transforms)
        .firstWhere((t) => (t.x - 100.0).abs() < 0.01);
    expect(transform.width, closeTo(64.0, 0.01));
    expect(transform.height, closeTo(64.0, 0.01));
    expect(transform.x, closeTo(100.0, 0.01));
    expect(transform.y, closeTo(200.0, 0.01));
    expect(transform.rotationRadians, closeTo(0.0, 0.001));
    expect(transform.isAxisAlignedRectangle, isTrue);
  });

  test('rotated rectangle image decomposes matrix into size + rotation, '
      'not the naive scale-only reading', () {
    final transform = file.images
        .expand((image) => image.transforms)
        .firstWhere((t) => (t.x - (-50.0)).abs() < 0.01);
    expect(transform.width, closeTo(32.0, 0.01));
    expect(transform.height, closeTo(48.0, 0.01));
    expect(transform.x, closeTo(-50.0, 0.01));
    expect(transform.y, closeTo(300.0, 0.01));
    expect(transform.rotationRadians, closeTo(pi / 6, 0.001)); // 30 degrees
  });

  test('cropped image reports the cropped size, and its crop polygon is '
      'detected as an axis-aligned inset rectangle', () {
    final transform = file.images
        .expand((image) => image.transforms)
        .firstWhere((t) => (t.x - 0.0).abs() < 0.01 && (t.y - (-100.0)).abs() < 0.01);
    expect(transform.width, closeTo(32.0, 0.01));
    expect(transform.height, closeTo(32.0, 0.01));
    expect(transform.isAxisAlignedRectangle, isTrue);
    // Crop points are pixel-offsets from the *native* image's center - the
    // 64x64 source cropped to its central 32x32 region should span -16..16.
    expect(transform.pointsX.reduce(min), closeTo(-16.0, 0.01));
    expect(transform.pointsX.reduce(max), closeTo(16.0, 0.01));
  });

  test('text note content and colors round-trip', () {
    final text = file.text.single;
    expect(text.text, 'Hello PureRef');
    expect(text.x, closeTo(0.0, 0.01));
    expect(text.y, closeTo(0.0, 0.01));
    expect(text.rgb, [65535, 65535, 65535]);
    expect(text.opacity, 65535);
    expect(text.rgbBackground, [0, 0, 0]);
    expect(text.opacityBackground, 32768);
  });

  test('rejects a file that is not a PureRef .pur file', () {
    final bogus = List<int>.filled(300, 0);
    expect(
      () => PurReader(Uint8List.fromList(bogus)).read(),
      throwsA(isA<PurFormatException>()),
    );
  });
}
