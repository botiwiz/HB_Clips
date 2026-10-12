import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart' show kBoardBackupExtension;
import '../../../core/theme/app_theme.dart';
import '../../../data/backup/board_backup_manifest.dart';
import '../../../data/providers.dart';
import 'backup_folder_listing_service.dart';
import 'board_backup_service.dart';
import 'save_file_service.dart';

/// Windows/mac/Linux-illegal filename characters, replaced with '_' -
/// board names are free-form user text, and (unlike the old manual Save
/// As) nothing here goes through a file-picker dialog that would
/// otherwise sanitize this for us.
String sanitizedBackupFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'board' : cleaned;
}

/// Opens a native "choose a folder" dialog. Same try/catch-zenity-missing
/// pattern `board_backup_service.dart`'s old file-picker call sites used.
/// Returns null if the user cancels or the picker itself couldn't open.
Future<String?> pickBackupFolder(BuildContext context) async {
  try {
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a backup folder',
    );
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't open the folder picker. On Linux this needs zenity "
          '(or kdialog) installed.',
        ),
        backgroundColor: AppTheme.danger,
      ),
    );
    return null;
  }
}

/// Shows the "choose a backup folder" explainer dialog if nothing is
/// configured yet; no-ops (returns true immediately) if something already
/// is. Returns whether a folder ended up configured by the time it
/// returns - "Later" (or dismissing the dialog, or cancelling the picker)
/// leaves nothing configured and returns false; the first-run prompt
/// (`BackupFolderPromptController`) relies on this to know to ask again
/// next launch rather than nagging mid-session.
Future<bool> ensureBackupFolderConfigured(
  BuildContext context,
  WidgetRef ref,
) async {
  if (kIsWeb) return false;
  final existing = await ref
      .read(appSettingsRepositoryProvider)
      .getBackupFolderPath();
  if (existing != null) return true;
  if (!context.mounted) return false;

  final choseToPick = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Choose a backup folder'),
      content: const Text(
        "HB_Clips can save every board's .hbbackup file into one folder "
        'you choose - handy if you sync it yourself (Dropbox, OneDrive, '
        "etc), so every machine always has every board's latest state. "
        "You can change this later from File > Backup folder...",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Choose folder...'),
        ),
      ],
    ),
  );
  if (choseToPick != true || !context.mounted) return false;

  final picked = await pickBackupFolder(context);
  if (picked == null) return false;
  await ref.read(appSettingsRepositoryProvider).setBackupFolderPath(picked);
  return true;
}

/// Writes every board's current state to
/// `<folderPath>/<sanitized board name>.hbbackup`, overwriting in place -
/// no run subfolder, no pruning, since there's only ever one file per
/// board now. Shared by [saveAllBoards] (the File menu action) and
/// [runAutoBackup] (the periodic scheduler). A failure on one board is
/// logged and skipped rather than aborting the rest - this is meant to be
/// a reliable background safety net, not an all-or-nothing transaction.
/// Returns how many boards were written successfully.
Future<int> saveAllBoardsToBackupFolder(
  WidgetRef ref,
  String folderPath,
) async {
  final boards = ref.read(boardsProvider).valueOrNull ?? [];
  var written = 0;
  for (final board in boards) {
    try {
      final bytes = await exportBoardBackup(ref, board.id);
      final fileName =
          '${sanitizedBackupFileName(board.name)}.$kBoardBackupExtension';
      await writeBytesToPath(p.join(folderPath, fileName), bytes);
      written++;
    } catch (e, st) {
      debugPrint('[backup-folder] failed to save "${board.name}": $e\n$st');
    }
  }
  return written;
}

/// File menu "Save" - writes every board into the configured backup
/// folder, prompting for one first (via [ensureBackupFolderConfigured])
/// only if none is set yet. No per-board dialog, ever - this always means
/// "every board," matching the single-folder model (there's nothing left
/// to pick a file for).
Future<void> saveAllBoards(BuildContext context, WidgetRef ref) async {
  final configured = await ensureBackupFolderConfigured(context, ref);
  if (!configured || !context.mounted) return;
  final folderPath = await ref
      .read(appSettingsRepositoryProvider)
      .getBackupFolderPath();
  if (folderPath == null) return; // shouldn't happen once configured==true
  final count = await saveAllBoardsToBackupFolder(ref, folderPath);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Saved $count board${count == 1 ? '' : 's'} to $folderPath',
      ),
    ),
  );
}

/// Replaces the old timestamped-subfolder auto-backup - silently no-ops
/// (no error, no nag) if no folder is configured yet, matching how
/// [saveAllBoards]/the first-run prompt never force the issue either.
/// Failures are logged, not surfaced - same "background safety net, not
/// a user-initiated save" convention the old auto-backup had.
Future<void> runAutoBackup(WidgetRef ref) async {
  if (kIsWeb) return;
  try {
    final folderPath = await ref
        .read(appSettingsRepositoryProvider)
        .getBackupFolderPath();
    if (folderPath == null) return;
    final count = await saveAllBoardsToBackupFolder(ref, folderPath);
    debugPrint('[auto-backup] wrote $count board(s) to $folderPath');
  } catch (e, st) {
    debugPrint('[auto-backup] failed: $e\n$st');
  }
}

