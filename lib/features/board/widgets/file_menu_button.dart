import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../services/backup_folder_service.dart';

/// A labeled "File" menu, separate from the main icon toolbar, for the
/// `.hbbackup` Load/Save actions - mirrors `BoardSwitcher`'s exact
/// `Material` + `PopupMenuButton` shape (same pill chrome, same icon+text
/// trigger convention) so it reads as part of the same UI family, just a
/// dedicated entry point for the one thing meant to be the primary,
/// always-findable way to persist a board's edits - previously three more
/// icon-only buttons buried in the big scrolling toolbar row, easy to
/// miss and hard to tell apart from PDF export/PureRef import.
///
/// "Load..."/"Save" both operate on one configured backup folder rather
/// than a per-board file dialog - see `backup_folder_service.dart`.
class FileMenuButton extends ConsumerWidget {
  const FileMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(kCornerRadius),
      elevation: 6,
      shadowColor: Colors.black54,
      child: PopupMenuButton<String>(
        tooltip: 'File',
        onSelected: (value) => _handleSelection(context, ref, value),
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'load',
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 20),
                SizedBox(width: 8),
                Text('Load...'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'save',
            child: Row(
              children: [
                Icon(Icons.save_outlined, size: 20),
                SizedBox(width: 8),
                Text('Save'),
              ],
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'backup_folder',
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 20),
                SizedBox(width: 8),
                Text('Backup folder...'),
              ],
            ),
          ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 20),
              SizedBox(width: 6),
              Text('File'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routes a selected menu value to its action and makes sure it can never
/// fail completely silently. `PopupMenuButton.onSelected` is a synchronous
/// callback, so without this wrapper any exception thrown anywhere inside
/// `loadBackupFolder`/`saveAllBoards`/`showBackupFolderDialog`'s await
/// chains (a desynced settings-table read, an unwritable folder a file
/// picker handed back, anything else) becomes an unhandled Future
/// rejection - logged to stderr only, invisible in a packaged release
/// build, which is exactly what made an earlier real-world report ("I
/// navigate to the folder and set it... but nothing happens") impossible
/// to diagnose from the user's side. Whatever the actual cause, the user
/// now always sees either a result or a real error message, never silence.
Future<void> _handleSelection(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  try {
    switch (value) {
      case 'load':
        await loadBackupFolder(context, ref);
      case 'save':
        await saveAllBoards(context, ref);
      case 'backup_folder':
        await showBackupFolderDialog(context, ref);
    }
  } catch (e, st) {
    debugPrint('[file-menu] "$value" failed: $e\n$st');
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Something went wrong'),
        content: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
