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

  group('kFrameAspectRatioGroups', () {
    test('every group has at least one preset', () {
      for (final group in kFrameAspectRatioGroups) {
        expect(group.presets, isNotEmpty, reason: group.label);
      }
    });

    test('every preset has strictly positive width and height', () {
      for (final group in kFrameAspectRatioGroups) {
        for (final preset in group.presets) {
          expect(preset.width, greaterThan(0), reason: preset.label);
          expect(preset.height, greaterThan(0), reason: preset.label);
        }
      }
    });

    test('every landscape/portrait pair swaps width and height exactly', () {
      final byLabel = <String, FramePreset>{
        for (final group in kFrameAspectRatioGroups)
          for (final preset in group.presets) preset.label: preset,
      };
      const pairs = [
        ('Tablet portrait (3:4)', 'Tablet landscape (4:3)'),
        ('21:9 portrait', '21:9 landscape'),
        ('32:9 portrait', '32:9 landscape'),
        ('16:10 portrait', '16:10 landscape'),
        ('A4 portrait', 'A4 landscape'),
      ];
      for (final (portraitLabel, landscapeLabel) in pairs) {
        final portrait = byLabel[portraitLabel]!;
        final landscape = byLabel[landscapeLabel]!;
        expect(
          portrait.width,
          landscape.height,
          reason: '$portraitLabel vs $landscapeLabel',
        );
        expect(
          portrait.height,
          landscape.width,
          reason: '$portraitLabel vs $landscapeLabel',
        );
      }
    });

    test('Square has an equal width and height', () {
      final square = kFrameAspectRatioGroups
          .firstWhere((g) => g.label == 'Square')
          .presets
          .single;
      expect(square.width, square.height);
    });

    test('no two entries share the exact same pixel dimensions - the '
        'dropdown should never show two differently-labeled presets that '
        'are actually identical (e.g. a "Mobile landscape" that was '
        'pixel-for-pixel the same as "1080p")', () {
      final seen = <(double, double), String>{};
      for (final group in kFrameAspectRatioGroups) {
        for (final preset in group.presets) {
          final key = (preset.width, preset.height);
          final existing = seen[key];
          expect(
            existing,
            isNull,
            reason:
                '${preset.label} (${preset.width}x${preset.height}) '
                'duplicates $existing',
          );
          seen[key] = preset.label;
        }
      }
    });
  });
}
