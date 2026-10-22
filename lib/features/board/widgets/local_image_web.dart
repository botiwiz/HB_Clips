import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';

/// Small in-memory cache so repeated rebuilds of the same clip don't
/// re-hit IndexedDB on every frame - only the first build for a given key
/// goes through the async `FutureBuilder` path below.
final _cache = <String, Uint8List>{};

/// Web: [path] is an opaque `LocalBlobStore` key, not a real path - bytes
/// are read from the local-only Drift-backed blob store and rendered via
/// `Image.memory`.
class LocalImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = _cache[path];
    if (cached != null) {
      return Image.memory(
        cached,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: errorBuilder,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: ref.read(localBlobStoreProvider).readBytes(path).then((bytes) {
        if (bytes != null) _cache[path] = bytes;
        return bytes;
      }),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return SizedBox(width: width, height: height);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          gaplessPlayback: true,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}
