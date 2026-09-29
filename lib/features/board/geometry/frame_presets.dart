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
