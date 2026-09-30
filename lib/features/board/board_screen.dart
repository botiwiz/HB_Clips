import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/color_swatch_button.dart';
import '../../data/local/database.dart' show FrameRow;
import '../../data/models/clip.dart';
import '../../data/models/connector.dart';
import '../../data/pdf/pdf_writer.dart';
import '../../data/providers.dart';
import '../../data/pureref/pur_writer.dart';
import '../../data/repositories/clips_repository.dart';
import '../about/about_screen.dart';
import '../annotation/controllers/annotation_controller.dart';
import '../annotation/draw_toolbar.dart';
import '../annotation/stroke_painter.dart' show hexToColor;
import '../bin/bin_screen.dart';
import 'controllers/board_controller.dart';
import 'controllers/undo_controller.dart';
import 'geometry/frame_geometry.dart';
import 'geometry/frame_presets.dart';
import 'geometry/selection_geometry.dart';
import 'services/add_image_service.dart' show pushAddClipUndo;
import 'services/clipboard_paste_service.dart';
import 'services/image_size_service.dart';
import 'services/pureref_import_service.dart';
import 'services/save_file_service.dart';
import 'widgets/board_canvas.dart';
import 'widgets/board_switcher.dart';
import 'widgets/board_toolbar.dart';
import 'widgets/gif_playback_toolbar.dart';

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
        withData: true,
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
    final picked = result?.files.single;
    final pickedBytes = picked?.bytes;
    if (picked == null || pickedBytes == null) return;

    final id = _uuid.v4();
    final ext = p.extension(picked.name);
    final destPath = await ref
        .read(localBlobStoreProvider)
        .writeBytes(pickedBytes, extension: ext);

    if (!context.mounted) return;
    final center = _viewportCenterBoardPoint(ref, MediaQuery.sizeOf(context));

    final clipSize = clipSizeForImageBytes(pickedBytes);
    await ref
        .read(clipsRepositoryProvider)
        .addImageClip(
          id: id,
          boardId: ref.read(currentBoardIdProvider),
          localFilePath: destPath,
          x: center.dx - clipSize.width / 2,
          y: center.dy - clipSize.height / 2,
          width: clipSize.width,
          height: clipSize.height,
          imageAspectRatio: imageAspectRatioForBytes(pickedBytes),
        );
    pushAddClipUndo(ref, id);
  }

  Future<void> _importPurFile(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pur'],
        withData: true,
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
    final pickedBytes = result?.files.single.bytes;
    if (pickedBytes == null) return;
    if (!context.mounted) return;

    final summary = await importPurFile(context, ref, pickedBytes);
    if (summary == null || !context.mounted) return;

    final parts = <String>[
      '${summary.imagesImported} image${summary.imagesImported == 1 ? '' : 's'}',
      '${summary.textNotesImported} text note${summary.textNotesImported == 1 ? '' : 's'}',
    ];
    if (summary.imagesUnrecoverable > 0) {
      parts.add(
        "${summary.imagesUnrecoverable} image${summary.imagesUnrecoverable == 1 ? '' : 's'} "
        "couldn't be recovered (no local copy embedded in this file)",
      );
    }
    if (summary.imagesRecoveredWithoutPosition > 0) {
      parts.add(
        "${summary.imagesRecoveredWithoutPosition} image${summary.imagesRecoveredWithoutPosition == 1 ? '' : 's'} "
        "recovered without their original position (arranged in a grid - "
        "this board's project database was too large to fully embed in "
        "the export)",
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

  Future<void> _exportPurFile(BuildContext context, WidgetRef ref) async {
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final blobStore = ref.read(localBlobStoreProvider);
    final result = await writePurFile(clips, readBytes: blobStore.readBytes);
    if (!context.mounted) return;

    String? savePath;
    try {
      savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export board as .pur',
        fileName: 'board.pur',
        type: FileType.custom,
        allowedExtensions: ['pur'],
        bytes: result.bytes,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the save dialog. On Linux this needs zenity "
            '(or kdialog) installed.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (savePath == null) return;
    if (!savePath.toLowerCase().endsWith('.pur')) {
      savePath = '$savePath.pur';
    }
    await writeBytesToPath(savePath, result.bytes);
    if (!context.mounted) return;

    final summary = result.summary;
    final parts = <String>[
      '${summary.imagesExported} image${summary.imagesExported == 1 ? '' : 's'}',
      '${summary.textNotesExported} text note${summary.textNotesExported == 1 ? '' : 's'}',
    ];
    if (summary.imagesSkipped > 0) {
      parts.add(
        '${summary.imagesSkipped} image${summary.imagesSkipped == 1 ? '' : 's'} skipped (unreadable file)',
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export complete'),
        content: Text('Exported ${parts.join(', ')}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdfFile(BuildContext context, WidgetRef ref) async {
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    final strokes = ref.read(boardStrokesProvider).valueOrNull ?? [];
    final blobStore = ref.read(localBlobStoreProvider);
    final result = await writePdfFile(
      frames: frames,
      clips: clips,
      strokes: strokes,
      readBytes: blobStore.readBytes,
    );
    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }

    String? savePath;
    try {
      savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export board as .pdf',
        fileName: 'board.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: result.bytes,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the save dialog. On Linux this needs zenity "
            '(or kdialog) installed.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (savePath == null) return;
    if (!savePath.toLowerCase().endsWith('.pdf')) {
      savePath = '$savePath.pdf';
    }
    await writeBytesToPath(savePath, result.bytes);
    if (!context.mounted) return;

    final summary = result.summary;
    final pageCount = summary.framePages + (summary.hasOverviewPage ? 1 : 0);
    final parts = <String>[
      '$pageCount page${pageCount == 1 ? '' : 's'}',
      '${summary.imagesDrawn} image${summary.imagesDrawn == 1 ? '' : 's'}',
    ];
    if (summary.imagesSkipped > 0) {
      parts.add(
        '${summary.imagesSkipped} image${summary.imagesSkipped == 1 ? '' : 's'} skipped (unreadable file)',
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export complete'),
        content: Text('Exported ${parts.join(', ')}.'),
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
    final center = _viewportCenterBoardPoint(ref, MediaQuery.sizeOf(context));
    await ref
        .read(clipsRepositoryProvider)
        .addTextNote(
          id: id,
          boardId: ref.read(currentBoardIdProvider),
          textContent: text.trim(),
          x: center.dx - kDefaultTextNoteWidth / 2,
          y: center.dy - kDefaultTextNoteHeight / 2,
        );
    pushAddClipUndo(ref, id);
  }

  void _selectAll(WidgetRef ref) {
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    ref.read(selectedClipIdsProvider.notifier).state = clips
        .map((c) => c.id)
        .toSet();
  }

  void _binSelected(WidgetRef ref) {
    // A selected connector takes priority over a clip selection - the two
    // are mutually exclusive per `board_canvas.dart`'s click-to-select
    // rules, so this is just precedence, not a real conflict.
    final selectedConnectorId = ref.read(selectedConnectorIdProvider);
    if (selectedConnectorId != null) {
      final connectors = ref.read(activeConnectorsProvider).valueOrNull ?? [];
      Connector? connector;
      for (final c in connectors) {
        if (c.id == selectedConnectorId) {
          connector = c;
          break;
        }
      }
      final connRepo = ref.read(connectorsRepositoryProvider);
      connRepo.deleteConnector(selectedConnectorId);
      ref.read(selectedConnectorIdProvider.notifier).state = null;
      if (connector != null) {
        final c = connector;
        ref
            .read(undoManagerProvider.notifier)
            .push(
              UndoableAction(
                undo: () => connRepo.addConnector(
                  id: c.id,
                  boardId: c.boardId,
                  fromClipId: c.fromClipId,
                  fromSide: c.fromSide,
                  toClipId: c.toClipId,
                  toRelX: c.toRelX,
                  toRelY: c.toRelY,
                ),
                redo: () => connRepo.deleteConnector(c.id),
              ),
            );
      }
      return;
    }

    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final repo = ref.read(clipsRepositoryProvider);
    final ids = selection.toList();
    for (final id in ids) {
      repo.binClip(id);
    }
    ref.read(selectedClipIdsProvider.notifier).state = {};
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () =>
                Future.wait([for (final id in ids) repo.restoreClip(id)]),
            redo: () => Future.wait([for (final id in ids) repo.binClip(id)]),
          ),
        );
  }

  void _nudgeSelection(WidgetRef ref, Offset delta) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final repo = ref.read(clipsRepositoryProvider);
    final before = <String, Offset>{};
    final after = <String, Offset>{};
    for (final id in selection) {
      final clip = ClipGeometry.findById(clips, id);
      if (clip == null) continue;
      before[id] = Offset(clip.x, clip.y);
      final next = Offset(clip.x + delta.dx, clip.y + delta.dy);
      after[id] = next;
      repo.updateTransform(id, x: next.dx, y: next.dy);
    }
    if (before.isEmpty) return;
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              for (final entry in before.entries)
                repo.updateTransform(
                  entry.key,
                  x: entry.value.dx,
                  y: entry.value.dy,
                ),
            ]),
            redo: () => Future.wait([
              for (final entry in after.entries)
                repo.updateTransform(
                  entry.key,
                  x: entry.value.dx,
                  y: entry.value.dy,
                ),
            ]),
          ),
        );
  }

  /// Handles bare/shift Backspace, Delete, and the 4 arrow keys as a
  /// `Focus.onKeyEvent` (not a `CallbackShortcuts` binding) specifically
  /// so it can conditionally ignore the event - a plain `CallbackShortcuts`
  /// binding always marks a match "handled" and stops it there, which
  /// would permanently block these keys from ever reaching Flutter's
  /// `DefaultTextEditingShortcuts` (mounted once at the app root - see
  /// `text_clip_edit_overlay.dart`'s doc comment on why its own
  /// `CallbackShortcuts` deliberately does NOT bind these keys either).
  /// While a text note is being edited, these keys are for the TextField
  /// itself (delete a character, move the caret) - ignored here so they
  /// keep bubbling up to that root-level handling. Outside of editing,
  /// they bin the selection / nudge it, exactly as before.
  KeyEventResult _handleEditAwareShortcut(WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isBinKey =
        key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete;
    final isArrowKey =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
    if (!isBinKey && !isArrowKey) return KeyEventResult.ignored;
    if (ref.read(editingTextClipIdProvider) != null) {
      return KeyEventResult.ignored;
    }
    if (isBinKey) {
      _binSelected(ref);
      return KeyEventResult.handled;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final step = shift ? _nudgeStepFast : _nudgeStep;
    final delta = switch (key) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => Offset.zero,
    };
    _nudgeSelection(ref, delta);
    return KeyEventResult.handled;
  }

  void _toggleDrawMode(WidgetRef ref) {
    final next = !ref.read(isDrawModeProvider);
    ref.read(isDrawModeProvider.notifier).state = next;
    if (next) {
      ref.read(selectedClipIdsProvider.notifier).state = {};
      ref.read(isTextToolActiveProvider.notifier).state = false;
    }
  }

  void _toggleTextTool(WidgetRef ref) {
    final next = !ref.read(isTextToolActiveProvider);
    ref.read(isTextToolActiveProvider.notifier).state = next;
    if (next) {
      ref.read(selectedClipIdsProvider.notifier).state = {};
      ref.read(isDrawModeProvider.notifier).state = false;
    }
  }

  void _applyZOrder(
    WidgetRef ref,
    Future<void> Function(ClipsRepository repo, String id, String boardId)
    action,
  ) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final repo = ref.read(clipsRepositoryProvider);
    final boardId = ref.read(currentBoardIdProvider);
    for (final id in selection) {
      action(repo, id, boardId);
    }
  }

  void _groupSelection(WidgetRef ref) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.length < 2) return;
    ref.read(clipsRepositoryProvider).groupClips(selection.toList());
  }

  void _ungroupSelection(WidgetRef ref, String groupId) {
    ref.read(clipsRepositoryProvider).ungroupClips(groupId);
  }

  Future<void> _addFrame(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Frame');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New frame'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Frame name'),
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
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;

    final center = _viewportCenterBoardPoint(ref, MediaQuery.sizeOf(context));
    await ref
        .read(framesRepositoryProvider)
        .createFrame(
          id: _uuid.v4(),
          boardId: ref.read(currentBoardIdProvider),
          name: name.trim(),
          x: center.dx - 160,
          y: center.dy - 120,
          width: 320,
          height: 240,
        );
  }

  Future<void> _renameFrame(
    BuildContext context,
    WidgetRef ref,
    FrameRow frame,
  ) async {
    final controller = TextEditingController(text: frame.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename frame'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    await ref.read(framesRepositoryProvider).renameFrame(frame.id, name.trim());
  }

  void _deleteFrame(WidgetRef ref, String frameId) {
    ref.read(framesRepositoryProvider).deleteFrame(frameId);
    ref.read(selectedFrameIdProvider.notifier).state = null;
  }

  Future<void> _setFrameColor(
    BuildContext context,
    WidgetRef ref,
    FrameRow frame,
  ) async {
    final repo = ref.read(framesRepositoryProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frame color'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorSwatchButton(
              color: AppTheme.textSecondary,
              selected: frame.backgroundColorHex == null,
              onTap: () {
                repo.updateColor(frame.id, null);
                Navigator.of(context).pop();
              },
            ),
            for (final colorHex in kStrokeColorPalette)
              ColorSwatchButton(
                color: hexToColor(colorHex),
                selected: frame.backgroundColorHex == colorHex,
                onTap: () {
                  repo.updateColor(frame.id, colorHex);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyFramePreset(
    WidgetRef ref,
    FrameRow frame,
    FramePreset preset,
  ) async {
    final startRect = FrameGeometry.boardRect(frame);
    final newRect = Rect.fromLTWH(
      startRect.left,
      startRect.top,
      preset.width,
      preset.height,
    );
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final children = {
      for (final c in clips)
        if (c.frameId == frame.id) c.id: c,
    };
    final scaled = FrameGeometry.scaleChildren(
      startClips: children,
      startRect: startRect,
      newRect: newRect,
    );

    await ref
        .read(framesRepositoryProvider)
        .updateTransform(frame.id, width: preset.width, height: preset.height);
    for (final entry in scaled.entries) {
      await ref
          .read(clipsRepositoryProvider)
          .updateTransform(
            entry.key,
            x: entry.value.x,
            y: entry.value.y,
            width: entry.value.width,
            height: entry.value.height,
          );
    }
  }

  Future<void> _pickFramePreset(
    BuildContext context,
    WidgetRef ref,
    FrameRow frame,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frame size preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in kFramePresets)
              ListTile(
                title: Text(preset.label),
                onTap: () {
                  _applyFramePreset(ref, frame, preset);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Undo history is only meaningful within the board it was recorded
    // against - actions reference specific clip/connector ids, which make
    // no sense replayed after switching to a different board.
    ref.listen(currentBoardIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        ref.read(undoManagerProvider.notifier).clear();
      }
    });
    final undoState = ref.watch(undoManagerProvider);
    final selection = ref.watch(selectedClipIdsProvider);
    final hasSelection = selection.isNotEmpty;
    final isDrawMode = ref.watch(isDrawModeProvider);
    final isTextToolActive = ref.watch(isTextToolActiveProvider);
    final panZoomClipId = ref.watch(panZoomClipIdProvider);
    final snapToGrid = ref.watch(snapToGridProvider);
    final framesPanelOpen = ref.watch(framesPanelOpenProvider);
    final selectedFrameId = ref.watch(selectedFrameIdProvider);
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    FrameRow? selectedFrame;
    for (final f in frames) {
      if (f.id == selectedFrameId) {
        selectedFrame = f;
        break;
      }
    }
    final clips = ref.watch(activeClipsProvider).valueOrNull ?? [];
    final selectedClips = [
      for (final c in clips)
        if (selection.contains(c.id)) c,
    ];
    final canGroup = selection.length >= 2;
    final commonGroupId = selectedClips.isNotEmpty
        ? selectedClips.first.groupId
        : null;
    final canUngroup =
        commonGroupId != null &&
        selectedClips.every((c) => c.groupId == commonGroupId);
    final canPlayGif =
        !isDrawMode &&
        !isTextToolActive &&
        panZoomClipId == null &&
        selectedClips.length == 1 &&
        selectedClips.first.type == ClipType.image &&
        (selectedClips.first.localFilePath?.toLowerCase().endsWith('.gif') ??
            false);

    return Scaffold(
      body: Focus(
        onKeyEvent: (node, event) => _handleEditAwareShortcut(ref, event),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                ref.read(undoManagerProvider.notifier).undo(),
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
                ref.read(undoManagerProvider.notifier).undo(),
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): () =>
                ref.read(undoManagerProvider.notifier).redo(),
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              meta: true,
              shift: true,
            ): () =>
                ref.read(undoManagerProvider.notifier).redo(),
            // Windows' other common redo convention, alongside Ctrl+Shift+Z.
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
                ref.read(undoManagerProvider.notifier).redo(),
            const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
                _selectAll(ref),
            const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
                _selectAll(ref),
            const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
                pasteImageFromClipboard(context, ref),
            const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
                pasteImageFromClipboard(context, ref),
          },
          child: Stack(
            children: [
              const Positioned.fill(child: BoardCanvas()),
              Positioned(
                top: 16,
                left: 16,
                // Reserves room for the independent Bin/About pill anchored
                // to this same row's right edge below, so the two can never
                // visually overlap - PillGroup's own internal horizontal
                // scroll continues to absorb overflow on this side exactly
                // as it does today if this button set grows.
                right: 116,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BoardSwitcher(),
                    const SizedBox(width: 8),
                    Flexible(
                      child: PillGroup(
                        children: [
                          PillIconButton(
                            tooltip: 'Undo',
                            icon: Icons.arrow_back,
                            onPressed: undoState.canUndo
                                ? () => ref
                                      .read(undoManagerProvider.notifier)
                                      .undo()
                                : null,
                          ),
                          // TEMPORARY diagnostic (Part 17B) - a loud
                          // background behind the reportedly-invisible
                          // redo icon, to tell apart "the icon/color
                          // isn't rendering" (this box shows, empty)
                          // from "nothing here is rendering at all"
                          // (this box doesn't show either). Revert once
                          // we have an answer.
                          ColoredBox(
                            color: Colors.yellow,
                            child: PillIconButton(
                              tooltip: 'Redo',
                              icon: Icons.arrow_forward,
                              onPressed: undoState.canRedo
                                  ? () => ref
                                        .read(undoManagerProvider.notifier)
                                        .redo()
                                  : null,
                            ),
                          ),
                          PillIconButton(
                            tooltip: isDrawMode
                                ? 'Exit draw mode'
                                : 'Draw / annotate',
                            icon: isDrawMode ? Icons.edit : Icons.edit_outlined,
                            color: isDrawMode ? AppTheme.red : null,
                            onPressed: () => _toggleDrawMode(ref),
                          ),
                          PillIconButton(
                            tooltip: isTextToolActive
                                ? 'Cancel text tool'
                                : 'Text tool',
                            icon: Icons.text_fields,
                            color: isTextToolActive ? AppTheme.red : null,
                            onPressed: () => _toggleTextTool(ref),
                          ),
                          PillIconButton(
                            tooltip: snapToGrid
                                ? 'Disable snap to grid'
                                : 'Snap to grid',
                            icon: snapToGrid ? Icons.grid_on : Icons.grid_off,
                            color: snapToGrid ? AppTheme.red : null,
                            onPressed: () =>
                                ref.read(snapToGridProvider.notifier).state =
                                    !snapToGrid,
                          ),
                          if (!isDrawMode &&
                              !isTextToolActive &&
                              hasSelection) ...[
                            if (canGroup)
                              PillIconButton(
                                tooltip: 'Group',
                                icon: Icons.group_work_outlined,
                                onPressed: () => _groupSelection(ref),
                              ),
                            if (canUngroup)
                              PillIconButton(
                                tooltip: 'Ungroup',
                                icon: Icons.group_off_outlined,
                                onPressed: () =>
                                    _ungroupSelection(ref, commonGroupId),
                              ),
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
                          if (selectedFrame != null) ...[
                            PillIconButton(
                              tooltip: 'Rename frame',
                              icon: Icons.edit_outlined,
                              onPressed: () =>
                                  _renameFrame(context, ref, selectedFrame!),
                            ),
                            PillIconButton(
                              tooltip: 'Frame color',
                              icon: Icons.palette_outlined,
                              onPressed: () =>
                                  _setFrameColor(context, ref, selectedFrame!),
                            ),
                            PillIconButton(
                              tooltip: 'Frame size preset',
                              icon: Icons.aspect_ratio,
                              onPressed: () => _pickFramePreset(
                                context,
                                ref,
                                selectedFrame!,
                              ),
                            ),
                            PillIconButton(
                              tooltip: 'Delete frame',
                              icon: Icons.delete_outline,
                              onPressed: () =>
                                  _deleteFrame(ref, selectedFrame!.id),
                            ),
                          ],
                          PillIconButton(
                            tooltip: 'New frame',
                            icon: Icons.crop_5_4_outlined,
                            onPressed: () => _addFrame(context, ref),
                          ),
                          PillIconButton(
                            tooltip: framesPanelOpen
                                ? 'Hide frames panel'
                                : 'Show frames panel',
                            icon: Icons.view_list_outlined,
                            color: framesPanelOpen ? AppTheme.red : null,
                            onPressed: () =>
                                ref
                                        .read(framesPanelOpenProvider.notifier)
                                        .state =
                                    !framesPanelOpen,
                          ),
                          PillIconButton(
                            tooltip: 'Paste image (Ctrl+V)',
                            icon: Icons.content_paste_outlined,
                            onPressed: () =>
                                pasteImageFromClipboard(context, ref),
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
                          PillIconButton(
                            tooltip: 'Export board as .pur',
                            icon: Icons.file_download_outlined,
                            onPressed: () => _exportPurFile(context, ref),
                          ),
                          PillIconButton(
                            tooltip: 'Export board as .pdf',
                            icon: Icons.picture_as_pdf_outlined,
                            onPressed: () => _exportPdfFile(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: PillGroup(
                  children: [
                    PillIconButton(
                      tooltip: 'Bin',
                      icon: Icons.delete_outline,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BinScreen()),
                      ),
                    ),
                    PillIconButton(
                      tooltip: 'About',
                      icon: Icons.info_outline,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDrawMode)
                const Positioned(
                  top: 76,
                  left: 0,
                  right: 0,
                  child: Center(child: DrawToolbar()),
                ),
              if (canPlayGif)
                Positioned(
                  top: 76,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GifPlaybackToolbar(clip: selectedClips.first),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
