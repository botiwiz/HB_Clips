import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hb_clips/core/theme/theme_settings.dart';
import 'package:hb_clips/data/local/database.dart';
import 'package:hb_clips/data/repositories/themes_repository.dart';

void main() {
  late AppDatabase db;
  late ThemesRepository themes;

  const settingsA = ThemeSettings(
    accent: Color(0xFFFF2E8F),
    danger: Color(0xFFFF0000),
    canvasBackground: Color(0xFF18181A),
    surfaceCard: Color(0xFF26262A),
    surfaceElevated: Color(0xFF313136),
    border: Color(0xFF3A3A40),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9B9BA1),
    fontFamily: 'Chakra Petch',
    fontSizeScale: 1.1,
  );

  const settingsB = ThemeSettings(
    accent: Color(0xFFA8FF3E),
    danger: Color(0xFFFF6600),
    canvasBackground: Color(0xFF000000),
    surfaceCard: Color(0xFF111111),
    surfaceElevated: Color(0xFF222222),
    border: Color(0xFF333333),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFAAAAAA),
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    themes = ThemesRepository(db);
  });

  tearDown(() => db.close());

  test('a fresh database has no saved themes yet', () async {
    final rows = await themes.watchThemes().first;
    expect(rows, isEmpty);
  });

  test(
    'createTheme persists every field, round-trippable via fromRow',
    () async {
      await themes.createTheme('theme-1', 'My theme', settingsA);
      final rows = await themes.watchThemes().first;
      expect(rows, hasLength(1));

      final row = rows.single;
      expect(row.id, 'theme-1');
      expect(row.name, 'My theme');
      expect(row.fontFamily, 'Chakra Petch');
      expect(row.fontSizeScale, 1.1);

      final roundTripped = ThemeSettings.fromRow(row);
      expect(roundTripped.accent, settingsA.accent);
      expect(roundTripped.danger, settingsA.danger);
      expect(roundTripped.canvasBackground, settingsA.canvasBackground);
      expect(roundTripped.surfaceCard, settingsA.surfaceCard);
      expect(roundTripped.surfaceElevated, settingsA.surfaceElevated);
      expect(roundTripped.border, settingsA.border);
      expect(roundTripped.textPrimary, settingsA.textPrimary);
      expect(roundTripped.textSecondary, settingsA.textSecondary);
      expect(roundTripped.fontFamily, settingsA.fontFamily);
      expect(roundTripped.fontSizeScale, settingsA.fontSizeScale);
    },
  );

  test('createTheme defaults fontFamily to null and fontSizeScale to 1.0 '
      'when the settings leave them unset', () async {
    await themes.createTheme('theme-1', 'My theme', settingsB);
    final row = (await themes.watchThemes().first).single;
    expect(row.fontFamily, isNull);
    expect(row.fontSizeScale, 1.0);
  });

  test('createTheme assigns strictly increasing sortOrder', () async {
    await themes.createTheme('theme-1', 'First', settingsA);
    await themes.createTheme('theme-2', 'Second', settingsB);
    final rows = await themes.watchThemes().first;
    final byId = {for (final t in rows) t.id: t.sortOrder};
    expect(byId['theme-1']! < byId['theme-2']!, isTrue);
  });

  test('watchThemes emits in sortOrder order', () async {
    await themes.createTheme('theme-1', 'First', settingsA);
    await themes.createTheme('theme-2', 'Second', settingsB);
    final rows = await themes.watchThemes().first;
    expect(rows.map((t) => t.id).toList(), ['theme-1', 'theme-2']);
  });

  test(
    'updateTheme with only a name leaves the colors/font untouched',
    () async {
      await themes.createTheme('theme-1', 'Original', settingsA);
      await themes.updateTheme('theme-1', name: 'Renamed');

      final row = (await themes.watchThemes().first).single;
      expect(row.name, 'Renamed');
      expect(ThemeSettings.fromRow(row).accent, settingsA.accent);
      expect(row.fontFamily, settingsA.fontFamily);
    },
  );

  test('updateTheme with only settings leaves the name untouched', () async {
    await themes.createTheme('theme-1', 'Original', settingsA);
    await themes.updateTheme('theme-1', settings: settingsB);

    final row = (await themes.watchThemes().first).single;
    expect(row.name, 'Original');
    expect(ThemeSettings.fromRow(row).accent, settingsB.accent);
    expect(row.fontFamily, isNull);
  });

  test('deleteTheme removes exactly that theme', () async {
    await themes.createTheme('theme-1', 'First', settingsA);
    await themes.createTheme('theme-2', 'Second', settingsB);
    await themes.deleteTheme('theme-1');

    final rows = await themes.watchThemes().first;
    expect(rows.map((t) => t.id).toList(), ['theme-2']);
  });

  test("reorderThemes changes watchThemes()'s emitted order to match the new "
      'arrangement, independent of createdAt', () async {
    await themes.createTheme('theme-1', 'First', settingsA);
    await themes.createTheme('theme-2', 'Second', settingsB);
    await themes.createTheme('theme-3', 'Third', settingsA);

    await themes.reorderThemes(['theme-3', 'theme-1', 'theme-2']);

    final rows = await themes.watchThemes().first;
    expect(rows.map((t) => t.id).toList(), ['theme-3', 'theme-1', 'theme-2']);
  });
}
