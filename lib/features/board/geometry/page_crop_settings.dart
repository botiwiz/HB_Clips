import 'package:flutter/rendering.dart';

import 'image_pan_zoom_geometry.dart';

/// Per-page zoom/pan for the PDF-export crop wizard - a page's whole
/// content block (a frame's rect, or the overview's loose-clip bounding
/// box) being cover-fit and cropped into one fixed export page size. A
/// deliberately SEPARATE concept from `BoardClip.imageZoom`/`imagePanX`/
/// `imagePanY` (one clip's own crop inside its own box) - same field
/// semantics/representation (zoom clamped via
/// `ImagePanZoomGeometry.clampZoom`, pan as a Flutter-`Alignment`-style
/// -1..1 per axis, 0 = centered) purely so the two features are built
/// from the same math and feel identical to use - never conflate the two.
class PageCropSettings {
  final double zoom;
  final double panX;
  final double panY;

  const PageCropSettings({this.zoom = 1.0, this.panX = 0.0, this.panY = 0.0});

  static const PageCropSettings initial = PageCropSettings();

  PageCropSettings copyWith({double? zoom, double? panX, double? panY}) =>
      PageCropSettings(
        zoom: zoom ?? this.zoom,
        panX: panX ?? this.panX,
        panY: panY ?? this.panY,
      );
}

/// Reserved key for the loose-clips "overview" page's entry in a
/// `Map<String, PageCropSettings>` keyed by frame id everywhere else -
/// safe since frame ids (uuid-generated) never collide with this literal.
const String kOverviewPageCropKey = '__overview__';

/// Page-crop zoom has no minimum or maximum, unlike per-image crop
/// (`ImagePanZoomGeometry.clampZoom`, floored at 1.0 so an image always
/// covers its frame) - a page's content block should be free to shrink
/// below cover-fit (showing empty margin so nothing gets cropped off,
/// entirely the user's own choice) or zoom in arbitrarily far. The only
/// floor here is a tiny positive epsilon, purely to keep the
/// cover/scale math well-defined - not a UX-chosen limit.
double clampPageCropZoom(double zoom) => zoom < 0.001 ? 0.001 : zoom;

/// Page-crop-specific analog of `ImagePanZoomGeometry.applyPanDelta`
/// using the RAW (signed, possibly negative) per-axis overflow instead
/// of the floored-at-0 `ImagePanZoomGeometry.overflow` - necessary
/// because a page's content block can now be smaller than the page
/// (see `clampPageCropZoom`'s own doc comment), in which case flooring
/// would freeze that axis's pan even though there's a well-defined
/// "fraction across the visible window" to drag across. Produces the
/// exact same panX/panY as `applyPanDelta` whenever [rawOverflow] is
/// already >= 0 (every case reachable before this feature could zoom
/// below cover-fit). An axis whose `rawOverflow` is exactly 0 is left
/// unchanged for that one frame - a pure divide-by-zero guard, not a
/// UX gate (contrast with `applyPanDelta`'s `> 0` gate, which
/// deliberately disables panning across a whole axis whenever there's
/// no overflow - wrong here, since a negative rawOverflow still has a
/// perfectly well-defined pan range).
Offset applyPageCropPanDelta(
  Offset startPan,
  Offset localDelta,
  Offset rawOverflow,
) {
  var panX = startPan.dx;
  var panY = startPan.dy;
  if (rawOverflow.dx != 0) {
    panX = (panX - 2 * localDelta.dx / rawOverflow.dx).clamp(-1.0, 1.0);
  }
  if (rawOverflow.dy != 0) {
    panY = (panY - 2 * localDelta.dy / rawOverflow.dy).clamp(-1.0, 1.0);
  }
  return Offset(panX, panY);
}

/// New pan (`panX`/`panY`) that keeps whatever content point sits under
/// [pointerPageSpace] (page-space pixels - the same space
/// `_PageCropEditorState._handleMove`'s `localDelta` already operates
/// in, i.e. `event.localPosition * previewToPageScale`) under the
/// pointer after zooming from [oldZoom] to [newZoom] - standard
/// "zoom toward cursor" behavior. [cover]/[pageSize] are the same
/// cover-fit/page values `_PageCropEditorState` already computes.
///
/// Mirrors the `visibleLeft`/`visibleTop` formula `pdf_writer.dart`/
/// `_PageCropEditorState` already use, solved for panX/panY instead:
/// computes the fraction of the OLD scaled content under the pointer,
/// then finds the panX/panY placing that same fraction of the NEW
/// scaled content back under the (unchanged) pointer. Clamped to
/// [-1, 1] - the full meaningful pan range either way; right at the
/// pan edges the cursor may not track exactly (nowhere further to
/// pan), matching every other interactive zoom-toward-cursor UI. An
/// axis whose scaled size is exactly 0 at [oldZoom] falls back to
/// treating the pointer as centered (`frac = 0.5`); an axis whose raw
/// overflow is exactly 0 at [newZoom] leaves that axis's pan
/// unchanged for that one frame - both pure divide-by-zero guards,
/// measure-zero in practice.
Offset zoomPageCropTowardPoint({
  required PageCropSettings crop,
  required double oldZoom,
  required double newZoom,
  required Offset pointerPageSpace,
  required Size cover,
  required Size pageSize,
}) {
  final oldScaled = ImagePanZoomGeometry.scaledSize(cover, oldZoom);
  final oldRawOverflowX = oldScaled.width - pageSize.width;
  final oldRawOverflowY = oldScaled.height - pageSize.height;
  final oldRenderedLeft = -(oldRawOverflowX / 2) * (1 + crop.panX);
  final oldRenderedTop = -(oldRawOverflowY / 2) * (1 + crop.panY);

  final fracX = oldScaled.width == 0
      ? 0.5
      : (pointerPageSpace.dx - oldRenderedLeft) / oldScaled.width;
  final fracY = oldScaled.height == 0
      ? 0.5
      : (pointerPageSpace.dy - oldRenderedTop) / oldScaled.height;

  final newScaled = ImagePanZoomGeometry.scaledSize(cover, newZoom);
  final newRenderedLeft = pointerPageSpace.dx - fracX * newScaled.width;
  final newRenderedTop = pointerPageSpace.dy - fracY * newScaled.height;

  final newRawOverflowX = newScaled.width - pageSize.width;
  final newRawOverflowY = newScaled.height - pageSize.height;

  final panX = newRawOverflowX == 0
      ? crop.panX
      : ((2 * -newRenderedLeft / newRawOverflowX) - 1).clamp(-1.0, 1.0);
  final panY = newRawOverflowY == 0
      ? crop.panY
      : ((2 * -newRenderedTop / newRawOverflowY) - 1).clamp(-1.0, 1.0);

  return Offset(panX, panY);
}
