import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/rendering.dart' show Offset;

import '../../core/constants.dart' show kBoardBackupFormatVersion;
import '../local/database.dart' show FrameRow;
import '../models/clip.dart';
import '../models/connector.dart';
import '../models/stroke.dart';

/// One frame, flattened to the plain fields a `.hbbackup` file needs -
/// mirrors `FrameRow` minus `boardId`/`createdAt`/`updatedAt`, which are
/// either re-derived (boardId - the freshly created board on import) or
/// meaningless to preserve (timestamps - a restored frame is "created"
/// now, same as `FramesRepository.duplicateFrame` already treats a
/// duplicate).
class BackupFrame {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? backgroundColorHex;

  const BackupFrame({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.backgroundColorHex,
  });

  factory BackupFrame.fromRow(FrameRow row) => BackupFrame(
    id: row.id,
    name: row.name,
    x: row.x,
    y: row.y,
    width: row.width,
    height: row.height,
    backgroundColorHex: row.backgroundColorHex,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'backgroundColorHex': backgroundColorHex,
  };

  factory BackupFrame.fromJson(Map<String, dynamic> json) => BackupFrame(
    id: json['id'] as String,
    name: json['name'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    backgroundColorHex: json['backgroundColorHex'] as String?,
  );
}

/// One clip, flattened to the plain fields a `.hbbackup` file needs -
/// every `BoardClip` field except `boardId`/`isBinned`/`binnedAt`/
/// `createdAt`/`updatedAt` (binned clips are never exported in the
/// first place - see `exportBoardBackup` - and the rest are either
/// re-derived or meaningless to preserve across a restore, same
/// reasoning as `BackupFrame`). [hasBlob] records whether an image
/// clip's bytes were actually embedded under `blobs/<id>` in the
/// archive at export time, so a reader can tell "this image's bytes
/// are genuinely missing from this very file" (an honest import-time
/// warning) apart from "this clip never had image bytes to begin with"
/// (not an error).
class BackupClip {
  final String id;
  final ClipType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;
  final double opacity;
  final String? textContent;
  final String? backgroundColorHex;
  final String? groupId;
  final String? frameId;
  final bool hasBlob;
  final double imagePanX;
  final double imagePanY;
  final double imageZoom;
  final double? imageAspectRatio;
  final String textFormattingJson;
  final double? fontSize;
  final double? sizeLockScale;
  final ShapeKind? shapeKind;
  final String? shapeFillColorHex;
  final String? shapeStrokeColorHex;
  final double? shapeStrokeWidth;
  final String? highlightColorHex;

  const BackupClip({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.zIndex,
    required this.opacity,
    this.textContent,
    this.backgroundColorHex,
    this.groupId,
    this.frameId,
    required this.hasBlob,
    required this.imagePanX,
    required this.imagePanY,
    required this.imageZoom,
    this.imageAspectRatio,
    required this.textFormattingJson,
    this.fontSize,
    this.sizeLockScale,
    this.shapeKind,
    this.shapeFillColorHex,
    this.shapeStrokeColorHex,
    this.shapeStrokeWidth,
    this.highlightColorHex,
  });

  factory BackupClip.fromModel(BoardClip clip, {required bool hasBlob}) =>
      BackupClip(
        id: clip.id,
        type: clip.type,
        x: clip.x,
        y: clip.y,
        width: clip.width,
        height: clip.height,
        rotation: clip.rotation,
        zIndex: clip.zIndex,
        opacity: clip.opacity,
        textContent: clip.textContent,
        backgroundColorHex: clip.backgroundColorHex,
        groupId: clip.groupId,
        frameId: clip.frameId,
        hasBlob: hasBlob,
        imagePanX: clip.imagePanX,
        imagePanY: clip.imagePanY,
        imageZoom: clip.imageZoom,
        imageAspectRatio: clip.imageAspectRatio,
        textFormattingJson: clip.textFormatting.toJson(),
        fontSize: clip.fontSize,
        sizeLockScale: clip.sizeLockScale,
        shapeKind: clip.shapeKind,
        shapeFillColorHex: clip.shapeFillColorHex,
        shapeStrokeColorHex: clip.shapeStrokeColorHex,
        shapeStrokeWidth: clip.shapeStrokeWidth,
        highlightColorHex: clip.highlightColorHex,
      );

