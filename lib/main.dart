import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'data/remote/supabase_client_provider.dart';

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

  await _bootstrapSync();

  runApp(const ProviderScope(child: HbClipsApp()));
}

/// Best-effort: brings up Supabase and a silent anonymous session when
/// `.env` is configured for it. Sync is strictly additive - any failure
/// here (missing `.env`, server unreachable, ...) is swallowed so the app
/// always starts in its existing fully-local-only mode rather than being
/// blocked by a network problem.
Future<void> _bootstrapSync() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    return; // no .env file at all - stay local-only, nothing else to do.
  }
  if (!Env.isConfigured) return;

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    await ensureAnonymousSession(Supabase.instance.client);
  } catch (error) {
    debugPrint('Supabase bootstrap failed, continuing in local-only mode: $error');
  }
}
