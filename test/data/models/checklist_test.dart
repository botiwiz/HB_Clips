import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/models/kanban.dart';

void main() {
  group('Checklist.fromJson/toJson', () {
    test('null input returns empty', () {
      expect(Checklist.fromJson(null).items, isEmpty);
    });

    test('empty-string input returns empty', () {
      expect(Checklist.fromJson('').items, isEmpty);
    });

    test('round-trips a single item', () {
      const checklist = Checklist(
        items: [ChecklistItem(id: 'a', label: 'Buy milk')],
      );
      final decoded = Checklist.fromJson(checklist.toJson());
      expect(decoded.items, hasLength(1));
      expect(decoded.items.single.id, 'a');
      expect(decoded.items.single.label, 'Buy milk');
      expect(decoded.items.single.done, isFalse);
    });

    test('round-trips several items with mixed done state', () {
      const checklist = Checklist(
        items: [
          ChecklistItem(id: 'a', label: 'First', done: true),
          ChecklistItem(id: 'b', label: 'Second'),
          ChecklistItem(id: 'c', label: 'Third', done: true),
        ],
      );
      final decoded = Checklist.fromJson(checklist.toJson());
      expect(decoded.items, hasLength(3));
      expect(decoded.items.map((i) => i.id), ['a', 'b', 'c']);
      expect(decoded.items.map((i) => i.done), [true, false, true]);
    });
  });

  group('ChecklistItem.copyWith', () {
    test('toggles done without touching label/id', () {
      const item = ChecklistItem(id: 'x', label: 'Task');
      final toggled = item.copyWith(done: true);
      expect(toggled.id, 'x');
      expect(toggled.label, 'Task');
      expect(toggled.done, isTrue);
    });

    test('changes label without touching id/done', () {
      const item = ChecklistItem(id: 'x', label: 'Task', done: true);
      final renamed = item.copyWith(label: 'Renamed');
      expect(renamed.id, 'x');
      expect(renamed.label, 'Renamed');
      expect(renamed.done, isTrue);
    });
  });
}
