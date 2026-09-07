import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase credentials from the gitignored `.env` file (see
/// `.env.example`). Wired into `main.dart`'s startup bootstrap - when
/// unconfigured (no `.env`, or still the placeholder values), the app
/// runs fully local-only with no sync.
class Env {
  Env._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('your-project-ref') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'your-anon-public-key';
}
