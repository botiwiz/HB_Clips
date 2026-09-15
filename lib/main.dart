import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/remote/supabase_client_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
