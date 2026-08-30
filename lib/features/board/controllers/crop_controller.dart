import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the crop tool is active for the sole selected image clip.
final isCropModeProvider = StateProvider<bool>((ref) => false);

/// The in-progress crop rectangle, fractional (0..1) within the clip's own
/// local (unrotated) width/height. Seeded to the full rect on entering crop
/// mode; null when crop mode isn't active.
final cropRectProvider = StateProvider<Rect?>((ref) => null);
