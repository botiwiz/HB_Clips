import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/board/board_screen.dart';

class HbClipsApp extends ConsumerWidget {
  const HbClipsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(resolvedThemeSettingsProvider);
    return MaterialApp(
      title: 'HB_Clips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(resolved),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(resolved.fontSizeScale)),
        child: child!,
      ),
      home: const BoardScreen(),
    );
  }
}
