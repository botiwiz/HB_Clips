/// Pure math for picking an image's `cacheWidth`/`cacheHeight` decode
/// resolution - no widget imports, unit-testable the same way
/// `selection_geometry.dart` is. See `clip_widget.dart`'s `_buildImage`,
/// the only caller.
class ImageCacheSizing {
  ImageCacheSizing._();

  static const int bucket = 64;

  /// A sane decode-resolution cap used when the image's own native pixel
  /// size isn't cheaply known at the call site - never requested unless
  /// [nativeSize] narrows it further.
  static const int defaultCeiling = 4096;

  /// Target decode pixels for an image shown at [logicalSize] on-screen
  /// logical pixels (already reflecting the current pan/zoom - see
  /// `ImagePanZoomFrame`'s own doc comment on its `imageBuilder` callback)
  /// at [devicePixelRatio] - rounded *up* to the nearest [bucket] px so
  /// small/continuous zoom changes reuse the same cached decode instead of
  /// forcing a redecode on every zoom tick; only a zoom change large
  /// enough to cross a bucket boundary triggers a new decode. Clamped to
  /// [nativeSize] when known (never request more than the source has),
  /// otherwise to [defaultCeiling].
  static int quantize(
    double logicalSize,
    double devicePixelRatio, {
    int? nativeSize,
  }) {
    final target = logicalSize * devicePixelRatio;
    final bucketed = ((target / bucket).ceil() * bucket).clamp(
      bucket,
      defaultCeiling,
    );
    if (nativeSize != null && nativeSize > 0 && bucketed > nativeSize) {
      return nativeSize;
    }
    return bucketed;
  }
}
