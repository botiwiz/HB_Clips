import 'dart:typed_data';

import 'pur_file.dart';

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
}
