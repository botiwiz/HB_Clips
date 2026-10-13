import 'package:drift/drift.dart';

import '../../core/theme/theme_settings.dart';
import '../local/database.dart';

/// Local read/write API for saved themes - same pattern as
/// [BoardsRepository].
class ThemesRepository {
  final AppDatabase _db;

  ThemesRepository(this._db);

  Stream<List<ThemeRow>> watchThemes() {
    final query = _db.select(_db.themes)
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch();
  }

  Future<int> _nextSortOrder() async {
    final query = _db.selectOnly(_db.themes)
      ..addColumns([_db.themes.sortOrder.max()]);
    final row = await query.getSingleOrNull();
    final maxOrder = row?.read(_db.themes.sortOrder.max());
    return (maxOrder ?? 0) + 1;
  }

  Future<void> createTheme(
    String id,
    String name,
    ThemeSettings settings,
  ) async {
    final sortOrder = await _nextSortOrder();
    await _db
        .into(_db.themes)
        .insert(
          ThemesCompanion.insert(
            id: id,
            name: name,
            accentHex: settings.accentHex,
            dangerHex: settings.dangerHex,
            canvasBackgroundHex: settings.canvasBackgroundHex,
            surfaceCardHex: settings.surfaceCardHex,
            surfaceElevatedHex: settings.surfaceElevatedHex,
            borderHex: settings.borderHex,
            textPrimaryHex: settings.textPrimaryHex,
            textSecondaryHex: settings.textSecondaryHex,
            fontFamily: Value(settings.fontFamily),
            fontSizeScale: Value(settings.fontSizeScale),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  /// Partial update - pass only [name] and/or [settings], whichever
  /// changed. Passing [settings] overwrites every one of its fields (it's
  /// always a complete `ThemeSettings`, not itself partial).
  Future<void> updateTheme(String id, {String? name, ThemeSettings? settings}) {
    return (_db.update(_db.themes)..where((t) => t.id.equals(id))).write(
      ThemesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        accentHex: settings == null
            ? const Value.absent()
            : Value(settings.accentHex),
        dangerHex: settings == null
            ? const Value.absent()
            : Value(settings.dangerHex),
        canvasBackgroundHex: settings == null
            ? const Value.absent()
            : Value(settings.canvasBackgroundHex),
        surfaceCardHex: settings == null
            ? const Value.absent()
            : Value(settings.surfaceCardHex),
        surfaceElevatedHex: settings == null
            ? const Value.absent()
            : Value(settings.surfaceElevatedHex),
        borderHex: settings == null
            ? const Value.absent()
            : Value(settings.borderHex),
        textPrimaryHex: settings == null
            ? const Value.absent()
            : Value(settings.textPrimaryHex),
        textSecondaryHex: settings == null
            ? const Value.absent()
            : Value(settings.textSecondaryHex),
        fontFamily: settings == null
            ? const Value.absent()
            : Value(settings.fontFamily),
        fontSizeScale: settings == null
            ? const Value.absent()
            : Value(settings.fontSizeScale),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteTheme(String id) {
    return (_db.delete(_db.themes)..where((t) => t.id.equals(id))).go();
  }

  /// Persists a new display order for every theme in [orderedIds] (as
  /// listed, lowest index sorts first) - drives the Settings dialog's
  /// saved-themes list, same shape as `BoardsRepository.reorderBoards`.
  Future<void> reorderThemes(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.themes)..where((t) => t.id.equals(orderedIds[i])))
          .write(ThemesCompanion(sortOrder: Value(i)));
    }
  }
}
