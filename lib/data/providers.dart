import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'local/database.dart';
import 'models/clip.dart';
import 'models/stroke.dart';
import 'repositories/clips_repository.dart';
import 'repositories/strokes_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final clipsRepositoryProvider = Provider<ClipsRepository>((ref) {
  return ClipsRepository(ref.watch(databaseProvider));
});

final activeClipsProvider = StreamProvider<List<BoardClip>>((ref) {
  return ref.watch(clipsRepositoryProvider).watchActiveClips(kLocalBoardId);
});

final binnedClipsProvider = StreamProvider<List<BoardClip>>((ref) {
  return ref.watch(clipsRepositoryProvider).watchBinnedClips(kLocalBoardId);
});

final imageSlotsRemainingProvider = StreamProvider<int>((ref) {
  return ref
      .watch(clipsRepositoryProvider)
      .watchImageSlotsRemaining(kLocalBoardId);
});

final strokesRepositoryProvider = Provider<StrokesRepository>((ref) {
  return StrokesRepository(ref.watch(databaseProvider));
});

final boardStrokesProvider = StreamProvider<List<Stroke>>((ref) {
  return ref.watch(strokesRepositoryProvider).watchStrokes(kLocalBoardId);
});
