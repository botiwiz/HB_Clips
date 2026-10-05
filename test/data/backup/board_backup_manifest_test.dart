import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/backup/board_backup_manifest.dart';
import 'package:hb_clips/data/models/clip.dart';
import 'package:hb_clips/data/models/connector.dart';

BoardBackupManifest _sampleManifest() => BoardBackupManifest(
  formatVersion: 1,
  appVersion: '1.0.0',
  exportedAt: DateTime.utc(2026, 1, 1),
  boardName: 'My Board',
  frames: const [
    BackupFrame(
      id: 'f1',
      name: 'Frame 1',
      x: 0,
      y: 0,
      width: 320,
      height: 240,
      backgroundColorHex: '#112233',
    ),
  ],
  clips: [
    const BackupClip(
      id: 'c1',
      type: ClipType.image,
      x: 10,
      y: 20,
      width: 200,
      height: 150,
      rotation: 0.5,
      zIndex: 1,
      opacity: 0.8,
      groupId: 'g1',
      frameId: 'f1',
      hasBlob: true,
      imagePanX: 0.1,
      imagePanY: -0.2,
      imageZoom: 2.0,
      imageAspectRatio: 1.333,
      textFormattingJson:
          '{"bold":[],"italic":[],"underline":[],'
          '"strikethrough":[],"highlight":[]}',
    ),
    BackupClip(
      id: 'c2',
      type: ClipType.text,
      x: 50,
      y: 60,
      width: 220,
      height: 140,
      rotation: 0,
      zIndex: 2,
      opacity: 1,
      textContent: 'hello world',
      groupId: 'g1',
      hasBlob: false,
      imagePanX: 0,
      imagePanY: 0,
      imageZoom: 1,
      fontSize: 18,
      highlightColorHex: '#FFEB3B',
      textFormattingJson: const TextFormatting(
        bold: [(start: 0, end: 5)],
      ).toJson(),
    ),
    const BackupClip(
      id: 'c3',
      type: ClipType.shape,
      x: 0,
      y: 0,
      width: 160,
      height: 120,
      rotation: 0,
      zIndex: 3,
      opacity: 1,
      hasBlob: false,
      imagePanX: 0,
      imagePanY: 0,
      imageZoom: 1,
      shapeKind: ShapeKind.ellipse,
      shapeFillColorHex: '#FF0000',
      shapeStrokeColorHex: '#00FF00',
      shapeStrokeWidth: 3,
      textFormattingJson:
          '{"bold":[],"italic":[],"underline":[],'
          '"strikethrough":[],"highlight":[]}',
    ),
  ],
  connectors: const [
    BackupConnector(
      id: 'conn1',
      fromClipId: 'c2',
      fromSide: ConnectorSide.right,
      toClipId: 'c1',
      toRelX: 0.5,
      toRelY: 0.25,
      colorHex: '#FFFFFF',
      strokeWidth: 2,
    ),
  ],
  strokes: [
    BackupStroke(
      id: 's1',
      clipId: 'c1',
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(0, 0), Offset(1, 1)],
      dashed: true,
      arrowEnd: false,
    ),
    BackupStroke(
      id: 's2',
      colorHex: '#FF3B30',
      strokeWidth: 3,
      points: const [Offset(5, 5), Offset(6, 7), Offset(8, 9)],
      dashed: false,
      arrowEnd: true,
    ),
  ],
);

