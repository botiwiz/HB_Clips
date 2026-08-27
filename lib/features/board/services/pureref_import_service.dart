import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';
import '../../../data/pureref/pur_file.dart';
import '../../../data/pureref/pur_reader.dart';
import '../../../data/repositories/clips_repository.dart';

const _uuid = Uuid();

/// Counts from one `.pur` import, shown to the user in a summary dialog -
/// deliberately not silent, since a large PureRef board can easily exceed
/// the 30-image cap or contain items this importer can't fully represent.
class PurImportSummary {
  final int imagesImported;
  final int textNotesImported;
  final int imagesSkippedAtCap;

  const PurImportSummary({
    required this.imagesImported,
    required this.textNotesImported,
    required this.imagesSkippedAtCap,
  });
}

/// One flattened item pulled out of a parsed [PurFile], ready to import in
/// PureRef's original relative stacking order (top-level images and
/// top-level text notes only - captions attached to an image via
/// `textChildren` aren't a concept HB_Clips has yet, so those are dropped;
/// nested nature is preserved on the parse side but this importer only
/// walks the top level).
sealed class _ImportItem {
  final double zLayer;
  _ImportItem(this.zLayer);
}

class _ImportImage extends _ImportItem {
  final PurImage image;
  final PurImageItem transform;
  _ImportImage(this.image, this.transform) : super(transform.zLayer);
}

class _ImportText extends _ImportItem {
  final PurTextItem text;
  _ImportText(this.text) : super(text.zLayer);
}

/// Imports a PureRef `.pur` project file (old 1.10/1.11.1 format only - see
/// `pur_reader.dart`) into the current board, reusing the same
/// add-clip/cap-handling path as manual add and clipboard paste.
Future<PurImportSummary?> importPurFile(
  BuildContext context,
  WidgetRef ref,
  String filePath,
) async {
  final Uint8List bytes;
  try {
    bytes = await File(filePath).readAsBytes();
  } catch (_) {
    if (!context.mounted) return null;
    _showError(context, "Couldn't read that file.");
    return null;
  }

  final PurFile parsed;
  try {
    parsed = PurReader(bytes).read();
  } on PurFormatException catch (error) {
    if (!context.mounted) return null;
    _showError(context, error.message);
    return null;
  } catch (_) {
    if (!context.mounted) return null;
    _showError(
      context,
      "Couldn't parse this .pur file - it may be corrupted or use an "
      "unsupported layout.",
    );
    return null;
  }

  final items = <_ImportItem>[
    for (final image in parsed.images)
      for (final transform in image.transforms) _ImportImage(image, transform),
    for (final text in parsed.text) _ImportText(text),
  ]..sort((a, b) => a.zLayer.compareTo(b.zLayer));

  if (!context.mounted) return null;
  final supportDir = await getApplicationSupportDirectory();
  final clipsDir = Directory(p.join(supportDir.path, 'clips'));
  await clipsDir.create(recursive: true);

  final repo = ref.read(clipsRepositoryProvider);
  var imagesImported = 0;
  var textNotesImported = 0;
  var imagesSkippedAtCap = 0;

  for (final item in items) {
    switch (item) {
      case _ImportImage():
        final placed = await _importImage(item, clipsDir, repo);
        if (placed) {
          imagesImported++;
        } else {
          imagesSkippedAtCap++;
        }
      case _ImportText():
        await _importText(item, repo);
        textNotesImported++;
    }
  }

  return PurImportSummary(
    imagesImported: imagesImported,
    textNotesImported: textNotesImported,
    imagesSkippedAtCap: imagesSkippedAtCap,
  );
}

/// Returns false if the image cap was already reached (nothing inserted).
Future<bool> _importImage(
  _ImportImage item,
  Directory clipsDir,
  ClipsRepository repo,
) async {
  final transform = item.transform;
  final decoded = img.decodePng(item.image.pngBytes);
  Uint8List finalBytes = item.image.pngBytes;
  double boardWidth;
  double boardHeight;

  if (decoded == null) {
    // Not a PNG we can decode (shouldn't happen for a well-formed old-format
    // file) - fall back to the format's own reported size so the clip still
    // lands at a sane size rather than crashing the whole import.
    boardWidth = transform.width;
    boardHeight = transform.height;
  } else {
    final nativeWidth = decoded.width.toDouble();
    final nativeHeight = decoded.height.toDouble();

    if (transform.isAxisAlignedRectangle) {
      final minX = transform.pointsX.reduce((a, b) => a < b ? a : b);
      final maxX = transform.pointsX.reduce((a, b) => a > b ? a : b);
      final minY = transform.pointsY.reduce((a, b) => a < b ? a : b);
      final maxY = transform.pointsY.reduce((a, b) => a > b ? a : b);

      final left = (nativeWidth / 2 + minX).round().clamp(0, decoded.width);
      final top = (nativeHeight / 2 + minY).round().clamp(0, decoded.height);
      final right = (nativeWidth / 2 + maxX).round().clamp(0, decoded.width);
      final bottom = (nativeHeight / 2 + maxY).round().clamp(0, decoded.height);
      final cropWidth = right - left;
      final cropHeight = bottom - top;

      if (cropWidth > 0 &&
          cropHeight > 0 &&
          (cropWidth < decoded.width || cropHeight < decoded.height)) {
        final cropped = img.copyCrop(
          decoded,
          x: left,
          y: top,
          width: cropWidth,
          height: cropHeight,
        );
        finalBytes = img.encodePng(cropped);
        boardWidth = cropWidth * transform.scaleX;
        boardHeight = cropHeight * transform.scaleY;
      } else {
        boardWidth = nativeWidth * transform.scaleX;
        boardHeight = nativeHeight * transform.scaleY;
      }
    } else {
      // A rotated/irregular crop polygon - importing the full image at its
      // true scale rather than guessing a crop we can't faithfully compute.
      boardWidth = nativeWidth * transform.scaleX;
      boardHeight = nativeHeight * transform.scaleY;
    }
  }

  final id = _uuid.v4();
  final destPath = p.join(clipsDir.path, '$id.png');
  await File(destPath).writeAsBytes(finalBytes);

  try {
    await repo.addImageClip(
      id: id,
      boardId: kLocalBoardId,
      localFilePath: destPath,
      x: transform.x - boardWidth / 2,
      y: transform.y - boardHeight / 2,
      width: boardWidth,
      height: boardHeight,
      rotation: transform.rotationRadians,
    );
    return true;
  } on ClipCapExceededException {
    try {
      await File(destPath).delete();
    } catch (_) {
      // Best-effort cleanup; a leftover file here is harmless.
    }
    return false;
  }
}

Future<void> _importText(_ImportText item, ClipsRepository repo) async {
  final text = item.text;
  await repo.addTextNote(
    id: _uuid.v4(),
    boardId: kLocalBoardId,
    textContent: text.text,
    x: text.x - kDefaultTextNoteWidth / 2,
    y: text.y - kDefaultTextNoteHeight / 2,
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.danger),
  );
}
