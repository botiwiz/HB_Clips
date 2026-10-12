import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/backup_folder_service.dart';

void main() {
  group('sanitizedBackupFileName', () {
    test('replaces illegal filename characters with underscores', () {
      expect(
        sanitizedBackupFileName('a/b\\c:d*e?f"g<h>i|j'),
        'a_b_c_d_e_f_g_h_i_j',
      );
    });

    test('trims surrounding whitespace', () {
      expect(sanitizedBackupFileName('  My Board  '), 'My Board');
    });

    test('falls back to "board" for an empty or whitespace-only name', () {
      expect(sanitizedBackupFileName(''), 'board');
      expect(sanitizedBackupFileName('   '), 'board');
    });

    test('leaves an already-clean name unchanged', () {
      expect(sanitizedBackupFileName('My Board'), 'My Board');
    });
  });

  group('decideLoadAction', () {
    test('creates new when the manifest has no board id', () {
      expect(
        decideLoadAction(manifestBoardId: null, existingBoardIds: {'a'}),
        LoadFileAction.createNew,
      );
    });

    test('creates new when the board id is not already known', () {
      expect(
        decideLoadAction(
          manifestBoardId: 'unseen',
          existingBoardIds: {'a', 'b'},
        ),
        LoadFileAction.createNew,
      );
    });

    test('updates existing when the board id is already known', () {
      expect(
        decideLoadAction(manifestBoardId: 'a', existingBoardIds: {'a', 'b'}),
        LoadFileAction.updateExisting,
      );
    });
  });
}
