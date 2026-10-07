import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart'
    show kAutoBackupRetentionCount, kBoardBackupExtension;
import '../../../data/providers.dart';
import 'backup_directory_service.dart';
import 'board_backup_service.dart';
import 'save_file_service.dart';

/// Windows/mac/Linux-illegal filename characters, replaced with '_' -
/// board names are free-form user text (unlike manual Save As, which
/// always goes through a file-picker dialog that handles this itself).
String sanitizedBackupFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'board' : cleaned;
}

/// Filesystem-safe timestamp (no colons) - also sorts lexicographically
/// in chronological order, which listBackupRunFolders relies on.
String backupRunFolderName(DateTime time) =>
    time.toIso8601String().replaceAll(':', '-').split('.').first;

/// Writes one timestamped backup of every board to
/// `<docs>/backups/<timestamp>/<board name>.hbbackup`, then prunes the
/// oldest runs beyond [kAutoBackupRetentionCount]. No-op on web (there is
/// no ambient, silently-writable filesystem there). Failures are logged,
/// not surfaced - this is a background safety net, not a user-initiated
/// save; the user's own explicit Save/Save As/Export still show real
/// errors exactly as before.
Future<void> runAutoBackup(WidgetRef ref) async {
  if (kIsWeb) return;
  try {
    final boards = ref.read(boardsProvider).valueOrNull ?? [];
    if (boards.isEmpty) return;
    final root = await backupsRootPath();
    final runPath = await createBackupRunFolder(
      root,
      backupRunFolderName(DateTime.now()),
    );
    for (final board in boards) {
      final bytes = await exportBoardBackup(ref, board.id);
      final fileName =
          '${sanitizedBackupFileName(board.name)}.$kBoardBackupExtension';
      await writeBytesToPath(p.join(runPath, fileName), bytes);
    }
    await _pruneOldRuns(root);
    debugPrint('[auto-backup] wrote $runPath (${boards.length} board(s))');
  } catch (e, st) {
    debugPrint('[auto-backup] failed: $e\n$st');
  }
}

Future<void> _pruneOldRuns(String root) async {
  final runs = await listBackupRunFolders(root);
  if (runs.length <= kAutoBackupRetentionCount) return;
  final toDelete = runs.take(runs.length - kAutoBackupRetentionCount);
  for (final name in toDelete) {
    await deleteBackupRunFolder(p.join(root, name));
  }
}

/// "Show Backups..." - opens the backups root folder in the OS file
/// manager, the same role OBS Studio's File -> "Show Recordings" plays.
/// Ensures the folder exists first (so this works even before any
/// backup has run yet) and falls back to a SnackBar with the raw path
/// if the OS launch itself fails.
Future<void> showBackupsFolder(BuildContext context, WidgetRef ref) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Automatic backups aren't available in the browser - use "
          'File > Save As to export a board manually.',
        ),
      ),
    );
    return;
  }
  final root = await backupsRootPath();
  bool opened;
  try {
    opened = await launchUrl(Uri.file(root));
  } catch (_) {
    opened = false;
  }
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Backups are stored at: $root')));
}
