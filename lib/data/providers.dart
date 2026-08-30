import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'local/database.dart';
import 'models/clip.dart';
import 'models/stroke.dart';
import 'repositories/boards_repository.dart';
import 'repositories/clips_repository.dart';
import 'repositories/strokes_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
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
