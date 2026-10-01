import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/controllers/annotation_controller.dart'
    show kDefaultStrokeWidth;
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import '../geometry/text_style_ranges.dart';
import 'gif_playback_view.dart';
import 'image_pan_zoom_frame.dart';
import 'local_image.dart';
import 'shape_painter.dart';

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
    // A shape clip draws its own outline/fill (see `_buildShape`) - it
    // skips the generic card chrome (rounded corners, shadow, filled
    // background) every other clip type gets, so it isn't double-bordered.
    // The selected-border rule stays universal: it's the only selection
    // cue for a multi-select (`SelectionHandles` only draws resize/rotate
    // handles for a single selection), so every clip type - shapes
    // included - must keep it.
    final isShape = clip.type == ClipType.shape;
    return Opacity(
      opacity: clip.opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: isShape ? BorderRadius.zero : BorderRadius.circular(10),
          border: selected
              ? Border.all(color: AppTheme.red, width: 2.5)
              : (isShape ? null : Border.all(color: AppTheme.border, width: 1)),
          boxShadow: isShape
              ? null
              : const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
          color: isShape
              ? null
              : (clip.type == ClipType.text
                    ? (clip.backgroundColorHex != null
                          ? hexToColor(clip.backgroundColorHex!)
                          : AppTheme.textNoteSurface)
                    : AppTheme.surfaceCard),
        ),
        child: switch (clip.type) {
          ClipType.image => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: _buildImage(),
          ),
          ClipType.text => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: _buildText(),
          ),
          ClipType.shape => _buildShape(),
        },
      ),
    );
  }

  Widget _buildImage() {
    final path = clip.localFilePath;
    if (path == null) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: AppTheme.textDisabled),
      );
    }
    if (selected && path.toLowerCase().endsWith('.gif')) {
      return GifPlaybackView(
        clipId: clip.id,
        path: path,
        clip: clip,
        panZoomLive: panZoomLive,
      );
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
      padding: EdgeInsets.symmetric(
        horizontal: kTextNoteHorizontalPadding * viewScale,
        vertical: kTextNoteVerticalPadding * viewScale,
      ),
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

  Widget _buildShape() {
    return CustomPaint(
      size: Size.infinite,
      painter: ShapePainter(
        kind: clip.shapeKind ?? ShapeKind.rectangle,
        fillColor: clip.shapeFillColorHex != null
            ? hexToColor(clip.shapeFillColorHex!)
            : null,
        strokeColor: clip.shapeStrokeColorHex != null
            ? hexToColor(clip.shapeStrokeColorHex!)
            : AppTheme.border,
        strokeWidth: clip.shapeStrokeWidth ?? kDefaultStrokeWidth,
      ),
    );
  }
}
