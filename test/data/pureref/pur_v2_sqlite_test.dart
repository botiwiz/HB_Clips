import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/pureref/pur_v2_sqlite.dart';

/// `multipage_sample.sqlite` is a real SQLite database (built with Python's
/// own `sqlite3` module - an independent encoder, not this reader's own
/// logic reflected back at itself): a single table `t(id INTEGER PRIMARY
/// KEY, val TEXT)` with 400 rows, enough that SQLite itself splits it
/// across 8 pages (default 4096-byte page size), making its root page a
/// genuine B-tree *interior* page (confirmed directly: type byte `0x05`) -
/// exactly the shape `readLeafTable` used to give up on immediately. Proves
/// the interior-page traversal added for PureRef 2.x import support (see
/// `pur_reader.dart`'s `_readV2`) works in isolation, independent of that
/// format's own schema/encoding.
void main() {
  late MiniSqlite db;
  late Map<String, int> schema;

  setUpAll(() {
    final bytes = File(
      'test/data/pureref/fixtures/multipage_sample.sqlite',
    ).readAsBytesSync();
    db = MiniSqlite(bytes);
    schema = db.readSchemaRootPages();
  });

  test('looks like a valid SQLite file', () {
    expect(db.looksValid, isTrue);
  });

  test('finds table t in the schema', () {
    expect(schema.containsKey('t'), isTrue);
  });

  test('reads every one of the 400 rows, not just the first leaf page', () {
    final rows = db.readLeafTable(schema['t']!, intPkColumnIndex: 0);
    expect(rows.length, 400);
  });

  test('every row is intact - correct id (from rowid) and val text', () {
    final rows = db.readLeafTable(schema['t']!, intPkColumnIndex: 0);
    final byId = {for (final row in rows) row[0] as int: row[1] as Uint8List};
    for (var i = 0; i < 400; i++) {
      final id = i + 1; // SQLite rowids for a fresh table start at 1.
      expect(byId.containsKey(id), isTrue, reason: 'missing row id $id');
      final val = String.fromCharCodes(byId[id]!);
      expect(val, 'row-${i.toString().padLeft(4, '0')}-${'x' * 40}');
    }
  });
}
