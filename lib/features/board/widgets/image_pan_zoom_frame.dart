import 'package:flutter/material.dart';

import '../../../data/models/clip.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import '../geometry/image_pan_zoom_geometry.dart';

/// Wraps an image-content builder with the pan/zoom framing math shared by
/// `ClipWidget` and `GifPlaybackView` - both display an image clip's
/// content and need identical `OverflowBox`/`Alignment` composition so a
/// clip looks the same whether or not its GIF is currently animating.
/// [imageBuilder] receives the image content's exact final size (already
/// scaled by cover-fit + zoom) and must fill it exactly - this widget
/// handles positioning/clamping via `OverflowBox`, not the image itself.
class ImagePanZoomFrame extends StatelessWidget {
  final BoardClip clip;
  final ImagePanZoomLive? live;
  final Widget Function(double width, double height) imageBuilder;

  const ImagePanZoomFrame({
    super.key,
    required this.clip,
    required this.imageBuilder,
    this.live,
  });

  @override
  Widget build(BuildContext context) {
    final panX = live?.panX ?? clip.imagePanX;
    final panY = live?.panY ?? clip.imagePanY;
    final zoom = ImagePanZoomGeometry.clampZoom(live?.zoom ?? clip.imageZoom);
    final r = clip.imageAspectRatio ?? (clip.width / clip.height);

    // Sized from this widget's *actual* layout constraints, not clip.width/
    // clip.height directly - those lag behind during a live resize/scale
    // drag (the clip object here is always the last-committed DB value;
    // the box this widget is actually laid out in already reflects the
    // in-progress drag via the caller's own live-preview positioning).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cover = ImagePanZoomGeometry.coverSize(
          constraints.maxWidth,
          constraints.maxHeight,
          r,
        );
        final scaled = ImagePanZoomGeometry.scaledSize(cover, zoom);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment(panX, panY),
            minWidth: scaled.width,
            maxWidth: scaled.width,
            minHeight: scaled.height,
            maxHeight: scaled.height,
            child: imageBuilder(scaled.width, scaled.height),
          ),
        );
      },
    );
  }
}
