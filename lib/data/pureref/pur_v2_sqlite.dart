import 'dart:typed_data';

/// A hand-rolled, read-only reader for the tiny slice of the SQLite file
/// format that PureRef 2.x's embedded database actually needs: the schema
/// table on page 1, and a handful of small tables that (in every real file
/// inspected so far) fit entirely on their own single leaf page. This is
/// deliberately not a general SQLite engine - PureRef 2.x's own embedded
/// database is reliably *truncated* in the exported `.pur` file (its header
/// declares a page count the file doesn't actually contain, and the large
/// `images` table's own root page is consistently a b-tree *interior* page
/// pointing at leaf pages that aren't present at all) - so a real engine
/// would just fail to open it anyway. Reading the handful of small,
/// always-present pages directly, and treating anything else as
/// "unavailable" rather than a hard error, is what actually works.
///
/// Every byte offset and encoding rule below is the standard, documented
/// SQLite file format (https://www.sqlite.org/fileformat2.html) - the only
/// PureRef-specific part is which table names/columns get read, in
/// `Pur2Database` in `pur_reader.dart`.
class MiniSqlite {
  final Uint8List _bytes;
  final int _pageSize;

  MiniSqlite(Uint8List bytes)
    : _bytes = bytes,
      _pageSize = bytes.length >= 18
          ? ByteData.sublistView(bytes, 16, 18).getUint16(0, Endian.big)
          : 0;

  bool get looksValid =>
      _pageSize > 0 &&
      _bytes.length >= 100 &&
      _bytes[0] == 0x53 && // 'S'
      _bytes[1] == 0x51; // 'Q' - full "SQLite format 3\0" checked by caller

  /// The page's raw bytes, or null if that page isn't within the buffer we
  /// were given - expected and normal for a truncated capture, not an error.
  Uint8List? _page(int pageNumber) {
    if (_pageSize <= 0 || pageNumber < 1) return null;
    final start = (pageNumber - 1) * _pageSize;
    final end = start + _pageSize;
    if (end > _bytes.length) return null;
    return Uint8List.sublistView(_bytes, start, end);
  }

  /// Reads a SQLite varint (big-endian-ish, 7 bits/byte with a continuation
  /// bit, up to 9 bytes) starting at `offset`. Returns the value and how
  /// many bytes it occupied.
  static (int, int) _readVarint(Uint8List data, int offset) {
    var result = 0;
    for (var i = 0; i < 8; i++) {
      final b = data[offset + i];
      result = (result << 7) | (b & 0x7f);
      if (b & 0x80 == 0) return (result, i + 1);
    }
    result = (result << 8) | data[offset + 8];
    return (result, 9);
  }

  /// Decodes one column value given its SQLite "serial type" - the
  /// standard record-format rules, see fileformat2.html section 2.1.
  static (Object?, int) _readSerialValue(
    Uint8List data,
    int offset,
    int serialType,
  ) {
    final view = ByteData.sublistView(data);
    switch (serialType) {
      case 0:
        return (null, 0);
      case 1:
        return (view.getInt8(offset), 1);
      case 2:
        return (view.getInt16(offset, Endian.big), 2);
      case 3:
        final b0 = data[offset], b1 = data[offset + 1], b2 = data[offset + 2];
        var v = (b0 << 16) | (b1 << 8) | b2;
        if (v & 0x800000 != 0) v -= 0x1000000;
        return (v, 3);
      case 4:
        return (view.getInt32(offset, Endian.big), 4);
      case 5:
        final hi = view.getInt16(offset, Endian.big);
        final lo = view.getUint32(offset + 2, Endian.big);
        return ((hi << 32) | lo, 6);
      case 6:
        return (view.getInt64(offset, Endian.big), 8);
      case 7:
        return (view.getFloat64(offset, Endian.big), 8);
      case 8:
        return (0, 0);
      case 9:
        return (1, 0);
      default:
        if (serialType >= 12 && serialType.isEven) {
          final len = (serialType - 12) ~/ 2;
          return (Uint8List.sublistView(data, offset, offset + len), len);
        }
        if (serialType >= 13 && serialType.isOdd) {
          final len = (serialType - 13) ~/ 2;
          return (Uint8List.sublistView(data, offset, offset + len), len);
        }
        // Reserved/unknown serial type (10, 11) - shouldn't appear in a
        // real file; treat as zero-length so parsing can still continue.
        return (null, 0);
    }
  }

