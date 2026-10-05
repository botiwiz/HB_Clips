import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/color_swatch_button.dart';
import '../../core/widgets/hsv_color_picker.dart';
import '../../data/local/database.dart' show FrameRow;
import '../../data/models/clip.dart';
import '../../data/models/connector.dart';
import '../../data/pdf/pdf_writer.dart';
import '../../data/providers.dart';
import '../../data/repositories/clips_repository.dart';
import '../about/about_screen.dart';
import '../annotation/controllers/annotation_controller.dart';
import '../annotation/draw_toolbar.dart';
import '../annotation/stroke_painter.dart' show colorToHex, hexToColor;
import '../bin/bin_screen.dart';
import 'controllers/board_controller.dart';
import 'controllers/undo_controller.dart';
import 'geometry/frame_geometry.dart';
import 'geometry/frame_presets.dart';
import 'geometry/selection_geometry.dart';
import 'services/add_image_service.dart' show pushAddClipUndo, pushAddClipsUndo;
import 'services/clipboard_paste_service.dart';
import 'services/image_size_service.dart';
import 'services/pureref_import_service.dart';
import 'services/save_file_service.dart';
import 'widgets/board_canvas.dart';
import 'widgets/board_switcher.dart';
import 'widgets/board_toolbar.dart';
import 'widgets/gif_playback_toolbar.dart';
import 'widgets/shape_tool_button.dart';

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

    if (summary.createdClipIds.isNotEmpty) {
      final repo = ref.read(clipsRepositoryProvider);
      final ids = summary.createdClipIds;
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => Future.wait([for (final id in ids) repo.binClip(id)]),
              redo: () =>
                  Future.wait([for (final id in ids) repo.restoreClip(id)]),
            ),
          );
    }

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

    // A selected frame (or several) also takes priority over a clip
    // selection, same precedence `_copySelection` already documents.
    final selectedFrameIds = ref.read(selectedFrameIdsProvider);
    if (selectedFrameIds.isNotEmpty) {
      _deleteFrames(ref, selectedFrameIds.toList());
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
    // A selected frame (or several) takes priority over a clip
    // selection, same precedence _binSelected/_copySelection already
    // document - arrow keys should move whichever is actually selected.
    final selectedFrameIds = ref.read(selectedFrameIdsProvider);
    if (selectedFrameIds.isNotEmpty) {
      final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
      final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
      final framesRepo = ref.read(framesRepositoryProvider);
      final repo = ref.read(clipsRepositoryProvider);
      final beforeFrames = <String, Offset>{};
      final afterFrames = <String, Offset>{};
      final beforeChildren = <String, Offset>{};
      final afterChildren = <String, Offset>{};
      for (final id in selectedFrameIds) {
        FrameRow? frame;
        for (final f in frames) {
          if (f.id == id) {
            frame = f;
            break;
          }
        }
        if (frame == null) continue;
        beforeFrames[id] = Offset(frame.x, frame.y);
        final next = Offset(frame.x + delta.dx, frame.y + delta.dy);
        afterFrames[id] = next;
        framesRepo.updateTransform(id, x: next.dx, y: next.dy);
        for (final c in clips) {
          if (c.frameId != id) continue;
          beforeChildren[c.id] = Offset(c.x, c.y);
          final childNext = Offset(c.x + delta.dx, c.y + delta.dy);
          afterChildren[c.id] = childNext;
          repo.updateTransform(c.id, x: childNext.dx, y: childNext.dy);
        }
      }
      if (beforeFrames.isEmpty) return;
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => Future.wait([
                for (final entry in beforeFrames.entries)
                  framesRepo.updateTransform(
                    entry.key,
                    x: entry.value.dx,
                    y: entry.value.dy,
                  ),
                for (final entry in beforeChildren.entries)
                  repo.updateTransform(
                    entry.key,
                    x: entry.value.dx,
                    y: entry.value.dy,
                  ),
              ]),
              redo: () => Future.wait([
                for (final entry in afterFrames.entries)
                  framesRepo.updateTransform(
                    entry.key,
                    x: entry.value.dx,
                    y: entry.value.dy,
                  ),
                for (final entry in afterChildren.entries)
                  repo.updateTransform(
                    entry.key,
                    x: entry.value.dx,
                    y: entry.value.dy,
                  ),
              ]),
            ),
          );
      return;
    }

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

  /// Board-space point a Ctrl+V paste should land at - the last-clicked
  /// board position, or the viewport center if nothing's been clicked
  /// yet. Same fallback `clipboard_paste_service.dart`'s image paste
  /// already uses, kept in sync with it deliberately (not extracted into
  /// a shared service for 6 lines, but should stay identical if either
  /// changes).
  Offset _pasteAnchor(BuildContext context, WidgetRef ref) {
    final lastClick = ref.read(lastClickBoardPositionProvider);
    if (lastClick != null) return lastClick;
    return _viewportCenterBoardPoint(ref, MediaQuery.sizeOf(context));
  }

  /// Snapshots whichever is currently selected - a frame (+ its
  /// children) takes priority over a clip selection, since
  /// `selectedFrameIdsProvider`/`selectedClipIdsProvider` aren't strictly
  /// enforced mutually-exclusive by every click path - into
  /// [copiedSelectionProvider], ready for [_pasteSelection]. A no-op if
  /// nothing is selected. Copying a frame is single-frame-only (same as
  /// renaming/color/preset) - with 2+ frames selected this falls through
  /// to the clip-selection check below, same as 0 selected frames today.
  void _copySelection(WidgetRef ref) {
    final selectedFrameIds = ref.read(selectedFrameIdsProvider);
    if (selectedFrameIds.length == 1) {
      final frameId = selectedFrameIds.first;
      final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
      FrameRow? frame;
      for (final f in frames) {
        if (f.id == frameId) {
          frame = f;
          break;
        }
      }
      if (frame == null) return;
      final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
      final children = clips.where((c) => c.frameId == frameId).toList();
      ref.read(copiedSelectionProvider.notifier).state = CopiedSelection(
        frame: frame,
        clips: children,
      );
      return;
    }

    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final copied = [
      for (final id in selection) ClipGeometry.findById(clips, id),
    ].whereType<BoardClip>().toList();
    if (copied.isEmpty) return;
    ref.read(copiedSelectionProvider.notifier).state = CopiedSelection(
      clips: copied,
    );
  }

  /// Pastes whatever [copiedSelectionProvider] holds, anchored at
  /// [_pasteAnchor] (preserving relative layout between multiple pasted
  /// clips, or between a pasted frame and its children). Falls back to
  /// the existing OS-clipboard image paste when nothing's been
  /// internally copied yet - this is the only remaining call site for
  /// [pasteImageFromClipboard].
  Future<void> _pasteSelection(BuildContext context, WidgetRef ref) async {
    final copied = ref.read(copiedSelectionProvider);
    if (copied == null) {
      await pasteImageFromClipboard(context, ref);
      return;
    }

    final anchor = _pasteAnchor(context, ref);
    final framesRepo = ref.read(framesRepositoryProvider);
    final clipsRepo = ref.read(clipsRepositoryProvider);

    final frame = copied.frame;
    if (frame != null) {
      final dx = anchor.dx - (frame.x + frame.width / 2);
      final dy = anchor.dy - (frame.y + frame.height / 2);
      final newFrameId = _uuid.v4();
      await framesRepo.duplicateFrame(
        frame,
        newId: newFrameId,
        x: frame.x + dx,
        y: frame.y + dy,
      );
      if (!context.mounted) return;
      final newChildIds = <String>[];
      for (final child in copied.clips) {
        final newChildId = _uuid.v4();
        await clipsRepo.duplicateClip(
          child,
          newId: newChildId,
          x: child.x + dx,
          y: child.y + dy,
          groupId: null,
          frameId: newFrameId,
        );
        if (!context.mounted) return;
        newChildIds.add(newChildId);
      }
      ref.read(selectedFrameIdsProvider.notifier).state = {newFrameId};
      ref.read(selectedClipIdsProvider.notifier).state = {};
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => Future.wait([
                framesRepo.deleteFrame(newFrameId),
                for (final id in newChildIds) clipsRepo.binClip(id),
              ]),
              redo: () => Future.wait([
                framesRepo.duplicateFrame(
                  frame,
                  newId: newFrameId,
                  x: frame.x + dx,
                  y: frame.y + dy,
                ),
                for (final id in newChildIds) clipsRepo.restoreClip(id),
              ]),
            ),
          );
      return;
    }

    final clips = copied.clips;
    if (clips.isEmpty) return;
    final minX = clips.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    final minY = clips.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    final maxX = clips
        .map((c) => c.x + c.width)
        .reduce((a, b) => a > b ? a : b);
    final maxY = clips
        .map((c) => c.y + c.height)
        .reduce((a, b) => a > b ? a : b);
    final dx = anchor.dx - (minX + maxX) / 2;
    final dy = anchor.dy - (minY + maxY) / 2;

    // Pasted clips always start ungrouped and unparented (frameId: null)
    // - simplest, matches the existing OS-clipboard image paste, which
    // never auto-parents into whatever frame it lands in either. Several
    // clips that all shared one group get one new shared group, so a
    // grouped selection pastes as a group too, just a different one from
    // the source.
    final sourceGroupIds = clips.map((c) => c.groupId).toSet();
    final pasteGroupId =
        clips.length > 1 &&
            sourceGroupIds.length == 1 &&
            sourceGroupIds.first != null
        ? _uuid.v4()
        : null;

    final newIds = <String>[];
    for (final clip in clips) {
      final newId = _uuid.v4();
      await clipsRepo.duplicateClip(
        clip,
        newId: newId,
        x: clip.x + dx,
        y: clip.y + dy,
        groupId: pasteGroupId,
        frameId: null,
      );
      if (!context.mounted) return;
      newIds.add(newId);
    }
    ref.read(selectedClipIdsProvider.notifier).state = newIds.toSet();
    pushAddClipsUndo(ref, newIds);
  }

  /// Handles bare/shift Backspace, Delete, the 4 arrow keys, and
  /// Ctrl/Cmd+C/+V as a `Focus.onKeyEvent` (not a `CallbackShortcuts`
  /// binding) specifically so it can conditionally ignore the event - a
  /// plain `CallbackShortcuts` binding always marks a match "handled" and
  /// stops it there, which would permanently block these keys from ever
  /// reaching Flutter's `DefaultTextEditingShortcuts` (mounted once at
  /// the app root - see `text_clip_edit_overlay.dart`'s doc comment on
  /// why its own `CallbackShortcuts` deliberately does NOT bind these
  /// keys either). While a text note is being edited, these keys are for
  /// the TextField itself (delete a character, move the caret, native
  /// text copy/paste) - ignored here so they keep bubbling up to that
  /// root-level handling. Outside of editing, they bin the selection /
  /// nudge it / copy-paste a clip or frame, exactly as before.
  KeyEventResult _handleEditAwareShortcut(
    BuildContext context,
    WidgetRef ref,
    KeyEvent event,
  ) {
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
    final modifierHeld =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isCopyKey = modifierHeld && key == LogicalKeyboardKey.keyC;
    final isPasteKey = modifierHeld && key == LogicalKeyboardKey.keyV;
    if (!isBinKey && !isArrowKey && !isCopyKey && !isPasteKey) {
      return KeyEventResult.ignored;
    }
    if (ref.read(editingTextClipIdProvider) != null) {
      return KeyEventResult.ignored;
    }
    if (isBinKey) {
      _binSelected(ref);
      return KeyEventResult.handled;
    }
    if (isCopyKey) {
      _copySelection(ref);
      return KeyEventResult.handled;
    }
    if (isPasteKey) {
      _pasteSelection(context, ref);
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

  Future<void> _applyZOrder(
    WidgetRef ref,
    Future<void> Function(ClipsRepository repo, String id, String boardId)
    action,
  ) async {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.isEmpty) return;
    final repo = ref.read(clipsRepositoryProvider);
    final boardId = ref.read(currentBoardIdProvider);
    final ids = selection.toList();
    final before = <String, int?>{
      for (final id in ids) id: await repo.getZIndex(id),
    };
    for (final id in ids) {
      await action(repo, id, boardId);
    }
    final after = <String, int?>{
      for (final id in ids) id: await repo.getZIndex(id),
    };
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              for (final id in ids)
                if (before[id] != null) repo.setZIndex(id, before[id]!),
            ]),
            redo: () => Future.wait([
              for (final id in ids)
                if (after[id] != null) repo.setZIndex(id, after[id]!),
            ]),
          ),
        );
  }

  void _groupSelection(WidgetRef ref) {
    final selection = ref.read(selectedClipIdsProvider);
    if (selection.length < 2) return;
    final ids = selection.toList();
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final before = <String, String?>{
      for (final id in ids) id: ClipGeometry.findById(clips, id)?.groupId,
    };
    final groupId = _uuid.v4();
    final repo = ref.read(clipsRepositoryProvider);
    repo.groupClips(ids, groupId);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              for (final id in ids) repo.setGroupId(id, before[id]),
            ]),
            redo: () => Future.wait([
              for (final id in ids) repo.setGroupId(id, groupId),
            ]),
          ),
        );
  }

  void _ungroupSelection(WidgetRef ref, String groupId) {
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final memberIds = [
      for (final c in clips)
        if (c.groupId == groupId) c.id,
    ];
    final repo = ref.read(clipsRepositoryProvider);
    repo.ungroupClips(groupId);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              for (final id in memberIds) repo.setGroupId(id, groupId),
            ]),
            redo: () => repo.ungroupClips(groupId),
          ),
        );
  }

  Future<void> _addFrame(BuildContext context, WidgetRef ref) async {
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    final trimmedName = FrameGeometry.nextAvailableFrameName(frames);

    final center = _viewportCenterBoardPoint(ref, MediaQuery.sizeOf(context));
    final id = _uuid.v4();
    final boardId = ref.read(currentBoardIdProvider);
    final x = center.dx - 160;
    final y = center.dy - 120;
    const width = 320.0;
    const height = 240.0;
    final framesRepo = ref.read(framesRepositoryProvider);
    await framesRepo.createFrame(
      id: id,
      boardId: boardId,
      name: trimmedName,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => framesRepo.deleteFrame(id),
            redo: () => framesRepo.createFrame(
              id: id,
              boardId: boardId,
              name: trimmedName,
              x: x,
              y: y,
              width: width,
              height: height,
            ),
          ),
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
    final beforeName = frame.name;
    final newName = name.trim();
    final framesRepo = ref.read(framesRepositoryProvider);
    await framesRepo.renameFrame(frame.id, newName);
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => framesRepo.renameFrame(frame.id, beforeName),
            redo: () => framesRepo.renameFrame(frame.id, newName),
          ),
        );
  }

  /// Deletes every frame in [frameIds] (each unparents its own children
  /// rather than deleting them, per `FramesRepository.deleteFrame`) and
  /// pushes one combined undo covering all of them - recreating each
  /// frame (+ its color) and re-parenting its children on undo, deleting
  /// them all again on redo. No confirmation dialog, matching the
  /// existing toolbar delete button's own unconfirmed-but-undoable
  /// behavior.
  void _deleteFrames(WidgetRef ref, List<String> frameIds) {
    final frames = ref.read(boardFramesProvider).valueOrNull ?? [];
    final clips = ref.read(activeClipsProvider).valueOrNull ?? [];
    final framesRepo = ref.read(framesRepositoryProvider);
    final clipsRepo = ref.read(clipsRepositoryProvider);

    final snapshots = <FrameRow>[];
    final childIdsByFrame = <String, List<String>>{};
    for (final frameId in frameIds) {
      FrameRow? frame;
      for (final f in frames) {
        if (f.id == frameId) {
          frame = f;
          break;
        }
      }
      if (frame == null) continue;
      snapshots.add(frame);
      childIdsByFrame[frameId] = [
        for (final c in clips)
          if (c.frameId == frameId) c.id,
      ];
    }
    if (snapshots.isEmpty) return;

    Future<void> restore(FrameRow f) async {
      await framesRepo.createFrame(
        id: f.id,
        boardId: f.boardId,
        name: f.name,
        x: f.x,
        y: f.y,
        width: f.width,
        height: f.height,
      );
      await Future.wait([
        if (f.backgroundColorHex != null)
          framesRepo.updateColor(f.id, f.backgroundColorHex),
        for (final childId in childIdsByFrame[f.id] ?? const [])
          clipsRepo.setFrameId(childId, f.id),
      ]);
    }

    for (final f in snapshots) {
      framesRepo.deleteFrame(f.id);
    }
    ref.read(selectedFrameIdsProvider.notifier).state = {};
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([for (final f in snapshots) restore(f)]),
            redo: () => Future.wait([
              for (final f in snapshots) framesRepo.deleteFrame(f.id),
            ]),
          ),
        );
  }

  void _deleteFrame(WidgetRef ref, String frameId) =>
      _deleteFrames(ref, [frameId]);

  /// Shows the frame-color picker as a plain `AlertDialog` (still modal -
  /// its barrier fully protects against `board_canvas.dart`'s own raw
  /// gesture `Listener` the way every modal dialog in this app already
  /// does, so no new click-through guard is needed), but with the HSV
  /// sliders shown inline via [InlineHsvPickerBar] instead of opening a
  /// SECOND, nested modal dialog - live-updating the frame's color as the
  /// user drags, same as every other color swatch in this app. One
  /// combined undo step covers the whole dialog session (whatever the
  /// color ends up as when it closes), rather than one per click.
  Future<void> _setFrameColor(
    BuildContext context,
    WidgetRef ref,
    FrameRow frame,
  ) async {
    final repo = ref.read(framesRepositoryProvider);
    final before = frame.backgroundColorHex;
    var pickerOpen = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final live = (ref.read(boardFramesProvider).valueOrNull ?? [])
              .firstWhere((f) => f.id == frame.id, orElse: () => frame);
          return AlertDialog(
            title: const Text('Frame color'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ColorSwatchButton(
                        color: AppTheme.textSecondary,
                        selected: live.backgroundColorHex == null,
                        onTap: () {
                          repo.updateColor(frame.id, null);
                          setState(() => pickerOpen = false);
                        },
                      ),
                      InlineColorPickerSwatch(
                        color: live.backgroundColorHex != null
                            ? hexToColor(live.backgroundColorHex!)
                            : AppTheme.surfaceCard,
                        open: pickerOpen,
                        onTap: () => setState(() => pickerOpen = !pickerOpen),
                      ),
                    ],
                  ),
                  if (pickerOpen) ...[
                    const SizedBox(height: 12),
                    InlineHsvPickerBar(
                      initialColor: live.backgroundColorHex != null
                          ? hexToColor(live.backgroundColorHex!)
                          : AppTheme.surfaceCard,
                      onChanged: (color) =>
                          repo.updateColor(frame.id, colorToHex(color)),
                      onDone: () => setState(() => pickerOpen = false),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    final liveFrames = ref.read(boardFramesProvider).valueOrNull ?? [];
    String? after;
    for (final f in liveFrames) {
      if (f.id == frame.id) {
        after = f.backgroundColorHex;
        break;
      }
    }
    if (before != after) {
      ref
          .read(undoManagerProvider.notifier)
          .push(
            UndoableAction(
              undo: () => repo.updateColor(frame.id, before),
              redo: () => repo.updateColor(frame.id, after),
            ),
          );
    }
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

    final framesRepo = ref.read(framesRepositoryProvider);
    final clipsRepo = ref.read(clipsRepositoryProvider);
    await framesRepo.updateTransform(
      frame.id,
      width: preset.width,
      height: preset.height,
    );
    for (final entry in scaled.entries) {
      await clipsRepo.updateTransform(
        entry.key,
        x: entry.value.x,
        y: entry.value.y,
        width: entry.value.width,
        height: entry.value.height,
      );
    }
    ref
        .read(undoManagerProvider.notifier)
        .push(
          UndoableAction(
            undo: () => Future.wait([
              framesRepo.updateTransform(
                frame.id,
                width: startRect.width,
                height: startRect.height,
              ),
              for (final entry in children.entries)
                clipsRepo.updateTransform(
                  entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                  width: entry.value.width,
                  height: entry.value.height,
                ),
            ]),
            redo: () => Future.wait([
              framesRepo.updateTransform(
                frame.id,
                width: preset.width,
                height: preset.height,
              ),
              for (final entry in scaled.entries)
                clipsRepo.updateTransform(
                  entry.key,
                  x: entry.value.x,
                  y: entry.value.y,
                  width: entry.value.width,
                  height: entry.value.height,
                ),
            ]),
          ),
        );
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
    final selectedFrameIds = ref.watch(selectedFrameIdsProvider);
    final frames = ref.watch(boardFramesProvider).valueOrNull ?? [];
    final selectedFrames = [
      for (final f in frames)
        if (selectedFrameIds.contains(f.id)) f,
    ];
    // Rename/color/preset stay single-frame-only actions (one text
    // field, one color, one size) - only Delete (just below) acts on
    // the whole selection.
    final selectedFrame = selectedFrames.length == 1
        ? selectedFrames.first
        : null;
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
        onKeyEvent: (node, event) =>
            _handleEditAwareShortcut(context, ref, event),
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
            // Ctrl/Cmd+C and +V are handled by _handleEditAwareShortcut
            // instead (above) - not as plain bindings here - since they
            // need to stay out of the way of native text copy/paste
            // while a note is being edited (see that method's doc
            // comment for why a CallbackShortcuts binding can't do that
            // conditionally).
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
                            icon: Icons.undo,
                            onPressed: undoState.canUndo
                                ? () => ref
                                      .read(undoManagerProvider.notifier)
                                      .undo()
                                : null,
                          ),
                          PillIconButton(
                            tooltip: 'Redo',
                            icon: Icons.redo,
                            onPressed: undoState.canRedo
                                ? () => ref
                                      .read(undoManagerProvider.notifier)
                                      .redo()
                                : null,
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
                          const ShapeToolButton(),
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
                              tooltip: 'Bring forward',
                              icon: Icons.arrow_upward,
                              onPressed: () => _applyZOrder(
                                ref,
                                (repo, id, boardId) =>
                                    repo.bringForward(id, boardId),
                              ),
                            ),
                            PillIconButton(
                              tooltip: 'Send backward',
                              icon: Icons.arrow_downward,
                              onPressed: () => _applyZOrder(
                                ref,
                                (repo, id, boardId) =>
                                    repo.sendBackward(id, boardId),
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
                                  _renameFrame(context, ref, selectedFrame),
                            ),
                            PillIconButton(
                              tooltip: 'Frame color',
                              icon: Icons.palette_outlined,
                              onPressed: () =>
                                  _setFrameColor(context, ref, selectedFrame),
                            ),
                            PillIconButton(
                              tooltip: 'Frame size preset',
                              icon: Icons.aspect_ratio,
                              onPressed: () =>
                                  _pickFramePreset(context, ref, selectedFrame),
                            ),
                            PillIconButton(
                              tooltip: 'Delete frame',
                              icon: Icons.delete_outline,
                              onPressed: () =>
                                  _deleteFrame(ref, selectedFrame.id),
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
