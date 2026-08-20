import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../data/repositories/clips_repository.dart';
import '../about/about_screen.dart';
import '../bin/bin_screen.dart';
import 'controllers/board_controller.dart';
import 'widgets/board_canvas.dart';
import 'widgets/clip_counter_badge.dart';

const _uuid = Uuid();

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  Offset _viewportCenterBoardPoint(WidgetRef ref, Size screenSize) {
    final view = ref.read(boardViewProvider);
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    return (screenCenter - view.panOffset) / view.scale;
  }

  Future<void> _addImageClip(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
    } catch (error) {
      // On Linux, file_picker shells out to zenity/kdialog for the native
      // file dialog; on a system without either installed this throws
      // instead of returning null, so it needs its own handling.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the file picker. On Linux this needs zenity "
            '(or kdialog) installed.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    final pickedPath = result?.files.single.path;
    if (pickedPath == null) return;

    final id = _uuid.v4();
    final supportDir = await getApplicationSupportDirectory();
    final clipsDir = Directory(p.join(supportDir.path, 'clips'));
    await clipsDir.create(recursive: true);
    final ext = p.extension(pickedPath);
    final destPath = p.join(clipsDir.path, '$id$ext');
    await File(pickedPath).copy(destPath);

    if (!context.mounted) return;
    final center = _viewportCenterBoardPoint(
      ref,
      MediaQuery.sizeOf(context),
    );

    try {
      await ref
          .read(clipsRepositoryProvider)
          .addImageClip(
            id: id,
            boardId: kLocalBoardId,
            localFilePath: destPath,
            x: center.dx - kDefaultClipWidth / 2,
            y: center.dy - kDefaultClipHeight / 2,
          );
    } on ClipCapExceededException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You\'ve reached the $kMaxImageClips image clip limit. '
            'Bin or delete one to add another.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _addTextNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New text note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Type a note...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;

    final id = _uuid.v4();
    final center = _viewportCenterBoardPoint(
      ref,
      MediaQuery.sizeOf(context),
    );
    await ref
        .read(clipsRepositoryProvider)
        .addTextNote(
          id: id,
          boardId: kLocalBoardId,
          textContent: text.trim(),
          x: center.dx - kDefaultTextNoteWidth / 2,
          y: center.dy - kDefaultTextNoteHeight / 2,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HB_Clips'),
        actions: [
          const ClipCounterBadge(),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Add text note',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => _addTextNote(context, ref),
          ),
          IconButton(
            tooltip: 'Add image clip',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _addImageClip(context, ref),
          ),
          IconButton(
            tooltip: 'Bin',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BinScreen()),
            ),
          ),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const BoardCanvas(),
    );
  }
}
