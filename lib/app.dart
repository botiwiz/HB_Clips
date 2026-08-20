import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/board/board_screen.dart';

class HbClipsApp extends StatelessWidget {
  const HbClipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HB_Clips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const BoardScreen(),
    );
  }
}