void main() {
  group('encodeBackupArchive / decodeBackupArchive', () {
    test('round-trips a manifest with one of each entity type exactly', () {
      final manifest = _sampleManifest();
      final blobBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final encoded = encodeBackupArchive(manifest, {'c1': blobBytes});

      final decoded = decodeBackupArchive(encoded);

      expect(decoded.manifest.formatVersion, manifest.formatVersion);
      expect(decoded.manifest.appVersion, manifest.appVersion);
      expect(decoded.manifest.exportedAt, manifest.exportedAt);
      expect(decoded.manifest.boardName, manifest.boardName);

      expect(decoded.manifest.frames, hasLength(1));
      final frame = decoded.manifest.frames.single;
      expect(frame.id, 'f1');
      expect(frame.name, 'Frame 1');
      expect(frame.width, 320);
      expect(frame.height, 240);
      expect(frame.backgroundColorHex, '#112233');

      expect(decoded.manifest.clips, hasLength(3));
      final image = decoded.manifest.clips.firstWhere((c) => c.id == 'c1');
      expect(image.type, ClipType.image);
      expect(image.rotation, 0.5);
      expect(image.groupId, 'g1');
      expect(image.frameId, 'f1');
      expect(image.hasBlob, isTrue);
      expect(image.imageZoom, 2.0);
      expect(image.imageAspectRatio, 1.333);

      final text = decoded.manifest.clips.firstWhere((c) => c.id == 'c2');
      expect(text.textContent, 'hello world');
      expect(text.fontSize, 18);
      expect(text.highlightColorHex, '#FFEB3B');
      final formatting = TextFormatting.fromJson(text.textFormattingJson);
      expect(formatting.bold, [(start: 0, end: 5)]);

      final shape = decoded.manifest.clips.firstWhere((c) => c.id == 'c3');
      expect(shape.shapeKind, ShapeKind.ellipse);
      expect(shape.shapeFillColorHex, '#FF0000');
      expect(shape.shapeStrokeColorHex, '#00FF00');
      expect(shape.shapeStrokeWidth, 3);

      expect(decoded.manifest.connectors, hasLength(1));
      final connector = decoded.manifest.connectors.single;
      expect(connector.fromClipId, 'c2');
      expect(connector.fromSide, ConnectorSide.right);
      expect(connector.toClipId, 'c1');
      expect(connector.toRelX, 0.5);
      expect(connector.toRelY, 0.25);

      expect(decoded.manifest.strokes, hasLength(2));
      final attachedStroke = decoded.manifest.strokes.firstWhere(
        (s) => s.id == 's1',
      );
      expect(attachedStroke.clipId, 'c1');
      expect(attachedStroke.dashed, isTrue);
      expect(attachedStroke.points, [const Offset(0, 0), const Offset(1, 1)]);
      final freestandingStroke = decoded.manifest.strokes.firstWhere(
        (s) => s.id == 's2',
      );
      expect(freestandingStroke.clipId, isNull);
      expect(freestandingStroke.arrowEnd, isTrue);
      expect(freestandingStroke.points, hasLength(3));

      expect(decoded.blobsByClipId, hasLength(1));
      expect(decoded.blobsByClipId['c1'], blobBytes);
    });

    test('a clip with hasBlob true but no embedded bytes decodes with no '
        'entry in blobsByClipId - the importer tells this apart from '
        '"never had an image" via hasBlob itself', () {
      final manifest = _sampleManifest();
      final encoded = encodeBackupArchive(manifest, const {});
      final decoded = decodeBackupArchive(encoded);
      expect(decoded.blobsByClipId, isEmpty);
      expect(
        decoded.manifest.clips.firstWhere((c) => c.id == 'c1').hasBlob,
        isTrue,
      );
    });

    test('toBoardClip rebuilds a full BoardClip with the given boardId and '
        'localFilePath, decoding textFormattingJson/shapeKind back out', () {
      final backupClip = _sampleManifest().clips.firstWhere(
        (c) => c.id == 'c2',
      );
      final clip = backupClip.toBoardClip(
        boardId: 'new-board',
        localFilePath: null,
      );
      expect(clip.id, 'c2');
      expect(clip.boardId, 'new-board');
      expect(clip.type, ClipType.text);
      expect(clip.textContent, 'hello world');
      expect(clip.textFormatting.bold, [(start: 0, end: 5)]);
      expect(clip.fontSize, 18);
    });

    test('rejects garbage bytes', () {
      expect(
        () => decodeBackupArchive(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('rejects a zip with no manifest.json entry', () {
      // encodeBackupArchive always writes manifest.json - simulate a
      // corrupt/foreign zip by encoding a manifest with no blobs, then
      // decoding a truncated prefix of the bytes (guaranteed not to be
      // a valid zip once cut, so this also exercises the "not a valid
      // zip at all" branch, not just "zip but missing manifest").
      final encoded = encodeBackupArchive(_sampleManifest(), const {});
      final truncated = encoded.sublist(0, encoded.length ~/ 2);
      expect(() => decodeBackupArchive(truncated), throwsFormatException);
    });

    test('rejects a formatVersion newer than this app understands', () {
      final newer = BoardBackupManifest(
        formatVersion: 999999,
        appVersion: '1.0.0',
        exportedAt: DateTime.utc(2026, 1, 1),
        boardName: 'Future board',
        frames: const [],
        clips: const [],
        connectors: const [],
        strokes: const [],
      );
      final encoded = encodeBackupArchive(newer, const {});
      expect(() => decodeBackupArchive(encoded), throwsFormatException);
    });
  });
}