/// Whether a decoded `.hbbackup` file should become a brand-new board or
/// overwrite an existing one in place - see [decideLoadAction].
enum LoadFileAction { createNew, updateExisting }

/// Matches on the manifest's own embedded board id, not on a remembered
/// file path - a synced folder (Dropbox/OneDrive/etc) resolves to a
/// different absolute path per machine, so path-matching would never
/// recognize "this is a newer export of a board I already have" across
/// machines, defeating the entire point of Loading a synced folder. A
/// board id embedded in the file itself travels correctly wherever it's
/// synced to. Pure and synchronous - no network/DB access - so it's
/// unit-testable on its own.
LoadFileAction decideLoadAction({
  required String? manifestBoardId,
  required Set<String> existingBoardIds,
}) {
  if (manifestBoardId != null && existingBoardIds.contains(manifestBoardId)) {
    return LoadFileAction.updateExisting;
  }
  return LoadFileAction.createNew;
}

/// File menu "Load..." - picks a folder (not a single file), imports or
/// updates every `.hbbackup` file found directly inside it (see
/// [decideLoadAction]), and adopts that folder as the configured Save/
/// auto-backup target too - matching the single-folder mental model, no
/// separate "now also set your save folder" step after Loading on a new
/// machine. A file that fails to read or decode is skipped (reported in
/// the summary dialog), not fatal to the rest of the folder.
Future<void> loadBackupFolder(BuildContext context, WidgetRef ref) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Loading a backup folder isn't available in the browser - "
          'there is no ambient filesystem to read from.',
        ),
      ),
    );
    return;
  }

  final folderPath = await pickBackupFolder(context);
  if (folderPath == null || !context.mounted) return;

  await ref.read(appSettingsRepositoryProvider).setBackupFolderPath(folderPath);

  final files = await readBackupFilesInFolder(folderPath);
  final existingBoardIds = (ref.read(boardsProvider).valueOrNull ?? [])
      .map((b) => b.id)
      .toSet();

  var created = 0;
  var updated = 0;
  final errors = <String>[];
  BoardBackupSummary? onlySummary;
  var processedCount = 0;

  for (final entry in files.entries) {
    final fileName = entry.key;
    final bytes = entry.value;
    final DecodedBackupArchive decoded;
    try {
      decoded = decodeBackupArchive(bytes);
    } catch (e) {
      errors.add('$fileName: $e');
      continue;
    }
    final action = decideLoadAction(
      manifestBoardId: decoded.manifest.boardId,
      existingBoardIds: existingBoardIds,
    );
    try {
      final BoardBackupSummary summary;
      if (action == LoadFileAction.updateExisting) {
        summary = await updateBoardFromBackup(
          ref,
          decoded.manifest.boardId!,
          bytes,
        );
        updated++;
      } else {
        summary = await importBoardBackup(ref, bytes);
        existingBoardIds.add(summary.boardId);
        created++;
      }
      processedCount++;
      onlySummary = summary;
    } catch (e) {
      errors.add('$fileName: $e');
    }
  }

  if (!context.mounted) return;

  // Only switch the open board when Load processed exactly one file - with
  // more than one, jumping to "whichever happened to be processed last"
  // would be an arbitrary surprise; the summary dialog is enough.
  if (processedCount == 1 && onlySummary != null) {
    ref.read(currentBoardIdProvider.notifier).state = onlySummary.boardId;
  }

  final parts = <String>[
    if (created > 0) 'created $created board${created == 1 ? '' : 's'}',
    if (updated > 0) 'updated $updated board${updated == 1 ? '' : 's'}',
  ];
  if (parts.isEmpty && errors.isEmpty) parts.add('no .hbbackup files found');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Load from folder'),
      content: Text(
        [
          'Loaded from $folderPath: ${parts.join(', ')}.',
          if (errors.isNotEmpty) ...["\nCouldn't read:", ...errors],
        ].join('\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// File menu "Backup folder..." - shows the current path (or "Not set
/// yet"), lets the user change it, and opens it in the OS file manager.
/// Same construction style as `board_switcher.dart`'s `_ManageBoardsDialog`.
Future<void> showBackupFolderDialog(BuildContext context, WidgetRef ref) async {
  var currentPath = await ref
      .read(appSettingsRepositoryProvider)
      .getBackupFolderPath();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Backup folder'),
        content: Text(currentPath ?? 'Not set yet'),
        actions: [
          TextButton(
            onPressed: () async {
              final picked = await pickBackupFolder(dialogContext);
              if (picked == null) return;
              await ref
                  .read(appSettingsRepositoryProvider)
                  .setBackupFolderPath(picked);
              setState(() => currentPath = picked);
            },
            child: const Text('Change folder...'),
          ),
          TextButton(
            onPressed: currentPath == null
                ? null
                : () => _openInFileManager(dialogContext, currentPath!),
            child: const Text('Open in file manager'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

/// Opens [path] in the OS file manager, falling back to a SnackBar with
/// the raw path if the OS launch itself fails - same pattern the old
/// "Show Backups..." used.
Future<void> _openInFileManager(BuildContext context, String path) async {
  bool opened;
  try {
    opened = await launchUrl(Uri.file(path));
  } catch (_) {
    opened = false;
  }
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Backup folder: $path')));
}
