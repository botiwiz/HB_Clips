import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/features/board/services/auto_backup_service.dart';

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

  group('backupRunFolderName', () {
    test('contains no colons', () {
      final name = backupRunFolderName(DateTime(2026, 10, 7, 13, 5, 30));
      expect(name.contains(':'), isFalse);
    });

    test('sorts lexicographically in chronological order', () {
      final earlier = backupRunFolderName(DateTime(2026, 10, 7, 9, 0, 0));
      final later = backupRunFolderName(DateTime(2026, 10, 7, 9, 0, 1));
      expect(earlier.compareTo(later), lessThan(0));
    });
  });
}
