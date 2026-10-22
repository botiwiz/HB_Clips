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
import '../widgets/duplicate_boards_dialog.dart';
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
/// Returns null if the user cancels, the picker itself couldn't open, or
/// the folder it handed back turns out not to actually be writable (see
/// below) - every failure path here already shows its own SnackBar, so
/// callers can treat a null return as "already explained, nothing more to
/// say."
Future<String?> pickBackupFolder(BuildContext context) async {
  final String? picked;
  try {
    picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a backup folder',
    );
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Couldn't open the folder picker. On Linux this needs zenity "
          '(or kdialog) installed.',
        ),
        backgroundColor: AppTheme.danger,
      ),
    );
    return null;
  }
  if (picked == null) return null;

  // Some file-picker backends (notably an xdg-desktop-portal-confined GTK
  // dialog on certain Linux desktops) can hand back a path that looks
  // valid but isn't actually writable by this process - silently adopting
  // it would make every later Save/Load fail with no visible reason at
  // all, exactly the "nothing happens" failure mode this probe exists to
  // catch right at the point of picking, instead of later and more
  // confusingly.
  try {
    await probeFolderWritable(picked);
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Can't write to $picked: $error"),
        backgroundColor: AppTheme.danger,
      ),
    );
    return null;
  }
  return picked;
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

/// A board name paired with the error that stopped it from being written -
/// see [saveAllBoardsToBackupFolder].
typedef SaveFailure = (String boardName, Object error);

/// How many boards [saveAllBoardsToBackupFolder] wrote successfully, plus
/// which ones (if any) failed and why - [saveAllBoards] surfaces
/// [failures] in its summary instead of only reporting a possibly-
/// confusing raw count.
typedef SaveAllBoardsResult = ({int written, List<SaveFailure> failures});

/// Writes every board's current state to
/// `<folderPath>/<sanitized board name>.hbbackup`, overwriting in place -
/// no run subfolder, no pruning, since there's only ever one file per
/// board now. Shared by [saveAllBoards] (the File menu action) and
/// [runAutoBackup] (the periodic scheduler). A failure on one board is
/// logged and skipped rather than aborting the rest - this is meant to be
/// a reliable background safety net, not an all-or-nothing transaction -
/// but is still collected and returned so a caller that wants to show the
/// user what went wrong (unlike the silent background scheduler) can.
Future<SaveAllBoardsResult> saveAllBoardsToBackupFolder(
  WidgetRef ref,
  String folderPath,
) async {
  final boards = ref.read(boardsProvider).valueOrNull ?? [];
  var written = 0;
  final failures = <SaveFailure>[];
  for (final board in boards) {
    try {
      final bytes = await exportBoardBackup(ref, board.id);
      final fileName =
          '${sanitizedBackupFileName(board.name)}.$kBoardBackupExtension';
      await writeBytesToPath(p.join(folderPath, fileName), bytes);
      written++;
    } catch (e, st) {
      debugPrint('[backup-folder] failed to save "${board.name}": $e\n$st');
      failures.add((board.name, e));
    }
  }
  return (written: written, failures: failures);
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
  final result = await saveAllBoardsToBackupFolder(ref, folderPath);
  if (!context.mounted) return;

  if (result.failures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${result.written} board'
          '${result.written == 1 ? '' : 's'} to $folderPath',
        ),
      ),
    );
    return;
  }

  // At least one board failed - a plain count would hide that something
  // is actually wrong, so switch to the same error-list dialog pattern
  // `loadBackupFolder` already uses for its own per-file failures.
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save to folder'),
      content: Text(
        [
          'Saved ${result.written} board${result.written == 1 ? '' : 's'} '
              'to $folderPath.',
          "\nCouldn't save:",
          for (final (boardName, error) in result.failures)
            '$boardName: $error',
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
    final result = await saveAllBoardsToBackupFolder(ref, folderPath);
    debugPrint(
      '[auto-backup] wrote ${result.written} board(s) to $folderPath'
      '${result.failures.isEmpty ? '' : ', ${result.failures.length} failed'}',
    );
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
  final createdBoardIds = <String>[];
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
        createdBoardIds.add(summary.boardId);
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
  if (!context.mounted || createdBoardIds.isEmpty) return;

  // Catches the legacy-import duplicate-board mechanism (a pre-boardId
  // .hbbackup export always creates new rather than updating) at the
  // moment it actually happens, rather than relying on the user to think
  // to check later via File > Find duplicates.
  final allBoards = ref.read(boardsProvider).valueOrNull ?? [];
  final namesById = {for (final b in allBoards) b.id: b.name.trim().toLowerCase()};
  final nameCounts = <String, int>{};
  for (final name in namesById.values) {
    nameCounts[name] = (nameCounts[name] ?? 0) + 1;
  }
  final hasCollision = createdBoardIds.any((id) {
    final name = namesById[id];
    return name != null && (nameCounts[name] ?? 0) > 1;
  });
  if (hasCollision && context.mounted) {
    await showDuplicateBoardsDialog(context, ref);
  }
}

/// Opens [path] in the OS file manager, falling back to a SnackBar with
/// the raw path if the OS launch itself fails - same pattern the old
/// "Show Backups..." used. Public - also called directly from the
/// Settings dialog's General section.
Future<void> openBackupFolderInFileManager(
  BuildContext context,
  String path,
) async {
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
