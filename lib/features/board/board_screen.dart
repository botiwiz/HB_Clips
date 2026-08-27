import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../data/repositories/clips_repository.dart';
import '../../main.dart';
import '../about/about_screen.dart';
import '../annotation/controllers/annotation_controller.dart';
import '../annotation/draw_toolbar.dart';
import '../bin/bin_screen.dart';
import 'controllers/board_controller.dart';
import 'geometry/selection_geometry.dart';
import 'services/clipboard_paste_service.dart';
import 'services/pureref_import_service.dart';
import 'widgets/board_canvas.dart';
import 'widgets/board_toolbar.dart';
import 'widgets/clip_counter_badge.dart';

const _uuid = Uuid();

/// Nudge distances (board-space pixels) for arrow-key movement.
const double _nudgeStep = 4;
const double _nudgeStepFast = 20;

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

  Future<void> _importPurFile(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pur'],
        withData: false,
      );
    } catch (error) {
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
    if (!context.mounted) return;

    final summary = await importPurFile(context, ref, pickedPath);
    if (summary == null || !context.mounted) return;

    final parts = <String>[
      '${summary.imagesImported} image${summary.imagesImported == 1 ? '' : 's'}',
      '${summary.textNotesImported} text note${summary.textNotesImported == 1 ? '' : 's'}',
    ];
    if (summary.imagesSkippedAtCap > 0) {
      parts.add(
        '${summary.imagesSkippedAtCap} image${summary.imagesSkippedAtCap == 1 ? '' : 's'} skipped (30-image limit reached)',
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import complete'),
        content: Text('Imported ${parts.join(', ')}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  void _selectAll(WidgetRef ref) {
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    ref.read(selectedClipIdsProvider.notifier).state = clips
        .map((c) => c.id)
        .toSet();
  }

  void _binSelected(WidgetRef ref) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final repo = ref.read(clipsRepositoryProvider);
    for (final id in selection) {
      repo.binClip(id);
    }
    ref.read(selectedClipIdsProvider.notifier).state = {};
  }

  void _nudgeSelection(WidgetRef ref, Offset delta) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final repo = ref.read(clipsRepositoryProvider);
    for (final id in selection) {
      final clip = ClipGeometry.findById(clips, id);
      if (clip == null) continue;
      repo.updateTransform(id, x: clip.x + delta.dx, y: clip.y + delta.dy);
    }
  }

  void _toggleDrawMode(WidgetRef ref) {
    final next = !ref.read(isDrawModeProvider);
    ref.read(isDrawModeProvider.notifier).state = next;
    if (next) {
      ref.read(selectedClipIdsProvider.notifier).state = {};
    }
  }

  void _applyZOrder(
    WidgetRef ref,
    Future<void> Function(ClipsRepository repo, String id, String boardId) action,
  ) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final repo = ref.read(clipsRepositoryProvider);
    for (final id in selection) {
      action(repo, id, kLocalBoardId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedClipIdsProvider);
    final hasSelection = selection.isNotEmpty;
    final isDrawMode = ref.watch(isDrawModeProvider);

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.delete): () =>
              _binSelected(ref),
          const SingleActivator(LogicalKeyboardKey.backspace): () =>
              _binSelected(ref),
          const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
              _selectAll(ref),
          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
              _selectAll(ref),
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
              pasteImageFromClipboard(context, ref),
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
              pasteImageFromClipboard(context, ref),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _nudgeSelection(ref, const Offset(-_nudgeStep, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _nudgeSelection(ref, const Offset(_nudgeStep, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _nudgeSelection(ref, const Offset(0, -_nudgeStep)),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _nudgeSelection(ref, const Offset(0, _nudgeStep)),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
              () => _nudgeSelection(ref, const Offset(-_nudgeStepFast, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
              () => _nudgeSelection(ref, const Offset(_nudgeStepFast, 0)),
          const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
              _nudgeSelection(ref, const Offset(0, -_nudgeStepFast)),
          const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
              () => _nudgeSelection(ref, const Offset(0, _nudgeStepFast)),
        },
        child: Stack(
          children: [
            const Positioned.fill(child: BoardCanvas()),
            Positioned(
              top: 16,
              left: 16,
              right: isDesktopPlatform ? 56 : 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PillGroup(
                    children: [
                      PillIconButton(
                        tooltip: isDrawMode
                            ? 'Exit draw mode'
                            : 'Draw / annotate',
                        icon: isDrawMode ? Icons.edit : Icons.edit_outlined,
                        color: isDrawMode ? AppTheme.red : null,
                        onPressed: () => _toggleDrawMode(ref),
                      ),
                      if (!isDrawMode && hasSelection) ...[
                        PillIconButton(
                          tooltip: 'Bring to front',
                          icon: Icons.flip_to_front_outlined,
                          onPressed: () => _applyZOrder(
                            ref,
                            (repo, id, boardId) =>
                                repo.bringToFront(id, boardId),
                          ),
                        ),
                        PillIconButton(
                          tooltip: 'Send to back',
                          icon: Icons.flip_to_back_outlined,
                          onPressed: () => _applyZOrder(
                            ref,
                            (repo, id, boardId) =>
                                repo.sendToBack(id, boardId),
                          ),
                        ),
                        PillIconButton(
                          tooltip: 'Bin selected',
                          icon: Icons.delete_sweep_outlined,
                          onPressed: () => _binSelected(ref),
                        ),
                      ],
                      PillIconButton(
                        tooltip: 'Paste image (Ctrl+V)',
                        icon: Icons.content_paste_outlined,
                        onPressed: () => pasteImageFromClipboard(context, ref),
                      ),
                      PillIconButton(
                        tooltip: 'Add text note',
                        icon: Icons.note_add_outlined,
                        onPressed: () => _addTextNote(context, ref),
                      ),
                      PillIconButton(
                        tooltip: 'Add image clip',
                        icon: Icons.add_photo_alternate_outlined,
                        onPressed: () => _addImageClip(context, ref),
                      ),
                      PillIconButton(
                        tooltip: 'Import PureRef (.pur) file',
                        icon: Icons.file_open_outlined,
                        onPressed: () => _importPurFile(context, ref),
                      ),
                    ],
                  ),
                  if (isDesktopPlatform)
                    Expanded(child: DragToMoveArea(child: SizedBox.expand()))
                  else
                    const Spacer(),
                  Row(
                    children: [
                      const ClipCounterBadge(),
                      const SizedBox(width: 8),
                      PillGroup(
                        children: [
                          PillIconButton(
                            tooltip: 'Bin',
                            icon: Icons.delete_outline,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BinScreen(),
                              ),
                            ),
                          ),
                          PillIconButton(
                            tooltip: 'About',
                            icon: Icons.info_outline,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isDesktopPlatform)
              const Positioned(
                top: 16,
                right: 12,
                child: WindowCloseButton(),
              ),
            if (isDrawMode)
              const Positioned(
                top: 76,
                left: 0,
                right: 0,
                child: Center(child: DrawToolbar()),
              ),
          ],
        ),
      ),
    );
  }
}
