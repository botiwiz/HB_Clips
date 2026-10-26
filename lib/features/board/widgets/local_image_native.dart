import 'dart:io';

import 'package:flutter/widgets.dart';

/// Native: [path] is a real filesystem path - unchanged `Image.file`
/// behavior from before this abstraction existed.
class LocalImage extends StatelessWidget {
  final String path;
  final BoxFit? fit;
  final double? width;
  final double? height;

  /// Decode-resolution hint, in physical pixels - see `ImageCacheSizing`,
  /// the only place these are computed. Null skips the hint (full-
  /// resolution decode), used by callers with no size to go on (e.g. no
  /// on-screen width/height known yet).
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const LocalImage({
    super.key,
    required this.path,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      // Every cacheWidth/cacheHeight bucket crossing during a zoom (see
      // ImageCacheSizing.quantize) is a genuinely new decode as far as
      // Flutter's ImageProvider is concerned, even though it's the same
      // source file - without this, the frame goes blank for the instant
      // between the old decode being dropped and the new one finishing,
      // which reads as the image "reloading"/breaking on every zoom step.
      // Keeping the last good frame visible until the new one is ready
      // makes repeated zooming look seamless instead. Matches
      // local_image_web.dart's own Image.memory calls, which already set
      // this.
      gaplessPlayback: true,
      errorBuilder: errorBuilder,
    );
  }
}
