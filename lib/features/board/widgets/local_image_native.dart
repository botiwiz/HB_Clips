import 'dart:io';

import 'package:flutter/widgets.dart';

/// Native: [path] is a real filesystem path - unchanged `Image.file`
/// behavior from before this abstraction existed.
class LocalImage extends StatelessWidget {
  final String path;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const LocalImage({
    super.key,
    required this.path,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
