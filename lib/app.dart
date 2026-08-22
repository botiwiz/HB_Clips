import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/board/board_screen.dart';
import 'main.dart';

class HbClipsApp extends StatelessWidget {
  const HbClipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HB_Clips',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: isDesktopPlatform
          ? DragToResizeArea(
              resizeEdgeSize: 6,
              child: const BoardScreen(),
            )
          : const BoardScreen(),
    );
  }
}
