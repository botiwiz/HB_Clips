/// Standard frame size presets - a data-entry convenience for setting a
/// frame to a common screen or paper size. Pure Dart, no Flutter/`pdf`
/// import: PDF export treats 1 board unit as 1 PDF point (see
/// `lib/data/pdf/pdf_writer.dart`), so an A4-preset frame becomes a literal,
/// exact A4 page with zero scaling.
class FramePreset {
  final String label;
  final double width;
  final double height;

  const FramePreset(this.label, this.width, this.height);
}

// ISO 216 A4 = 21cm x 29.7cm, evaluated in exactly the same order as
// package:pdf's own PdfPageFormat.a4 constant (21.0 * cm / 29.7 * cm, cm =
// 72.0 / 2.54) so the two agree bit-for-bit - floating-point evaluation
// order matters here, not just the mathematical formula. Reproduced as a
// literal so this file doesn't need to depend on package:pdf just for two
// numbers. Verified by frame_presets_test.dart.
const double _cm = 72.0 / 2.54;
const double _a4WidthPt = 21.0 * _cm;
const double _a4HeightPt = 29.7 * _cm;

const List<FramePreset> kFramePresets = [
  FramePreset('1080p (1920×1080)', 1920, 1080),
  FramePreset('1440p (2560×1440)', 2560, 1440),
  FramePreset('4K (3840×2160)', 3840, 2160),
  FramePreset('A4 portrait', _a4WidthPt, _a4HeightPt),
  FramePreset('A4 landscape', _a4HeightPt, _a4WidthPt),
];

/// One labeled category of presets inside [kFrameAspectRatioGroups] - a
/// dropdown section header (e.g. "Mobile") plus the presets under it.
class FramePresetGroup {
  final String label;
  final List<FramePreset> presets;

  const FramePresetGroup(this.label, this.presets);
}

/// A much bigger, categorized catalog of frame sizes/aspect ratios for
/// `FrameOptionsMenu`'s inline dropdown - common device classes, screen
/// resolutions, monitor/ultrawide ratios, and paper. Deliberately a
/// separate list from [kFramePresets] (which stays a short, flat catalog
/// used by the PDF export wizard and the toolbar's own "Frame size
/// preset" dialog) - this one is scoped to "pick an aspect ratio for
/// this frame," not "pick an export page size," so it can grow
/// independently without disturbing either of those.
///
/// Deliberately does NOT list every orientation of every entry, or
/// every entry at every ratio that happens to share a ratio with
/// another one - "16:9" is already fully covered by 1080p/1440p/4K
/// below (all exactly 16:9), so there's no separate, redundant "16:9
/// landscape" entry at yet another resolution; "mobile landscape" would
/// be pixel-identical to 1080p, so only the mobile-specific portrait
/// orientation gets its own entry. Each entry here is a genuinely
/// distinct size or ratio, not a restatement of one already above it.
const List<FramePresetGroup> kFrameAspectRatioGroups = [
  FramePresetGroup('Square', [FramePreset('Square (1:1)', 1080, 1080)]),
  FramePresetGroup('Mobile', [FramePreset('Mobile (9:16)', 1080, 1920)]),
  FramePresetGroup('Tablet', [
    FramePreset('Tablet portrait (3:4)', 1536, 2048),
    FramePreset('Tablet landscape (4:3)', 2048, 1536),
  ]),
  FramePresetGroup('Screen resolutions', [
    FramePreset('1080p (1920×1080)', 1920, 1080),
    FramePreset('1440p (2560×1440)', 2560, 1440),
    FramePreset('4K (3840×2160)', 3840, 2160),
  ]),
  FramePresetGroup('Widescreen', [
    FramePreset('16:10 landscape', 1920, 1200),
    FramePreset('16:10 portrait', 1200, 1920),
    FramePreset('21:9 landscape', 2560, 1080),
    FramePreset('21:9 portrait', 1080, 2560),
    FramePreset('32:9 landscape', 3840, 1080),
    FramePreset('32:9 portrait', 1080, 3840),
  ]),
  FramePresetGroup('Paper', [
    FramePreset('A4 portrait', _a4WidthPt, _a4HeightPt),
    FramePreset('A4 landscape', _a4HeightPt, _a4WidthPt),
  ]),
];
