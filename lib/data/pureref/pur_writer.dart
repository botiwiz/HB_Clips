import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/clip.dart';

/// Default text-note background color (`AppTheme.textNoteSurface`, hardcoded
/// here since `data/pureref` deliberately has no UI-layer dependency - the
/// same independence `pur_reader.dart` keeps).
const _defaultTextBackgroundHex = '#EDEDED';

/// How many of each clip type actually made it into the exported file, and
/// how many image clips were skipped because their file couldn't be read or
/// decoded.
class PurExportSummary {
  final int imagesExported;
  final int textNotesExported;
  final int imagesSkipped;

  const PurExportSummary({
    required this.imagesExported,
    required this.textNotesExported,
    required this.imagesSkipped,
  });
}

class PurWriteResult {
  final Uint8List bytes;
  final PurExportSummary summary;
  const PurWriteResult(this.bytes, this.summary);
}

class _EncodedImage {
  final BoardClip clip;
  final Uint8List pngBytes;
  final double nativeWidth;
  final double nativeHeight;

  const _EncodedImage({
    required this.clip,
    required this.pngBytes,
    required this.nativeWidth,
    required this.nativeHeight,
  });
}

/// Writes [clips] out as an old-format (1.10/1.11.1) PureRef `.pur` file -
/// the inverse of `pur_reader.dart`, symmetric with the importer. Every
/// active image and text clip becomes one top-level item; position/size/
/// rotation convert from HB_Clips' top-left+width/height+radians
/// representation into the format's center+matrix representation (the
/// inverse of the math `pureref_import_service.dart` already does the other
/// way).
///
/// Honest scope limits (matching the importer's own documented ones): text
/// notes don't carry rotation into the exported matrix - the format has no
/// documented display convention for a rotated text item, and the reader
/// itself never uses a text item's matrix for sizing/positioning, only its
/// `x`/`y` center. Every exported image is re-encoded as PNG regardless of
/// its source format, since the format only supports embedding PNG bytes.
/// Grouped clips lose their group membership - the format has no grouping
/// concept.
Future<PurWriteResult> writePurFile(List<BoardClip> clips) async {
  final imageClips = clips.where((c) => c.type == ClipType.image).toList();
  final textClips = clips.where((c) => c.type == ClipType.text).toList();

  final encoded = <_EncodedImage>[];
  var imagesSkipped = 0;
  for (final clip in imageClips) {
    final path = clip.localFilePath;
    if (path == null) {
      imagesSkipped++;
      continue;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        imagesSkipped++;
        continue;
      }
      encoded.add(
        _EncodedImage(
          clip: clip,
          pngBytes: img.encodePng(decoded),
          nativeWidth: decoded.width.toDouble(),
          nativeHeight: decoded.height.toDouble(),
        ),
      );
    } catch (_) {
      imagesSkipped++;
    }
  }

  final builder = BytesBuilder();
  builder.add(_buildHeader(itemCount: encoded.length + textClips.length));

  final pngOffsets = <int>[];
  for (final enc in encoded) {
    pngOffsets.add(builder.length);
    builder.add(enc.pngBytes);
  }

  var nextId = 1;
  final imageIds = <int>[];
  for (final enc in encoded) {
    final id = nextId++;
    imageIds.add(id);
    builder.add(_buildImageItem(enc, id, builder.length));
  }
  for (final clip in textClips) {
    final id = nextId++;
    builder.add(_buildTextItem(clip, id, builder.length));
  }

  builder.add(_uint32Bytes(0)); // empty folderLocation string

  for (var i = 0; i < encoded.length; i++) {
    builder.add(_uint32Bytes(imageIds[i]));
    builder.add(_uint64Bytes(pngOffsets[i]));
    builder.add(Uint8List(8)); // unused trailer padding
  }

  return PurWriteResult(
    builder.toBytes(),
    PurExportSummary(
      imagesExported: encoded.length,
      textNotesExported: textClips.length,
      imagesSkipped: imagesSkipped,
    ),
  );
}

