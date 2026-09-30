import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One reversible board edit: [undo] restores the prior state, [redo]
/// re-applies it. Both are plain closures over the same repository calls
/// the original edit itself used - [UndoManager.undo]/[UndoManager.redo]
/// call these directly (never through [UndoManager.push]), so replaying
/// history never grows the stacks it's replaying.
class UndoableAction {
  final Future<void> Function() undo;
  final Future<void> Function() redo;

  const UndoableAction({required this.undo, required this.redo});
}

/// Bounded past/future stacks of [UndoableAction]s.
class UndoState {
  final List<UndoableAction> undoStack;
  final List<UndoableAction> redoStack;

  const UndoState({required this.undoStack, required this.redoStack});

  static const empty = UndoState(undoStack: [], redoStack: []);

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
}

/// Drives the board's Ctrl+Z/Ctrl+Shift+Z shortcuts and the toolbar's
/// back/forward buttons. Scoped to whichever board is currently open -
/// `board_screen.dart` clears it on every board switch, since an action
/// captured against one board's clips makes no sense replayed against
/// another.
class UndoManager extends StateNotifier<UndoState> {
  UndoManager() : super(UndoState.empty);

  /// Caps memory for a very long editing session - the oldest entry is
  /// dropped once exceeded, same "bounded history" convention as most
  /// editors (undo is a convenience for recent mistakes, not a full
  /// audit log).
  static const int maxDepth = 100;

  /// Pushes a newly-performed edit onto the undo stack. Clears the redo
  /// stack - the usual "you branched off, the old future is gone" editor
  /// convention.
  void push(UndoableAction action) {
    final undoStack = [...state.undoStack, action];
    if (undoStack.length > maxDepth) undoStack.removeAt(0);
    state = UndoState(undoStack: undoStack, redoStack: const []);
  }

  Future<void> undo() async {
    if (state.undoStack.isEmpty) return;
    final action = state.undoStack.last;
    final undoStack = state.undoStack.sublist(0, state.undoStack.length - 1);
    await action.undo();
    state = UndoState(
      undoStack: undoStack,
      redoStack: [...state.redoStack, action],
    );
  }

  Future<void> redo() async {
    if (state.redoStack.isEmpty) return;
    final action = state.redoStack.last;
    final redoStack = state.redoStack.sublist(0, state.redoStack.length - 1);
    await action.redo();
    state = UndoState(
      undoStack: [...state.undoStack, action],
      redoStack: redoStack,
    );
  }

  /// Wipes both stacks - called when switching boards.
  void clear() => state = UndoState.empty;
}

final undoManagerProvider = StateNotifierProvider<UndoManager, UndoState>(
  (ref) => UndoManager(),
);
