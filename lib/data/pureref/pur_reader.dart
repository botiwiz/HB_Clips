import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'pur_file.dart';
import 'pur_v2_sqlite.dart';

final Uint8List _sqliteMagic = Uint8List.fromList(
  'SQLite format 3\x00'.codeUnits,
);
final Uint8List _jpegSoiPrefix = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

const _graphicsImageItem = 34;
const _graphicsTextItem = 32;

final Uint8List _pngHead = Uint8List.fromList(
  [137, 80, 78, 71, 13, 10, 26, 10],
);
final Uint8List _pngFoot = Uint8List.fromList(
  [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130],
);

class _RawImage {
  final List<int> address;
  Uint8List data;
  List<PurImageItem> transforms = const [];

  _RawImage({required this.address, required this.data});

  /// A 4-byte non-PNG entry: either a duplicate-placement marker (its 4
  /// bytes are the id of the transform it duplicates) or an external/missing
  /// image link (`0xFFFFFFFF`).
  bool get isMarker => data.length == 4;

  bool get isMissingLink =>
      isMarker &&
      data[0] == 0xFF &&
      data[1] == 0xFF &&
      data[2] == 0xFF &&
      data[3] == 0xFF;
}

/// Parses PureRef's old (1.10/1.11.1) `.pur` file format - reverse
/// engineered by the community (no official spec exists; PureRef 2.0+ uses a
/// different, undocumented format this cannot read). Every offset and field
/// below was cross-checked against a from-scratch fixture generated with the
/// reference implementation's own writer, not guessed.
///
/// Big-endian throughout. The file is a flat byte stream read strictly
/// front-to-back - `_pos` is the only piece of state, standing in for the
/// reference Python implementation's "erase consumed bytes from the front"
/// approach (erase-by-slicing is O(n^2) and unnecessary once you track a
/// cursor instead).
class PurReader {
  final Uint8List _bytes;
  late final ByteData _view;
  int _pos = 0;

  PurReader(this._bytes) {
    _view = ByteData.sublistView(_bytes);
  }

  PurFile read() {
    if (_bytes.length >= 4 && _view.getUint32(0, Endian.big) == 6) {
      return _readV2();
    }
    _validateHeader();
    final header = _readHeader();
    final rawImages = _readImages();
    final result = _readItems();
    final folderLocation = _pos < _bytes.length ? _readString() : '';
    _readReferences(result.imageTransforms, rawImages);
    _mergeDuplicates(rawImages);

    final images = rawImages
        .where((img) => !img.isMarker && img.transforms.isNotEmpty)
        .map((img) => PurImage(pngBytes: img.data, transforms: img.transforms))
        .toList();

    return PurFile(
      canvas: header.canvas,
      zoom: header.zoom,
      xCanvas: header.xCanvas,
      yCanvas: header.yCanvas,
      folderLocation: folderLocation,
      images: images,
      text: result.topLevelText,
    );
  }

  // ---- primitive reads --------------------------------------------------

