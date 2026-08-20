import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase credentials from the gitignored `.env` file (see
/// `.env.example`). Not wired into `main.dart` yet — cloud sync/auth land
/// in a later phase; this exists so the config surface is in place early.
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
