import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'local/database.dart';
import 'local_blob_store.dart';
import 'models/clip.dart';
import 'models/stroke.dart';
import 'remote/boards_remote_source.dart';
import 'remote/clips_remote_source.dart';
import 'remote/frames_remote_source.dart';
import 'remote/pairing_service.dart';
import 'remote/storage_source.dart';
import 'remote/strokes_remote_source.dart';
import 'remote/supabase_client_provider.dart';
import 'repositories/boards_repository.dart';
import 'repositories/clips_repository.dart';
import 'repositories/frames_repository.dart';
import 'repositories/strokes_repository.dart';
import 'sync/realtime_listener.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_queue_drainer.dart';

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

final imageSlotsRemainingProvider = StreamProvider<int>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(clipsRepositoryProvider).watchImageSlotsRemaining(boardId);
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

final framesRepositoryProvider = Provider<FramesRepository>((ref) {
  return FramesRepository(ref.watch(databaseProvider));
});

final boardFramesProvider = StreamProvider<List<FrameRow>>((ref) {
  final boardId = ref.watch(currentBoardIdProvider);
  return ref.watch(framesRepositoryProvider).watchFrames(boardId);
});

/// Null when sync isn't configured (no [supabaseClientProvider]) - the app
/// then behaves exactly as it did before this feature, fully local-only.
/// Read once (`ref.read(syncEngineProvider)?.start()`) at app startup, in
/// `app.dart` - never on the critical path of any UI-facing repository
/// call, and never `ref.watch`-ed, since nothing should rebuild off it.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final db = ref.watch(databaseProvider);
  final blobStore = ref.watch(localBlobStoreProvider);
  final clipsRemote = SupabaseClipsRemoteSource(client);
  final strokesRemote = SupabaseStrokesRemoteSource(client);
  final boardsRemote = SupabaseBoardsRemoteSource(client);
  final framesRemote = SupabaseFramesRemoteSource(client);
  final storage = SupabaseStorageSource(client, blobStore);

  final drainer = SyncQueueDrainer(
    db,
    () => client.auth.currentUser!.id,
    clipsRemote,
    strokesRemote,
    boardsRemote,
    framesRemote,
    storage,
    blobStore,
  );
  final realtime = RealtimeListener(db, client, storage);
  final engine = SyncEngine(
    db,
    drainer,
    realtime,
    clipsRemote,
    strokesRemote,
    boardsRemote,
    framesRemote,
  );
  ref.onDispose(() => engine.stop());
  return engine;
});

/// Null when sync isn't configured, same as [syncEngineProvider] - the
/// device-pairing UI in `board_screen.dart` only shows up when this is
/// non-null.
final pairingServiceProvider = Provider<PairingService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return PairingService(client);
});
