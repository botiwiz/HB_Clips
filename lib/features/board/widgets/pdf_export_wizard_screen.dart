import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;

import '../../../core/constants.dart' show kBoardGridSpacing;
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database.dart' show FrameRow;
import '../../../data/models/clip.dart';
import '../../../data/models/connector.dart';
import '../../annotation/stroke_painter.dart' show hexToColor;
import '../geometry/connector_geometry.dart';
import '../geometry/frame_geometry.dart';
import '../geometry/frame_presets.dart';
import '../geometry/image_pan_zoom_geometry.dart';
import '../geometry/page_crop_settings.dart';
import '../geometry/pdf_export_selection.dart';
import '../geometry/selection_geometry.dart';
import 'clip_widget.dart';
import 'connector_painter.dart';

/// Extra "bleed" margin shown around the page's own edges in the live
/// crop preview, as a fraction of the page's own width/height per side
/// - a fixed VIEWPORT overscan computed purely from pageSize (never
/// from zoom/content/aspect ratio), so it's always present regardless
/// of preset/orientation or how the crop is currently zoomed/panned -
/// lets the user see exactly what bleeds past the real export boundary
/// (marked by [_CropMarksOverlay]'s red rectangle). Tunable by eye once
/// seen live.
const double _kCropMarkBleedFraction = 0.25;

/// Result of the export wizard - the resolution preset/orientation chosen
/// once for the whole export, plus each page's committed pan/zoom crop.
/// `null` (returned by [PdfExportWizardScreen]'s own `Navigator.pop()`,
/// not this class) means the user cancelled.
class ExportWizardResult {
  final FramePreset preset;
  final bool landscape;
  final Map<String, PageCropSettings> pageCrops;
  const ExportWizardResult({
    required this.preset,
    required this.landscape,
    required this.pageCrops,
  });
}

/// Full-screen export wizard: pick a resolution/orientation once for the
/// whole export, then adjust each page's pan/zoom crop with a live
/// preview before committing. A full screen (not a dialog) because N
/// independent scroll-to-zoom/drag-to-pan gesture regions - one per page
/// - need real screen space.
class PdfExportWizardScreen extends StatefulWidget {
  final PdfExportSelection selection;
  const PdfExportWizardScreen({super.key, required this.selection});

  @override
  State<PdfExportWizardScreen> createState() => _PdfExportWizardScreenState();
}

class _PdfExportWizardScreenState extends State<PdfExportWizardScreen> {
  FramePreset _preset = kFramePresets.first;
  bool _landscape = false;
  final Map<String, PageCropSettings> _pageCrops = {};

  Size get _pageSize {
    final w = _landscape ? _preset.height : _preset.width;
    final h = _landscape ? _preset.width : _preset.height;
    return Size(w, h);
  }

  PageCropSettings _cropFor(String key) =>
      _pageCrops[key] ?? PageCropSettings.initial;

  void _setCrop(String key, PageCropSettings value) =>
      setState(() => _pageCrops[key] = value);

  // The connectors among widget.selection.connectors whose BOTH endpoint
  // clips are present in [pageClips] - mirrors pdf_writer.dart's own
  // per-page relevantConnectors filter exactly, so the wizard's live
  // preview always shows exactly what the final export will.
  List<Connector> _connectorsFor(List<BoardClip> pageClips) {
    final ids = pageClips.map((c) => c.id).toSet();
    return widget.selection.connectors
        .where((c) => ids.contains(c.fromClipId) && ids.contains(c.toClipId))
        .toList();
  }

