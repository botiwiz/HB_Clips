import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/pureref/pur_file.dart';
import 'package:hb_clips/data/pureref/pur_reader.dart';

/// `sample_v2.pur` is a synthetic PureRef 2.x-shaped file: a real embedded
/// JPEG (one of the actual images taken from a real-world PureRef 2.x
/// export, not hand-rolled bytes) followed by a real SQLite database (built
/// with Python's own `sqlite3` module - an independent encoder, not this
/// reader's own logic reflected back at itself) whose `items`/
/// `items_images` tables match the column layout confirmed by hex/schema
/// -inspecting that real export. See the generation notes in this repo's
/// PR/commit history for exactly how it was built.
///
/// It deliberately has two items but only one embedded image, to exercise
/// [PurFile.unrecoverableImageCount]:
///   - item 0: transform scale=2.0, translate=(100.0, 50.0), paired with
///     the one embedded 256x256 JPEG -> expect a 512x512 image centered at
///     (100, 50).
///   - item 1: transform scale=1.0, translate=(-30.0, 400.0), but
///     references an `images.id` with no corresponding embedded JPEG in
///     this file -> expect it to be dropped, not guessed at.
void main() {
  late PurFile file;

  setUpAll(() {
    final bytes = File(
      'test/data/pureref/fixtures/sample_v2.pur',
    ).readAsBytesSync();
    file = PurReader(bytes).read();
  });

  test('imports exactly the one recoverable image', () {
    final transforms = file.images.expand((image) => image.transforms).toList();
    expect(transforms.length, 1);
  });

  test('reports the other item as unrecoverable rather than guessing', () {
    expect(file.unrecoverableImageCount, 1);
  });

  test('the recovered image has the correct center, size and no rotation', () {
    final transform = file.images.single.transforms.single;
    expect(transform.x, closeTo(100.0, 0.01));
    expect(transform.y, closeTo(50.0, 0.01));
    expect(transform.scaleX, closeTo(2.0, 0.0001));
    expect(transform.scaleY, closeTo(2.0, 0.0001));
    expect(transform.rotationRadians, closeTo(0.0, 0.0001));
    expect(transform.unscaledWidth, closeTo(256.0, 0.01));
    expect(transform.unscaledHeight, closeTo(256.0, 0.01));
    expect(transform.width, closeTo(512.0, 0.01));
    expect(transform.height, closeTo(512.0, 0.01));
    expect(transform.isAxisAlignedRectangle, isTrue);
  });

  test('the recovered image bytes decode as a valid (converted) PNG', () {
    // pur_reader converts the embedded JPEG to PNG bytes internally so the
    // rest of the import pipeline (which expects PurImage.pngBytes to
    // actually be PNG) doesn't need a separate code path for 2.x.
    final pngBytes = file.images.single.pngBytes;
    expect(pngBytes.length, greaterThan(8));
    // PNG magic.
    expect(pngBytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('no text notes yet for 2.x', () {
    expect(file.text, isEmpty);
  });
}
