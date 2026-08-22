import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';

/// window_manager only ships plugins for desktop; guard every call so this
/// stays inert once Phase 9 adds an Android build.
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await windowManager.setBackgroundColor(AppTheme.canvasBackground);
    await windowManager.setMinimumSize(const Size(480, 360));
  }

  runApp(const ProviderScope(child: HbClipsApp()));
}