Uint8List _uint32Bytes(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.big)).buffer.asUint8List();

Uint8List _uint64Bytes(int v) =>
    (ByteData(8)..setUint64(0, v, Endian.big)).buffer.asUint8List();

List<int> _hexToRgb16(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.parse(digits, radix: 16);
  final r = (value >> 16) & 0xFF;
  final g = (value >> 8) & 0xFF;
  final b = value & 0xFF;
  return [r * 257, g * 257, b * 257];
}

/// Fixed byte length of an exported image item with 5 crop-polygon points
/// (an uncropped rectangle) and zero children - see the field-by-field
/// writes in [_buildImageItem].
const _imageItemLength = 347;

/// 224-byte fixed header - only the fields `pur_reader.dart` actually reads
/// (magic, version, canvas bounds, zoom, view x/y) carry real values; the
/// rest is zero padding, matching the format's documented layout.
Uint8List _buildHeader({required int itemCount}) {
  final w = _ByteWriter();
  w.writeUint32(8); // magic
  w.writeUtf16Raw('1.10'); // offset 4-12
  w.writeUint32(itemCount); // offset 12-16, cosmetic (unread)
  w.writeBytes(Uint8List(96)); // offset 16-112 padding
  w.writeDouble(0); // canvas 112-144
  w.writeDouble(0);
  w.writeDouble(0);
  w.writeDouble(0);
  w.writeDouble(1.0); // zoom 144-152
  w.writeBytes(Uint8List(24)); // 152-176 padding
  w.writeDouble(1.0); // zoom repeat 176-184
  w.writeBytes(Uint8List(24)); // 184-208 padding
  w.writeDouble(1.0); // zoom multiplier 208-216
  w.writeInt32(0); // xCanvas 216-220
  w.writeInt32(0); // yCanvas 220-224
  final bytes = w.toBytes();
  assert(bytes.length == 224);
  return bytes;
}

Uint8List _buildImageItem(_EncodedImage enc, int id, int startPos) {
  final clip = enc.clip;
  final scaleX = clip.width / enc.nativeWidth;
  final scaleY = clip.height / enc.nativeHeight;
  final theta = clip.rotation;
  final a = scaleX * cos(theta);
  final b = -scaleY * sin(theta);
  final c = scaleX * sin(theta);
  final d = scaleY * cos(theta);
  final centerX = clip.x + clip.width / 2;
  final centerY = clip.y + clip.height / 2;
  final halfW = enc.nativeWidth / 2;
  final halfH = enc.nativeHeight / 2;
  final ptsX = [-halfW, halfW, halfW, -halfW, -halfW];
  final ptsY = [-halfH, -halfH, halfH, halfH, -halfH];

  final w = _ByteWriter();
  w.writeUint64(startPos + _imageItemLength);
  w.writeUint32(34);
  w.writeUtf16Raw('GraphicsImageItem'); // exactly 34 bytes
  w.writeInt32(-1); // source = null
  w.writeInt32(-1); // name = null
  w.writeDouble(1.0); // permanent pad
  w.writeDouble(a);
  w.writeDouble(b);
  w.writeDouble(0.0); // matrix padding
  w.writeDouble(c);
  w.writeDouble(d);
  w.writeDouble(0.0); // matrix padding
  w.writeDouble(centerX);
  w.writeDouble(centerY);
  w.writeDouble(1.0); // permanent pad
  w.writeUint32(id);
  w.writeDouble(clip.zIndex.toDouble());
  // matrixBeforeCrop - discarded on read, written identical to matrix since
  // HB_Clips has no separate pre-crop state to preserve.
  w.writeDouble(a);
  w.writeDouble(b);
  w.writeDouble(0.0);
  w.writeDouble(c);
  w.writeDouble(d);
  w.writeDouble(0.0);
  w.writeDouble(0.0); // xCrop
  w.writeDouble(0.0); // yCrop
  w.writeDouble(1.0); // scaleCrop
  w.writeUint32(5); // pointCount
  for (var i = 0; i < 5; i++) {
    w.writeUint32(0); // per-point skip(4)
    w.writeDouble(ptsX[i]);
    w.writeDouble(ptsY[i]);
  }
  w.writeBytes(Uint8List(21)); // footer padding up to the childCount peek
  w.writeUint32(0); // childCount
  final bytes = w.toBytes();
  assert(bytes.length == _imageItemLength);
  return bytes;
}

