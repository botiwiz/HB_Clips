import 'dart:typed_data';

/// Web: `FilePicker.platform.saveFile` was called with `bytes:` and already
/// triggered a browser download - nothing further to do here.
Future<void> writeBytesToPath(String path, Uint8List bytes) async {}

/// Web has no ambient filesystem to probe - `pickBackupFolder`'s callers
/// are all guarded with `kIsWeb` anyway (see `backup_folder_service.dart`),
/// so this is never actually reached; it exists only to satisfy the
/// conditional export.
Future<void> probeFolderWritable(String folderPath) async {}
