import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart' show kCornerRadius;
import '../../../core/theme/app_theme.dart';
import '../services/auto_backup_service.dart';
import '../services/board_backup_service.dart';

/// A labeled "File" menu, separate from the main icon toolbar, for the
/// `.hbbackup` Open/Save/Save As actions - mirrors `BoardSwitcher`'s
/// exact `Material` + `PopupMenuButton` shape (same pill chrome, same
/// icon+text trigger convention) so it reads as part of the same UI
/// family, just a dedicated entry point for the one thing meant to be
/// the primary, always-findable way to persist a board's edits -
/// previously three more icon-only buttons buried in the big scrolling
/// toolbar row, easy to miss and hard to tell apart from PDF export/
/// PureRef import.
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
        onSelected: (value) {
          switch (value) {
            case 'open':
              openBoardBackup(context, ref);
            case 'save':
              saveBoardBackup(context, ref);
            case 'save_as':
              saveBoardBackupAs(context, ref);
            case 'show_backups':
              showBackupsFolder(context, ref);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 20),
                SizedBox(width: 8),
                Text('Open...'),
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
          PopupMenuItem<String>(
            value: 'save_as',
            child: Row(
              children: [
                Icon(Icons.save_as_outlined, size: 20),
                SizedBox(width: 8),
                Text('Save As...'),
              ],
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'show_backups',
            child: Row(
              children: [
                Icon(Icons.history, size: 20),
                SizedBox(width: 8),
                Text('Show Backups...'),
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
