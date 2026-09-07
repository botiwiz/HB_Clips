import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/board/board_screen.dart';
import 'main.dart';

class HbClipsApp extends ConsumerStatefulWidget {
  const HbClipsApp({super.key});

  @override
  ConsumerState<HbClipsApp> createState() => _HbClipsAppState();
}

class _HbClipsAppState extends ConsumerState<HbClipsApp> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: a no-op when sync isn't configured, and never on
    // the critical path of anything the UI needs to render.
    ref.read(syncEngineProvider)?.start();
  }

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
