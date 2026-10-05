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