Uint8List _buildTextItem(BoardClip clip, int id, int startPos) {
  final text = clip.textContent ?? '';
  final itemLength = 158 + text.length * 2;
  final centerX = clip.x + clip.width / 2;
  final centerY = clip.y + clip.height / 2;
  final bgHex = clip.backgroundColorHex ?? _defaultTextBackgroundHex;
  final bgRgb = _hexToRgb16(bgHex);

  final w = _ByteWriter();
  w.writeUint64(startPos + itemLength);
  w.writeUint32(32);
  w.writeUtf16Raw('GraphicsTextItem'); // exactly 32 bytes
  w.writeString(text);
  // Identity matrix - text notes don't carry rotation into the exported
  // matrix (see the class doc comment's scope-limit note).
  w.writeDouble(1.0);
  w.writeDouble(0.0);
  w.writeDouble(0.0);
  w.writeDouble(0.0);
  w.writeDouble(1.0);
  w.writeDouble(0.0);
  w.writeDouble(centerX);
  w.writeDouble(centerY);
  w.writeDouble(1.0); // permanent pad
  w.writeUint32(id);
  w.writeDouble(clip.zIndex.toDouble());
  w.writeInt8(0); // isForegroundHsv = false (plain RGB)
  w.writeUint16(65535); // opacity: full
  w.writeUint16(65535); // white foreground
  w.writeUint16(65535);
  w.writeUint16(65535);
  w.writeUint16(0); // unknown, 2-byte skip
  w.writeInt8(0); // isBackgroundHsv = false
  w.writeUint16(65535); // opacityBackground: full
  w.writeUint16(bgRgb[0]);
  w.writeUint16(bgRgb[1]);
  w.writeUint16(bgRgb[2]);
  w.writeBytes(Uint8List(2)); // footer padding up to the childCount peek
  w.writeUint32(0); // childCount
  final bytes = w.toBytes();
  assert(bytes.length == itemLength);
  return bytes;
}

/// Big-endian primitive writer, the inverse of `PurReader`'s primitive
/// readers.
class _ByteWriter {
  final BytesBuilder _b = BytesBuilder();

  void writeUint32(int v) {
    _b.add((ByteData(4)..setUint32(0, v, Endian.big)).buffer.asUint8List());
  }

  void writeUint64(int v) {
    _b.add((ByteData(8)..setUint64(0, v, Endian.big)).buffer.asUint8List());
  }

  void writeInt32(int v) {
    _b.add((ByteData(4)..setInt32(0, v, Endian.big)).buffer.asUint8List());
  }

  void writeInt8(int v) {
    _b.add((ByteData(1)..setInt8(0, v)).buffer.asUint8List());
  }

  void writeUint16(int v) {
    _b.add((ByteData(2)..setUint16(0, v, Endian.big)).buffer.asUint8List());
  }

  void writeDouble(double v) {
    _b.add((ByteData(8)..setFloat64(0, v, Endian.big)).buffer.asUint8List());
  }

  void writeBytes(List<int> bytes) => _b.add(bytes);

  /// Encodes [s] as big-endian UTF-16 with no length prefix - BMP characters
  /// only, matching `PurReader._readString`'s own simple pairwise decode.
  void writeUtf16Raw(String s) {
    final bytes = Uint8List(s.length * 2);
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      bytes[i * 2] = (code >> 8) & 0xFF;
      bytes[i * 2 + 1] = code & 0xFF;
    }
    _b.add(bytes);
  }

  void writeString(String s) {
    writeUint32(s.length * 2);
    writeUtf16Raw(s);
  }

  Uint8List toBytes() => _b.toBytes();
}
