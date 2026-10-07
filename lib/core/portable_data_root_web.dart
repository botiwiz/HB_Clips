// Web has no `.exe` of its own to be "portable" next to - this is never
// actually called on web; it exists only to satisfy the conditional export
// in portable_data_root.dart.

Future<dynamic> portableDataRoot() =>
    throw UnsupportedError('portableDataRoot is not supported on this platform');
