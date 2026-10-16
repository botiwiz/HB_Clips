import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/board/board_screen.dart';

class HbClipsApp extends ConsumerWidget {
  const HbClipsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Side-effect-only watch: seeds the 3 starter presets (and migrates a
    // pre-upgrade built-in choice) the first time this runs. Its own
    // ThemeSettings still comes from resolvedThemeSettingsProvider below -
    // see themeSeedProvider's doc comment.
    ref.watch(themeSeedProvider);
    final resolved = ref.watch(resolvedThemeSettingsProvider);
    return MaterialApp(
      title: 'HB_Clips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(resolved),
      builder: (context, child) => MediaQuery(
        // Force animations on regardless of what the platform reports.
        // Many Linux desktop sessions have no working accessibility bus,
        // so the engine reports disableAnimations: true by default - which
        // makes every Material implicit animation (menus, dialogs,
        // AnimatedPositioned, Hero) jump straight to its end state instead
        // of transitioning. Windows doesn't hit this, which is why the
        // same code already animates smoothly there.
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(resolved.fontSizeScale),
          disableAnimations: false,
        ),
        child: child!,
      ),
      home: const BoardScreen(),
    );
  }
}
