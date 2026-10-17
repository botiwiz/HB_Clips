import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme/theme_settings.dart';
import 'local/database.dart';
import 'local_blob_store.dart';
import 'models/clip.dart';
import 'models/connector.dart';
import 'models/kanban.dart';
import 'models/stroke.dart';
import 'repositories/app_settings_repository.dart';
import 'repositories/boards_repository.dart';
import 'repositories/clips_repository.dart';
import 'repositories/connectors_repository.dart';
import 'repositories/frames_repository.dart';
import 'repositories/kanban_columns_repository.dart';
import 'repositories/kanban_elements_repository.dart';
import 'repositories/kanban_task_links_repository.dart';
import 'repositories/kanban_tasks_repository.dart';
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

final kanbanElementsRepositoryProvider = Provider<KanbanElementsRepository>((
  ref,
) {
  return KanbanElementsRepository(ref.watch(databaseProvider));
});

final boardKanbanElementsProvider = StreamProvider<List<KanbanElementRow>>((
  ref,
) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref
      .watch(kanbanElementsRepositoryProvider)
      .watchKanbanElements(boardId);
});

final kanbanColumnsRepositoryProvider = Provider<KanbanColumnsRepository>((
  ref,
) {
  return KanbanColumnsRepository(ref.watch(databaseProvider));
});

/// Every column belonging to any kanban element on the current board, in
/// one subscription - `KanbanElementWidget` groups these by
/// `kanbanElementId` and sorts by `sortOrder` itself (see
/// `KanbanColumnGeometry`), same "watch everything for the board, filter/
/// group in-memory" convention `boardFramesProvider` already follows.
final boardKanbanColumnsProvider = StreamProvider<List<KanbanColumnRow>>((
  ref,
) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref
      .watch(kanbanColumnsRepositoryProvider)
      .watchColumnsForBoard(boardId);
});

final kanbanTasksRepositoryProvider = Provider<KanbanTasksRepository>((ref) {
  return KanbanTasksRepository(ref.watch(databaseProvider));
});

/// Every task belonging to any column of any kanban element on the
/// current board, in one subscription - consumers group by
/// `KanbanTask.columnId` and sort by `sortOrder` themselves (see
/// `KanbanColumnGeometry`). A single board-wide stream (rather than one
/// scoped per element) is what lets e.g. `KanbanTaskFieldEditOverlay`
/// find "the task currently being edited" by id alone, without first
/// having to know which element it belongs to.
final boardKanbanTasksProvider = StreamProvider<List<KanbanTask>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(kanbanTasksRepositoryProvider).watchTasksForBoard(boardId);
});

final kanbanTaskLinksRepositoryProvider = Provider<KanbanTaskLinksRepository>((
  ref,
) {
  return KanbanTaskLinksRepository(ref.watch(databaseProvider));
});

/// Every kanban-task link on the current board, in one subscription -
/// `ClipWidget`/`FrameWidget`'s link-badge rendering filters this by their
/// own clip/frame id (same "watch everything for the parent scope, filter
/// client-side" convention the rest of this provider file already uses).
final boardKanbanTaskLinksProvider = StreamProvider<List<KanbanTaskLinkRow>>((
  ref,
) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref
      .watch(kanbanTaskLinksRepositoryProvider)
      .watchLinksForBoard(boardId);
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

/// Which saved theme (a `themesProvider` row's id, or null for the
/// code-level fallback look) is currently applied app-wide. See
/// `settings_dialog.dart`.
final activeThemeIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchActiveThemeId();
});

/// The actual `ThemeSettings` to render right now - resolves
/// [activeThemeIdProvider] against the saved [themesProvider] list, falling
/// back to [ThemeSettings.builtInDefault] if the id is null or references a
/// since-deleted theme. `lib/app.dart` is this provider's one real
/// consumer - every other color/font call site in the app reads the
/// mutable `AppTheme` statics it drives instead.
final resolvedThemeSettingsProvider = Provider<ThemeSettings>((ref) {
  final activeId = ref.watch(activeThemeIdProvider).valueOrNull;
  if (activeId == null) return ThemeSettings.builtInDefault;

  final themes = ref.watch(themesProvider).valueOrNull ?? const [];
  for (final row in themes) {
    if (row.id == activeId) return ThemeSettings.fromRow(row);
  }
  return ThemeSettings.builtInDefault;
});

/// Seeds `kSeedThemePresets` as real saved themes on first run (see
/// `ThemesRepository.ensureSeeded`), then makes one of them active so the
/// app always opens into a real, named, user-editable preset rather than
/// the bare code-level fallback look. If the active theme id was one of
/// the old hardcoded built-in ids from before presets became plain saved
/// themes, remaps it to the matching newly-seeded row instead of losing
/// the user's prior pink/green choice. `lib/app.dart` watches this once at
/// startup purely for its side effect; its own `ThemeSettings` value comes
/// from [resolvedThemeSettingsProvider] as always.
final themeSeedProvider = FutureProvider<void>((ref) async {
  final themesRepo = ref.watch(themesRepositoryProvider);
  final appSettings = ref.watch(appSettingsRepositoryProvider);
  final seededIds = await themesRepo.ensureSeeded();
  if (seededIds == null) return;

  final currentActive = await appSettings.getActiveThemeId();
  const legacyBuiltInIndex = {'builtin-hot-pink': 1, 'builtin-neon-green': 2};
  if (currentActive == null) {
    await appSettings.setActiveThemeId(seededIds[0]);
  } else if (legacyBuiltInIndex.containsKey(currentActive)) {
    await appSettings.setActiveThemeId(
      seededIds[legacyBuiltInIndex[currentActive]!],
    );
  }
});
