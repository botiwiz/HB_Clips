import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/app_settings_repository.dart';

void main() {
  late AppDatabase db;
  late AppSettingsRepository settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
  });

  tearDown(() => db.close());

  test('a fresh database has no backup folder configured yet', () async {
    expect(await settings.getBackupFolderPath(), isNull);
  });

  test(
    'setBackupFolderPath round-trips, and null clears it back out',
    () async {
      await settings.setBackupFolderPath('/tmp/my-backups');
      expect(await settings.getBackupFolderPath(), '/tmp/my-backups');

      await settings.setBackupFolderPath(null);
      expect(await settings.getBackupFolderPath(), isNull);
    },
  );

  test('setBackupFolderPath overwrites a previously set value', () async {
    await settings.setBackupFolderPath('/tmp/first');
    await settings.setBackupFolderPath('/tmp/second');
    expect(await settings.getBackupFolderPath(), '/tmp/second');
  });

  test(
    'watchBackupFolderPath emits the current value and later updates',
    () async {
      final values = <String?>[];
      final subscription = settings.watchBackupFolderPath().listen(values.add);
      await Future<void>.delayed(Duration.zero);

      await settings.setBackupFolderPath('/tmp/my-backups');
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      expect(values, [null, '/tmp/my-backups']);
    },
  );

  test('a fresh database has no active theme set yet', () async {
    expect(await settings.getActiveThemeId(), isNull);
  });

  test('setActiveThemeId round-trips, and null clears it back out', () async {
    await settings.setActiveThemeId('builtin-hot-pink');
    expect(await settings.getActiveThemeId(), 'builtin-hot-pink');

    await settings.setActiveThemeId(null);
    expect(await settings.getActiveThemeId(), isNull);
  });

  test('setActiveThemeId overwrites a previously set value', () async {
    await settings.setActiveThemeId('builtin-hot-pink');
    await settings.setActiveThemeId('builtin-neon-green');
    expect(await settings.getActiveThemeId(), 'builtin-neon-green');
  });

  test(
    'watchActiveThemeId emits the current value and later updates',
    () async {
      final values = <String?>[];
      final subscription = settings.watchActiveThemeId().listen(values.add);
      await Future<void>.delayed(Duration.zero);

      await settings.setActiveThemeId('builtin-hot-pink');
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      expect(values, [null, 'builtin-hot-pink']);
    },
  );

  test('setBackupFolderPath and setActiveThemeId are independent columns on '
      'the same settings row', () async {
    await settings.setBackupFolderPath('/tmp/my-backups');
    await settings.setActiveThemeId('builtin-hot-pink');

    expect(await settings.getBackupFolderPath(), '/tmp/my-backups');
    expect(await settings.getActiveThemeId(), 'builtin-hot-pink');
  });
}
