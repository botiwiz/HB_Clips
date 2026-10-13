import 'package:drift/drift.dart';

/// A named, saved UI theme - every token `AppTheme` resolves (8 chrome
/// colors) plus the chosen font family/size, bundled as one switchable,
/// user-saveable identity rather than separate independent settings. See
/// `lib/core/theme/theme_settings.dart`'s `ThemeSettings` for the
/// in-memory value type this table round-trips, and
/// `AppSettings.activeThemeId` for which row (if any) is currently applied.
@DataClassName('ThemeRow')
class Themes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  TextColumn get accentHex => text()();
  TextColumn get dangerHex => text()();
  TextColumn get canvasBackgroundHex => text()();
  TextColumn get surfaceCardHex => text()();
  TextColumn get surfaceElevatedHex => text()();
  TextColumn get borderHex => text()();
  TextColumn get textPrimaryHex => text()();
  TextColumn get textSecondaryHex => text()();

  /// A `google_fonts` family name (e.g. `'Chakra Petch'`), or null for the
  /// platform's default font - see `theme_fonts.dart`'s `kThemeFontChoices`.
  TextColumn get fontFamily => text().nullable()();

  /// Applied as a `MediaQuery` text-scale factor (1.0 = today's sizes,
  /// unchanged) - not baked into individual `TextStyle` literals, so this
  /// scales every piece of text in the app uniformly regardless of how its
  /// own font size was set. See `lib/app.dart`.
  RealColumn get fontSizeScale => real().withDefault(const Constant(1.0))();

  /// User-controlled display order in the Settings dialog's saved-themes
  /// list - lower sorts first, same convention as `Boards.sortOrder`.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
