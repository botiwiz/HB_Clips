import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../controllers/board_controller.dart';
import 'add_image_service.dart';
import 'image_file_formats.dart';
import 'link_preview_service.dart';

/// Reads an image off the OS clipboard (e.g. a pasted screenshot) and adds
/// it as a new image clip, or - if there's no image but the clipboard holds
/// plain text that looks like a URL - adds a link clip instead. Shared by
/// the Ctrl+V shortcut and the paste toolbar button so there is exactly one
/// code path.
Future<void> pasteFromClipboard(BuildContext context, WidgetRef ref) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    showBoardSnack(
      context,
      'Clipboard access is not available on this platform.',
    );
    return;
  }

  final reader = await clipboard.read();
  if (!context.mounted) return;

  final lastClick = ref.read(lastClickBoardPositionProvider);
  final Offset boardCenter;
  if (lastClick != null) {
    boardCenter = lastClick;
  } else {
    final size = MediaQuery.sizeOf(context);
    final screenCenter = Offset(size.width / 2, size.height / 2);
    final view = ref.read(boardViewProvider);
    boardCenter = (screenCenter - view.panOffset) / view.scale;
  }

  final matchedFormat = matchImageFormat(reader);
  if (matchedFormat != null) {
    final Uint8List? bytes;
    try {
      bytes = await readImageFileBytes(reader, matchedFormat);
    } catch (_) {
      if (!context.mounted) return;
      showBoardSnack(
        context,
        "Couldn't read the image from the clipboard.",
        isError: true,
      );
      return;
    }
    if (!context.mounted) return;
    if (bytes == null || bytes.isEmpty) {
      showBoardSnack(context, 'No image found on the clipboard.');
      return;
    }

    await addImageClipFromBytes(
      ref,
      bytes: bytes,
      extension: imageFileFormats[matchedFormat]!,
      boardCenter: boardCenter,
    );
    return;
  }

  final text = await _readPlainText(reader);
  if (text != null && looksLikeUrl(text)) {
    await addLinkClipFromUrl(ref, url: text.trim(), boardCenter: boardCenter);
    return;
  }

  if (!context.mounted) return;
  showBoardSnack(context, 'Nothing pasteable found on the clipboard.');
}

/// `getValue` is callback-based (same shape as `getFile`) - this wraps it
/// the same way `image_file_formats.dart`'s private `_readValue` does, for
/// `Formats.plainText`.
Future<String?> _readPlainText(DataReader reader) {
  if (!reader.canProvide(Formats.plainText)) return Future.value(null);
  final completer = Completer<String?>();
  final progress = reader.getValue<String>(
    Formats.plainText,
    (value) => completer.complete(value),
    onError: completer.completeError,
  );
  if (progress == null) completer.complete(null);
  return completer.future;
}
