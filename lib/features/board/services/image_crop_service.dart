import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

/// Result of cropping an image to a fractional rect.
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

/// Crops [sourceBytes] to [fractionalRect] (0..1 of its native pixel
/// bounds), returning re-encoded PNG bytes and the cropped pixel
/// dimensions - shared by the interactive crop tool and mirrors the
/// equivalent inline crop logic in `pureref_import_service.dart`. Returns
/// null if the bytes can't be decoded as an image. Operates on raw bytes
/// (not a file path) so it works unchanged on web, where callers read
/// bytes via `LocalBlobStore` instead of `dart:io`.
Future<ImageCropResult?> cropImageFile(
  Uint8List sourceBytes,
  Rect fractionalRect,
) async {
  final decoded = img.decodeImage(sourceBytes);
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