  double _readDouble() {
    final v = _view.getFloat64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  int _readUint16() {
    final v = _view.getUint16(_pos, Endian.big);
    _pos += 2;
    return v;
  }

  int _readUint32() {
    final v = _view.getUint32(_pos, Endian.big);
    _pos += 4;
    return v;
  }

  int _readInt8() {
    final v = _view.getInt8(_pos);
    _pos += 1;
    return v;
  }

  int _peekUint32(int relativeOffset) =>
      _view.getUint32(_pos + relativeOffset, Endian.big);

  int _peekInt32(int relativeOffset) =>
      _view.getInt32(_pos + relativeOffset, Endian.big);

  void _skip(int n) => _pos += n;

  List<double> _readMatrix() {
    // Written as 6 doubles (a, b, 0.0, c, d, 0.0) - the middle and trailing
    // slots are always-zero padding, not meaningful fields.
    final a = _readDouble();
    final b = _readDouble();
    _skip(8);
    final c = _readDouble();
    final d = _readDouble();
    _skip(8);
    return [a, b, c, d];
  }

  List<int> _readRgb() => [_readUint16(), _readUint16(), _readUint16()];

  /// Standard HSV->RGB, matching Python's `colorsys.hsv_to_rgb` exactly
  /// (including the format's odd hue divisor of 35900, not 65535/360).
  List<int> _hsvToRgb(List<int> hsv) {
    final h = hsv[0] / 35900.0;
    final s = hsv[1] / 65535.0;
    final v = hsv[2] / 65535.0;
    double r, g, b;
    if (s == 0.0) {
      r = g = b = v;
    } else {
      final i = (h * 6.0).floor();
      final f = (h * 6.0) - i;
      final p = v * (1.0 - s);
      final q = v * (1.0 - s * f);
      final t = v * (1.0 - s * (1.0 - f));
      switch (i % 6) {
        case 0:
          r = v;
          g = t;
          b = p;
        case 1:
          r = q;
          g = v;
          b = p;
        case 2:
          r = p;
          g = v;
          b = t;
        case 3:
          r = p;
          g = q;
          b = v;
        case 4:
          r = t;
          g = p;
          b = v;
        default:
          r = v;
          g = p;
          b = q;
      }
    }
    return [(r * 65535).round(), (g * 65535).round(), (b * 65535).round()];
  }

  String _readString() {
    final length = _readUint32();
    final bytes = Uint8List.sublistView(_bytes, _pos, _pos + length);
    _pos += length;
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      codeUnits.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(codeUnits);
  }

  int _indexOf(Uint8List needle, int from) {
    final limit = _bytes.length - needle.length;
    outer:
    for (var i = from; i <= limit; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (_bytes[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  // ---- header -------------------------------------------------------

  void _validateHeader() {
    if (_bytes.length < 224) {
      throw const PurFormatException(
        'This file is too short to be a PureRef project file.',
      );
    }
    // Magic 6 (PureRef 2.x) is handled entirely separately by `_readV2` -
    // `read()` dispatches to it before this method is ever called.
    final magic = _view.getUint32(0, Endian.big);
    if (magic != 8) {
      throw const PurFormatException(
        "This doesn't look like a PureRef .pur file.",
      );
    }
    final versionBytes = Uint8List.sublistView(_bytes, 4, 12);
    final codeUnits = <int>[];
    for (var i = 0; i + 1 < versionBytes.length; i += 2) {
      codeUnits.add((versionBytes[i] << 8) | versionBytes[i + 1]);
    }
    final version = String.fromCharCodes(codeUnits);
    if (version != '1.10') {
      throw PurFormatException(
        'This .pur file uses format version "$version". HB_Clips can only '
        'import the older PureRef 1.10/1.11.1 format - PureRef 2.0 and '
        'later save in a different, undocumented format that isn\'t '
        'supported yet.',
      );
    }
  }

  ({List<double> canvas, double zoom, int xCanvas, int yCanvas}) _readHeader() {
    final canvas = [
      _view.getFloat64(112, Endian.big),
      _view.getFloat64(120, Endian.big),
      _view.getFloat64(128, Endian.big),
      _view.getFloat64(136, Endian.big),
    ];
    final zoom = _view.getFloat64(144, Endian.big);
    final xCanvas = _view.getInt32(216, Endian.big);
    final yCanvas = _view.getInt32(220, Endian.big);
    _pos = 224;
    return (canvas: canvas, zoom: zoom, xCanvas: xCanvas, yCanvas: yCanvas);
  }

  // ---- images ---------------------------------------------------------

  List<_RawImage> _readImages() {
    final images = <_RawImage>[];

    while (true) {
      final headIdx = _indexOf(_pngHead, _pos);
      if (headIdx == -1) break;
      final start = headIdx - _pos;
      if (start >= 4) {
        // A duplicate/link marker sits before the next real image.
        final data = Uint8List.sublistView(_bytes, _pos, _pos + 4);
        images.add(_RawImage(address: [_pos, _pos + 4], data: data));
        _pos += 4;
      } else {
        final footIdx = _indexOf(_pngFoot, _pos);
        if (footIdx == -1) {
          throw const PurFormatException(
            'Found an incomplete image while reading this .pur file.',
          );
        }
        final end = (footIdx - _pos) + 12;
        final data = Uint8List.sublistView(
          _bytes,
          _pos + start,
          _pos + end,
        );
        images.add(
          _RawImage(address: [_pos + start, _pos + end], data: data),
        );
        _pos += end;
      }
    }

    // Any trailing duplicate/link markers before the item stream starts.
    while (_pos + 12 <= _bytes.length &&
        !(_peekUint32(8) == _graphicsImageItem ||
            _peekUint32(8) == _graphicsTextItem)) {
      final data = Uint8List.sublistView(_bytes, _pos, _pos + 4);
      images.add(_RawImage(address: [_pos, _pos + 4], data: data));
      _pos += 4;
    }

    return images;
  }

  // ---- items ------------------------------------------------------------

  ({List<PurImageItem> imageTransforms, List<PurTextItem> topLevelText})
  _readItems() {
    final imageTransforms = <PurImageItem>[];
    final topLevelText = <PurTextItem>[];

    while (_pos + 12 <= _bytes.length) {
      final typeTag = _peekUint32(8);
      if (typeTag == _graphicsImageItem) {
        imageTransforms.add(_readImageItem());
      } else if (typeTag == _graphicsTextItem) {
        topLevelText.add(_readTextItem());
      } else {
        break;
      }
    }

    return (imageTransforms: imageTransforms, topLevelText: topLevelText);
  }

  PurTextItem _readTextItem() {
    final transformEnd = _readUint64();
    final typeCode = _readUint32(); // 32; also the byte-length of the
    _skip(typeCode); // literal "GraphicsTextItem" name that follows it.

    final text = _readString();
    final matrix = _readMatrix();
    final x = _readDouble();
    final y = _readDouble();
    _skip(8); // permanent 1.0 double, no known meaning
    final id = _readUint32();
    final zLayer = _readDouble();

    final isForegroundHsv = _readInt8() == 2;
    final opacity = _readUint16();
    var rgb = _readRgb();
    if (isForegroundHsv) rgb = _hsvToRgb(rgb);

    _skip(2); // unknown
    final isBackgroundHsv = _readInt8() == 2;
    final opacityBackground = _readUint16();
    var rgbBackground = _readRgb();
    if (isBackgroundHsv) rgbBackground = _hsvToRgb(rgbBackground);

    final childCount = _peekUint32(2);
    _pos = transformEnd;

    final children = <PurTextItem>[];
    for (var i = 0; i < childCount; i++) {
      children.add(_readTextItem());
    }

    return PurTextItem(
      id: id,
      zLayer: zLayer,
      matrix: matrix,
      x: x,
      y: y,
      text: text,
      opacity: opacity,
      rgb: rgb,
      opacityBackground: opacityBackground,
      rgbBackground: rgbBackground,
      textChildren: children,
    );
  }

  PurImageItem _readImageItem() {
    final transformEnd = _readUint64();
    final typeCode = _readUint32(); // 34; also the byte-length of the
    _skip(typeCode); // literal "GraphicsImageItem" name that follows it.

    final bruteForceLoaded = _peekUint32(0) == 0;
    if (bruteForceLoaded) _skip(4);

    String? source;
    if (_peekInt32(0) == -1) {
      _skip(4);
    } else {
      source = _readString();
    }

    String? name;
    if (!bruteForceLoaded) {
      if (_peekInt32(0) == -1) {
        _skip(4);
      } else {
        name = _readString();
      }
    }

    _skip(8); // permanent 1.0 double, no known meaning
    final matrix = _readMatrix();
    final x = _readDouble();
    final y = _readDouble();
    _skip(8); // second permanent 1.0 double

    final id = _readUint32();
    final zLayer = _readDouble();
    _readMatrix(); // matrixBeforeCrop - not needed for import, only for
    // reproducing PureRef's own "undo crop" gesture.
    _readDouble(); // xCrop
    _readDouble(); // yCrop
    _readDouble(); // scaleCrop

    final pointCount = _readUint32();
    final pointsX = <double>[];
    final pointsY = <double>[];
    for (var i = 0; i < pointCount; i++) {
      _skip(4);
      pointsX.add(_readDouble());
      pointsY.add(_readDouble());
    }

    final childCount = _peekUint32(21);
    _pos = transformEnd;

    final children = <PurTextItem>[];
    for (var i = 0; i < childCount; i++) {
      children.add(_readTextItem());
    }

    return PurImageItem(
      id: id,
      zLayer: zLayer,
      matrix: matrix,
      x: x,
      y: y,
      source: source,
      name: name,
      pointsX: pointsX,
      pointsY: pointsY,
      textChildren: children,
    );
  }

  int _readUint64() {
    final v = _view.getUint64(_pos, Endian.big);
    _pos += 8;
    return v;
  }

  // ---- trailer: image <-> transform references --------------------------

  void _readReferences(List<PurImageItem> imageTransforms, List<_RawImage> rawImages) {
    for (var i = 0; i < imageTransforms.length; i++) {
      if (_pos + 20 > _bytes.length) break;
      final refId = _peekUint32(0);
      final refAddress0 = _view.getUint64(_pos + 4, Endian.big);
      for (final item in imageTransforms) {
        if (item.id == refId) {
          for (final image in rawImages) {
            if (image.address[0] == refAddress0) {
              image.transforms = [item];
            }
          }
        }
      }
      _skip(20);
    }
  }

  void _mergeDuplicates(List<_RawImage> rawImages) {
    for (final image in rawImages) {
      if (image.isMarker && !image.isMissingLink) {
        final linkedId = ByteData.sublistView(image.data).getUint32(0, Endian.big);
        for (final other in rawImages) {
          if (other.transforms.isNotEmpty && other.transforms.first.id == linkedId) {
            other.transforms = [...other.transforms, ...image.transforms];
          }
        }
      }
    }
  }

  // ---- PureRef 2.x --------------------------------------------------
  //
  // Reverse-engineered from a single real export (no official spec exists
  // for this format either) - see the doc comments below and in
  // `pur_v2_sqlite.dart` for exactly what's confirmed vs. assumed. Unlike
  // the 1.x format above, this hasn't been cross-checked against a
  // from-scratch fixture generated by PureRef's own writer, so treat every
  // offset/assumption here as best-effort, not verified.
  //
  // Structure: a fixed-size header (unused by this importer), followed by
  // zero or more embedded JPEG images in their original bytes, followed by
  // an embedded SQLite database holding every item's transform, z-order,
  // and which `images.id` each item uses. The database is reliably
  // truncated in the exported file - only the small tables fit in what's
  // actually present, never the `images` table itself (see
  // `pur_v2_sqlite.dart`) - so this can't recover *which* embedded JPEG
  // belongs to *which* item by id or checksum. The best available signal
  // is assuming images were embedded in the same order as their
  // `images.id`, ascending - documented here, not hidden, since it's a
  // real gap: an item whose image can't be paired up this way is dropped
  // and counted in [PurFile.unrecoverableImageCount] rather than guessed at.

  PurFile _readV2() {
    final sqliteOffset = _indexOf(_sqliteMagic, 0);
    if (sqliteOffset == -1) {
      throw const PurFormatException(
        "This PureRef 2.x file doesn't contain a readable project "
        'database - it may be corrupted, or use a layout different from '
        'the one HB_Clips understands.',
      );
    }
    final db = MiniSqlite(Uint8List.sublistView(_bytes, sqliteOffset));
    if (!db.looksValid) {
      throw const PurFormatException(
        "This PureRef 2.x file's embedded project database looks "
        'corrupted.',
      );
    }
    final rootPages = db.readSchemaRootPages();
    final itemsRoot = rootPages['items'];
    final itemsImagesRoot = rootPages['items_images'];
    if (itemsRoot == null || itemsImagesRoot == null) {
      throw const PurFormatException(
        "Couldn't find this file's item data - it may use a different "
        "PureRef 2.x database layout than HB_Clips understands.",
      );
    }

    // items: (parent, id, name, transform, sort_order, z, opacity, locked,
    // comment) - id (index 1) is the INTEGER PRIMARY KEY.
    final itemRows = db.readLeafTable(itemsRoot, intPkColumnIndex: 1);
    // items_images: (image, playback_speed, id, playback_state,
    // image_transform, image_bounds, playback_frame, flags) - id (index 2)
    // is the INTEGER PRIMARY KEY, and (confirmed on the one real sample
    // available) always equal to the owning item's own id.
    final itemsImagesRows = db.readLeafTable(
      itemsImagesRoot,
      intPkColumnIndex: 2,
    );

    final itemTransforms = <int, ({double scale, double dx, double dy, double zLayer})>{};
    for (final row in itemRows) {
      if (row.length < 6) continue;
      final id = row[1];
      final transformBytes = row[3];
      final z = row[5];
      if (id is! int || transformBytes is! Uint8List) continue;
      final decoded = _decodeQTransform(transformBytes);
      if (decoded == null) continue;
      itemTransforms[id] = (
        scale: decoded.$1,
        dx: decoded.$2,
        dy: decoded.$3,
        zLayer: z is double ? z : (z is int ? z.toDouble() : 0.0),
      );
    }

    final imageIdToItemId = <int, int>{};
    for (final row in itemsImagesRows) {
      if (row.length < 3) continue;
      final imageId = row[0];
      final itemId = row[2];
      if (imageId is int && itemId is int) {
        imageIdToItemId[imageId] = itemId;
      }
    }
    final orderedImageIds = imageIdToItemId.keys.toList()..sort();

    final jpegBlobs = _findTopLevelJpegs(sqliteOffset);

    final images = <PurImage>[];
    var unrecoverable = 0;
    final pairCount = orderedImageIds.length < jpegBlobs.length
        ? orderedImageIds.length
        : jpegBlobs.length;
    for (var i = 0; i < pairCount; i++) {
      final itemId = imageIdToItemId[orderedImageIds[i]]!;
      final transform = itemTransforms[itemId];
      final dims = _readJpegDimensions(jpegBlobs[i]);
      final decoded = dims == null ? null : img.decodeJpg(jpegBlobs[i]);
      if (transform == null || dims == null || decoded == null) {
        unrecoverable++;
        continue;
      }
      final (width, height) = dims;
      final halfW = width / 2;
      final halfH = height / 2;
      images.add(
        PurImage(
          pngBytes: img.encodePng(decoded),
          transforms: [
            PurImageItem(
              id: itemId,
              zLayer: transform.zLayer,
              // No rotation/shear seen on any item in the one real sample
              // available (every QTransform found has m12=m21=0) - a pure
              // uniform-scale linear map, matching the old format's
              // [a,b,c,d] shape with b=c=0.
              matrix: [transform.scale, 0.0, 0.0, transform.scale],
              // Assumed to be the image's *center* in canvas space, matching
              // the old 1.x format's own center-based convention (and
              // PureRef's rotate-around-center behavior) - not verified
              // against a rotated 2.x sample, since this one has none.
              x: transform.dx,
              y: transform.dy,
              pointsX: [-halfW, halfW, halfW, -halfW, -halfW],
              pointsY: [-halfH, -halfH, halfH, halfH, -halfH],
            ),
          ],
        ),
      );
    }
    unrecoverable += imageIdToItemId.length - pairCount;

    return PurFile(
      canvas: const [0, 0, 0, 0],
      zoom: 1.0,
      xCanvas: 0,
      yCanvas: 0,
      folderLocation: '',
      images: images,
      // Text notes, groups and drawings aren't handled yet for 2.x - this
      // sample file has none of any of them (empty `items_notes` /
      // `items_groups` / `items_drawings` tables), so there's no ground
      // truth yet to check a guessed encoding against.
      text: const [],
      unrecoverableImageCount: unrecoverable,
    );
  }

  /// Decodes an `items.transform` value. Qt's own SQLite driver stores this
  /// BLOB column using *TEXT* storage - fine for genuinely-textual columns,
  /// but for a raw binary blob it means every on-disk byte first went
  /// through a UTF-8 encode of that byte's Latin-1 codepoint (byte 0xNN ->
  /// the UTF-8 bytes for codepoint U+00NN), a classic double-encoding
  /// mojibake. `utf8.decode` undoes exactly that - each resulting codepoint
  /// (always <= 0xFF, since that's all that encoding ever produces) is one
  /// original byte. *Then* the real content is: a 4-byte big-endian length
  /// prefix (always 80 on the one file checked), a 1-byte marker (always
  /// 0), then 9 big-endian float64s - a Qt `QTransform`'s row-major 3x3
  /// matrix (`m11 m12 m13 / m21 m22 m23 / m31 m32 m33`). Only `m11` (scale -
  /// every item seen has `m11==m22`, i.e. uniform scale, no rotation/skew)
  /// and `m31`/`m32` (translation) are extracted; returns null if the blob
  /// can't be decoded as UTF-8, or is too short once decoded.
  (double, double, double)? _decodeQTransform(Uint8List onDiskBytes) {
    late Uint8List bytes;
    try {
      bytes = Uint8List.fromList(utf8.decode(onDiskBytes).codeUnits);
    } on FormatException {
      return null;
    }
    const doublesOffset = 5;
    if (bytes.length < doublesOffset + 9 * 8) return null;
    final view = ByteData.sublistView(bytes);
    final m11 = view.getFloat64(doublesOffset, Endian.big);
    final m31 = view.getFloat64(doublesOffset + 6 * 8, Endian.big);
    final m32 = view.getFloat64(doublesOffset + 7 * 8, Endian.big);
    return (m11, m31, m32);
  }

  /// Scans `_bytes[0, limit)` (everything before the embedded SQLite
  /// database) for complete, top-level embedded JPEG images, in file order.
  /// A naive search for `FFD8FF...FFD9` byte patterns over-counts: a JPEG
  /// can itself embed a smaller JPEG-format EXIF thumbnail (with its own
  /// SOI, but often no proper EOI of its own) inside an APP1 segment, and a
  /// truncated/dangling one of those would otherwise get counted as a
  /// second top-level image. This walks real JPEG markers instead - segment
  /// lengths, and entropy-coded scan data up to the next genuine marker -
  /// so only clean, fully-delimited images come back.
  List<Uint8List> _findTopLevelJpegs(int limit) {
    final candidates = <int>[];
    var searchFrom = 0;
    while (true) {
      final idx = _indexOf(_jpegSoiPrefix, searchFrom);
      if (idx == -1 || idx >= limit) break;
      candidates.add(idx);
      searchFrom = idx + 1;
    }

    final blobs = <Uint8List>[];
    var consumedUntil = 0;
    for (final soi in candidates) {
      if (soi < consumedUntil) continue;
      final end = _walkJpegToEoi(soi, limit);
      if (end == null) continue;
      blobs.add(Uint8List.sublistView(_bytes, soi, end));
      consumedUntil = end;
    }
    return blobs;
  }

  /// Walks JPEG markers from an SOI at `start`, returning the offset just
  /// past its EOI marker, or null if a clean EOI isn't found before `limit`
  /// (e.g. a truncated/dangling embedded thumbnail - see
  /// [_findTopLevelJpegs]).
  int? _walkJpegToEoi(int start, int limit) {
    if (_bytes[start] != 0xFF || _bytes[start + 1] != 0xD8) return null;
    var pos = start + 2;
    while (pos < limit - 1) {
      if (_bytes[pos] != 0xFF) return null;
      final marker = _bytes[pos + 1];
      if (marker == 0xD9) return pos + 2;
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        pos += 2;
        continue;
      }
      if (pos + 4 > limit) return null;
      final segLen = (_bytes[pos + 2] << 8) | _bytes[pos + 3];
      if (marker == 0xDA) {
        var p = pos + 2 + segLen;
        while (p < limit - 1) {
          if (_bytes[p] == 0xFF &&
              _bytes[p + 1] != 0x00 &&
              !(_bytes[p + 1] >= 0xD0 && _bytes[p + 1] <= 0xD7)) {
            break;
          }
          p++;
        }
        pos = p;
        continue;
      }
      pos += 2 + segLen;
    }
    return null;
  }

  /// Reads a JPEG's native pixel dimensions straight from its SOFn segment
  /// (works for both baseline `SOF0` and progressive `SOF2`, which every
  /// image in the one real 2.x sample available uses) - no full JPEG
  /// decode needed just for this.
  (int, int)? _readJpegDimensions(Uint8List jpeg) {
    var pos = 2;
    while (pos < jpeg.length - 8) {
      if (jpeg[pos] != 0xFF) return null;
      final marker = jpeg[pos + 1];
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        final height = (jpeg[pos + 5] << 8) | jpeg[pos + 6];
        final width = (jpeg[pos + 7] << 8) | jpeg[pos + 8];
        return (width, height);
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        pos += 2;
        continue;
      }
      final segLen = (jpeg[pos + 2] << 8) | jpeg[pos + 3];
      pos += 2 + segLen;
    }
    return null;
  }
}
