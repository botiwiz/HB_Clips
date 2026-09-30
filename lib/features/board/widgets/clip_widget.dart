import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import '../geometry/text_style_ranges.dart';
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

  /// The caller's already-resolved effective scale (board-view zoom,
  /// unless the clip's "constant size" toggle pins it to a different
  /// value - see `board_canvas.dart._positionedClip`), so a text clip's
  /// font renders at a world-space size (`kTextNoteFontSize * viewScale`)
  /// like every other clip's content, instead of a constant screen size
  /// regardless of zoom. Unused for image clips.
  final double viewScale;

  const ClipWidget({
    super.key,
    required this.clip,
    required this.selected,
    required this.viewScale,
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
        // antiAliasWithSaveLayer (not the plain antiAlias default) - image
        // content is painted via its own compositing layer (Image/RawImage,
        // especially the GIF playback path's texture-backed frames), and a
        // plain canvas clipPath doesn't reliably constrain a child's own
        // layer to the rounded shape, so the image's square corners could
        // paint right over the rounded red selection border instead of
        // being clipped to match it. The extra offscreen composite this
        // costs is bounded to the handful of clips on screen at once.
        clipBehavior: Clip.antiAliasWithSaveLayer,
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
    // Note: [viewScale] is the caller's already-resolved effective scale -
    // `clip.sizeLockScale ?? view.scale` - not necessarily the board's raw
    // live zoom (see `board_canvas.dart._positionedClip`'s "constant size"
    // toggle handling), so the box and its font always agree on how big to
    // render regardless of which one is in effect.
    final baseStyle = TextStyle(
      color: AppTheme.textNoteText,
      fontSize: (clip.fontSize ?? kTextNoteFontSize) * viewScale,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text.rich(
        TextSpan(
          children: TextStyleRanges.buildSpans(
            clip.textContent ?? '',
            clip.textFormatting,
            baseStyle,
          ),
        ),
      ),
    );
  }
}
