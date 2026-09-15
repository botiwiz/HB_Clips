import 'package:flutter/widgets.dart';

/// Fallback for a platform that is neither `dart.library.ffi` (native) nor
/// `dart.library.js_interop` (web) - should never actually be selected in
/// this app, but conditional exports require a default target.
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
    throw UnsupportedError('LocalImage is not supported on this platform');
  }
}
