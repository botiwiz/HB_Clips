import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants.dart';

/// Decodes [bytes] and returns a board-space size preserving the image's
/// real aspect ratio, with its longer edge capped at [maxEdge] (matching
/// today's default single-clip footprint for a square image, so a square
/// screenshot's size is unchanged) and its shorter edge floored at
/// [minEdge] (matching `ClipGeometry.minClipSize`) so a very thin
/// banner-shaped image doesn't collapse to a sliver. Falls back to a
/// square [maxEdge] x [maxEdge] box if the bytes can't be decoded.
///
/// Works for animated GIFs too - `decodeImage` reads just the first frame,
/// whose dimensions match every other frame in the animation.
Size clipSizeForImageBytes(
  Uint8List bytes, {
  double maxEdge = kDefaultClipWidth,
  double minEdge = 40,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return Size(maxEdge, maxEdge);
  }

  final aspect = decoded.width / decoded.height;
  double width, height;
  if (aspect >= 1) {
    width = maxEdge;
    height = maxEdge / aspect;
  } else {
    height = maxEdge;
    width = maxEdge * aspect;
  }
  if (width < minEdge) width = minEdge;
  if (height < minEdge) height = minEdge;
  return Size(width, height);
}

/// The image's native aspect ratio (width/height), or null if it can't be
/// decoded - paired with [clipSizeForImageBytes] for callers that also need
/// to persist `imageAspectRatio` for the pan/zoom feature.
double? imageAspectRatioForBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    return null;
  }
  return decoded.width / decoded.height;
}
