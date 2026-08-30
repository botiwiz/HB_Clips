import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

/// Result of cropping an image file to a fractional rect.
class ImageCropResult {
  final Uint8List pngBytes;
  final int width;
  final int height;

  const ImageCropResult({
    required this.pngBytes,
    required this.width,
    required this.height,
  });
}

/// Crops the image at [sourcePath] to [fractionalRect] (0..1 of its native
/// pixel bounds), returning re-encoded PNG bytes and the cropped pixel
/// dimensions - shared by the interactive crop tool and mirrors the
/// equivalent inline crop logic in `pureref_import_service.dart`. Returns
/// null if the file can't be decoded as an image.
Future<ImageCropResult?> cropImageFile(
  String sourcePath,
  Rect fractionalRect,
) async {
  final bytes = await File(sourcePath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final left = (fractionalRect.left * decoded.width).round().clamp(
    0,
    decoded.width - 1,
  );
  final top = (fractionalRect.top * decoded.height).round().clamp(
    0,
    decoded.height - 1,
  );
  final right = (fractionalRect.right * decoded.width).round().clamp(
    left + 1,
    decoded.width,
  );
  final bottom = (fractionalRect.bottom * decoded.height).round().clamp(
    top + 1,
    decoded.height,
  );

  final cropped = img.copyCrop(
    decoded,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );

  return ImageCropResult(
    pngBytes: img.encodePng(cropped),
    width: cropped.width,
    height: cropped.height,
  );
}