  _PageCropSection _frameSection(FrameRow frame, double previewMaxHeight) {
    final frameClips =
        widget.selection.clips.where((c) => c.frameId == frame.id).toList()
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return _PageCropSection(
      label: frame.name,
      pageSize: _pageSize,
      contentRect: FrameGeometry.boardRect(frame),
      clips: frameClips,
      connectors: _connectorsFor(frameClips),
      backgroundColorHex: frame.backgroundColorHex,
      crop: _cropFor(frame.id),
      onChanged: (c) => _setCrop(frame.id, c),
      previewMaxHeight: previewMaxHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final looseClips = widget.selection.clips
        .where((c) => c.frameId == null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Export settings')),
      body: Column(
        children: [
          _PresetPicker(
            preset: _preset,
            landscape: _landscape,
            onPresetChanged: (p) => setState(() => _preset = p),
            onLandscapeChanged: (v) => setState(() => _landscape = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewMaxHeight =
                    (constraints.maxHeight - _kPageCropChromeAllowance).clamp(
                      200.0,
                      double.infinity,
                    );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (looseClips.isNotEmpty)
                      _PageCropSection(
                        label: 'Overview',
                        pageSize: _pageSize,
                        contentRect: ClipGeometry.boardBoundingBox(looseClips),
                        clips: looseClips,
                        connectors: _connectorsFor(looseClips),
                        backgroundColorHex: null,
                        crop: _cropFor(kOverviewPageCropKey),
                        onChanged: (c) => _setCrop(kOverviewPageCropKey, c),
                        previewMaxHeight: previewMaxHeight,
                      ),
                    for (final frame in widget.selection.frames)
                      _frameSection(frame, previewMaxHeight),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(
              ExportWizardResult(
                preset: _preset,
                landscape: _landscape,
                pageCrops: Map.of(_pageCrops),
              ),
            ),
            child: const Text('Export'),
          ),
        ),
      ),
    );
  }
}

/// The resolution/orientation picker - today's `_pickExportSettings`
/// dialog body, shown once at the top of the wizard instead of in a
/// dialog, driven by callbacks instead of a dialog's local `setState`.
class _PresetPicker extends StatelessWidget {
  final FramePreset preset;
  final bool landscape;
  final ValueChanged<FramePreset> onPresetChanged;
  final ValueChanged<bool> onLandscapeChanged;

  const _PresetPicker({
    required this.preset,
    required this.landscape,
    required this.onPresetChanged,
    required this.onLandscapeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final p in kFramePresets)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == preset,
                    onSelected: (_) => onPresetChanged(p),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Landscape'),
              Switch(value: landscape, onChanged: onLandscapeChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chrome reserved around a page's crop preview that
/// [_PdfExportWizardScreenState.build]'s `LayoutBuilder` must subtract
/// from the available list height to compute each section's actual
/// preview budget: the ListView's own top+bottom padding (16+16), a
/// section's own label height (~24), the label-to-preview gap (8), and
/// a section's own bottom padding (24) - everything `_PageCropSection`/
/// the ListView already reserve around the preview itself, so
/// `previewMaxHeight` uses exactly what's actually left over, not a
/// guessed constant.
const double _kPageCropChromeAllowance = 32 + 24 + 8 + 24;

/// One scrollable list item: a page's label plus its fixed-aspect crop
/// preview/editor box.
class _PageCropSection extends StatelessWidget {
  final String label;
  final Size pageSize;
  final Rect contentRect;
  final List<BoardClip> clips;
  final List<Connector> connectors;
  final String? backgroundColorHex;
  final PageCropSettings crop;
  final ValueChanged<PageCropSettings> onChanged;
  final double previewMaxHeight;

  const _PageCropSection({
    required this.label,
    required this.pageSize,
    required this.contentRect,
    required this.clips,
    required this.connectors,
    required this.backgroundColorHex,
    required this.crop,
    required this.onChanged,
    required this.previewMaxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: previewMaxHeight),
            child: Center(
              child: AspectRatio(
                aspectRatio: pageSize.width / pageSize.height,
                child: _PageCropEditor(
                  pageSize: pageSize,
                  contentSize: contentRect.size,
                  contentOrigin: contentRect.topLeft,
                  clips: clips,
                  connectors: connectors,
                  backgroundColorHex: backgroundColorHex,
                  crop: crop,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gesture-and-render widget for one page's crop: cover-fits the
/// page's content block into [pageSize] via [ImagePanZoomGeometry] (the
/// same math/representation the existing per-image crop tool uses, just
/// applied to a whole page's content instead of one image), with
/// Ctrl/Cmd+scroll-to-zoom (a plain scroll instead passes through to
/// the wizard's own scrollable page, so a tall crop box never traps the
/// mouse wheel) and drag-to-pan mirroring `board_canvas.dart`'s
/// existing per-image pan/zoom gesture handling.
class _PageCropEditor extends StatefulWidget {
  final Size pageSize;
  final Size contentSize;
  final Offset contentOrigin;
  final List<BoardClip> clips;
  final List<Connector> connectors;
  final String? backgroundColorHex;
  final PageCropSettings crop;
  final ValueChanged<PageCropSettings> onChanged;

  const _PageCropEditor({
    required this.pageSize,
    required this.contentSize,
    required this.contentOrigin,
    required this.clips,
    required this.connectors,
    required this.backgroundColorHex,
    required this.crop,
    required this.onChanged,
  });

  @override
  State<_PageCropEditor> createState() => _PageCropEditorState();
}

class _PageCropEditorState extends State<_PageCropEditor> {
  Offset? _dragStartLocal;
  Offset? _dragStartPan;
  bool _dragIsMiddleButton = false;

  double get _r => widget.contentSize.width / widget.contentSize.height;

  Size get _cover => ImagePanZoomGeometry.coverSize(
    widget.pageSize.width,
    widget.pageSize.height,
    _r,
  );

  // No min/max clamp here, unlike per-image crop - see
  // clampPageCropZoom's own doc comment.
  Size get _scaled => ImagePanZoomGeometry.scaledSize(
    _cover,
    clampPageCropZoom(widget.crop.zoom),
  );

  // Raw, possibly-negative per-axis overflow - replaces the floored
  // ImagePanZoomGeometry.overflow (correct for per-image crop, where
  // zoom never drops below 1.0, but wrong here once content can shrink
  // below the page) - feeds applyPageCropPanDelta.
  Offset get _rawOverflow => Offset(
    _scaled.width - widget.pageSize.width,
    _scaled.height - widget.pageSize.height,
  );

  // The page-space scale factor the content block is actually rendered
  // at - same role as pdf_writer.dart's own `scale` local in the
  // `needsFit` branch.
  double get _scaleFactor => _scaled.width / widget.contentSize.width;

  // Raw, possibly-negative overflow (not the floored _overflow above,
  // which is correct for OverflowBox's own alignment math but would be
  // wrong for computing the visible board-space window once zoom can
  // shrink content below the page's own size) - mirrors pdf_writer
  // .dart's own visibleLeft/visibleTop exactly.
  double get _visibleLeft =>
      ((_scaled.width - widget.pageSize.width) / 2) * (1 + widget.crop.panX);
  double get _visibleTop =>
      ((_scaled.height - widget.pageSize.height) / 2) * (1 + widget.crop.panY);

  // The bigger "canvas" rendered in place of the page itself, so the
  // crop marks overlay always has a visible bleed margin around the
  // real export boundary - see _kCropMarkBleedFraction's own doc
  // comment. Scaled uniformly on both axes, so its aspect ratio always
  // matches pageSize's own exactly - _PageCropSection's outer
  // AspectRatio wrapper needs no change.
  Size get _canvasSize => Size(
    widget.pageSize.width * (1 + 2 * _kCropMarkBleedFraction),
    widget.pageSize.height * (1 + 2 * _kCropMarkBleedFraction),
  );

  // Where the page's own top-left corner sits within the bigger canvas
  // - symmetric on both axes (verified algebraically: canvasSize.width
  // - pageOffset.dx - pageSize.width == pageOffset.dx), so the page
  // rect is always exactly centered in the canvas.
  Offset get _pageOffsetInCanvas => Offset(
    widget.pageSize.width * _kCropMarkBleedFraction,
    widget.pageSize.height * _kCropMarkBleedFraction,
  );

  // The full board-space window actually visible across the whole
  // CANVAS (not just the page) - the inverse of the transform
  // positioning the content below, shifted by _pageOffsetInCanvas so
  // the margin band's dot grid continues seamlessly past the red crop
  // mark too, not just past the content's own extent. Reduces to
  // pdf_writer.dart's own `visibleBoardRect` formula exactly when
  // _pageOffsetInCanvas is zero and _canvasSize equals pageSize (i.e.
  // with no bleed margin), so this is a strict generalization, not a
  // behavior change for the underlying crop math itself.
  Rect get _visibleBoardRect => Rect.fromLTWH(
    widget.contentOrigin.dx +
        (_visibleLeft - _pageOffsetInCanvas.dx) / _scaleFactor,
    widget.contentOrigin.dy +
        (_visibleTop - _pageOffsetInCanvas.dy) / _scaleFactor,
    _canvasSize.width / _scaleFactor,
    _canvasSize.height / _scaleFactor,
  );

  // Shared by both scroll gestures below - zooms by [factor] while
  // keeping [pointerPageSpace] (page-space coordinates) fixed under
  // that point. Plain scroll passes the live cursor position; Ctrl/Cmd+
  // scroll passes the page's own fixed center instead (see
  // _handleScaleFromMarqueeCenter), so both end up driving the exact
  // same underlying zoom/pan state through one code path.
  void _zoomBy(double factor, Offset pointerPageSpace) {
    final oldZoom = clampPageCropZoom(widget.crop.zoom);
    final newZoom = clampPageCropZoom(widget.crop.zoom * factor);
    final newPan = zoomPageCropTowardPoint(
      crop: widget.crop,
      oldZoom: oldZoom,
      newZoom: newZoom,
      pointerPageSpace: pointerPageSpace,
      cover: _cover,
      pageSize: widget.pageSize,
    );
    widget.onChanged(
      widget.crop.copyWith(zoom: newZoom, panX: newPan.dx, panY: newPan.dy),
    );
  }

  // Plain scroll - always zooms toward the cursor, no modifier needed.
  void _handleScroll(PointerScrollEvent event, double previewToCanvasScale) {
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    // Shifts from canvas-space (the widget's own on-screen rendering,
    // now bigger than the page by the bleed margin) into page-space
    // (origin at the page's own top-left) - the coordinate system
    // zoomPageCropTowardPoint/_visibleLeft/_visibleTop already use.
    final pointerPageSpace =
        event.localPosition * previewToCanvasScale - _pageOffsetInCanvas;
    _zoomBy(factor, pointerPageSpace);
  }

  // Ctrl/Cmd+scroll - "scale the marquee": anchored at the fixed center
  // of the page rect itself (not the cursor), so the crop grows/shrinks
  // symmetrically regardless of where the mouse happens to be.
  void _handleScaleFromMarqueeCenter(PointerScrollEvent event) {
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final pageCenter = Offset(
      widget.pageSize.width / 2,
      widget.pageSize.height / 2,
    );
    _zoomBy(factor, pageCenter);
  }

  void _handleDown(PointerDownEvent event) {
    _dragStartLocal = event.localPosition;
    _dragStartPan = Offset(widget.crop.panX, widget.crop.panY);
    // MMB ("pan the marquee") is the exact inverse of LMB ("pan the
    // content") - detected here so _handleMove knows whether to negate
    // the drag delta.
    _dragIsMiddleButton = event.buttons & kMiddleMouseButton != 0;
  }

  void _handleMove(PointerMoveEvent event, double previewToCanvasScale) {
    if (_dragStartLocal == null) return;
    // A delta of two event.localPosition samples - the canvas/page
    // offset is a constant that cancels out in the subtraction, so
    // only the (renamed) scale factor itself needs to change here.
    final rawDelta =
        (event.localPosition - _dragStartLocal!) * previewToCanvasScale;
    // MMB pans the marquee - the inverse of LMB panning the content -
    // same math, negated input delta, so the red rectangle reads as
    // the thing being dragged instead of the content under it.
    final localDelta = _dragIsMiddleButton ? -rawDelta : rawDelta;
    final newPan = applyPageCropPanDelta(
      _dragStartPan!,
      localDelta,
      _rawOverflow,
    );
    widget.onChanged(widget.crop.copyWith(panX: newPan.dx, panY: newPan.dy));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The widget's own on-screen size now represents the bigger
        // CANVAS (page + bleed margin), not the page itself - see
        // _canvasSize's doc comment.
        final previewToCanvasScale = _canvasSize.width / constraints.maxWidth;
        return ClipRect(
          child: Listener(
            onPointerSignal: (e) {
              if (e is! PointerScrollEvent) return;
              // Ctrl/Cmd+scroll scales from the marquee's own center;
              // plain scroll always zooms toward the cursor - both
              // always claim the scroll signal (registered through the
              // resolver below), reversing the previous Ctrl-gate on
              // registering at all. Known tradeoff: with the preview
              // now maximized too, scrolling the wizard's own page past
              // multiple frame sections via the mouse wheel may need
              // the cursor positioned outside any crop editor's own box
              // (its label/padding/the preset row) - an explicit,
              // accepted consequence of this choice, not a bug.
              final scaleFromMarqueeCenter =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed;
              // Registers through the same PointerSignalResolver every
              // Scrollable (including the wizard's own ListView, an
              // ancestor of this editor) uses for its own scroll
              // handling - "first registered callback wins," and
              // pointer-signal dispatch visits the deepest hit-test
              // target first, so this editor wins the resolution and
              // the ListView's own, later registration for the same
              // event is dropped entirely. Calling a handler directly
              // would sidestep this arbitration, letting scroll also
              // bleed into the list.
              GestureBinding.instance.pointerSignalResolver.register(
                e,
                (event) => scaleFromMarqueeCenter
                    ? _handleScaleFromMarqueeCenter(event as PointerScrollEvent)
                    : _handleScroll(
                        event as PointerScrollEvent,
                        previewToCanvasScale,
                      ),
              );
            },
            onPointerDown: _handleDown,
            onPointerMove: (e) => _handleMove(e, previewToCanvasScale),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: Stack(
                    children: [
                      // Background + extended dot-grid layer, sized to
                      // the full page and sitting BEHIND the content
                      // composition below - continues the board's own
                      // dot-grid pattern into any margin revealed once
                      // zoomed out past the content's own extent, rather
                      // than showing a blank void. A custom frame color
                      // still just shows that solid color in the margin
                      // (no grid), matching pdf_writer.dart's behavior.
                      Positioned.fill(
                        child: Container(
                          color: widget.backgroundColorHex != null
                              ? hexToColor(widget.backgroundColorHex!)
                              : AppTheme.canvasBackground,
                        ),
                      ),
                      if (widget.backgroundColorHex == null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ExportDotGridPainter(
                              _visibleBoardRect.topLeft,
                              _visibleBoardRect.size,
                              scale: _scaleFactor,
                            ),
                          ),
                        ),
                      // Positioned + Transform.scale (not OverflowBox) -
                      // OverflowBox would FORCE this subtree's layout
                      // size to _scaled (even when contentSize is
                      // explicitly declared below), since OverflowBox's
                      // min/maxWidth/Height become tight incoming
                      // constraints that collapse any descendant's own
                      // declared size into them. That's harmless when
                      // _scaled is comfortably bigger than contentSize,
                      // but once zoomed out far enough that _scaled
                      // shrinks below contentSize, _PageContent's own
                      // Stack (positioned via absolute native-board-unit
                      // offsets up to contentSize) gets forced to that
                      // same shrunken size and clips anything beyond it
                      // - exactly the "elements disappear when zoomed
                      // out far" bug. A plain Positioned (only
                      // left/top set) hands its child fully unconstrained
                      // BoxConstraints instead, so contentSize is
                      // respected regardless of zoom - mirrors
                      // pdf_writer.dart's own (already-correct)
                      // Positioned+Transform.scale pattern exactly. The
                      // outer Stack's default Clip.hardEdge now crops at
                      // the canvas edge instead of the page edge - the
                      // extra _pageOffsetInCanvas shift below moves the
                      // content's origin from page-space into
                      // canvas-space so it still lands exactly where it
                      // used to relative to the page, just centered
                      // within the bigger canvas.
                      Positioned(
                        left: _pageOffsetInCanvas.dx - _visibleLeft,
                        top: _pageOffsetInCanvas.dy - _visibleTop,
                        child: Transform.scale(
                          scale: _scaleFactor,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: widget.contentSize.width,
                            height: widget.contentSize.height,
                            child: _PageContent(
                              contentOrigin: widget.contentOrigin,
                              clips: widget.clips,
                              connectors: widget.connectors,
                            ),
                          ),
                        ),
                      ),
                      // Always on top: dims everything outside the real
                      // export boundary and marks it with a red
                      // rectangle, so bleed is visible but clearly
                      // distinguished from what survives the crop.
                      _CropMarksOverlay(
                        canvasSize: _canvasSize,
                        pageOffset: _pageOffsetInCanvas,
                        pageSize: widget.pageSize,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Always-visible overlay marking exactly the real export boundary
/// inside the bigger bleed-margin canvas `_PageCropEditor` now renders -
/// a red rectangle outline at the page rect, with everything outside it
/// dimmed (not hidden) so bled-over content is still visible but
/// clearly distinguished from what survives the crop. Purely a preview
/// aid - `pdf_writer.dart` is unaffected and still crops exactly at the
/// page boundary with no margin/marks baked into the exported file.
class _CropMarksOverlay extends StatelessWidget {
  final Size canvasSize;
  final Offset pageOffset;
  final Size pageSize;

  const _CropMarksOverlay({
    required this.canvasSize,
    required this.pageOffset,
    required this.pageSize,
  });

  @override
  Widget build(BuildContext context) {
    final scrim = Colors.black.withValues(alpha: 0.55);
    const borderWidth = 1.0;
    return IgnorePointer(
      child: Stack(
        children: [
          // 4 dimming bands covering everything outside the page rect -
          // darkens whatever the background/grid/content layers already
          // painted there rather than hiding it. Left/right and
          // top/bottom bands are each exactly `pageOffset`-sized since
          // the page rect is always centered in the canvas (verified:
          // canvasSize.width - pageOffset.dx - pageSize.width ==
          // pageOffset.dx).
          Positioned(
            left: 0,
            top: 0,
            width: canvasSize.width,
            height: pageOffset.dy,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: 0,
            top: pageOffset.dy + pageSize.height,
            width: canvasSize.width,
            height: pageOffset.dy,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: 0,
            top: pageOffset.dy,
            width: pageOffset.dx,
            height: pageSize.height,
            child: ColoredBox(color: scrim),
          ),
          Positioned(
            left: pageOffset.dx + pageSize.width,
            top: pageOffset.dy,
            width: pageOffset.dx,
            height: pageSize.height,
            child: ColoredBox(color: scrim),
          ),
          // The crop mark itself - drawn last, always crisp/undimmed,
          // exactly at the real export boundary.
          Positioned(
            left: pageOffset.dx,
            top: pageOffset.dy,
            width: pageSize.width,
            height: pageSize.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: borderWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The positioned/rotated clips loop from `pdf_writer.dart`'s
/// `_buildPage` Stack - background fill and the dot grid now live in
/// `_PageCropEditor.build()`'s own outer layer instead (so that layer
/// can extend the grid past this content block's own extent once
/// zoomed out below cover-fit; drawing a second background/grid here
/// would just double-paint underneath it). Deliberately excludes
/// `FrameWidget`'s chrome (border/title) - the real export never draws
/// that either.
class _PageContent extends StatelessWidget {
  final Offset contentOrigin;
  final List<BoardClip> clips;
  final List<Connector> connectors;

  const _PageContent({
    required this.contentOrigin,
    required this.clips,
    required this.connectors,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final clip in clips)
          Positioned(
            left: clip.x - contentOrigin.dx,
            top: clip.y - contentOrigin.dy,
            child: Transform.rotate(
              angle: clip.rotation,
              child: SizedBox(
                width: clip.width,
                height: clip.height,
                child: ClipWidget(clip: clip, selected: false, viewScale: 1.0),
              ),
            ),
          ),
        // Connectors painted on top of every clip above, matching the
        // live board's own ConnectorsOverlay stacking - points are
        // plain board-space-minus-contentOrigin coordinates, the same
        // convention the clips loop above already uses; the ancestor
        // Transform.scale in _PageCropEditor scales this whole
        // subtree uniformly, so no extra scale factor is needed here.
        if (connectors.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: ConnectorPainter([
                for (final connector in connectors)
                  if (_connectorSpecFor(connector, clips, contentOrigin)
                      case final spec?)
                    spec,
              ]),
            ),
          ),
      ],
    );
  }
}

ConnectorSpec? _connectorSpecFor(
  Connector connector,
  List<BoardClip> clips,
  Offset contentOrigin,
) {
  final fromClip = ClipGeometry.findById(clips, connector.fromClipId);
  final toClip = ClipGeometry.findById(clips, connector.toClipId);
  if (fromClip == null || toClip == null) return null;
  final route = ConnectorGeometry.routeBoard(
    fromClip: fromClip,
    fromSide: connector.fromSide,
    toClip: toClip,
    toRelX: connector.toRelX,
    toRelY: connector.toRelY,
  );
  return ConnectorSpec(
    points: [for (final p in route) p - contentOrigin],
    color: hexToColor(connector.colorHex),
    width: connector.strokeWidth,
  );
}

/// Mirrors `pdf_writer.dart`'s `_drawDotGrid` (fixed board-space density,
/// not the live board's zoom-dependent `DotGridPainter`) so the preview's
/// grid matches the exported page's grid exactly - same spacing/radius/
/// color/opacity constants. [scale] (default 1.0, matching this
/// painter's pre-Part-57 behavior byte-for-byte) scales both dot radius
/// and position, mirroring `_drawDotGrid`'s own generalization - used by
/// `_PageCropEditor` to draw the grid at the page's own fit scale across
/// [contentSize] (now the full visible board-space window, not just the
/// content block's own rect).
class _ExportDotGridPainter extends CustomPainter {
  final Offset origin;
  final Size contentSize;
  final double scale;
  const _ExportDotGridPainter(
    this.origin,
    this.contentSize, {
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = kBoardGridSpacing;
    final radius = 1.5 * scale;
    final startCol = (origin.dx / spacing).floor();
    final endCol = ((origin.dx + contentSize.width) / spacing).ceil();
    final startRow = (origin.dy / spacing).floor();
    final endRow = ((origin.dy + contentSize.height) / spacing).ceil();

    final paint = Paint()..color = AppTheme.gridDot.withValues(alpha: 0.5);
    for (var col = startCol; col <= endCol; col++) {
      final x = (col * spacing - origin.dx) * scale;
      for (var row = startRow; row <= endRow; row++) {
        final y = (row * spacing - origin.dy) * scale;
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExportDotGridPainter oldDelegate) =>
      origin != oldDelegate.origin ||
      contentSize != oldDelegate.contentSize ||
      scale != oldDelegate.scale;
}
