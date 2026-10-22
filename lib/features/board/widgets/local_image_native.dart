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
      errorBuilder: errorBuilder,
    );
  }
}
