import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

/// Samples the pixel color at [fractionalPoint] (0..1 of the image's native
/// pixel bounds) in the image file at [sourcePath], returning it as an
/// uppercase `#RRGGBB` hex string - the eyedropper tool's primitive. Returns
/// null if the file can't be decoded as an image.
Future<String?> sampleColorAt(
  String sourcePath,
  Offset fractionalPoint,
) async {
  final bytes = await File(sourcePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final x = (fractionalPoint.dx * decoded.width).round().clamp(
    0,
    decoded.width - 1,
  );
  final y = (fractionalPoint.dy * decoded.height).round().clamp(
    0,
    decoded.height - 1,
  );

  final pixel = decoded.getPixel(x, y);
  final r = pixel.r.toInt();
  final g = pixel.g.toInt();
  final b = pixel.b.toInt();
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}
