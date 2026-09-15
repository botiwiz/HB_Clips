import 'package:drift/drift.dart';

/// Local-only cache of clip image bytes, backing the web `LocalBlobStore`
/// implementation in place of real files on disk (`dart:io` doesn't
/// compile for Flutter Web at all). Never synced - no `user_id`, no
/// outbox entries; native platforms never populate this table since they
/// still cache to real files instead, exactly as before.
class LocalBlobs extends Table {
  TextColumn get id => text()();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {id};
}
