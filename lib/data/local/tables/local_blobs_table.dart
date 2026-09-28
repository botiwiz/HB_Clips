import 'package:drift/drift.dart';

/// Local cache of clip image bytes, backing the web `LocalBlobStore`
/// implementation in place of real files on disk (`dart:io` doesn't
/// compile for Flutter Web at all) - native platforms still cache to real
/// files instead and never populate this table.
class LocalBlobs extends Table {
  TextColumn get id => text()();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {id};
}
