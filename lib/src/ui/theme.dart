import 'package:flutter/material.dart';

/// Dayline's look: calm, high contrast, system font, nothing decorative.
///
/// The Today screen has to be readable at arm's length while you are putting
/// your shoes on, so body text runs larger than Material's defaults and the
/// palette is near-monochrome — colour belongs to the events themselves, not
/// to the chrome around them.
abstract final class DaylineTheme {
  /// Minimum tap target. Comfortably above the 48dp guideline, because these
  /// rows get tapped in a hurry.
  static const double rowMinHeight = 64;

  static const double gutter = 20;

  /// The day reads down a straight column of clock times, with the timeline's
  /// thread beside it. Every row on the Today screen lines up on these, so a
  /// dot, a divider and a stay's thread all sit on the same spine.
  static const double timeColumnWidth = 52;
  static const double railGap = 14;
  static const double railWidth = 10;

  static const _accent = Color(0xFF3B82F6);

  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: _accent,
      onPrimary: Colors.white,
      secondary: Color(0xFF57534E),
      onSecondary: Colors.white,
      // Set explicitly: left to derive from the seed these came out a muddy
      // brown, which is what segmented buttons and filter chips fill with.
      secondaryContainer: Color(0xFFE7E5E4),
      onSecondaryContainer: Color(0xFF1C1917),
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: Color(0xFFFAFAF9),
      onSurface: Color(0xFF1C1917),
      surfaceContainer: Colors.white,
      surfaceContainerHighest: Color(0xFFF5F5F4),
      onSurfaceVariant: Color(0xFF57534E),
      outline: Color(0xFFD6D3D1),
      outlineVariant: Color(0xFFE7E5E4),
    ),
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF60A5FA),
      onPrimary: Color(0xFF0C0A09),
      secondary: Color(0xFFA8A29E),
      onSecondary: Color(0xFF0C0A09),
      secondaryContainer: Color(0xFF33302C),
      onSecondaryContainer: Color(0xFFFAFAF9),
      error: Color(0xFFF87171),
      onError: Color(0xFF0C0A09),
      surface: Color(0xFF0C0A09),
      onSurface: Color(0xFFFAFAF9),
      surfaceContainer: Color(0xFF1C1917),
      surfaceContainerHighest: Color(0xFF292524),
      onSurfaceVariant: Color(0xFFA8A29E),
      outline: Color(0xFF44403C),
      outlineVariant: Color(0xFF292524),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        // Bumped a step: this is the event title on the Today list.
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: gutter),
      ),
    );
  }
}

/// The tabular figures trick: clock digits that do not jiggle as a countdown
/// ticks. Applied to any number that changes in place.
const TextStyle monospacedFigures = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);