  /// Rebuilds a full `BoardClip` for [ClipsRepository.duplicateClip] to
  /// insert from - [boardId]/[localFilePath] are supplied by the
  /// importer (the freshly created board's id, and a fresh local blob
  /// key written from this clip's embedded bytes, if any).
  /// `createdAt`/`updatedAt` are placeholders `duplicateClip` never
  /// reads off the source object it's given.
  BoardClip toBoardClip({required String boardId, String? localFilePath}) {
    final now = DateTime.now();
    return BoardClip(
      id: id,
      boardId: boardId,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      zIndex: zIndex,
      opacity: opacity,
      textContent: textContent,
      backgroundColorHex: backgroundColorHex,
      localFilePath: localFilePath,
      imagePanX: imagePanX,
      imagePanY: imagePanY,
      imageZoom: imageZoom,
      imageAspectRatio: imageAspectRatio,
      textFormatting: TextFormatting.fromJson(textFormattingJson),
      fontSize: fontSize,
      sizeLockScale: sizeLockScale,
      shapeKind: shapeKind,
      shapeFillColorHex: shapeFillColorHex,
      shapeStrokeColorHex: shapeStrokeColorHex,
      shapeStrokeWidth: shapeStrokeWidth,
      highlightColorHex: highlightColorHex,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.storageValue,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'zIndex': zIndex,
    'opacity': opacity,
    'textContent': textContent,
    'backgroundColorHex': backgroundColorHex,
    'groupId': groupId,
    'frameId': frameId,
    'hasBlob': hasBlob,
    'imagePanX': imagePanX,
    'imagePanY': imagePanY,
    'imageZoom': imageZoom,
    'imageAspectRatio': imageAspectRatio,
    'textFormattingJson': textFormattingJson,
    'fontSize': fontSize,
    'sizeLockScale': sizeLockScale,
    'shapeKind': shapeKind?.storageValue,
    'shapeFillColorHex': shapeFillColorHex,
    'shapeStrokeColorHex': shapeStrokeColorHex,
    'shapeStrokeWidth': shapeStrokeWidth,
    'highlightColorHex': highlightColorHex,
  };

  factory BackupClip.fromJson(Map<String, dynamic> json) => BackupClip(
    id: json['id'] as String,
    type: ClipTypeStorage.fromStorage(json['type'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    rotation: (json['rotation'] as num).toDouble(),
    zIndex: json['zIndex'] as int,
    opacity: (json['opacity'] as num).toDouble(),
    textContent: json['textContent'] as String?,
    backgroundColorHex: json['backgroundColorHex'] as String?,
    groupId: json['groupId'] as String?,
    frameId: json['frameId'] as String?,
    hasBlob: json['hasBlob'] as bool,
    imagePanX: (json['imagePanX'] as num).toDouble(),
    imagePanY: (json['imagePanY'] as num).toDouble(),
    imageZoom: (json['imageZoom'] as num).toDouble(),
    imageAspectRatio: (json['imageAspectRatio'] as num?)?.toDouble(),
    textFormattingJson: json['textFormattingJson'] as String,
    fontSize: (json['fontSize'] as num?)?.toDouble(),
    sizeLockScale: (json['sizeLockScale'] as num?)?.toDouble(),
    shapeKind: json['shapeKind'] == null
        ? null
        : ShapeKindStorage.fromStorage(json['shapeKind'] as String),
    shapeFillColorHex: json['shapeFillColorHex'] as String?,
    shapeStrokeColorHex: json['shapeStrokeColorHex'] as String?,
    shapeStrokeWidth: (json['shapeStrokeWidth'] as num?)?.toDouble(),
    highlightColorHex: json['highlightColorHex'] as String?,
  );
}

/// One connector, flattened to the plain fields a `.hbbackup` file
/// needs - every `Connector` field except `boardId`/`createdAt`/
/// `updatedAt`, same reasoning as `BackupFrame`/`BackupClip`.
/// `fromClipId`/`toClipId` are the ORIGINAL clip ids - the importer
/// remaps them through the id map it builds while restoring clips.
class BackupConnector {
  final String id;
  final String fromClipId;
  final ConnectorSide fromSide;
  final String toClipId;
  final double? toRelX;
  final double? toRelY;
  final String colorHex;
  final double strokeWidth;

  const BackupConnector({
    required this.id,
    required this.fromClipId,
    required this.fromSide,
    required this.toClipId,
    this.toRelX,
    this.toRelY,
    required this.colorHex,
    required this.strokeWidth,
  });

  factory BackupConnector.fromModel(Connector connector) => BackupConnector(
    id: connector.id,
    fromClipId: connector.fromClipId,
    fromSide: connector.fromSide,
    toClipId: connector.toClipId,
    toRelX: connector.toRelX,
    toRelY: connector.toRelY,
    colorHex: connector.colorHex,
    strokeWidth: connector.strokeWidth,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromClipId': fromClipId,
    'fromSide': fromSide.storageValue,
    'toClipId': toClipId,
    'toRelX': toRelX,
    'toRelY': toRelY,
    'colorHex': colorHex,
    'strokeWidth': strokeWidth,
  };

  factory BackupConnector.fromJson(Map<String, dynamic> json) =>
      BackupConnector(
        id: json['id'] as String,
        fromClipId: json['fromClipId'] as String,
        fromSide: ConnectorSideStorage.fromStorage(json['fromSide'] as String),
        toClipId: json['toClipId'] as String,
        toRelX: (json['toRelX'] as num?)?.toDouble(),
        toRelY: (json['toRelY'] as num?)?.toDouble(),
        colorHex: json['colorHex'] as String,
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
      );
}

/// One stroke, flattened to the plain fields a `.hbbackup` file needs -
/// every `Stroke` field except `boardId`/`createdAt`/`updatedAt`, same
/// reasoning as the other Backup* classes. [clipId] (when non-null) is
/// the ORIGINAL clip id, remapped by the importer the same way
/// `BackupConnector`'s clip ids are.
class BackupStroke {
  final String id;
  final String? clipId;
  final String colorHex;
  final double strokeWidth;
  final List<Offset> points;
  final bool dashed;
  final bool arrowEnd;

  const BackupStroke({
    required this.id,
    this.clipId,
    required this.colorHex,
    required this.strokeWidth,
    required this.points,
    required this.dashed,
    required this.arrowEnd,
  });

  factory BackupStroke.fromModel(Stroke stroke) => BackupStroke(
    id: stroke.id,
    clipId: stroke.clipId,
    colorHex: stroke.colorHex,
    strokeWidth: stroke.strokeWidth,
    points: stroke.points,
    dashed: stroke.dashed,
    arrowEnd: stroke.arrowEnd,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clipId': clipId,
    'colorHex': colorHex,
    'strokeWidth': strokeWidth,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'dashed': dashed,
    'arrowEnd': arrowEnd,
  };

  factory BackupStroke.fromJson(Map<String, dynamic> json) => BackupStroke(
    id: json['id'] as String,
    clipId: json['clipId'] as String?,
    colorHex: json['colorHex'] as String,
    strokeWidth: (json['strokeWidth'] as num).toDouble(),
    points: (json['points'] as List<dynamic>).map((entry) {
      final pair = entry as List<dynamic>;
      return Offset((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
    }).toList(),
    dashed: json['dashed'] as bool,
    arrowEnd: json['arrowEnd'] as bool,
  );
}

/// The full, self-describing contents of a `.hbbackup` file's
/// `manifest.json` entry - one board's frames/clips/connectors/strokes,
/// id-for-id as stored, with image bytes referenced only indirectly
/// (via [BackupClip.hasBlob]) since they live as separate zip entries
/// under `blobs/<clipId>`, not inline in this JSON.
class BoardBackupManifest {
  final int formatVersion;
  final String appVersion;
  final DateTime exportedAt;
  final String boardName;
  final List<BackupFrame> frames;
  final List<BackupClip> clips;
  final List<BackupConnector> connectors;
  final List<BackupStroke> strokes;

  const BoardBackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.boardName,
    required this.frames,
    required this.clips,
    required this.connectors,
    required this.strokes,
  });

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'boardName': boardName,
    'frames': frames.map((f) => f.toJson()).toList(),
    'clips': clips.map((c) => c.toJson()).toList(),
    'connectors': connectors.map((c) => c.toJson()).toList(),
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };

  factory BoardBackupManifest.fromJson(Map<String, dynamic> json) =>
      BoardBackupManifest(
        formatVersion: json['formatVersion'] as int,
        appVersion: json['appVersion'] as String,
        exportedAt: DateTime.parse(json['exportedAt'] as String),
        boardName: json['boardName'] as String,
        frames: (json['frames'] as List<dynamic>)
            .map((e) => BackupFrame.fromJson(e as Map<String, dynamic>))
            .toList(),
        clips: (json['clips'] as List<dynamic>)
            .map((e) => BackupClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        connectors: (json['connectors'] as List<dynamic>)
            .map((e) => BackupConnector.fromJson(e as Map<String, dynamic>))
            .toList(),
        strokes: (json['strokes'] as List<dynamic>)
            .map((e) => BackupStroke.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Encodes [manifest] plus every image clip's raw bytes (keyed by clip
/// id in [blobsByClipId]) into one `.hbbackup` zip archive's bytes -
/// `manifest.json` at the archive root, each blob under
/// `blobs/<clipId>` with no extension (irrelevant at read time - image
/// decoding in this app always sniffs the format from the bytes
/// themselves, never the file name).
Uint8List encodeBackupArchive(
  BoardBackupManifest manifest,
  Map<String, Uint8List> blobsByClipId,
) {
  final archive = Archive()
    ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())));
  for (final entry in blobsByClipId.entries) {
    archive.add(
      ArchiveFile('blobs/${entry.key}', entry.value.length, entry.value),
    );
  }
  final encoded = ZipEncoder().encodeBytes(archive);
  return encoded;
}

/// The decoded contents of a `.hbbackup` archive - the manifest plus
/// every embedded image blob, keyed by the clip id it belongs to.
class DecodedBackupArchive {
  final BoardBackupManifest manifest;
  final Map<String, Uint8List> blobsByClipId;

  const DecodedBackupArchive({
    required this.manifest,
    required this.blobsByClipId,
  });
}

/// Inverse of [encodeBackupArchive]. Throws a [FormatException] with a
/// user-presentable message for anything that isn't a valid, readable
/// `.hbbackup` archive - not a zip at all, missing `manifest.json`,
/// unparseable JSON, or a `formatVersion` newer than this app
/// understands (`kBoardBackupFormatVersion`) - so the caller can catch
/// it and show the message directly, same convention as this app's
/// existing file-picker error handling.
DecodedBackupArchive decodeBackupArchive(Uint8List bytes) {
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(
      "This doesn't look like a valid .hbbackup file.",
    );
  }

  final manifestFile = archive.findFile('manifest.json');
  if (manifestFile == null) {
    throw const FormatException(
      "This doesn't look like a valid .hbbackup file (no manifest found).",
    );
  }

  Map<String, dynamic> decodedJson;
  BoardBackupManifest manifest;
  try {
    decodedJson =
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    manifest = BoardBackupManifest.fromJson(decodedJson);
  } catch (_) {
    throw const FormatException(
      "This .hbbackup file's contents couldn't be read.",
    );
  }

  if (manifest.formatVersion > kBoardBackupFormatVersion) {
    throw const FormatException(
      'This backup was made with a newer version of HB_Clips and '
      "can't be opened here.",
    );
  }

  final blobsByClipId = <String, Uint8List>{};
  for (final clip in manifest.clips) {
    final blobFile = archive.findFile('blobs/${clip.id}');
    if (blobFile != null) blobsByClipId[clip.id] = blobFile.content;
  }

  return DecodedBackupArchive(manifest: manifest, blobsByClipId: blobsByClipId);
}
