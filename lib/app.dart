import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/board/board_screen.dart';

class HbClipsApp extends ConsumerWidget {
  const HbClipsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HB_Clips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const BoardScreen(),
    );
  }
}
