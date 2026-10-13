import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/theme/theme_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = TextTheme(
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
  );

  test('a null font family returns the base TextTheme unchanged', () {
    expect(resolveFontTextTheme(null, base), same(base));
  });

  test('a non-null font family returns a different, google_fonts-backed '
      'TextTheme', () async {
    // The synchronous half of GoogleFonts.getTextTheme always returns a
    // real TextTheme immediately; it also kicks off a background font
    // *download* this sandbox's test environment has no network path
    // for, which surfaces later as an unhandled async rejection
    // unrelated to resolveFontTextTheme's own (synchronous) contract -
    // caught and ignored here so it can't fail this or a later test.
    final completer = Completer<TextTheme>();
    runZonedGuarded(
      () => completer.complete(resolveFontTextTheme('Chakra Petch', base)),
      (error, stack) {},
    );
    final resolved = await completer.future;

    expect(resolved, isNot(same(base)));
    expect(resolved.bodyMedium?.fontFamily, isNotNull);
    expect(resolved.bodyMedium?.fontFamily, isNot(base.bodyMedium?.fontFamily));
  });

  test('kThemeFontChoices maps "System default" to null', () {
    expect(kThemeFontChoices['System default'], isNull);
  });

  test('every non-default kThemeFontChoices entry names itself', () {
    for (final entry in kThemeFontChoices.entries) {
      if (entry.key == 'System default') continue;
      expect(entry.value, entry.key);
    }
  });
}
