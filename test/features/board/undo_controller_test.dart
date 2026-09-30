import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/controllers/undo_controller.dart';

void main() {
  group('UndoManager', () {
    test('push then undo restores prior state and enables redo', () async {
      final manager = UndoManager();
      var value = 0;
      manager.push(
        UndoableAction(
          undo: () async => value = 0,
          redo: () async => value = 1,
        ),
      );
      value = 1;

      expect(manager.state.canUndo, isTrue);
      expect(manager.state.canRedo, isFalse);

      await manager.undo();

      expect(value, 0);
      expect(manager.state.canUndo, isFalse);
      expect(manager.state.canRedo, isTrue);
    });

    test('redo re-applies the action and moves it back to the undo stack', () async {
      final manager = UndoManager();
      var value = 0;
      manager.push(
        UndoableAction(
          undo: () async => value = 0,
          redo: () async => value = 1,
        ),
      );
      value = 1;
      await manager.undo();

      await manager.redo();

      expect(value, 1);
      expect(manager.state.canUndo, isTrue);
      expect(manager.state.canRedo, isFalse);
    });

    test('pushing a new action clears the redo stack', () async {
      final manager = UndoManager();
      manager.push(UndoableAction(undo: () async {}, redo: () async {}));
      await manager.undo();
      expect(manager.state.canRedo, isTrue);

      manager.push(UndoableAction(undo: () async {}, redo: () async {}));

      expect(manager.state.canRedo, isFalse);
      expect(manager.state.canUndo, isTrue);
    });

    test('undo/redo on empty stacks is a safe no-op', () async {
      final manager = UndoManager();
      await manager.undo();
      await manager.redo();
      expect(manager.state.canUndo, isFalse);
      expect(manager.state.canRedo, isFalse);
    });

    test('clear wipes both stacks', () async {
      final manager = UndoManager();
      manager.push(UndoableAction(undo: () async {}, redo: () async {}));
      await manager.undo();
      expect(manager.state.canRedo, isTrue);

      manager.clear();

      expect(manager.state.canUndo, isFalse);
      expect(manager.state.canRedo, isFalse);
    });

    test('drops the oldest entry once maxDepth is exceeded', () {
      final manager = UndoManager();
      for (var i = 0; i < UndoManager.maxDepth + 5; i++) {
        manager.push(UndoableAction(undo: () async {}, redo: () async {}));
      }
      expect(manager.state.undoStack.length, UndoManager.maxDepth);
    });

    test('undo/redo replay history without growing the stacks themselves', () async {
      // Guards against a push-from-within-undo/redo bug: since undo/redo
      // call the captured closures directly rather than through push,
      // repeatedly undoing and redoing the same action must never grow
      // either stack.
      final manager = UndoManager();
      var value = 0;
      manager.push(
        UndoableAction(
          undo: () async => value--,
          redo: () async => value++,
        ),
      );
      value = 1;

      for (var i = 0; i < 5; i++) {
        await manager.undo();
        await manager.redo();
      }

      expect(value, 1);
      expect(manager.state.undoStack.length, 1);
      expect(manager.state.redoStack.length, 0);
    });
  });
}
