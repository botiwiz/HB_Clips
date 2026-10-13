import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/theme_settings.dart';
import 'local/database.dart';
import 'local_blob_store.dart';
import 'models/clip.dart';
import 'models/connector.dart';
import 'models/stroke.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/boards_repository.dart';
import 'repositories/clips_repository.dart';
import 'repositories/connectors_repository.dart';
import 'repositories/frames_repository.dart';
import 'repositories/strokes_repository.dart';
import 'repositories/themes_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Native-file-backed on desktop/mobile, IndexedDB-backed on web - see
/// `local_blob_store.dart`'s doc comment for the full picture.
final localBlobStoreProvider = Provider<LocalBlobStore>((ref) {
  return LocalBlobStore(ref.watch(databaseProvider));
});

/// The board currently shown/edited. Defaults to the seeded default board;
/// switched by the board-switcher dropdown in `board_screen.dart`.
final currentBoardIdProvider = StateProvider<String>((ref) => kLocalBoardId);

final clipsRepositoryProvider = Provider<ClipsRepository>((ref) {
  return ClipsRepository(ref.watch(databaseProvider));
});

final activeClipsProvider = StreamProvider<List<BoardClip>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(clipsRepositoryProvider).watchActiveClips(boardId);
});

final binnedClipsProvider = StreamProvider<List<BoardClip>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(clipsRepositoryProvider).watchBinnedClips(boardId);
});

final strokesRepositoryProvider = Provider<StrokesRepository>((ref) {
  return StrokesRepository(ref.watch(databaseProvider));
});

final boardStrokesProvider = StreamProvider<List<Stroke>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(strokesRepositoryProvider).watchStrokes(boardId);
});

final boardsRepositoryProvider = Provider<BoardsRepository>((ref) {
  return BoardsRepository(ref.watch(databaseProvider));
});

final boardsProvider = StreamProvider<List<BoardRow>>((ref) {
  return ref.watch(boardsRepositoryProvider).watchBoards();
});

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(ref.watch(databaseProvider));
});

/// The one folder every board's `.hbbackup` file is saved to/loaded from -
/// null means never configured yet. See `backup_folder_service.dart`.
final backupFolderPathProvider = StreamProvider<String?>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchBackupFolderPath();
});

final framesRepositoryProvider = Provider<FramesRepository>((ref) {
  return FramesRepository(ref.watch(databaseProvider));
});

final boardFramesProvider = StreamProvider<List<FrameRow>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(framesRepositoryProvider).watchFrames(boardId);
});

final connectorsRepositoryProvider = Provider<ConnectorsRepository>((ref) {
  return ConnectorsRepository(ref.watch(databaseProvider));
});

final activeConnectorsProvider = StreamProvider<List<Connector>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(connectorsRepositoryProvider).watchConnectors(boardId);
});

final themesRepositoryProvider = Provider<ThemesRepository>((ref) {
  return ThemesRepository(ref.watch(databaseProvider));
});

final themesProvider = StreamProvider<List<ThemeRow>>((ref) {
  return ref.watch(themesRepositoryProvider).watchThemes();
});

/// Which theme (by id - a `kBuiltInThemes` key, a saved `ThemeRow.id`, or
/// null for the built-in default) is currently applied app-wide. See
/// `settings_dialog.dart`.
final activeThemeIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchActiveThemeId();
});

/// The actual `ThemeSettings` to render right now - resolves
/// [activeThemeIdProvider] against [kBuiltInThemes] first, then the saved
/// [themesProvider] list, then falls back to [ThemeSettings.builtInDefault]
/// if the id is null or references a since-deleted theme. `lib/app.dart`
/// is this provider's one real consumer - every other color/font call site
/// in the app reads the mutable `AppTheme` statics it drives instead.
final resolvedThemeSettingsProvider = Provider<ThemeSettings>((ref) {
  final activeId = ref.watch(activeThemeIdProvider).valueOrNull;
  if (activeId == null) return ThemeSettings.builtInDefault;

  final builtIn = kBuiltInThemes[activeId];
  if (builtIn != null) return builtIn;

  final themes = ref.watch(themesProvider).valueOrNull ?? const [];
  for (final row in themes) {
    if (row.id == activeId) return ThemeSettings.fromRow(row);
  }
  return ThemeSettings.builtInDefault;
});
