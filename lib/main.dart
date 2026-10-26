import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter's default ImageCache (1000 entries / 100MB) is easily
  // exhausted by an image-heavy board: ImageCacheSizing.quantize gives
  // each source image several distinct decode variants as its on-screen
  // size crosses bucket boundaries during a zoom, and a board can easily
  // hold far more than 1000 photos. Once the cache is full, scrolling
  // back to an already-seen image re-decodes it from scratch instead of
  // reusing the cached frame - the exact "renders slower as the board
  // fills up" symptom. Raised generously for a desktop app with no tight
  // memory budget; this is a cache ceiling; it only fills up if the board
  // actually calls for it.
  PaintingBinding.instance.imageCache.maximumSize = 4000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 512 << 20;

  runApp(const ProviderScope(child: HbClipsApp()));
}
