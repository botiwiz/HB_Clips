// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ClipsTable extends Clips with TableInfo<$ClipsTable, ClipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardIdMeta = const VerificationMeta(
    'boardId',
  );
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
    'board_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(200),
  );
  static const VerificationMeta _rotationMeta = const VerificationMeta(
    'rotation',
  );
  @override
  late final GeneratedColumn<double> rotation = GeneratedColumn<double>(
    'rotation',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _zIndexMeta = const VerificationMeta('zIndex');
  @override
  late final GeneratedColumn<int> zIndex = GeneratedColumn<int>(
    'z_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _opacityMeta = const VerificationMeta(
    'opacity',
  );
  @override
  late final GeneratedColumn<double> opacity = GeneratedColumn<double>(
    'opacity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frameIdMeta = const VerificationMeta(
    'frameId',
  );
  @override
  late final GeneratedColumn<String> frameId = GeneratedColumn<String>(
    'frame_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundColorHexMeta =
      const VerificationMeta('backgroundColorHex');
  @override
  late final GeneratedColumn<String> backgroundColorHex =
      GeneratedColumn<String>(
        'background_color_hex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _localFilePathMeta = const VerificationMeta(
    'localFilePath',
  );
  @override
  late final GeneratedColumn<String> localFilePath = GeneratedColumn<String>(
    'local_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagePanXMeta = const VerificationMeta(
    'imagePanX',
  );
  @override
  late final GeneratedColumn<double> imagePanX = GeneratedColumn<double>(
    'image_pan_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _imagePanYMeta = const VerificationMeta(
    'imagePanY',
  );
  @override
  late final GeneratedColumn<double> imagePanY = GeneratedColumn<double>(
    'image_pan_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _imageZoomMeta = const VerificationMeta(
    'imageZoom',
  );
  @override
  late final GeneratedColumn<double> imageZoom = GeneratedColumn<double>(
    'image_zoom',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _imageAspectRatioMeta = const VerificationMeta(
    'imageAspectRatio',
  );
  @override
  late final GeneratedColumn<double> imageAspectRatio = GeneratedColumn<double>(
    'image_aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textFormattingJsonMeta =
      const VerificationMeta('textFormattingJson');
  @override
  late final GeneratedColumn<String> textFormattingJson =
      GeneratedColumn<String>(
        'text_formatting_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fontSizeMeta = const VerificationMeta(
    'fontSize',
  );
  @override
  late final GeneratedColumn<double> fontSize = GeneratedColumn<double>(
    'font_size',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeLockScaleMeta = const VerificationMeta(
    'sizeLockScale',
  );
  @override
  late final GeneratedColumn<double> sizeLockScale = GeneratedColumn<double>(
    'size_lock_scale',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeKindMeta = const VerificationMeta(
    'shapeKind',
  );
  @override
  late final GeneratedColumn<String> shapeKind = GeneratedColumn<String>(
    'shape_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeFillColorHexMeta = const VerificationMeta(
    'shapeFillColorHex',
  );
  @override
  late final GeneratedColumn<String> shapeFillColorHex =
      GeneratedColumn<String>(
        'shape_fill_color_hex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shapeStrokeColorHexMeta =
      const VerificationMeta('shapeStrokeColorHex');
  @override
  late final GeneratedColumn<String> shapeStrokeColorHex =
      GeneratedColumn<String>(
        'shape_stroke_color_hex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _shapeStrokeWidthMeta = const VerificationMeta(
    'shapeStrokeWidth',
  );
  @override
  late final GeneratedColumn<double> shapeStrokeWidth = GeneratedColumn<double>(
    'shape_stroke_width',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highlightColorHexMeta = const VerificationMeta(
    'highlightColorHex',
  );
  @override
  late final GeneratedColumn<String> highlightColorHex =
      GeneratedColumn<String>(
        'highlight_color_hex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isBinnedMeta = const VerificationMeta(
    'isBinned',
  );
  @override
  late final GeneratedColumn<bool> isBinned = GeneratedColumn<bool>(
    'is_binned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_binned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _binnedAtMeta = const VerificationMeta(
    'binnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> binnedAt = GeneratedColumn<DateTime>(
    'binned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boardId,
    type,
    x,
    y,
    width,
    height,
    rotation,
    zIndex,
    opacity,
    groupId,
    frameId,
    textContent,
    backgroundColorHex,
    localFilePath,
    imagePanX,
    imagePanY,
    imageZoom,
    imageAspectRatio,
    textFormattingJson,
    fontSize,
    sizeLockScale,
    shapeKind,
    shapeFillColorHex,
    shapeStrokeColorHex,
    shapeStrokeWidth,
    highlightColorHex,
    isBinned,
    binnedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(
        _boardIdMeta,
        boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('rotation')) {
      context.handle(
        _rotationMeta,
        rotation.isAcceptableOrUnknown(data['rotation']!, _rotationMeta),
      );
    }
    if (data.containsKey('z_index')) {
      context.handle(
        _zIndexMeta,
        zIndex.isAcceptableOrUnknown(data['z_index']!, _zIndexMeta),
      );
    }
    if (data.containsKey('opacity')) {
      context.handle(
        _opacityMeta,
        opacity.isAcceptableOrUnknown(data['opacity']!, _opacityMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('frame_id')) {
      context.handle(
        _frameIdMeta,
        frameId.isAcceptableOrUnknown(data['frame_id']!, _frameIdMeta),
      );
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    }
    if (data.containsKey('background_color_hex')) {
      context.handle(
        _backgroundColorHexMeta,
        backgroundColorHex.isAcceptableOrUnknown(
          data['background_color_hex']!,
          _backgroundColorHexMeta,
        ),
      );
    }
    if (data.containsKey('local_file_path')) {
      context.handle(
        _localFilePathMeta,
        localFilePath.isAcceptableOrUnknown(
          data['local_file_path']!,
          _localFilePathMeta,
        ),
      );
    }
    if (data.containsKey('image_pan_x')) {
      context.handle(
        _imagePanXMeta,
        imagePanX.isAcceptableOrUnknown(data['image_pan_x']!, _imagePanXMeta),
      );
    }
    if (data.containsKey('image_pan_y')) {
      context.handle(
        _imagePanYMeta,
        imagePanY.isAcceptableOrUnknown(data['image_pan_y']!, _imagePanYMeta),
      );
    }
    if (data.containsKey('image_zoom')) {
      context.handle(
        _imageZoomMeta,
        imageZoom.isAcceptableOrUnknown(data['image_zoom']!, _imageZoomMeta),
      );
    }
    if (data.containsKey('image_aspect_ratio')) {
      context.handle(
        _imageAspectRatioMeta,
        imageAspectRatio.isAcceptableOrUnknown(
          data['image_aspect_ratio']!,
          _imageAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('text_formatting_json')) {
      context.handle(
        _textFormattingJsonMeta,
        textFormattingJson.isAcceptableOrUnknown(
          data['text_formatting_json']!,
          _textFormattingJsonMeta,
        ),
      );
    }
    if (data.containsKey('font_size')) {
      context.handle(
        _fontSizeMeta,
        fontSize.isAcceptableOrUnknown(data['font_size']!, _fontSizeMeta),
      );
    }
    if (data.containsKey('size_lock_scale')) {
      context.handle(
        _sizeLockScaleMeta,
        sizeLockScale.isAcceptableOrUnknown(
          data['size_lock_scale']!,
          _sizeLockScaleMeta,
        ),
      );
    }
    if (data.containsKey('shape_kind')) {
      context.handle(
        _shapeKindMeta,
        shapeKind.isAcceptableOrUnknown(data['shape_kind']!, _shapeKindMeta),
      );
    }
    if (data.containsKey('shape_fill_color_hex')) {
      context.handle(
        _shapeFillColorHexMeta,
        shapeFillColorHex.isAcceptableOrUnknown(
          data['shape_fill_color_hex']!,
          _shapeFillColorHexMeta,
        ),
      );
    }
    if (data.containsKey('shape_stroke_color_hex')) {
      context.handle(
        _shapeStrokeColorHexMeta,
        shapeStrokeColorHex.isAcceptableOrUnknown(
          data['shape_stroke_color_hex']!,
          _shapeStrokeColorHexMeta,
        ),
      );
    }
    if (data.containsKey('shape_stroke_width')) {
      context.handle(
        _shapeStrokeWidthMeta,
        shapeStrokeWidth.isAcceptableOrUnknown(
          data['shape_stroke_width']!,
          _shapeStrokeWidthMeta,
        ),
      );
    }
    if (data.containsKey('highlight_color_hex')) {
      context.handle(
        _highlightColorHexMeta,
        highlightColorHex.isAcceptableOrUnknown(
          data['highlight_color_hex']!,
          _highlightColorHexMeta,
        ),
      );
    }
    if (data.containsKey('is_binned')) {
      context.handle(
        _isBinnedMeta,
        isBinned.isAcceptableOrUnknown(data['is_binned']!, _isBinnedMeta),
      );
    }
    if (data.containsKey('binned_at')) {
      context.handle(
        _binnedAtMeta,
        binnedAt.isAcceptableOrUnknown(data['binned_at']!, _binnedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      boardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      rotation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rotation'],
      )!,
      zIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}z_index'],
      )!,
      opacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opacity'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      frameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frame_id'],
      ),
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      backgroundColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_color_hex'],
      ),
      localFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_path'],
      ),
      imagePanX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_pan_x'],
      )!,
      imagePanY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_pan_y'],
      )!,
      imageZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_zoom'],
      )!,
      imageAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_aspect_ratio'],
      ),
      textFormattingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_formatting_json'],
      ),
      fontSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}font_size'],
      ),
      sizeLockScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}size_lock_scale'],
      ),
      shapeKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape_kind'],
      ),
      shapeFillColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape_fill_color_hex'],
      ),
      shapeStrokeColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape_stroke_color_hex'],
      ),
      shapeStrokeWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shape_stroke_width'],
      ),
      highlightColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}highlight_color_hex'],
      ),
      isBinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_binned'],
      )!,
      binnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}binned_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ClipsTable createAlias(String alias) {
    return $ClipsTable(attachedDatabase, alias);
  }
}

class ClipRow extends DataClass implements Insertable<ClipRow> {
  /// Client-generated UUID so offline creation works without a round trip.
  final String id;
  final String boardId;

  /// 'image', 'text', or 'shape'.
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;

  /// 0.0 (fully transparent) to 1.0 (fully opaque, the default).
  final double opacity;

  /// Shared by every clip in a group; null when ungrouped. Clicking any
  /// clip in a group selects (and then drags) every clip sharing this id.
  final String? groupId;

  /// The frame this clip is currently nested inside, or null. Set/cleared
  /// automatically when a clip is dragged into/out of a frame's bounds
  /// (Miro's frame-containment behavior) - moving a frame moves every clip
  /// with a matching `frameId` along with it.
  final String? frameId;
  final String? textContent;

  /// Custom background color for a text note, as `#RRGGBB`. Null uses the
  /// app's default text-note surface color.
  final String? backgroundColorHex;

  /// Key into [LocalBlobStore] for this image clip's bytes.
  final String? localFilePath;

  /// Pan/zoom of the image content within this clip's fixed on-board frame
  /// (double-click a clip to enter this mode) - Flutter `Alignment`
  /// convention, -1..1 per axis, 0 = centered. Ignored for text notes.
  final double imagePanX;
  final double imagePanY;

  /// Multiplier on top of the frame's own base "cover" scale; always >= 1.0
  /// so the image can never show a gap inside its frame.
  final double imageZoom;

  /// The source image's native width/height ratio - null for legacy rows
  /// or text notes, treated as "matches the frame's own aspect" (renders
  /// identically to a plain cover-fit with no pan/zoom available yet).
  final double? imageAspectRatio;

  /// JSON-encoded bold/italic/strikethrough ranges over [textContent] - see
  /// `TextFormatting`. Null/empty means no rich formatting. Ignored for
  /// image clips.
  final String? textFormattingJson;

  /// Board-space (world) font size override for a text note - null means
  /// use the app default (`kTextNoteFontSize`). Whole-note scope, not
  /// per-character-range. Ignored for image clips.
  final double? fontSize;

  /// When non-null, the board-view scale this text note's on-screen size
  /// was pinned to (see the edit toolbar's "constant size" toggle) - the
  /// clip renders at `width/height * sizeLockScale` regardless of the
  /// current live zoom, instead of the usual `* view.scale`. Null means
  /// normal world-space scaling. Ignored for image clips.
  final double? sizeLockScale;

