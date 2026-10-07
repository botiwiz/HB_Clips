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
/// Created once and kept alive for the app's lifetime by being read once
/// from `BoardScreen.build()` - a plain (non-autoDispose) `Provider` stays
/// alive once created regardless of further use, the same "a provider
/// whose job is side effects" shape every other long-lived singleton
/// service in this app already uses.
class BoardViewPersistenceController with WidgetsBindingObserver {
  final Ref ref;
  Timer? _debounce;
  String _trackedBoardId;
  bool _loadedInitialView = false;

  BoardViewPersistenceController(this.ref)
    : _trackedBoardId = ref.read(currentBoardIdProvider) {
    WidgetsBinding.instance.addObserver(this);

    // Cold start: boardsProvider's first stream event may not have landed
    // yet on the very first build, so the initially-current board's saved
    // view is applied the first time it resolves - fireImmediately covers
    // the (more common) case it's already resolved by the time this
    // listener attaches.
    ref.listen<AsyncValue<List<BoardRow>>>(boardsProvider, (previous, next) {
      if (_loadedInitialView) return;
      final boards = next.valueOrNull;
      if (boards == null) return;
      _loadedInitialView = true;
      _applyView(_trackedBoardId, boards);
    }, fireImmediately: true);

    ref.listen<String>(currentBoardIdProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _flushSave(previous);
      _trackedBoardId = next;
      _applyView(next, ref.read(boardsProvider).valueOrNull ?? []);
    });

    ref.listen<BoardViewState>(boardViewProvider, (previous, next) {
      if (previous == next) return;
      _scheduleSave(_trackedBoardId);
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _debounce?.cancel();
    });
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
  }

  Future<void> _flushSave(String boardId) {
    _debounce?.cancel();
    final view = ref.read(boardViewProvider);
    return ref
        .read(boardsRepositoryProvider)
        .updateViewState(
          boardId,
          panX: view.panOffset.dx,
          panY: view.panOffset.dy,
          scale: view.scale,
        );
  }

  void _applyView(String boardId, List<BoardRow> boards) {
    final board = _findBoard(boards, boardId);
    final notifier = ref.read(boardViewProvider.notifier);
    if (board == null ||
        board.viewPanX == null ||
        board.viewPanY == null ||
        board.viewScale == null) {
      notifier.reset();
    } else {
      notifier.setView(
        Offset(board.viewPanX!, board.viewPanY!),
        board.viewScale!,
      );
    }
  }
}

final boardViewPersistenceProvider = Provider<BoardViewPersistenceController>(
  (ref) => BoardViewPersistenceController(ref),
);
