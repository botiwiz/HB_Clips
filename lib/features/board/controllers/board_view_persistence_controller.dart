import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database.dart' show BoardRow;
import '../../../data/providers.dart';
import 'board_controller.dart';

const _kViewSaveDebounce = Duration(milliseconds: 500);

BoardRow? _findBoard(List<BoardRow> boards, String id) {
  for (final b in boards) {
    if (b.id == id) return b;
  }
  return null;
}

/// Persists each board's own pan/zoom camera, so switching back to a board
/// resumes exactly where it was left - instead of `boardViewProvider`'s
/// default behavior of carrying over whatever the camera last happened to
/// be, unchanged, across a board switch.
///
/// `board_canvas.dart` writes to `boardViewProvider` on every
/// pointer-move/scroll frame while panning or zooming, so saves are
/// debounced rather than synced on every change, and always flushed
/// immediately before switching boards (or backgrounding the app) so the
/// tail end of a gesture is never lost.
///
/// An invisible (`SizedBox.shrink()`) widget rather than a bare side-effect
/// `Provider` - an earlier revision hosted this logic in a plain `Provider`
/// whose `create` callback called `ref.listen` on its own internal `Ref`;
/// that never visibly fired on a live build despite reading as correct and
/// type-checking cleanly. This version uses only `WidgetRef.listen` calls
/// made directly inside a `ConsumerState.build()` - the exact mechanism
/// `board_screen.dart`'s own undo-clearing listener already uses
/// successfully - with the debounce `Timer` held as a genuinely persistent
/// `State` instance field. Insert `const BoardViewPersistence()` once into
/// `BoardScreen`'s widget tree (a zero-footprint `Stack` child) - see that
/// file.
///
/// TEMPORARY: every decision point below logs via `debugPrint` (prefixed
/// `[view-persist]`) - added because a live report said resuming doesn't
/// work at all, and this sandbox can't run the app's GUI to reproduce it.
/// Run via `flutter run` and watch the raw console (not just DevTools'
/// Logging tab, which can filter print output separately from navigation
/// events) while panning/switching boards/restarting to see exactly which
/// step (if any) isn't doing what it should; remove this logging once the
/// real cause is found.
class BoardViewPersistence extends ConsumerStatefulWidget {
  const BoardViewPersistence({super.key});

  @override
  ConsumerState<BoardViewPersistence> createState() =>
      _BoardViewPersistenceState();
}

class _BoardViewPersistenceState extends ConsumerState<BoardViewPersistence>
    with WidgetsBindingObserver {
  Timer? _debounce;
  late String _trackedBoardId;
  bool _loadedInitialView = false;

  @override
  void initState() {
    super.initState();
    _trackedBoardId = ref.read(currentBoardIdProvider);
    debugPrint('[view-persist] initState, initial board = $_trackedBoardId');
    WidgetsBinding.instance.addObserver(this);

    // WidgetRef.listen has no fireImmediately param (unlike Ref.listen) -
    // emulate it manually: if boardsProvider already resolved by the time
    // this widget is inserted, apply the saved view right away instead of
    // waiting for a future change event that may never come.
    final initialBoards = ref.read(boardsProvider).valueOrNull;
    if (initialBoards != null) {
      _loadedInitialView = true;
      _applyView(_trackedBoardId, initialBoards);
    }
  }

  @override
  void dispose() {
    debugPrint('[view-persist] disposed');
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding/closing shouldn't lose up to _kViewSaveDebounce's
    // worth of un-persisted panning - flush immediately rather than
    // waiting for the debounce timer.
    if (state != AppLifecycleState.resumed) {
      _debounce?.cancel();
      _flushSave(_trackedBoardId);
    }
  }

  void _scheduleSave(String boardId) {
    _debounce?.cancel();
    _debounce = Timer(_kViewSaveDebounce, () => _flushSave(boardId));
    debugPrint('[view-persist] save scheduled for $boardId');
  }

  Future<void> _flushSave(String boardId) async {
    _debounce?.cancel();
    final view = ref.read(boardViewProvider);
    debugPrint(
      '[view-persist] flushing save for $boardId: '
      '${view.panOffset}/${view.scale}',
    );
    try {
      await ref
          .read(boardsRepositoryProvider)
          .updateViewState(
            boardId,
            panX: view.panOffset.dx,
            panY: view.panOffset.dy,
            scale: view.scale,
          );
      debugPrint('[view-persist] save succeeded for $boardId');
    } catch (e, st) {
      debugPrint('[view-persist] save FAILED for $boardId: $e\n$st');
    }
  }

  void _applyView(String boardId, List<BoardRow> boards) {
    final board = _findBoard(boards, boardId);
    final notifier = ref.read(boardViewProvider.notifier);
    debugPrint(
      '[view-persist] applying view for $boardId: found=${board != null}, '
      'panX=${board?.viewPanX}, panY=${board?.viewPanY}, '
      'scale=${board?.viewScale}',
    );
    if (board == null ||
        board.viewPanX == null ||
        board.viewPanY == null ||
        board.viewScale == null) {
      debugPrint('[view-persist] -> reset() (no saved view)');
      notifier.reset();
    } else {
      debugPrint(
        '[view-persist] -> setView(${board.viewPanX}, ${board.viewPanY}, '
        '${board.viewScale})',
      );
      notifier.setView(
        Offset(board.viewPanX!, board.viewPanY!),
        board.viewScale!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Registered every build - cheap/idempotent, since Riverpod diffs
    // against what this Element already listens to, same as any
    // ref.listen inside a ConsumerWidget's build (board_screen.dart's
    // own undo-clearing listener already relies on exactly this).
    ref.listen<AsyncValue<List<BoardRow>>>(boardsProvider, (previous, next) {
      debugPrint(
        '[view-persist] boardsProvider listener fired: '
        'loadedInitialView=$_loadedInitialView, hasValue=${next.hasValue}, '
        'error=${next.error}',
      );
      if (_loadedInitialView) return;
      final boards = next.valueOrNull;
      if (boards == null) return;
      _loadedInitialView = true;
      _applyView(_trackedBoardId, boards);
    });

    ref.listen<String>(currentBoardIdProvider, (previous, next) {
      debugPrint('[view-persist] currentBoardIdProvider: $previous -> $next');
      if (previous == null || previous == next) return;
      _flushSave(previous);
      _trackedBoardId = next;
      _applyView(next, ref.read(boardsProvider).valueOrNull ?? []);
    });

    ref.listen<BoardViewState>(boardViewProvider, (previous, next) {
      if (previous == next) return;
      debugPrint(
        '[view-persist] boardViewProvider changed: '
        '${previous?.panOffset}/${previous?.scale} -> '
        '${next.panOffset}/${next.scale} - scheduling save for '
        '$_trackedBoardId',
      );
      _scheduleSave(_trackedBoardId);
    });

    return const SizedBox.shrink();
  }
}
