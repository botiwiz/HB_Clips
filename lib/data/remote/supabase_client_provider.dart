import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

/// The app's Supabase client, or null when sync isn't configured (no valid
/// `.env` - the app then runs exactly as it did before this feature,
/// fully local-only). Reading `Supabase.instance.client` before
/// `Supabase.initialize()` has run throws, so this defensively returns
/// null in that case too rather than propagating the exception into every
/// provider that depends on it.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Ensures [client] has a persistent, silent session with no login UI -
/// `supabase_flutter`'s own `SharedPreferencesLocalStorage` already
/// persists the session across app restarts, so this only actually signs
/// in on a genuinely first launch (or after `signOut()`/local storage
/// being cleared).
Future<void> ensureAnonymousSession(SupabaseClient client) async {
  if (client.auth.currentSession != null) return;
  await client.auth.signInAnonymously();
}