  /// Decodes one table-leaf-page record (the payload of one cell) into its
  /// column values, in declared-column order. `intPkColumnIndex` is the
  /// index of an `INTEGER PRIMARY KEY` column, if any - SQLite stores that
  /// column's value as the cell's rowid and writes a NULL placeholder (serial
  /// type 0) in the record itself, so it has to be substituted back in.
  static List<Object?> _decodeRecord(
    Uint8List payload,
    int rowid,
    int? intPkColumnIndex,
  ) {
    var pos = 0;
    final (headerLength, headerLenBytes) = _readVarint(payload, 0);
    pos = headerLenBytes;
    final serialTypes = <int>[];
    while (pos < headerLength) {
      final (type, n) = _readVarint(payload, pos);
      serialTypes.add(type);
      pos += n;
    }
    var valuePos = headerLength;
    final values = <Object?>[];
    for (final type in serialTypes) {
      final (value, len) = _readSerialValue(payload, valuePos, type);
      values.add(value);
      valuePos += len;
    }
    if (intPkColumnIndex != null &&
        intPkColumnIndex < values.length &&
        values[intPkColumnIndex] == null) {
      values[intPkColumnIndex] = rowid;
    }
    return values;
  }

  /// Reads every row of a table whose root page is a single table-leaf page
  /// (type 0x0d) - returns an empty list (not an error) if the page is
  /// absent from this (possibly truncated) buffer, or isn't a leaf page at
  /// all (a table with enough rows to need an interior page can't be read
  /// by this minimal reader - see the class doc comment).
  List<List<Object?>> readLeafTable(int rootPage, {int? intPkColumnIndex}) {
    final page = _page(rootPage);
    if (page == null) return const [];
    // Only page 1 has the extra 100-byte file header before its own b-tree
    // page header.
    final headerOffset = rootPage == 1 ? 100 : 0;
    final pageType = page[headerOffset];
    if (pageType != 0x0d) return const []; // not a leaf page - can't read it
    final numCells = ByteData.sublistView(
      page,
      headerOffset + 3,
      headerOffset + 5,
    ).getUint16(0, Endian.big);
    final cellPointerStart = headerOffset + 8;

    final rows = <List<Object?>>[];
    for (var i = 0; i < numCells; i++) {
      final cellOffset = ByteData.sublistView(
        page,
        cellPointerStart + i * 2,
        cellPointerStart + i * 2 + 2,
      ).getUint16(0, Endian.big);
      var pos = cellOffset;
      final (payloadLength, n1) = _readVarint(page, pos);
      pos += n1;
      final (rowid, n2) = _readVarint(page, pos);
      pos += n2;
      // Rows this small never overflow to a separate page (overflow only
      // kicks in past roughly page_size - 35 bytes of payload) - every
      // table this reader targets is well under that.
      final payload = Uint8List.sublistView(page, pos, pos + payloadLength);
      rows.add(_decodeRecord(payload, rowid, intPkColumnIndex));
    }
    return rows;
  }

  /// Reads `sqlite_master` (always page 1, always small enough to be a
  /// single leaf page) and returns `name -> rootpage` for every table.
  /// Columns are the fixed, documented `sqlite_master` schema: `(type,
  /// name, tbl_name, rootpage, sql)`.
  Map<String, int> readSchemaRootPages() {
    final rows = readLeafTable(1);
    final result = <String, int>{};
    for (final row in rows) {
      if (row.length < 4) continue;
      final type = row[0];
      final name = row[1];
      final rootpage = row[3];
      if (type is Uint8List &&
          String.fromCharCodes(type) == 'table' &&
          name is Uint8List &&
          rootpage is int) {
        result[String.fromCharCodes(name)] = rootpage;
      }
    }
    return result;
  }
}
