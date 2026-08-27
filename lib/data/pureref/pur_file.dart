import 'dart:math';
import 'dart:typed_data';

/// A text note parsed from a PureRef `.pur` file (either freestanding on the
/// canvas, or a caption attached to an image via [textChildren]).
class PurTextItem {
  final int id;
  final double zLayer;
  final List<double> matrix;
  final double x;
  final double y;
  final String text;

  /// 0-65535, matching the format's own fixed-point opacity/color scale.
  final int opacity;
  final List<int> rgb;
  final int opacityBackground;
  final List<int> rgbBackground;
  final List<PurTextItem> textChildren;

  const PurTextItem({
    required this.id,
    required this.zLayer,
    required this.matrix,
    required this.x,
    required this.y,
    required this.text,
    required this.opacity,
    required this.rgb,
    required this.opacityBackground,
    required this.rgbBackground,
    this.textChildren = const [],
  });
}

/// One placement (transform) of an image on the canvas, parsed from a
/// PureRef `.pur` file. A single source image can have multiple transforms
/// if it was pasted onto the board more than once.
class PurImageItem {
  final int id;
  final double zLayer;

  /// `[a, b, c, d]` - the combined scale+rotation linear map. Deliberately
  /// decomposed below via each column's magnitude/angle rather than reading
  /// `matrix[0]`/`matrix[3]` directly - that shortcut (used by the format's
  /// own reference tool for its convenience getters) silently conflates
  /// rotation with scale once the item is actually rotated, confirmed by
  /// generating a rotated fixture and comparing sizes.
  final List<double> matrix;

  /// Center position, in canvas space (this format positions items by
  /// center, not top-left).
  final double x;
  final double y;
  final String? source;
  final String? name;

  /// Crop polygon, in pixel-offsets from the *native* image's own center
  /// (i.e. independent of [matrix]). An uncropped image's polygon spans the
  /// full native bounds.
  final List<double> pointsX;
  final List<double> pointsY;
  final List<PurTextItem> textChildren;

  const PurImageItem({
    required this.id,
    required this.zLayer,
    required this.matrix,
    required this.x,
    required this.y,
    this.source,
    this.name,
    required this.pointsX,
    required this.pointsY,
    this.textChildren = const [],
  });

  double get scaleX => sqrt(matrix[0] * matrix[0] + matrix[2] * matrix[2]);
  double get scaleY => sqrt(matrix[1] * matrix[1] + matrix[3] * matrix[3]);

  /// Radians. Extracted from the matrix's first column, which is only a
  /// faithful rotation angle when the item isn't sheared - PureRef's normal
  /// rotate/resize gestures never introduce shear, so this covers the
  /// common case; a sheared matrix will produce a best-effort angle.
  double get rotationRadians => atan2(matrix[2], matrix[0]);

  double get unscaledWidth =>
      pointsX.isEmpty ? 0 : pointsX.reduce(max) - pointsX.reduce(min);
  double get unscaledHeight =>
      pointsY.isEmpty ? 0 : pointsY.reduce(max) - pointsY.reduce(min);

  double get width => unscaledWidth * scaleX;
  double get height => unscaledHeight * scaleY;

  /// True when [pointsX]/[pointsY] form the standard axis-aligned rectangle
  /// this format writes (5 points: 4 corners + a closing repeat of the
  /// first). A rotated/irregular crop polygon returns false - the importer
  /// treats that as "don't know how to crop this, import the full image."
  bool get isAxisAlignedRectangle {
    if (pointsX.length != 5 || pointsY.length != 5) return false;
    const epsilon = 0.001;
    final minX = pointsX.reduce(min);
    final maxX = pointsX.reduce(max);
    final minY = pointsY.reduce(min);
    final maxY = pointsY.reduce(max);
    final expectedX = [minX, maxX, maxX, minX, minX];
    final expectedY = [minY, minY, maxY, maxY, minY];
    for (var i = 0; i < 5; i++) {
      if ((pointsX[i] - expectedX[i]).abs() > epsilon) return false;
      if ((pointsY[i] - expectedY[i]).abs() > epsilon) return false;
    }
    return true;
  }
}

/// One embedded image and every place it's used on the canvas (usually one
/// transform, but the same image can be pasted more than once).
class PurImage {
  final Uint8List pngBytes;
  final List<PurImageItem> transforms;

  const PurImage({required this.pngBytes, required this.transforms});
}

/// The full contents of a parsed PureRef `.pur` (1.10/1.11.1 format) file.
class PurFile {
  final List<double> canvas;
  final double zoom;
  final int xCanvas;
  final int yCanvas;
  final String folderLocation;
  final List<PurImage> images;
  final List<PurTextItem> text;

  const PurFile({
    required this.canvas,
    required this.zoom,
    required this.xCanvas,
    required this.yCanvas,
    required this.folderLocation,
    required this.images,
    required this.text,
  });
}

/// Thrown when a file isn't a recognized old-format (1.10/1.11.1) `.pur`
/// file - including, deliberately, files saved by PureRef 2.0+, which
/// changed to an undocumented format this parser cannot read.
class PurFormatException implements Exception {
  final String message;
  const PurFormatException(this.message);

  @override
  String toString() => message;
}
