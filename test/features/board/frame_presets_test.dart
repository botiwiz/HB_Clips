import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/geometry/frame_presets.dart';
import 'package:pdf/pdf.dart';

FramePreset _byLabel(String label) =>
    kFramePresets.firstWhere((p) => p.label == label);

void main() {
  group('kFramePresets', () {
    test('A4 portrait matches PdfPageFormat.a4 exactly', () {
      final preset = _byLabel('A4 portrait');
      expect(preset.width, PdfPageFormat.a4.width);
      expect(preset.height, PdfPageFormat.a4.height);
    });

    test('A4 landscape is A4 portrait with width/height swapped', () {
      final portrait = _byLabel('A4 portrait');
      final landscape = _byLabel('A4 landscape');
      expect(landscape.width, portrait.height);
      expect(landscape.height, portrait.width);
    });

    test('contains the expected screen-size presets', () {
      expect(_byLabel('1080p (1920×1080)').width, 1920);
      expect(_byLabel('1080p (1920×1080)').height, 1080);
      expect(_byLabel('1440p (2560×1440)').width, 2560);
      expect(_byLabel('1440p (2560×1440)').height, 1440);
      expect(_byLabel('4K (3840×2160)').width, 3840);
      expect(_byLabel('4K (3840×2160)').height, 2160);
    });
  });
}
