import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import 'gif_playback_view.dart';
import 'image_pan_zoom_frame.dart';
import 'local_image.dart';

/// Renders one clip's content (image or text note) at its given size. The
/// caller (`BoardCanvas`) is responsible for positioning this via
/// `Positioned` in board space - this widget just draws the card itself.
class ClipWidget extends StatelessWidget {
  final BoardClip clip;
  final bool selected;

  /// Live pan/zoom override while a drag/wheel-zoom gesture is in
  /// progress for this clip - null otherwise, in which case the clip's
  /// own persisted `imagePanX/Y`/`imageZoom` are used. Computed externally
  /// by `BoardCanvas` (same convention `groupDragProvider` already uses for
  /// position/size), not watched by this widget directly.
  final ImagePanZoomLive? panZoomLive;

  const ClipWidget({
    super.key,
    required this.clip,
    required this.selected,
    this.panZoomLive,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: clip.opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.red : AppTheme.border,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          color: clip.type == ClipType.text
              ? (clip.backgroundColorHex != null
                    ? hexToColor(clip.backgroundColorHex!)
                    : AppTheme.textNoteSurface)
              : AppTheme.surfaceCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: clip.type == ClipType.image ? _buildImage() : _buildText(),
      ),
    );
  }

  Widget _buildImage() {
    final path = clip.localFilePath;
    if (path == null) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppTheme.textDisabled,
        ),
      );
    }
    if (selected && path.toLowerCase().endsWith('.gif')) {
      return GifPlaybackView(clipId: clip.id, path: path, clip: clip, panZoomLive: panZoomLive);
    }
    return ImagePanZoomFrame(
      clip: clip,
      live: panZoomLive,
      imageBuilder: (width, height) => LocalImage(
        path: path,
        fit: BoxFit.fill,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppTheme.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _buildText() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        clip.textContent ?? '',
        style: const TextStyle(
          color: AppTheme.textNoteText,
          fontSize: 14,
          height: 1.3,
        ),
      ),
    );
  }
}