  /// Which flowchart-style vector primitive a shape clip renders as, as
  /// `ShapeKindStorage.storageValue` ('rectangle'/'ellipse'/'triangle'/
  /// 'trapezoid'/'parallelogram'). Null for every non-shape clip.
  final String? shapeKind;

  /// Fill color as `#RRGGBB`, or null for no fill (outline-only shape).
  /// Ignored for non-shape clips.
  final String? shapeFillColorHex;

  /// Stroke/outline color as `#RRGGBB`. Null falls back to a neutral
  /// default at render time rather than at write time, so the default can
  /// change later without a migration. Ignored for non-shape clips.
  final String? shapeStrokeColorHex;

  /// Stroke width in board-space pixels. Null falls back to
  /// `kDefaultStrokeWidth`. Ignored for non-shape clips.
  final double? shapeStrokeWidth;

  /// Background color behind text covered by `textFormattingJson`'s
  /// `highlight` ranges, as `#RRGGBB`. Null falls back to
  /// `kDefaultHighlightColorHex` at render time. One color per note, not
  /// per-range. Ignored for image/shape clips.
  final String? highlightColorHex;
  final bool isBinned;
  final DateTime? binnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ClipRow({
    required this.id,
    required this.boardId,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.zIndex,
    required this.opacity,
    this.groupId,
    this.frameId,
    this.textContent,
    this.backgroundColorHex,
    this.localFilePath,
    required this.imagePanX,
    required this.imagePanY,
    required this.imageZoom,
    this.imageAspectRatio,
    this.textFormattingJson,
    this.fontSize,
    this.sizeLockScale,
    this.shapeKind,
    this.shapeFillColorHex,
    this.shapeStrokeColorHex,
    this.shapeStrokeWidth,
    this.highlightColorHex,
    required this.isBinned,
    this.binnedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['type'] = Variable<String>(type);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['rotation'] = Variable<double>(rotation);
    map['z_index'] = Variable<int>(zIndex);
    map['opacity'] = Variable<double>(opacity);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || frameId != null) {
      map['frame_id'] = Variable<String>(frameId);
    }
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || backgroundColorHex != null) {
      map['background_color_hex'] = Variable<String>(backgroundColorHex);
    }
    if (!nullToAbsent || localFilePath != null) {
      map['local_file_path'] = Variable<String>(localFilePath);
    }
    map['image_pan_x'] = Variable<double>(imagePanX);
    map['image_pan_y'] = Variable<double>(imagePanY);
    map['image_zoom'] = Variable<double>(imageZoom);
    if (!nullToAbsent || imageAspectRatio != null) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio);
    }
    if (!nullToAbsent || textFormattingJson != null) {
      map['text_formatting_json'] = Variable<String>(textFormattingJson);
    }
    if (!nullToAbsent || fontSize != null) {
      map['font_size'] = Variable<double>(fontSize);
    }
    if (!nullToAbsent || sizeLockScale != null) {
      map['size_lock_scale'] = Variable<double>(sizeLockScale);
    }
    if (!nullToAbsent || shapeKind != null) {
      map['shape_kind'] = Variable<String>(shapeKind);
    }
    if (!nullToAbsent || shapeFillColorHex != null) {
      map['shape_fill_color_hex'] = Variable<String>(shapeFillColorHex);
    }
    if (!nullToAbsent || shapeStrokeColorHex != null) {
      map['shape_stroke_color_hex'] = Variable<String>(shapeStrokeColorHex);
    }
    if (!nullToAbsent || shapeStrokeWidth != null) {
      map['shape_stroke_width'] = Variable<double>(shapeStrokeWidth);
    }
    if (!nullToAbsent || highlightColorHex != null) {
      map['highlight_color_hex'] = Variable<String>(highlightColorHex);
    }
    map['is_binned'] = Variable<bool>(isBinned);
    if (!nullToAbsent || binnedAt != null) {
      map['binned_at'] = Variable<DateTime>(binnedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ClipsCompanion toCompanion(bool nullToAbsent) {
    return ClipsCompanion(
      id: Value(id),
      boardId: Value(boardId),
      type: Value(type),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      rotation: Value(rotation),
      zIndex: Value(zIndex),
      opacity: Value(opacity),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      frameId: frameId == null && nullToAbsent
          ? const Value.absent()
          : Value(frameId),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      backgroundColorHex: backgroundColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColorHex),
      localFilePath: localFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localFilePath),
      imagePanX: Value(imagePanX),
      imagePanY: Value(imagePanY),
      imageZoom: Value(imageZoom),
      imageAspectRatio: imageAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAspectRatio),
      textFormattingJson: textFormattingJson == null && nullToAbsent
          ? const Value.absent()
          : Value(textFormattingJson),
      fontSize: fontSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fontSize),
      sizeLockScale: sizeLockScale == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeLockScale),
      shapeKind: shapeKind == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeKind),
      shapeFillColorHex: shapeFillColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeFillColorHex),
      shapeStrokeColorHex: shapeStrokeColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeStrokeColorHex),
      shapeStrokeWidth: shapeStrokeWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(shapeStrokeWidth),
      highlightColorHex: highlightColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(highlightColorHex),
      isBinned: Value(isBinned),
      binnedAt: binnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(binnedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ClipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipRow(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      type: serializer.fromJson<String>(json['type']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      rotation: serializer.fromJson<double>(json['rotation']),
      zIndex: serializer.fromJson<int>(json['zIndex']),
      opacity: serializer.fromJson<double>(json['opacity']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      frameId: serializer.fromJson<String?>(json['frameId']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      backgroundColorHex: serializer.fromJson<String?>(
        json['backgroundColorHex'],
      ),
      localFilePath: serializer.fromJson<String?>(json['localFilePath']),
      imagePanX: serializer.fromJson<double>(json['imagePanX']),
      imagePanY: serializer.fromJson<double>(json['imagePanY']),
      imageZoom: serializer.fromJson<double>(json['imageZoom']),
      imageAspectRatio: serializer.fromJson<double?>(json['imageAspectRatio']),
      textFormattingJson: serializer.fromJson<String?>(
        json['textFormattingJson'],
      ),
      fontSize: serializer.fromJson<double?>(json['fontSize']),
      sizeLockScale: serializer.fromJson<double?>(json['sizeLockScale']),
      shapeKind: serializer.fromJson<String?>(json['shapeKind']),
      shapeFillColorHex: serializer.fromJson<String?>(
        json['shapeFillColorHex'],
      ),
      shapeStrokeColorHex: serializer.fromJson<String?>(
        json['shapeStrokeColorHex'],
      ),
      shapeStrokeWidth: serializer.fromJson<double?>(json['shapeStrokeWidth']),
      highlightColorHex: serializer.fromJson<String?>(
        json['highlightColorHex'],
      ),
      isBinned: serializer.fromJson<bool>(json['isBinned']),
      binnedAt: serializer.fromJson<DateTime?>(json['binnedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'type': serializer.toJson<String>(type),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'rotation': serializer.toJson<double>(rotation),
      'zIndex': serializer.toJson<int>(zIndex),
      'opacity': serializer.toJson<double>(opacity),
      'groupId': serializer.toJson<String?>(groupId),
      'frameId': serializer.toJson<String?>(frameId),
      'textContent': serializer.toJson<String?>(textContent),
      'backgroundColorHex': serializer.toJson<String?>(backgroundColorHex),
      'localFilePath': serializer.toJson<String?>(localFilePath),
      'imagePanX': serializer.toJson<double>(imagePanX),
      'imagePanY': serializer.toJson<double>(imagePanY),
      'imageZoom': serializer.toJson<double>(imageZoom),
      'imageAspectRatio': serializer.toJson<double?>(imageAspectRatio),
      'textFormattingJson': serializer.toJson<String?>(textFormattingJson),
      'fontSize': serializer.toJson<double?>(fontSize),
      'sizeLockScale': serializer.toJson<double?>(sizeLockScale),
      'shapeKind': serializer.toJson<String?>(shapeKind),
      'shapeFillColorHex': serializer.toJson<String?>(shapeFillColorHex),
      'shapeStrokeColorHex': serializer.toJson<String?>(shapeStrokeColorHex),
      'shapeStrokeWidth': serializer.toJson<double?>(shapeStrokeWidth),
      'highlightColorHex': serializer.toJson<String?>(highlightColorHex),
      'isBinned': serializer.toJson<bool>(isBinned),
      'binnedAt': serializer.toJson<DateTime?>(binnedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ClipRow copyWith({
    String? id,
    String? boardId,
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    double? opacity,
    Value<String?> groupId = const Value.absent(),
    Value<String?> frameId = const Value.absent(),
    Value<String?> textContent = const Value.absent(),
    Value<String?> backgroundColorHex = const Value.absent(),
    Value<String?> localFilePath = const Value.absent(),
    double? imagePanX,
    double? imagePanY,
    double? imageZoom,
    Value<double?> imageAspectRatio = const Value.absent(),
    Value<String?> textFormattingJson = const Value.absent(),
    Value<double?> fontSize = const Value.absent(),
    Value<double?> sizeLockScale = const Value.absent(),
    Value<String?> shapeKind = const Value.absent(),
    Value<String?> shapeFillColorHex = const Value.absent(),
    Value<String?> shapeStrokeColorHex = const Value.absent(),
    Value<double?> shapeStrokeWidth = const Value.absent(),
    Value<String?> highlightColorHex = const Value.absent(),
    bool? isBinned,
    Value<DateTime?> binnedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ClipRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    type: type ?? this.type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    zIndex: zIndex ?? this.zIndex,
    opacity: opacity ?? this.opacity,
    groupId: groupId.present ? groupId.value : this.groupId,
    frameId: frameId.present ? frameId.value : this.frameId,
    textContent: textContent.present ? textContent.value : this.textContent,
    backgroundColorHex: backgroundColorHex.present
        ? backgroundColorHex.value
        : this.backgroundColorHex,
    localFilePath: localFilePath.present
        ? localFilePath.value
        : this.localFilePath,
    imagePanX: imagePanX ?? this.imagePanX,
    imagePanY: imagePanY ?? this.imagePanY,
    imageZoom: imageZoom ?? this.imageZoom,
    imageAspectRatio: imageAspectRatio.present
        ? imageAspectRatio.value
        : this.imageAspectRatio,
    textFormattingJson: textFormattingJson.present
        ? textFormattingJson.value
        : this.textFormattingJson,
    fontSize: fontSize.present ? fontSize.value : this.fontSize,
    sizeLockScale: sizeLockScale.present
        ? sizeLockScale.value
        : this.sizeLockScale,
    shapeKind: shapeKind.present ? shapeKind.value : this.shapeKind,
    shapeFillColorHex: shapeFillColorHex.present
        ? shapeFillColorHex.value
        : this.shapeFillColorHex,
    shapeStrokeColorHex: shapeStrokeColorHex.present
        ? shapeStrokeColorHex.value
        : this.shapeStrokeColorHex,
    shapeStrokeWidth: shapeStrokeWidth.present
        ? shapeStrokeWidth.value
        : this.shapeStrokeWidth,
    highlightColorHex: highlightColorHex.present
        ? highlightColorHex.value
        : this.highlightColorHex,
    isBinned: isBinned ?? this.isBinned,
    binnedAt: binnedAt.present ? binnedAt.value : this.binnedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ClipRow copyWithCompanion(ClipsCompanion data) {
    return ClipRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      type: data.type.present ? data.type.value : this.type,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      rotation: data.rotation.present ? data.rotation.value : this.rotation,
      zIndex: data.zIndex.present ? data.zIndex.value : this.zIndex,
      opacity: data.opacity.present ? data.opacity.value : this.opacity,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      frameId: data.frameId.present ? data.frameId.value : this.frameId,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      backgroundColorHex: data.backgroundColorHex.present
          ? data.backgroundColorHex.value
          : this.backgroundColorHex,
      localFilePath: data.localFilePath.present
          ? data.localFilePath.value
          : this.localFilePath,
      imagePanX: data.imagePanX.present ? data.imagePanX.value : this.imagePanX,
      imagePanY: data.imagePanY.present ? data.imagePanY.value : this.imagePanY,
      imageZoom: data.imageZoom.present ? data.imageZoom.value : this.imageZoom,
      imageAspectRatio: data.imageAspectRatio.present
          ? data.imageAspectRatio.value
          : this.imageAspectRatio,
      textFormattingJson: data.textFormattingJson.present
          ? data.textFormattingJson.value
          : this.textFormattingJson,
      fontSize: data.fontSize.present ? data.fontSize.value : this.fontSize,
      sizeLockScale: data.sizeLockScale.present
          ? data.sizeLockScale.value
          : this.sizeLockScale,
      shapeKind: data.shapeKind.present ? data.shapeKind.value : this.shapeKind,
      shapeFillColorHex: data.shapeFillColorHex.present
          ? data.shapeFillColorHex.value
          : this.shapeFillColorHex,
      shapeStrokeColorHex: data.shapeStrokeColorHex.present
          ? data.shapeStrokeColorHex.value
          : this.shapeStrokeColorHex,
      shapeStrokeWidth: data.shapeStrokeWidth.present
          ? data.shapeStrokeWidth.value
          : this.shapeStrokeWidth,
      highlightColorHex: data.highlightColorHex.present
          ? data.highlightColorHex.value
          : this.highlightColorHex,
      isBinned: data.isBinned.present ? data.isBinned.value : this.isBinned,
      binnedAt: data.binnedAt.present ? data.binnedAt.value : this.binnedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('type: $type, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('rotation: $rotation, ')
          ..write('zIndex: $zIndex, ')
          ..write('opacity: $opacity, ')
          ..write('groupId: $groupId, ')
          ..write('frameId: $frameId, ')
          ..write('textContent: $textContent, ')
          ..write('backgroundColorHex: $backgroundColorHex, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('imagePanX: $imagePanX, ')
          ..write('imagePanY: $imagePanY, ')
          ..write('imageZoom: $imageZoom, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('textFormattingJson: $textFormattingJson, ')
          ..write('fontSize: $fontSize, ')
          ..write('sizeLockScale: $sizeLockScale, ')
          ..write('shapeKind: $shapeKind, ')
          ..write('shapeFillColorHex: $shapeFillColorHex, ')
          ..write('shapeStrokeColorHex: $shapeStrokeColorHex, ')
          ..write('shapeStrokeWidth: $shapeStrokeWidth, ')
          ..write('highlightColorHex: $highlightColorHex, ')
          ..write('isBinned: $isBinned, ')
          ..write('binnedAt: $binnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    boardId,
    type,
    x,
    y,
    width,
    height,
    rotation,
    zIndex,
    opacity,
    groupId,
    frameId,
    textContent,
    backgroundColorHex,
    localFilePath,
    imagePanX,
    imagePanY,
    imageZoom,
    imageAspectRatio,
    textFormattingJson,
    fontSize,
    sizeLockScale,
    shapeKind,
    shapeFillColorHex,
    shapeStrokeColorHex,
    shapeStrokeWidth,
    highlightColorHex,
    isBinned,
    binnedAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.type == this.type &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.rotation == this.rotation &&
          other.zIndex == this.zIndex &&
          other.opacity == this.opacity &&
          other.groupId == this.groupId &&
          other.frameId == this.frameId &&
          other.textContent == this.textContent &&
          other.backgroundColorHex == this.backgroundColorHex &&
          other.localFilePath == this.localFilePath &&
          other.imagePanX == this.imagePanX &&
          other.imagePanY == this.imagePanY &&
          other.imageZoom == this.imageZoom &&
          other.imageAspectRatio == this.imageAspectRatio &&
          other.textFormattingJson == this.textFormattingJson &&
          other.fontSize == this.fontSize &&
          other.sizeLockScale == this.sizeLockScale &&
          other.shapeKind == this.shapeKind &&
          other.shapeFillColorHex == this.shapeFillColorHex &&
          other.shapeStrokeColorHex == this.shapeStrokeColorHex &&
          other.shapeStrokeWidth == this.shapeStrokeWidth &&
          other.highlightColorHex == this.highlightColorHex &&
          other.isBinned == this.isBinned &&
          other.binnedAt == this.binnedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ClipsCompanion extends UpdateCompanion<ClipRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> type;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<double> rotation;
  final Value<int> zIndex;
  final Value<double> opacity;
  final Value<String?> groupId;
  final Value<String?> frameId;
  final Value<String?> textContent;
  final Value<String?> backgroundColorHex;
  final Value<String?> localFilePath;
  final Value<double> imagePanX;
  final Value<double> imagePanY;
  final Value<double> imageZoom;
  final Value<double?> imageAspectRatio;
  final Value<String?> textFormattingJson;
  final Value<double?> fontSize;
  final Value<double?> sizeLockScale;
  final Value<String?> shapeKind;
  final Value<String?> shapeFillColorHex;
  final Value<String?> shapeStrokeColorHex;
  final Value<double?> shapeStrokeWidth;
  final Value<String?> highlightColorHex;
  final Value<bool> isBinned;
  final Value<DateTime?> binnedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ClipsCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.type = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.rotation = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.opacity = const Value.absent(),
    this.groupId = const Value.absent(),
    this.frameId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.backgroundColorHex = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.imagePanX = const Value.absent(),
    this.imagePanY = const Value.absent(),
    this.imageZoom = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.textFormattingJson = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.sizeLockScale = const Value.absent(),
    this.shapeKind = const Value.absent(),
    this.shapeFillColorHex = const Value.absent(),
    this.shapeStrokeColorHex = const Value.absent(),
    this.shapeStrokeWidth = const Value.absent(),
    this.highlightColorHex = const Value.absent(),
    this.isBinned = const Value.absent(),
    this.binnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClipsCompanion.insert({
    required String id,
    required String boardId,
    required String type,
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.rotation = const Value.absent(),
    this.zIndex = const Value.absent(),
    this.opacity = const Value.absent(),
    this.groupId = const Value.absent(),
    this.frameId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.backgroundColorHex = const Value.absent(),
    this.localFilePath = const Value.absent(),
    this.imagePanX = const Value.absent(),
    this.imagePanY = const Value.absent(),
    this.imageZoom = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.textFormattingJson = const Value.absent(),
    this.fontSize = const Value.absent(),
    this.sizeLockScale = const Value.absent(),
    this.shapeKind = const Value.absent(),
    this.shapeFillColorHex = const Value.absent(),
    this.shapeStrokeColorHex = const Value.absent(),
    this.shapeStrokeWidth = const Value.absent(),
    this.highlightColorHex = const Value.absent(),
    this.isBinned = const Value.absent(),
    this.binnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId),
       type = Value(type);
  static Insertable<ClipRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? type,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<double>? rotation,
    Expression<int>? zIndex,
    Expression<double>? opacity,
    Expression<String>? groupId,
    Expression<String>? frameId,
    Expression<String>? textContent,
    Expression<String>? backgroundColorHex,
    Expression<String>? localFilePath,
    Expression<double>? imagePanX,
    Expression<double>? imagePanY,
    Expression<double>? imageZoom,
    Expression<double>? imageAspectRatio,
    Expression<String>? textFormattingJson,
    Expression<double>? fontSize,
    Expression<double>? sizeLockScale,
    Expression<String>? shapeKind,
    Expression<String>? shapeFillColorHex,
    Expression<String>? shapeStrokeColorHex,
    Expression<double>? shapeStrokeWidth,
    Expression<String>? highlightColorHex,
    Expression<bool>? isBinned,
    Expression<DateTime>? binnedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (type != null) 'type': type,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (rotation != null) 'rotation': rotation,
      if (zIndex != null) 'z_index': zIndex,
      if (opacity != null) 'opacity': opacity,
      if (groupId != null) 'group_id': groupId,
      if (frameId != null) 'frame_id': frameId,
      if (textContent != null) 'text_content': textContent,
      if (backgroundColorHex != null)
        'background_color_hex': backgroundColorHex,
      if (localFilePath != null) 'local_file_path': localFilePath,
      if (imagePanX != null) 'image_pan_x': imagePanX,
      if (imagePanY != null) 'image_pan_y': imagePanY,
      if (imageZoom != null) 'image_zoom': imageZoom,
      if (imageAspectRatio != null) 'image_aspect_ratio': imageAspectRatio,
      if (textFormattingJson != null)
        'text_formatting_json': textFormattingJson,
      if (fontSize != null) 'font_size': fontSize,
      if (sizeLockScale != null) 'size_lock_scale': sizeLockScale,
      if (shapeKind != null) 'shape_kind': shapeKind,
      if (shapeFillColorHex != null) 'shape_fill_color_hex': shapeFillColorHex,
      if (shapeStrokeColorHex != null)
        'shape_stroke_color_hex': shapeStrokeColorHex,
      if (shapeStrokeWidth != null) 'shape_stroke_width': shapeStrokeWidth,
      if (highlightColorHex != null) 'highlight_color_hex': highlightColorHex,
      if (isBinned != null) 'is_binned': isBinned,
      if (binnedAt != null) 'binned_at': binnedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClipsCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String>? type,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<double>? rotation,
    Value<int>? zIndex,
    Value<double>? opacity,
    Value<String?>? groupId,
    Value<String?>? frameId,
    Value<String?>? textContent,
    Value<String?>? backgroundColorHex,
    Value<String?>? localFilePath,
    Value<double>? imagePanX,
    Value<double>? imagePanY,
    Value<double>? imageZoom,
    Value<double?>? imageAspectRatio,
    Value<String?>? textFormattingJson,
    Value<double?>? fontSize,
    Value<double?>? sizeLockScale,
    Value<String?>? shapeKind,
    Value<String?>? shapeFillColorHex,
    Value<String?>? shapeStrokeColorHex,
    Value<double?>? shapeStrokeWidth,
    Value<String?>? highlightColorHex,
    Value<bool>? isBinned,
    Value<DateTime?>? binnedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ClipsCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      opacity: opacity ?? this.opacity,
      groupId: groupId ?? this.groupId,
      frameId: frameId ?? this.frameId,
      textContent: textContent ?? this.textContent,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      localFilePath: localFilePath ?? this.localFilePath,
      imagePanX: imagePanX ?? this.imagePanX,
      imagePanY: imagePanY ?? this.imagePanY,
      imageZoom: imageZoom ?? this.imageZoom,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      textFormattingJson: textFormattingJson ?? this.textFormattingJson,
      fontSize: fontSize ?? this.fontSize,
      sizeLockScale: sizeLockScale ?? this.sizeLockScale,
      shapeKind: shapeKind ?? this.shapeKind,
      shapeFillColorHex: shapeFillColorHex ?? this.shapeFillColorHex,
      shapeStrokeColorHex: shapeStrokeColorHex ?? this.shapeStrokeColorHex,
      shapeStrokeWidth: shapeStrokeWidth ?? this.shapeStrokeWidth,
      highlightColorHex: highlightColorHex ?? this.highlightColorHex,
      isBinned: isBinned ?? this.isBinned,
      binnedAt: binnedAt ?? this.binnedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (rotation.present) {
      map['rotation'] = Variable<double>(rotation.value);
    }
    if (zIndex.present) {
      map['z_index'] = Variable<int>(zIndex.value);
    }
    if (opacity.present) {
      map['opacity'] = Variable<double>(opacity.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (frameId.present) {
      map['frame_id'] = Variable<String>(frameId.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (backgroundColorHex.present) {
      map['background_color_hex'] = Variable<String>(backgroundColorHex.value);
    }
    if (localFilePath.present) {
      map['local_file_path'] = Variable<String>(localFilePath.value);
    }
    if (imagePanX.present) {
      map['image_pan_x'] = Variable<double>(imagePanX.value);
    }
    if (imagePanY.present) {
      map['image_pan_y'] = Variable<double>(imagePanY.value);
    }
    if (imageZoom.present) {
      map['image_zoom'] = Variable<double>(imageZoom.value);
    }
    if (imageAspectRatio.present) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio.value);
    }
    if (textFormattingJson.present) {
      map['text_formatting_json'] = Variable<String>(textFormattingJson.value);
    }
    if (fontSize.present) {
      map['font_size'] = Variable<double>(fontSize.value);
    }
    if (sizeLockScale.present) {
      map['size_lock_scale'] = Variable<double>(sizeLockScale.value);
    }
    if (shapeKind.present) {
      map['shape_kind'] = Variable<String>(shapeKind.value);
    }
    if (shapeFillColorHex.present) {
      map['shape_fill_color_hex'] = Variable<String>(shapeFillColorHex.value);
    }
    if (shapeStrokeColorHex.present) {
      map['shape_stroke_color_hex'] = Variable<String>(
        shapeStrokeColorHex.value,
      );
    }
    if (shapeStrokeWidth.present) {
      map['shape_stroke_width'] = Variable<double>(shapeStrokeWidth.value);
    }
    if (highlightColorHex.present) {
      map['highlight_color_hex'] = Variable<String>(highlightColorHex.value);
    }
    if (isBinned.present) {
      map['is_binned'] = Variable<bool>(isBinned.value);
    }
    if (binnedAt.present) {
      map['binned_at'] = Variable<DateTime>(binnedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipsCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('type: $type, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('rotation: $rotation, ')
          ..write('zIndex: $zIndex, ')
          ..write('opacity: $opacity, ')
          ..write('groupId: $groupId, ')
          ..write('frameId: $frameId, ')
          ..write('textContent: $textContent, ')
          ..write('backgroundColorHex: $backgroundColorHex, ')
          ..write('localFilePath: $localFilePath, ')
          ..write('imagePanX: $imagePanX, ')
          ..write('imagePanY: $imagePanY, ')
          ..write('imageZoom: $imageZoom, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('textFormattingJson: $textFormattingJson, ')
          ..write('fontSize: $fontSize, ')
          ..write('sizeLockScale: $sizeLockScale, ')
          ..write('shapeKind: $shapeKind, ')
          ..write('shapeFillColorHex: $shapeFillColorHex, ')
          ..write('shapeStrokeColorHex: $shapeStrokeColorHex, ')
          ..write('shapeStrokeWidth: $shapeStrokeWidth, ')
          ..write('highlightColorHex: $highlightColorHex, ')
          ..write('isBinned: $isBinned, ')
          ..write('binnedAt: $binnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StrokesTable extends Strokes with TableInfo<$StrokesTable, StrokeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StrokesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardIdMeta = const VerificationMeta(
    'boardId',
  );
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
    'board_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clipIdMeta = const VerificationMeta('clipId');
  @override
  late final GeneratedColumn<String> clipId = GeneratedColumn<String>(
    'clip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#FF3B30'),
  );
  static const VerificationMeta _strokeWidthMeta = const VerificationMeta(
    'strokeWidth',
  );
  @override
  late final GeneratedColumn<double> strokeWidth = GeneratedColumn<double>(
    'stroke_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _pointsJsonMeta = const VerificationMeta(
    'pointsJson',
  );
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
    'points_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dashedMeta = const VerificationMeta('dashed');
  @override
  late final GeneratedColumn<bool> dashed = GeneratedColumn<bool>(
    'dashed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dashed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _arrowEndMeta = const VerificationMeta(
    'arrowEnd',
  );
  @override
  late final GeneratedColumn<bool> arrowEnd = GeneratedColumn<bool>(
    'arrow_end',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("arrow_end" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boardId,
    clipId,
    color,
    strokeWidth,
    pointsJson,
    dashed,
    arrowEnd,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'strokes';
  @override
  VerificationContext validateIntegrity(
    Insertable<StrokeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(
        _boardIdMeta,
        boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('clip_id')) {
      context.handle(
        _clipIdMeta,
        clipId.isAcceptableOrUnknown(data['clip_id']!, _clipIdMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('stroke_width')) {
      context.handle(
        _strokeWidthMeta,
        strokeWidth.isAcceptableOrUnknown(
          data['stroke_width']!,
          _strokeWidthMeta,
        ),
      );
    }
    if (data.containsKey('points_json')) {
      context.handle(
        _pointsJsonMeta,
        pointsJson.isAcceptableOrUnknown(data['points_json']!, _pointsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('dashed')) {
      context.handle(
        _dashedMeta,
        dashed.isAcceptableOrUnknown(data['dashed']!, _dashedMeta),
      );
    }
    if (data.containsKey('arrow_end')) {
      context.handle(
        _arrowEndMeta,
        arrowEnd.isAcceptableOrUnknown(data['arrow_end']!, _arrowEndMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StrokeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StrokeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      boardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_id'],
      )!,
      clipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clip_id'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      strokeWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stroke_width'],
      )!,
      pointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points_json'],
      )!,
      dashed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dashed'],
      )!,
      arrowEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}arrow_end'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StrokesTable createAlias(String alias) {
    return $StrokesTable(attachedDatabase, alias);
  }
}

class StrokeRow extends DataClass implements Insertable<StrokeRow> {
  final String id;
  final String boardId;
  final String? clipId;
  final String color;
  final double strokeWidth;

  /// JSON-encoded list of [x, y] board-space points.
  final String pointsJson;
  final bool dashed;
  final bool arrowEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StrokeRow({
    required this.id,
    required this.boardId,
    this.clipId,
    required this.color,
    required this.strokeWidth,
    required this.pointsJson,
    required this.dashed,
    required this.arrowEnd,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    if (!nullToAbsent || clipId != null) {
      map['clip_id'] = Variable<String>(clipId);
    }
    map['color'] = Variable<String>(color);
    map['stroke_width'] = Variable<double>(strokeWidth);
    map['points_json'] = Variable<String>(pointsJson);
    map['dashed'] = Variable<bool>(dashed);
    map['arrow_end'] = Variable<bool>(arrowEnd);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StrokesCompanion toCompanion(bool nullToAbsent) {
    return StrokesCompanion(
      id: Value(id),
      boardId: Value(boardId),
      clipId: clipId == null && nullToAbsent
          ? const Value.absent()
          : Value(clipId),
      color: Value(color),
      strokeWidth: Value(strokeWidth),
      pointsJson: Value(pointsJson),
      dashed: Value(dashed),
      arrowEnd: Value(arrowEnd),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StrokeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StrokeRow(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      clipId: serializer.fromJson<String?>(json['clipId']),
      color: serializer.fromJson<String>(json['color']),
      strokeWidth: serializer.fromJson<double>(json['strokeWidth']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      dashed: serializer.fromJson<bool>(json['dashed']),
      arrowEnd: serializer.fromJson<bool>(json['arrowEnd']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'clipId': serializer.toJson<String?>(clipId),
      'color': serializer.toJson<String>(color),
      'strokeWidth': serializer.toJson<double>(strokeWidth),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'dashed': serializer.toJson<bool>(dashed),
      'arrowEnd': serializer.toJson<bool>(arrowEnd),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StrokeRow copyWith({
    String? id,
    String? boardId,
    Value<String?> clipId = const Value.absent(),
    String? color,
    double? strokeWidth,
    String? pointsJson,
    bool? dashed,
    bool? arrowEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StrokeRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    clipId: clipId.present ? clipId.value : this.clipId,
    color: color ?? this.color,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    pointsJson: pointsJson ?? this.pointsJson,
    dashed: dashed ?? this.dashed,
    arrowEnd: arrowEnd ?? this.arrowEnd,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StrokeRow copyWithCompanion(StrokesCompanion data) {
    return StrokeRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      clipId: data.clipId.present ? data.clipId.value : this.clipId,
      color: data.color.present ? data.color.value : this.color,
      strokeWidth: data.strokeWidth.present
          ? data.strokeWidth.value
          : this.strokeWidth,
      pointsJson: data.pointsJson.present
          ? data.pointsJson.value
          : this.pointsJson,
      dashed: data.dashed.present ? data.dashed.value : this.dashed,
      arrowEnd: data.arrowEnd.present ? data.arrowEnd.value : this.arrowEnd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StrokeRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('clipId: $clipId, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('dashed: $dashed, ')
          ..write('arrowEnd: $arrowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boardId,
    clipId,
    color,
    strokeWidth,
    pointsJson,
    dashed,
    arrowEnd,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrokeRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.clipId == this.clipId &&
          other.color == this.color &&
          other.strokeWidth == this.strokeWidth &&
          other.pointsJson == this.pointsJson &&
          other.dashed == this.dashed &&
          other.arrowEnd == this.arrowEnd &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StrokesCompanion extends UpdateCompanion<StrokeRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String?> clipId;
  final Value<String> color;
  final Value<double> strokeWidth;
  final Value<String> pointsJson;
  final Value<bool> dashed;
  final Value<bool> arrowEnd;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StrokesCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.clipId = const Value.absent(),
    this.color = const Value.absent(),
    this.strokeWidth = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.dashed = const Value.absent(),
    this.arrowEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StrokesCompanion.insert({
    required String id,
    required String boardId,
    this.clipId = const Value.absent(),
    this.color = const Value.absent(),
    this.strokeWidth = const Value.absent(),
    required String pointsJson,
    this.dashed = const Value.absent(),
    this.arrowEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId),
       pointsJson = Value(pointsJson);
  static Insertable<StrokeRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? clipId,
    Expression<String>? color,
    Expression<double>? strokeWidth,
    Expression<String>? pointsJson,
    Expression<bool>? dashed,
    Expression<bool>? arrowEnd,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (clipId != null) 'clip_id': clipId,
      if (color != null) 'color': color,
      if (strokeWidth != null) 'stroke_width': strokeWidth,
      if (pointsJson != null) 'points_json': pointsJson,
      if (dashed != null) 'dashed': dashed,
      if (arrowEnd != null) 'arrow_end': arrowEnd,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StrokesCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String?>? clipId,
    Value<String>? color,
    Value<double>? strokeWidth,
    Value<String>? pointsJson,
    Value<bool>? dashed,
    Value<bool>? arrowEnd,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StrokesCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      clipId: clipId ?? this.clipId,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      pointsJson: pointsJson ?? this.pointsJson,
      dashed: dashed ?? this.dashed,
      arrowEnd: arrowEnd ?? this.arrowEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (clipId.present) {
      map['clip_id'] = Variable<String>(clipId.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (strokeWidth.present) {
      map['stroke_width'] = Variable<double>(strokeWidth.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (dashed.present) {
      map['dashed'] = Variable<bool>(dashed.value);
    }
    if (arrowEnd.present) {
      map['arrow_end'] = Variable<bool>(arrowEnd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StrokesCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('clipId: $clipId, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('dashed: $dashed, ')
          ..write('arrowEnd: $arrowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BoardsTable extends Boards with TableInfo<$BoardsTable, BoardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('My Board'),
  );
  static const VerificationMeta _backupFilePathMeta = const VerificationMeta(
    'backupFilePath',
  );
  @override
  late final GeneratedColumn<String> backupFilePath = GeneratedColumn<String>(
    'backup_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _viewPanXMeta = const VerificationMeta(
    'viewPanX',
  );
  @override
  late final GeneratedColumn<double> viewPanX = GeneratedColumn<double>(
    'view_pan_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewPanYMeta = const VerificationMeta(
    'viewPanY',
  );
  @override
  late final GeneratedColumn<double> viewPanY = GeneratedColumn<double>(
    'view_pan_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewScaleMeta = const VerificationMeta(
    'viewScale',
  );
  @override
  late final GeneratedColumn<double> viewScale = GeneratedColumn<double>(
    'view_scale',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    backupFilePath,
    colorHex,
    sortOrder,
    viewPanX,
    viewPanY,
    viewScale,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boards';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('backup_file_path')) {
      context.handle(
        _backupFilePathMeta,
        backupFilePath.isAcceptableOrUnknown(
          data['backup_file_path']!,
          _backupFilePathMeta,
        ),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('view_pan_x')) {
      context.handle(
        _viewPanXMeta,
        viewPanX.isAcceptableOrUnknown(data['view_pan_x']!, _viewPanXMeta),
      );
    }
    if (data.containsKey('view_pan_y')) {
      context.handle(
        _viewPanYMeta,
        viewPanY.isAcceptableOrUnknown(data['view_pan_y']!, _viewPanYMeta),
      );
    }
    if (data.containsKey('view_scale')) {
      context.handle(
        _viewScaleMeta,
        viewScale.isAcceptableOrUnknown(data['view_scale']!, _viewScaleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      backupFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_file_path'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      viewPanX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}view_pan_x'],
      ),
      viewPanY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}view_pan_y'],
      ),
      viewScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}view_scale'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BoardsTable createAlias(String alias) {
    return $BoardsTable(attachedDatabase, alias);
  }
}

class BoardRow extends DataClass implements Insertable<BoardRow> {
  final String id;
  final String name;

  /// Filesystem path this board was last opened from or saved to as a
  /// `.hbbackup` file, or null if it's never been associated with one
  /// (e.g. the seeded default board, or one built from scratch). Lets
  /// "Save" write back to this exact file with no dialog, instead of
  /// always behaving like "Save As" - see `board_backup_service.dart`.
  /// Always null on web (no ambient filesystem path exists there).
  final String? backupFilePath;

  /// Custom background tint for this board's row in "Manage boards", as
  /// `#RRGGBB` - purely a glance-at-a-list organizational aid, no effect
  /// anywhere else. Null uses the dialog's default row background - same
  /// null-means-default convention as `Frames.backgroundColorHex`.
  final String? colorHex;

  /// User-controlled display order in "Manage boards" (and everywhere
  /// else boards are listed) - lower sorts first. Not necessarily
  /// contiguous; only relative order matters. Sits alongside `createdAt`
  /// rather than replacing it, since `createdAt` is also kept as a
  /// stable, never-reordered tiebreaker.
  final int sortOrder;

  /// Last pan/zoom camera this board was viewed at - null means this
  /// board has never had a view saved (brand new, or predates this
  /// column), which falls back to `BoardViewState()`'s own default
  /// (centered, scale 1) - the same view every board already opens to
  /// today. Always written/read together as one (panX, panY, scale)
  /// triple; see `BoardViewPersistenceController`.
  final double? viewPanX;
  final double? viewPanY;
  final double? viewScale;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BoardRow({
    required this.id,
    required this.name,
    this.backupFilePath,
    this.colorHex,
    required this.sortOrder,
    this.viewPanX,
    this.viewPanY,
    this.viewScale,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || backupFilePath != null) {
      map['backup_file_path'] = Variable<String>(backupFilePath);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || viewPanX != null) {
      map['view_pan_x'] = Variable<double>(viewPanX);
    }
    if (!nullToAbsent || viewPanY != null) {
      map['view_pan_y'] = Variable<double>(viewPanY);
    }
    if (!nullToAbsent || viewScale != null) {
      map['view_scale'] = Variable<double>(viewScale);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BoardsCompanion toCompanion(bool nullToAbsent) {
    return BoardsCompanion(
      id: Value(id),
      name: Value(name),
      backupFilePath: backupFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(backupFilePath),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      sortOrder: Value(sortOrder),
      viewPanX: viewPanX == null && nullToAbsent
          ? const Value.absent()
          : Value(viewPanX),
      viewPanY: viewPanY == null && nullToAbsent
          ? const Value.absent()
          : Value(viewPanY),
      viewScale: viewScale == null && nullToAbsent
          ? const Value.absent()
          : Value(viewScale),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BoardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      backupFilePath: serializer.fromJson<String?>(json['backupFilePath']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      viewPanX: serializer.fromJson<double?>(json['viewPanX']),
      viewPanY: serializer.fromJson<double?>(json['viewPanY']),
      viewScale: serializer.fromJson<double?>(json['viewScale']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'backupFilePath': serializer.toJson<String?>(backupFilePath),
      'colorHex': serializer.toJson<String?>(colorHex),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'viewPanX': serializer.toJson<double?>(viewPanX),
      'viewPanY': serializer.toJson<double?>(viewPanY),
      'viewScale': serializer.toJson<double?>(viewScale),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BoardRow copyWith({
    String? id,
    String? name,
    Value<String?> backupFilePath = const Value.absent(),
    Value<String?> colorHex = const Value.absent(),
    int? sortOrder,
    Value<double?> viewPanX = const Value.absent(),
    Value<double?> viewPanY = const Value.absent(),
    Value<double?> viewScale = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BoardRow(
    id: id ?? this.id,
    name: name ?? this.name,
    backupFilePath: backupFilePath.present
        ? backupFilePath.value
        : this.backupFilePath,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    sortOrder: sortOrder ?? this.sortOrder,
    viewPanX: viewPanX.present ? viewPanX.value : this.viewPanX,
    viewPanY: viewPanY.present ? viewPanY.value : this.viewPanY,
    viewScale: viewScale.present ? viewScale.value : this.viewScale,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BoardRow copyWithCompanion(BoardsCompanion data) {
    return BoardRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      backupFilePath: data.backupFilePath.present
          ? data.backupFilePath.value
          : this.backupFilePath,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      viewPanX: data.viewPanX.present ? data.viewPanX.value : this.viewPanX,
      viewPanY: data.viewPanY.present ? data.viewPanY.value : this.viewPanY,
      viewScale: data.viewScale.present ? data.viewScale.value : this.viewScale,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backupFilePath: $backupFilePath, ')
          ..write('colorHex: $colorHex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('viewPanX: $viewPanX, ')
          ..write('viewPanY: $viewPanY, ')
          ..write('viewScale: $viewScale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    backupFilePath,
    colorHex,
    sortOrder,
    viewPanX,
    viewPanY,
    viewScale,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.backupFilePath == this.backupFilePath &&
          other.colorHex == this.colorHex &&
          other.sortOrder == this.sortOrder &&
          other.viewPanX == this.viewPanX &&
          other.viewPanY == this.viewPanY &&
          other.viewScale == this.viewScale &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BoardsCompanion extends UpdateCompanion<BoardRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> backupFilePath;
  final Value<String?> colorHex;
  final Value<int> sortOrder;
  final Value<double?> viewPanX;
  final Value<double?> viewPanY;
  final Value<double?> viewScale;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BoardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.backupFilePath = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.viewPanX = const Value.absent(),
    this.viewPanY = const Value.absent(),
    this.viewScale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardsCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    this.backupFilePath = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.viewPanX = const Value.absent(),
    this.viewPanY = const Value.absent(),
    this.viewScale = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<BoardRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? backupFilePath,
    Expression<String>? colorHex,
    Expression<int>? sortOrder,
    Expression<double>? viewPanX,
    Expression<double>? viewPanY,
    Expression<double>? viewScale,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (backupFilePath != null) 'backup_file_path': backupFilePath,
      if (colorHex != null) 'color_hex': colorHex,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (viewPanX != null) 'view_pan_x': viewPanX,
      if (viewPanY != null) 'view_pan_y': viewPanY,
      if (viewScale != null) 'view_scale': viewScale,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? backupFilePath,
    Value<String?>? colorHex,
    Value<int>? sortOrder,
    Value<double?>? viewPanX,
    Value<double?>? viewPanY,
    Value<double?>? viewScale,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BoardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      backupFilePath: backupFilePath ?? this.backupFilePath,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      viewPanX: viewPanX ?? this.viewPanX,
      viewPanY: viewPanY ?? this.viewPanY,
      viewScale: viewScale ?? this.viewScale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (backupFilePath.present) {
      map['backup_file_path'] = Variable<String>(backupFilePath.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (viewPanX.present) {
      map['view_pan_x'] = Variable<double>(viewPanX.value);
    }
    if (viewPanY.present) {
      map['view_pan_y'] = Variable<double>(viewPanY.value);
    }
    if (viewScale.present) {
      map['view_scale'] = Variable<double>(viewScale.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('backupFilePath: $backupFilePath, ')
          ..write('colorHex: $colorHex, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('viewPanX: $viewPanX, ')
          ..write('viewPanY: $viewPanY, ')
          ..write('viewScale: $viewScale, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBlobsTable extends LocalBlobs
    with TableInfo<$LocalBlobsTable, LocalBlob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBlobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_blobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBlob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBlob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBlob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $LocalBlobsTable createAlias(String alias) {
    return $LocalBlobsTable(attachedDatabase, alias);
  }
}

class LocalBlob extends DataClass implements Insertable<LocalBlob> {
  final String id;
  final Uint8List bytes;
  const LocalBlob({required this.id, required this.bytes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  LocalBlobsCompanion toCompanion(bool nullToAbsent) {
    return LocalBlobsCompanion(id: Value(id), bytes: Value(bytes));
  }

  factory LocalBlob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBlob(
      id: serializer.fromJson<String>(json['id']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  LocalBlob copyWith({String? id, Uint8List? bytes}) =>
      LocalBlob(id: id ?? this.id, bytes: bytes ?? this.bytes);
  LocalBlob copyWithCompanion(LocalBlobsCompanion data) {
    return LocalBlob(
      id: data.id.present ? data.id.value : this.id,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlob(')
          ..write('id: $id, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBlob &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class LocalBlobsCompanion extends UpdateCompanion<LocalBlob> {
  final Value<String> id;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const LocalBlobsCompanion({
    this.id = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBlobsCompanion.insert({
    required String id,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bytes = Value(bytes);
  static Insertable<LocalBlob> custom({
    Expression<String>? id,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBlobsCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return LocalBlobsCompanion(
      id: id ?? this.id,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlobsCompanion(')
          ..write('id: $id, ')
          ..write('bytes: $bytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FramesTable extends Frames with TableInfo<$FramesTable, FrameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FramesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardIdMeta = const VerificationMeta(
    'boardId',
  );
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
    'board_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Frame'),
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(320),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(240),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _backgroundColorHexMeta =
      const VerificationMeta('backgroundColorHex');
  @override
  late final GeneratedColumn<String> backgroundColorHex =
      GeneratedColumn<String>(
        'background_color_hex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boardId,
    name,
    x,
    y,
    width,
    height,
    sortOrder,
    backgroundColorHex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'frames';
  @override
  VerificationContext validateIntegrity(
    Insertable<FrameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(
        _boardIdMeta,
        boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('background_color_hex')) {
      context.handle(
        _backgroundColorHexMeta,
        backgroundColorHex.isAcceptableOrUnknown(
          data['background_color_hex']!,
          _backgroundColorHexMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FrameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FrameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      boardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      backgroundColorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_color_hex'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FramesTable createAlias(String alias) {
    return $FramesTable(attachedDatabase, alias);
  }
}

class FrameRow extends DataClass implements Insertable<FrameRow> {
  final String id;
  final String boardId;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;

  /// User-controlled display order in the Frames Panel (and on-canvas
  /// stacking order, since both read the same `watchFrames()` list - frames
  /// have no separate z-index concept) - lower sorts first. Not necessarily
  /// contiguous; only relative order matters. Sits alongside `createdAt`
  /// rather than replacing it, since `createdAt` is also kept as a stable,
  /// never-reordered tiebreaker.
  final int sortOrder;

  /// Custom accent color for this frame's border/label/subtle fill, as
  /// `#RRGGBB`. Null uses the default neutral gray - same
  /// null-means-default convention as `Clips.backgroundColorHex`.
  final String? backgroundColorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FrameRow({
    required this.id,
    required this.boardId,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sortOrder,
    this.backgroundColorHex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['name'] = Variable<String>(name);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || backgroundColorHex != null) {
      map['background_color_hex'] = Variable<String>(backgroundColorHex);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FramesCompanion toCompanion(bool nullToAbsent) {
    return FramesCompanion(
      id: Value(id),
      boardId: Value(boardId),
      name: Value(name),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      sortOrder: Value(sortOrder),
      backgroundColorHex: backgroundColorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColorHex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FrameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FrameRow(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      name: serializer.fromJson<String>(json['name']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      backgroundColorHex: serializer.fromJson<String?>(
        json['backgroundColorHex'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'name': serializer.toJson<String>(name),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'backgroundColorHex': serializer.toJson<String?>(backgroundColorHex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FrameRow copyWith({
    String? id,
    String? boardId,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    int? sortOrder,
    Value<String?> backgroundColorHex = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FrameRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    name: name ?? this.name,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    sortOrder: sortOrder ?? this.sortOrder,
    backgroundColorHex: backgroundColorHex.present
        ? backgroundColorHex.value
        : this.backgroundColorHex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FrameRow copyWithCompanion(FramesCompanion data) {
    return FrameRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      name: data.name.present ? data.name.value : this.name,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      backgroundColorHex: data.backgroundColorHex.present
          ? data.backgroundColorHex.value
          : this.backgroundColorHex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FrameRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('backgroundColorHex: $backgroundColorHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boardId,
    name,
    x,
    y,
    width,
    height,
    sortOrder,
    backgroundColorHex,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FrameRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.name == this.name &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.sortOrder == this.sortOrder &&
          other.backgroundColorHex == this.backgroundColorHex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FramesCompanion extends UpdateCompanion<FrameRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> name;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<int> sortOrder;
  final Value<String?> backgroundColorHex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FramesCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.name = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.backgroundColorHex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FramesCompanion.insert({
    required String id,
    required String boardId,
    this.name = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.backgroundColorHex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId);
  static Insertable<FrameRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? name,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<int>? sortOrder,
    Expression<String>? backgroundColorHex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (name != null) 'name': name,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (backgroundColorHex != null)
        'background_color_hex': backgroundColorHex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FramesCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String>? name,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<int>? sortOrder,
    Value<String?>? backgroundColorHex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FramesCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      sortOrder: sortOrder ?? this.sortOrder,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (backgroundColorHex.present) {
      map['background_color_hex'] = Variable<String>(backgroundColorHex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FramesCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('backgroundColorHex: $backgroundColorHex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConnectorsTable extends Connectors
    with TableInfo<$ConnectorsTable, ConnectorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardIdMeta = const VerificationMeta(
    'boardId',
  );
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
    'board_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromClipIdMeta = const VerificationMeta(
    'fromClipId',
  );
  @override
  late final GeneratedColumn<String> fromClipId = GeneratedColumn<String>(
    'from_clip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromSideMeta = const VerificationMeta(
    'fromSide',
  );
  @override
  late final GeneratedColumn<String> fromSide = GeneratedColumn<String>(
    'from_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toClipIdMeta = const VerificationMeta(
    'toClipId',
  );
  @override
  late final GeneratedColumn<String> toClipId = GeneratedColumn<String>(
    'to_clip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toRelXMeta = const VerificationMeta('toRelX');
  @override
  late final GeneratedColumn<double> toRelX = GeneratedColumn<double>(
    'to_rel_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toRelYMeta = const VerificationMeta('toRelY');
  @override
  late final GeneratedColumn<double> toRelY = GeneratedColumn<double>(
    'to_rel_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#FFFFFF'),
  );
  static const VerificationMeta _strokeWidthMeta = const VerificationMeta(
    'strokeWidth',
  );
  @override
  late final GeneratedColumn<double> strokeWidth = GeneratedColumn<double>(
    'stroke_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boardId,
    fromClipId,
    fromSide,
    toClipId,
    toRelX,
    toRelY,
    color,
    strokeWidth,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(
        _boardIdMeta,
        boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('from_clip_id')) {
      context.handle(
        _fromClipIdMeta,
        fromClipId.isAcceptableOrUnknown(
          data['from_clip_id']!,
          _fromClipIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromClipIdMeta);
    }
    if (data.containsKey('from_side')) {
      context.handle(
        _fromSideMeta,
        fromSide.isAcceptableOrUnknown(data['from_side']!, _fromSideMeta),
      );
    } else if (isInserting) {
      context.missing(_fromSideMeta);
    }
    if (data.containsKey('to_clip_id')) {
      context.handle(
        _toClipIdMeta,
        toClipId.isAcceptableOrUnknown(data['to_clip_id']!, _toClipIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toClipIdMeta);
    }
    if (data.containsKey('to_rel_x')) {
      context.handle(
        _toRelXMeta,
        toRelX.isAcceptableOrUnknown(data['to_rel_x']!, _toRelXMeta),
      );
    }
    if (data.containsKey('to_rel_y')) {
      context.handle(
        _toRelYMeta,
        toRelY.isAcceptableOrUnknown(data['to_rel_y']!, _toRelYMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('stroke_width')) {
      context.handle(
        _strokeWidthMeta,
        strokeWidth.isAcceptableOrUnknown(
          data['stroke_width']!,
          _strokeWidthMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectorRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      boardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_id'],
      )!,
      fromClipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_clip_id'],
      )!,
      fromSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_side'],
      )!,
      toClipId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_clip_id'],
      )!,
      toRelX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_rel_x'],
      ),
      toRelY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}to_rel_y'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      strokeWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stroke_width'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConnectorsTable createAlias(String alias) {
    return $ConnectorsTable(attachedDatabase, alias);
  }
}

class ConnectorRow extends DataClass implements Insertable<ConnectorRow> {
  final String id;
  final String boardId;
  final String fromClipId;
  final String fromSide;
  final String toClipId;

  /// The target anchor's position as a fraction (0-1) of [toClipId]'s own
  /// width/height, in its local unrotated frame - lets a connector land on
  /// any specific spot on the target's surface, not just its boundary.
  /// Null (legacy rows, or any row this session's migration didn't touch)
  /// falls back to the original behavior: the anchor is recomputed live
  /// every frame as the nearest point on the target clip's (rotated)
  /// boundary to the source anchor, so it stays correct as either clip
  /// moves/resizes/rotates without a stale stored value.
  final double? toRelX;
  final double? toRelY;
  final String color;
  final double strokeWidth;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConnectorRow({
    required this.id,
    required this.boardId,
    required this.fromClipId,
    required this.fromSide,
    required this.toClipId,
    this.toRelX,
    this.toRelY,
    required this.color,
    required this.strokeWidth,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['from_clip_id'] = Variable<String>(fromClipId);
    map['from_side'] = Variable<String>(fromSide);
    map['to_clip_id'] = Variable<String>(toClipId);
    if (!nullToAbsent || toRelX != null) {
      map['to_rel_x'] = Variable<double>(toRelX);
    }
    if (!nullToAbsent || toRelY != null) {
      map['to_rel_y'] = Variable<double>(toRelY);
    }
    map['color'] = Variable<String>(color);
    map['stroke_width'] = Variable<double>(strokeWidth);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConnectorsCompanion toCompanion(bool nullToAbsent) {
    return ConnectorsCompanion(
      id: Value(id),
      boardId: Value(boardId),
      fromClipId: Value(fromClipId),
      fromSide: Value(fromSide),
      toClipId: Value(toClipId),
      toRelX: toRelX == null && nullToAbsent
          ? const Value.absent()
          : Value(toRelX),
      toRelY: toRelY == null && nullToAbsent
          ? const Value.absent()
          : Value(toRelY),
      color: Value(color),
      strokeWidth: Value(strokeWidth),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConnectorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectorRow(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      fromClipId: serializer.fromJson<String>(json['fromClipId']),
      fromSide: serializer.fromJson<String>(json['fromSide']),
      toClipId: serializer.fromJson<String>(json['toClipId']),
      toRelX: serializer.fromJson<double?>(json['toRelX']),
      toRelY: serializer.fromJson<double?>(json['toRelY']),
      color: serializer.fromJson<String>(json['color']),
      strokeWidth: serializer.fromJson<double>(json['strokeWidth']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'fromClipId': serializer.toJson<String>(fromClipId),
      'fromSide': serializer.toJson<String>(fromSide),
      'toClipId': serializer.toJson<String>(toClipId),
      'toRelX': serializer.toJson<double?>(toRelX),
      'toRelY': serializer.toJson<double?>(toRelY),
      'color': serializer.toJson<String>(color),
      'strokeWidth': serializer.toJson<double>(strokeWidth),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConnectorRow copyWith({
    String? id,
    String? boardId,
    String? fromClipId,
    String? fromSide,
    String? toClipId,
    Value<double?> toRelX = const Value.absent(),
    Value<double?> toRelY = const Value.absent(),
    String? color,
    double? strokeWidth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConnectorRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    fromClipId: fromClipId ?? this.fromClipId,
    fromSide: fromSide ?? this.fromSide,
    toClipId: toClipId ?? this.toClipId,
    toRelX: toRelX.present ? toRelX.value : this.toRelX,
    toRelY: toRelY.present ? toRelY.value : this.toRelY,
    color: color ?? this.color,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConnectorRow copyWithCompanion(ConnectorsCompanion data) {
    return ConnectorRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      fromClipId: data.fromClipId.present
          ? data.fromClipId.value
          : this.fromClipId,
      fromSide: data.fromSide.present ? data.fromSide.value : this.fromSide,
      toClipId: data.toClipId.present ? data.toClipId.value : this.toClipId,
      toRelX: data.toRelX.present ? data.toRelX.value : this.toRelX,
      toRelY: data.toRelY.present ? data.toRelY.value : this.toRelY,
      color: data.color.present ? data.color.value : this.color,
      strokeWidth: data.strokeWidth.present
          ? data.strokeWidth.value
          : this.strokeWidth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectorRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('fromClipId: $fromClipId, ')
          ..write('fromSide: $fromSide, ')
          ..write('toClipId: $toClipId, ')
          ..write('toRelX: $toRelX, ')
          ..write('toRelY: $toRelY, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boardId,
    fromClipId,
    fromSide,
    toClipId,
    toRelX,
    toRelY,
    color,
    strokeWidth,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectorRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.fromClipId == this.fromClipId &&
          other.fromSide == this.fromSide &&
          other.toClipId == this.toClipId &&
          other.toRelX == this.toRelX &&
          other.toRelY == this.toRelY &&
          other.color == this.color &&
          other.strokeWidth == this.strokeWidth &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConnectorsCompanion extends UpdateCompanion<ConnectorRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> fromClipId;
  final Value<String> fromSide;
  final Value<String> toClipId;
  final Value<double?> toRelX;
  final Value<double?> toRelY;
  final Value<String> color;
  final Value<double> strokeWidth;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConnectorsCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.fromClipId = const Value.absent(),
    this.fromSide = const Value.absent(),
    this.toClipId = const Value.absent(),
    this.toRelX = const Value.absent(),
    this.toRelY = const Value.absent(),
    this.color = const Value.absent(),
    this.strokeWidth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConnectorsCompanion.insert({
    required String id,
    required String boardId,
    required String fromClipId,
    required String fromSide,
    required String toClipId,
    this.toRelX = const Value.absent(),
    this.toRelY = const Value.absent(),
    this.color = const Value.absent(),
    this.strokeWidth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId),
       fromClipId = Value(fromClipId),
       fromSide = Value(fromSide),
       toClipId = Value(toClipId);
  static Insertable<ConnectorRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? fromClipId,
    Expression<String>? fromSide,
    Expression<String>? toClipId,
    Expression<double>? toRelX,
    Expression<double>? toRelY,
    Expression<String>? color,
    Expression<double>? strokeWidth,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (fromClipId != null) 'from_clip_id': fromClipId,
      if (fromSide != null) 'from_side': fromSide,
      if (toClipId != null) 'to_clip_id': toClipId,
      if (toRelX != null) 'to_rel_x': toRelX,
      if (toRelY != null) 'to_rel_y': toRelY,
      if (color != null) 'color': color,
      if (strokeWidth != null) 'stroke_width': strokeWidth,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConnectorsCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String>? fromClipId,
    Value<String>? fromSide,
    Value<String>? toClipId,
    Value<double?>? toRelX,
    Value<double?>? toRelY,
    Value<String>? color,
    Value<double>? strokeWidth,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConnectorsCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      fromClipId: fromClipId ?? this.fromClipId,
      fromSide: fromSide ?? this.fromSide,
      toClipId: toClipId ?? this.toClipId,
      toRelX: toRelX ?? this.toRelX,
      toRelY: toRelY ?? this.toRelY,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (fromClipId.present) {
      map['from_clip_id'] = Variable<String>(fromClipId.value);
    }
    if (fromSide.present) {
      map['from_side'] = Variable<String>(fromSide.value);
    }
    if (toClipId.present) {
      map['to_clip_id'] = Variable<String>(toClipId.value);
    }
    if (toRelX.present) {
      map['to_rel_x'] = Variable<double>(toRelX.value);
    }
    if (toRelY.present) {
      map['to_rel_y'] = Variable<double>(toRelY.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (strokeWidth.present) {
      map['stroke_width'] = Variable<double>(strokeWidth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectorsCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('fromClipId: $fromClipId, ')
          ..write('fromSide: $fromSide, ')
          ..write('toClipId: $toClipId, ')
          ..write('toRelX: $toRelX, ')
          ..write('toRelY: $toRelY, ')
          ..write('color: $color, ')
          ..write('strokeWidth: $strokeWidth, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ClipsTable clips = $ClipsTable(this);
  late final $StrokesTable strokes = $StrokesTable(this);
  late final $BoardsTable boards = $BoardsTable(this);
  late final $LocalBlobsTable localBlobs = $LocalBlobsTable(this);
  late final $FramesTable frames = $FramesTable(this);
  late final $ConnectorsTable connectors = $ConnectorsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    clips,
    strokes,
    boards,
    localBlobs,
    frames,
    connectors,
  ];
}

typedef $$ClipsTableCreateCompanionBuilder =
    ClipsCompanion Function({
      required String id,
      required String boardId,
      required String type,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<double> rotation,
      Value<int> zIndex,
      Value<double> opacity,
      Value<String?> groupId,
      Value<String?> frameId,
      Value<String?> textContent,
      Value<String?> backgroundColorHex,
      Value<String?> localFilePath,
      Value<double> imagePanX,
      Value<double> imagePanY,
      Value<double> imageZoom,
      Value<double?> imageAspectRatio,
      Value<String?> textFormattingJson,
      Value<double?> fontSize,
      Value<double?> sizeLockScale,
      Value<String?> shapeKind,
      Value<String?> shapeFillColorHex,
      Value<String?> shapeStrokeColorHex,
      Value<double?> shapeStrokeWidth,
      Value<String?> highlightColorHex,
      Value<bool> isBinned,
      Value<DateTime?> binnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ClipsTableUpdateCompanionBuilder =
    ClipsCompanion Function({
      Value<String> id,
      Value<String> boardId,
      Value<String> type,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<double> rotation,
      Value<int> zIndex,
      Value<double> opacity,
      Value<String?> groupId,
      Value<String?> frameId,
      Value<String?> textContent,
      Value<String?> backgroundColorHex,
      Value<String?> localFilePath,
      Value<double> imagePanX,
      Value<double> imagePanY,
      Value<double> imageZoom,
      Value<double?> imageAspectRatio,
      Value<String?> textFormattingJson,
      Value<double?> fontSize,
      Value<double?> sizeLockScale,
      Value<String?> shapeKind,
      Value<String?> shapeFillColorHex,
      Value<String?> shapeStrokeColorHex,
      Value<double?> shapeStrokeWidth,
      Value<String?> highlightColorHex,
      Value<bool> isBinned,
      Value<DateTime?> binnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ClipsTableFilterComposer extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get zIndex => $composableBuilder(
    column: $table.zIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frameId => $composableBuilder(
    column: $table.frameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imagePanX => $composableBuilder(
    column: $table.imagePanX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imagePanY => $composableBuilder(
    column: $table.imagePanY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageZoom => $composableBuilder(
    column: $table.imageZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textFormattingJson => $composableBuilder(
    column: $table.textFormattingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sizeLockScale => $composableBuilder(
    column: $table.sizeLockScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shapeKind => $composableBuilder(
    column: $table.shapeKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shapeFillColorHex => $composableBuilder(
    column: $table.shapeFillColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shapeStrokeColorHex => $composableBuilder(
    column: $table.shapeStrokeColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shapeStrokeWidth => $composableBuilder(
    column: $table.shapeStrokeWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highlightColorHex => $composableBuilder(
    column: $table.highlightColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBinned => $composableBuilder(
    column: $table.isBinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get binnedAt => $composableBuilder(
    column: $table.binnedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rotation => $composableBuilder(
    column: $table.rotation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get zIndex => $composableBuilder(
    column: $table.zIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frameId => $composableBuilder(
    column: $table.frameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imagePanX => $composableBuilder(
    column: $table.imagePanX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imagePanY => $composableBuilder(
    column: $table.imagePanY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageZoom => $composableBuilder(
    column: $table.imageZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textFormattingJson => $composableBuilder(
    column: $table.textFormattingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fontSize => $composableBuilder(
    column: $table.fontSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sizeLockScale => $composableBuilder(
    column: $table.sizeLockScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shapeKind => $composableBuilder(
    column: $table.shapeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shapeFillColorHex => $composableBuilder(
    column: $table.shapeFillColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shapeStrokeColorHex => $composableBuilder(
    column: $table.shapeStrokeColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shapeStrokeWidth => $composableBuilder(
    column: $table.shapeStrokeWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highlightColorHex => $composableBuilder(
    column: $table.highlightColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBinned => $composableBuilder(
    column: $table.isBinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get binnedAt => $composableBuilder(
    column: $table.binnedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipsTable> {
  $$ClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get rotation =>
      $composableBuilder(column: $table.rotation, builder: (column) => column);

  GeneratedColumn<int> get zIndex =>
      $composableBuilder(column: $table.zIndex, builder: (column) => column);

  GeneratedColumn<double> get opacity =>
      $composableBuilder(column: $table.opacity, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get frameId =>
      $composableBuilder(column: $table.frameId, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localFilePath => $composableBuilder(
    column: $table.localFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<double> get imagePanX =>
      $composableBuilder(column: $table.imagePanX, builder: (column) => column);

  GeneratedColumn<double> get imagePanY =>
      $composableBuilder(column: $table.imagePanY, builder: (column) => column);

  GeneratedColumn<double> get imageZoom =>
      $composableBuilder(column: $table.imageZoom, builder: (column) => column);

  GeneratedColumn<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textFormattingJson => $composableBuilder(
    column: $table.textFormattingJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fontSize =>
      $composableBuilder(column: $table.fontSize, builder: (column) => column);

  GeneratedColumn<double> get sizeLockScale => $composableBuilder(
    column: $table.sizeLockScale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shapeKind =>
      $composableBuilder(column: $table.shapeKind, builder: (column) => column);

  GeneratedColumn<String> get shapeFillColorHex => $composableBuilder(
    column: $table.shapeFillColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shapeStrokeColorHex => $composableBuilder(
    column: $table.shapeStrokeColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shapeStrokeWidth => $composableBuilder(
    column: $table.shapeStrokeWidth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highlightColorHex => $composableBuilder(
    column: $table.highlightColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBinned =>
      $composableBuilder(column: $table.isBinned, builder: (column) => column);

  GeneratedColumn<DateTime> get binnedAt =>
      $composableBuilder(column: $table.binnedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClipsTable,
          ClipRow,
          $$ClipsTableFilterComposer,
          $$ClipsTableOrderingComposer,
          $$ClipsTableAnnotationComposer,
          $$ClipsTableCreateCompanionBuilder,
          $$ClipsTableUpdateCompanionBuilder,
          (ClipRow, BaseReferences<_$AppDatabase, $ClipsTable, ClipRow>),
          ClipRow,
          PrefetchHooks Function()
        > {
  $$ClipsTableTableManager(_$AppDatabase db, $ClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> boardId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<int> zIndex = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> frameId = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> backgroundColorHex = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<double> imagePanX = const Value.absent(),
                Value<double> imagePanY = const Value.absent(),
                Value<double> imageZoom = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String?> textFormattingJson = const Value.absent(),
                Value<double?> fontSize = const Value.absent(),
                Value<double?> sizeLockScale = const Value.absent(),
                Value<String?> shapeKind = const Value.absent(),
                Value<String?> shapeFillColorHex = const Value.absent(),
                Value<String?> shapeStrokeColorHex = const Value.absent(),
                Value<double?> shapeStrokeWidth = const Value.absent(),
                Value<String?> highlightColorHex = const Value.absent(),
                Value<bool> isBinned = const Value.absent(),
                Value<DateTime?> binnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion(
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
                groupId: groupId,
                frameId: frameId,
                textContent: textContent,
                backgroundColorHex: backgroundColorHex,
                localFilePath: localFilePath,
                imagePanX: imagePanX,
                imagePanY: imagePanY,
                imageZoom: imageZoom,
                imageAspectRatio: imageAspectRatio,
                textFormattingJson: textFormattingJson,
                fontSize: fontSize,
                sizeLockScale: sizeLockScale,
                shapeKind: shapeKind,
                shapeFillColorHex: shapeFillColorHex,
                shapeStrokeColorHex: shapeStrokeColorHex,
                shapeStrokeWidth: shapeStrokeWidth,
                highlightColorHex: highlightColorHex,
                isBinned: isBinned,
                binnedAt: binnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                required String type,
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> rotation = const Value.absent(),
                Value<int> zIndex = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> frameId = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> backgroundColorHex = const Value.absent(),
                Value<String?> localFilePath = const Value.absent(),
                Value<double> imagePanX = const Value.absent(),
                Value<double> imagePanY = const Value.absent(),
                Value<double> imageZoom = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String?> textFormattingJson = const Value.absent(),
                Value<double?> fontSize = const Value.absent(),
                Value<double?> sizeLockScale = const Value.absent(),
                Value<String?> shapeKind = const Value.absent(),
                Value<String?> shapeFillColorHex = const Value.absent(),
                Value<String?> shapeStrokeColorHex = const Value.absent(),
                Value<double?> shapeStrokeWidth = const Value.absent(),
                Value<String?> highlightColorHex = const Value.absent(),
                Value<bool> isBinned = const Value.absent(),
                Value<DateTime?> binnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClipsCompanion.insert(
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
                groupId: groupId,
                frameId: frameId,
                textContent: textContent,
                backgroundColorHex: backgroundColorHex,
                localFilePath: localFilePath,
                imagePanX: imagePanX,
                imagePanY: imagePanY,
                imageZoom: imageZoom,
                imageAspectRatio: imageAspectRatio,
                textFormattingJson: textFormattingJson,
                fontSize: fontSize,
                sizeLockScale: sizeLockScale,
                shapeKind: shapeKind,
                shapeFillColorHex: shapeFillColorHex,
                shapeStrokeColorHex: shapeStrokeColorHex,
                shapeStrokeWidth: shapeStrokeWidth,
                highlightColorHex: highlightColorHex,
                isBinned: isBinned,
                binnedAt: binnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClipsTable,
      ClipRow,
      $$ClipsTableFilterComposer,
      $$ClipsTableOrderingComposer,
      $$ClipsTableAnnotationComposer,
      $$ClipsTableCreateCompanionBuilder,
      $$ClipsTableUpdateCompanionBuilder,
      (ClipRow, BaseReferences<_$AppDatabase, $ClipsTable, ClipRow>),
      ClipRow,
      PrefetchHooks Function()
    >;
typedef $$StrokesTableCreateCompanionBuilder =
    StrokesCompanion Function({
      required String id,
      required String boardId,
      Value<String?> clipId,
      Value<String> color,
      Value<double> strokeWidth,
      required String pointsJson,
      Value<bool> dashed,
      Value<bool> arrowEnd,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StrokesTableUpdateCompanionBuilder =
    StrokesCompanion Function({
      Value<String> id,
      Value<String> boardId,
      Value<String?> clipId,
      Value<String> color,
      Value<double> strokeWidth,
      Value<String> pointsJson,
      Value<bool> dashed,
      Value<bool> arrowEnd,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StrokesTableFilterComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dashed => $composableBuilder(
    column: $table.dashed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get arrowEnd => $composableBuilder(
    column: $table.arrowEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StrokesTableOrderingComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clipId => $composableBuilder(
    column: $table.clipId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dashed => $composableBuilder(
    column: $table.dashed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get arrowEnd => $composableBuilder(
    column: $table.arrowEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StrokesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StrokesTable> {
  $$StrokesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get clipId =>
      $composableBuilder(column: $table.clipId, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dashed =>
      $composableBuilder(column: $table.dashed, builder: (column) => column);

  GeneratedColumn<bool> get arrowEnd =>
      $composableBuilder(column: $table.arrowEnd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StrokesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StrokesTable,
          StrokeRow,
          $$StrokesTableFilterComposer,
          $$StrokesTableOrderingComposer,
          $$StrokesTableAnnotationComposer,
          $$StrokesTableCreateCompanionBuilder,
          $$StrokesTableUpdateCompanionBuilder,
          (StrokeRow, BaseReferences<_$AppDatabase, $StrokesTable, StrokeRow>),
          StrokeRow,
          PrefetchHooks Function()
        > {
  $$StrokesTableTableManager(_$AppDatabase db, $StrokesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StrokesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StrokesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StrokesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> boardId = const Value.absent(),
                Value<String?> clipId = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<double> strokeWidth = const Value.absent(),
                Value<String> pointsJson = const Value.absent(),
                Value<bool> dashed = const Value.absent(),
                Value<bool> arrowEnd = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion(
                id: id,
                boardId: boardId,
                clipId: clipId,
                color: color,
                strokeWidth: strokeWidth,
                pointsJson: pointsJson,
                dashed: dashed,
                arrowEnd: arrowEnd,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                Value<String?> clipId = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<double> strokeWidth = const Value.absent(),
                required String pointsJson,
                Value<bool> dashed = const Value.absent(),
                Value<bool> arrowEnd = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StrokesCompanion.insert(
                id: id,
                boardId: boardId,
                clipId: clipId,
                color: color,
                strokeWidth: strokeWidth,
                pointsJson: pointsJson,
                dashed: dashed,
                arrowEnd: arrowEnd,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StrokesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StrokesTable,
      StrokeRow,
      $$StrokesTableFilterComposer,
      $$StrokesTableOrderingComposer,
      $$StrokesTableAnnotationComposer,
      $$StrokesTableCreateCompanionBuilder,
      $$StrokesTableUpdateCompanionBuilder,
      (StrokeRow, BaseReferences<_$AppDatabase, $StrokesTable, StrokeRow>),
      StrokeRow,
      PrefetchHooks Function()
    >;
typedef $$BoardsTableCreateCompanionBuilder =
    BoardsCompanion Function({
      required String id,
      Value<String> name,
      Value<String?> backupFilePath,
      Value<String?> colorHex,
      Value<int> sortOrder,
      Value<double?> viewPanX,
      Value<double?> viewPanY,
      Value<double?> viewScale,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BoardsTableUpdateCompanionBuilder =
    BoardsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> backupFilePath,
      Value<String?> colorHex,
      Value<int> sortOrder,
      Value<double?> viewPanX,
      Value<double?> viewPanY,
      Value<double?> viewScale,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BoardsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupFilePath => $composableBuilder(
    column: $table.backupFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viewPanX => $composableBuilder(
    column: $table.viewPanX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viewPanY => $composableBuilder(
    column: $table.viewPanY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get viewScale => $composableBuilder(
    column: $table.viewScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BoardsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupFilePath => $composableBuilder(
    column: $table.backupFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viewPanX => $composableBuilder(
    column: $table.viewPanX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viewPanY => $composableBuilder(
    column: $table.viewPanY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get viewScale => $composableBuilder(
    column: $table.viewScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardsTable> {
  $$BoardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get backupFilePath => $composableBuilder(
    column: $table.backupFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get viewPanX =>
      $composableBuilder(column: $table.viewPanX, builder: (column) => column);

  GeneratedColumn<double> get viewPanY =>
      $composableBuilder(column: $table.viewPanY, builder: (column) => column);

  GeneratedColumn<double> get viewScale =>
      $composableBuilder(column: $table.viewScale, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BoardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardsTable,
          BoardRow,
          $$BoardsTableFilterComposer,
          $$BoardsTableOrderingComposer,
          $$BoardsTableAnnotationComposer,
          $$BoardsTableCreateCompanionBuilder,
          $$BoardsTableUpdateCompanionBuilder,
          (BoardRow, BaseReferences<_$AppDatabase, $BoardsTable, BoardRow>),
          BoardRow,
          PrefetchHooks Function()
        > {
  $$BoardsTableTableManager(_$AppDatabase db, $BoardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> backupFilePath = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<double?> viewPanX = const Value.absent(),
                Value<double?> viewPanY = const Value.absent(),
                Value<double?> viewScale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardsCompanion(
                id: id,
                name: name,
                backupFilePath: backupFilePath,
                colorHex: colorHex,
                sortOrder: sortOrder,
                viewPanX: viewPanX,
                viewPanY: viewPanY,
                viewScale: viewScale,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> name = const Value.absent(),
                Value<String?> backupFilePath = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<double?> viewPanX = const Value.absent(),
                Value<double?> viewPanY = const Value.absent(),
                Value<double?> viewScale = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BoardsCompanion.insert(
                id: id,
                name: name,
                backupFilePath: backupFilePath,
                colorHex: colorHex,
                sortOrder: sortOrder,
                viewPanX: viewPanX,
                viewPanY: viewPanY,
                viewScale: viewScale,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BoardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardsTable,
      BoardRow,
      $$BoardsTableFilterComposer,
      $$BoardsTableOrderingComposer,
      $$BoardsTableAnnotationComposer,
      $$BoardsTableCreateCompanionBuilder,
      $$BoardsTableUpdateCompanionBuilder,
      (BoardRow, BaseReferences<_$AppDatabase, $BoardsTable, BoardRow>),
      BoardRow,
      PrefetchHooks Function()
    >;
typedef $$LocalBlobsTableCreateCompanionBuilder =
    LocalBlobsCompanion Function({
      required String id,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$LocalBlobsTableUpdateCompanionBuilder =
    LocalBlobsCompanion Function({
      Value<String> id,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

class $$LocalBlobsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBlobsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBlobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBlobsTable> {
  $$LocalBlobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);
}

class $$LocalBlobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBlobsTable,
          LocalBlob,
          $$LocalBlobsTableFilterComposer,
          $$LocalBlobsTableOrderingComposer,
          $$LocalBlobsTableAnnotationComposer,
          $$LocalBlobsTableCreateCompanionBuilder,
          $$LocalBlobsTableUpdateCompanionBuilder,
          (
            LocalBlob,
            BaseReferences<_$AppDatabase, $LocalBlobsTable, LocalBlob>,
          ),
          LocalBlob,
          PrefetchHooks Function()
        > {
  $$LocalBlobsTableTableManager(_$AppDatabase db, $LocalBlobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBlobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBlobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBlobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalBlobsCompanion(id: id, bytes: bytes, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List bytes,
                Value<int> rowid = const Value.absent(),
              }) => LocalBlobsCompanion.insert(
                id: id,
                bytes: bytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBlobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBlobsTable,
      LocalBlob,
      $$LocalBlobsTableFilterComposer,
      $$LocalBlobsTableOrderingComposer,
      $$LocalBlobsTableAnnotationComposer,
      $$LocalBlobsTableCreateCompanionBuilder,
      $$LocalBlobsTableUpdateCompanionBuilder,
      (LocalBlob, BaseReferences<_$AppDatabase, $LocalBlobsTable, LocalBlob>),
      LocalBlob,
      PrefetchHooks Function()
    >;
typedef $$FramesTableCreateCompanionBuilder =
    FramesCompanion Function({
      required String id,
      required String boardId,
      Value<String> name,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<int> sortOrder,
      Value<String?> backgroundColorHex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$FramesTableUpdateCompanionBuilder =
    FramesCompanion Function({
      Value<String> id,
      Value<String> boardId,
      Value<String> name,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<int> sortOrder,
      Value<String?> backgroundColorHex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$FramesTableFilterComposer
    extends Composer<_$AppDatabase, $FramesTable> {
  $$FramesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FramesTableOrderingComposer
    extends Composer<_$AppDatabase, $FramesTable> {
  $$FramesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FramesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FramesTable> {
  $$FramesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get backgroundColorHex => $composableBuilder(
    column: $table.backgroundColorHex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FramesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FramesTable,
          FrameRow,
          $$FramesTableFilterComposer,
          $$FramesTableOrderingComposer,
          $$FramesTableAnnotationComposer,
          $$FramesTableCreateCompanionBuilder,
          $$FramesTableUpdateCompanionBuilder,
          (FrameRow, BaseReferences<_$AppDatabase, $FramesTable, FrameRow>),
          FrameRow,
          PrefetchHooks Function()
        > {
  $$FramesTableTableManager(_$AppDatabase db, $FramesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FramesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FramesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FramesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> boardId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> backgroundColorHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FramesCompanion(
                id: id,
                boardId: boardId,
                name: name,
                x: x,
                y: y,
                width: width,
                height: height,
                sortOrder: sortOrder,
                backgroundColorHex: backgroundColorHex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                Value<String> name = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> backgroundColorHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FramesCompanion.insert(
                id: id,
                boardId: boardId,
                name: name,
                x: x,
                y: y,
                width: width,
                height: height,
                sortOrder: sortOrder,
                backgroundColorHex: backgroundColorHex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FramesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FramesTable,
      FrameRow,
      $$FramesTableFilterComposer,
      $$FramesTableOrderingComposer,
      $$FramesTableAnnotationComposer,
      $$FramesTableCreateCompanionBuilder,
      $$FramesTableUpdateCompanionBuilder,
      (FrameRow, BaseReferences<_$AppDatabase, $FramesTable, FrameRow>),
      FrameRow,
      PrefetchHooks Function()
    >;
typedef $$ConnectorsTableCreateCompanionBuilder =
    ConnectorsCompanion Function({
      required String id,
      required String boardId,
      required String fromClipId,
      required String fromSide,
      required String toClipId,
      Value<double?> toRelX,
      Value<double?> toRelY,
      Value<String> color,
      Value<double> strokeWidth,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ConnectorsTableUpdateCompanionBuilder =
    ConnectorsCompanion Function({
      Value<String> id,
      Value<String> boardId,
      Value<String> fromClipId,
      Value<String> fromSide,
      Value<String> toClipId,
      Value<double?> toRelX,
      Value<double?> toRelY,
      Value<String> color,
      Value<double> strokeWidth,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ConnectorsTableFilterComposer
    extends Composer<_$AppDatabase, $ConnectorsTable> {
  $$ConnectorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromClipId => $composableBuilder(
    column: $table.fromClipId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromSide => $composableBuilder(
    column: $table.fromSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toClipId => $composableBuilder(
    column: $table.toClipId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toRelX => $composableBuilder(
    column: $table.toRelX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get toRelY => $composableBuilder(
    column: $table.toRelY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConnectorsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConnectorsTable> {
  $$ConnectorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromClipId => $composableBuilder(
    column: $table.fromClipId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromSide => $composableBuilder(
    column: $table.fromSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toClipId => $composableBuilder(
    column: $table.toClipId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toRelX => $composableBuilder(
    column: $table.toRelX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get toRelY => $composableBuilder(
    column: $table.toRelY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConnectorsTable> {
  $$ConnectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get fromClipId => $composableBuilder(
    column: $table.fromClipId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromSide =>
      $composableBuilder(column: $table.fromSide, builder: (column) => column);

  GeneratedColumn<String> get toClipId =>
      $composableBuilder(column: $table.toClipId, builder: (column) => column);

  GeneratedColumn<double> get toRelX =>
      $composableBuilder(column: $table.toRelX, builder: (column) => column);

  GeneratedColumn<double> get toRelY =>
      $composableBuilder(column: $table.toRelY, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<double> get strokeWidth => $composableBuilder(
    column: $table.strokeWidth,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConnectorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConnectorsTable,
          ConnectorRow,
          $$ConnectorsTableFilterComposer,
          $$ConnectorsTableOrderingComposer,
          $$ConnectorsTableAnnotationComposer,
          $$ConnectorsTableCreateCompanionBuilder,
          $$ConnectorsTableUpdateCompanionBuilder,
          (
            ConnectorRow,
            BaseReferences<_$AppDatabase, $ConnectorsTable, ConnectorRow>,
          ),
          ConnectorRow,
          PrefetchHooks Function()
        > {
  $$ConnectorsTableTableManager(_$AppDatabase db, $ConnectorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> boardId = const Value.absent(),
                Value<String> fromClipId = const Value.absent(),
                Value<String> fromSide = const Value.absent(),
                Value<String> toClipId = const Value.absent(),
                Value<double?> toRelX = const Value.absent(),
                Value<double?> toRelY = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<double> strokeWidth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConnectorsCompanion(
                id: id,
                boardId: boardId,
                fromClipId: fromClipId,
                fromSide: fromSide,
                toClipId: toClipId,
                toRelX: toRelX,
                toRelY: toRelY,
                color: color,
                strokeWidth: strokeWidth,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                required String fromClipId,
                required String fromSide,
                required String toClipId,
                Value<double?> toRelX = const Value.absent(),
                Value<double?> toRelY = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<double> strokeWidth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConnectorsCompanion.insert(
                id: id,
                boardId: boardId,
                fromClipId: fromClipId,
                fromSide: fromSide,
                toClipId: toClipId,
                toRelX: toRelX,
                toRelY: toRelY,
                color: color,
                strokeWidth: strokeWidth,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConnectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConnectorsTable,
      ConnectorRow,
      $$ConnectorsTableFilterComposer,
      $$ConnectorsTableOrderingComposer,
      $$ConnectorsTableAnnotationComposer,
      $$ConnectorsTableCreateCompanionBuilder,
      $$ConnectorsTableUpdateCompanionBuilder,
      (
        ConnectorRow,
        BaseReferences<_$AppDatabase, $ConnectorsTable, ConnectorRow>,
      ),
      ConnectorRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ClipsTableTableManager get clips =>
      $$ClipsTableTableManager(_db, _db.clips);
  $$StrokesTableTableManager get strokes =>
      $$StrokesTableTableManager(_db, _db.strokes);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db, _db.boards);
  $$LocalBlobsTableTableManager get localBlobs =>
      $$LocalBlobsTableTableManager(_db, _db.localBlobs);
  $$FramesTableTableManager get frames =>
      $$FramesTableTableManager(_db, _db.frames);
  $$ConnectorsTableTableManager get connectors =>
      $$ConnectorsTableTableManager(_db, _db.connectors);
}
