import 'package:flutter/material.dart';

/// The palette offered in the editor. Deliberately small — a colour is a
/// glanceable category, and twenty of them stop being glanceable.
///
/// Each is chosen to stay legible as a small bar against both the light and
/// the dark surface, so there is one value per colour rather than a pair.
abstract final class EventColors {
  static const blue = 0xFF3B82F6;
  static const violet = 0xFF8B5CF6;
  static const green = 0xFF10B981;
  static const amber = 0xFFF59E0B;
  static const rose = 0xFFF43F5E;
  static const teal = 0xFF14B8A6;
  static const slate = 0xFF64748B;

  static const all = <int>[blue, violet, green, amber, rose, teal, slate];

  static const fallback = blue;

  static Color of(int value) => Color(value);
}
