import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/clip.dart';
import '../../annotation/controllers/annotation_controller.dart'
    show kDefaultStrokeWidth;
import '../../annotation/stroke_painter.dart';
import '../controllers/board_controller.dart' show ImagePanZoomLive;
import '../geometry/highlight_geometry.dart';
import '../geometry/text_note_geometry.dart';
import '../geometry/text_style_ranges.dart';
import 'gif_playback_view.dart';
import 'highlight_painter.dart';
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
    // Images are the sole deliberate exception to this app's otherwise-
    // sharp corner design - see `kImageCornerRadius`'s doc comment.
    final cardRadius = clip.type == ClipType.image
        ? kImageCornerRadius
        : kCornerRadius;
    return Opacity(
      opacity: clip.opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          border: selected
              ? Border.all(color: AppTheme.red, width: 1.0)
              : (isShape || clip.type == ClipType.text
                    ? null
                    : Border.all(color: AppTheme.border, width: 1)),
          boxShadow: (isShape || clip.type == ClipType.text)
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
            borderRadius: BorderRadius.circular(cardRadius),
            clipBehavior: Clip.antiAlias,
            child: _buildImage(),
          ),
          ClipType.text => _buildText(),
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
    final baseStyle = TextNoteGeometry.baseStyle(
      fontSize: (clip.fontSize ?? kTextNoteFontSize) * viewScale,
      color: AppTheme.textNoteText,
    );
    final text = clip.textContent ?? '';
    final formatting = clip.textFormatting;
    final innerWidth = (clip.width - 2 * kTextNotePadding) * viewScale;
    // The live editor's real TextField wraps text kTextCaretReservedWidth
    // narrower than innerWidth (its RenderEditable reserves that margin
    // for the cursor - see that constant's doc comment). Text.rich/
    // RenderParagraph has no such reservation, so without this same
    // correction here, this static render would wrap a line later than
    // the live editor does - the same content producing a different line
    // count (and so a different box shape/position) depending on whether
    // the note is being edited, which read as the text "jumping" when
    // entering/exiting edit mode. Constraining Text.rich itself to this
    // narrower width (not just HighlightGeometry's rects below) is what
    // makes the two agree.
    final contentWidth = innerWidth > kTextCaretReservedWidth
        ? innerWidth - kTextCaretReservedWidth
        : innerWidth;
    final highlightRects = HighlightGeometry.rectsFor(
      text: text,
      formatting: formatting,
      baseStyle: baseStyle,
      width: contentWidth,
      cornerRadius: kHighlightCornerRadius * viewScale,
    );
    return Padding(
      padding: EdgeInsets.all(kTextNotePadding * viewScale),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (highlightRects.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: HighlightPainter(
                  rects: highlightRects,
                  color: hexToColor(
                    clip.highlightColorHex ?? kDefaultHighlightColorHex,
                  ),
                ),
              ),
            ),
          // A Positioned (not a bare Stack child) so its explicit width
          // survives this Stack's StackFit.expand - a non-positioned
          // child would otherwise be forced to the Stack's full size,
          // overriding contentWidth entirely.
          Positioned(
            left: 0,
            top: 0,
            width: contentWidth,
            child: Text.rich(
              TextSpan(
                children: TextStyleRanges.buildSpans(
                  text,
                  formatting,
                  baseStyle,
                ),
              ),
              textScaler: TextScaler.noScaling,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
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
