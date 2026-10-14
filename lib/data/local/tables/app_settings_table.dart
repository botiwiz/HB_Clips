import 'package:drift/drift.dart';

/// A single-row table of app-level settings that aren't scoped to any one
/// board - today just the one configured backup folder (see
/// `backup_folder_service.dart`). A fixed-id singleton row rather than a
/// bare key/value table: there's exactly one setting so far and this
/// stays simplest while that remains true.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  TextColumn get id => text()();

  /// The one folder every board's `.hbbackup` file is saved to/loaded
  /// from - null means "never configured," which is what triggers the
  /// first-run prompt (`BackupFolderPromptController`) and makes the
  /// periodic auto-backup/manual Save silently no-op until it's set.
  TextColumn get backupFolderPath => text().nullable()();

  /// Which saved `Themes` row (by id) is currently applied app-wide - null
  /// means the bare code-level fallback look (`ThemeSettings.builtInDefault`),
  /// only reachable if every saved theme has been deleted (`ensureSeeded`
  /// keeps at least one seeded on every normal startup). See
  /// `lib/core/theme/theme_settings.dart` and `lib/data/providers.dart`'s
  /// `resolvedThemeSettingsProvider`/`themeSeedProvider`.
  TextColumn get activeThemeId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fixed row id for the one settings row this table ever holds.
const String kAppSettingsRowId = 'singleton';
