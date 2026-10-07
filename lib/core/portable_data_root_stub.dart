// Fallback for a platform that is neither web nor native (dart:ffi) - never
// actually reached in this app; exists only to satisfy the conditional
// export in portable_data_root.dart.

Future<dynamic> portableDataRoot() =>
    throw UnsupportedError('portableDataRoot is not supported on this platform');
