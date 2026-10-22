import 'package:flutter/material.dart';

/// Central color palette for the EV Fleet design system.
///
/// Light theme is the primary theme: white/soft-gray surfaces, dark charcoal
/// typography, deep forest green brand color and restrained lime accents.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand — deep forest / emerald green.
  // ---------------------------------------------------------------------------
  static const Color brand = Color(0xFF0E6B4C);
  static const Color brandDark = Color(0xFF08452F);
  static const Color brandMedium = Color(0xFF13815C);
  static const Color brandSoft = Color(0xFFE4F1EB);

  // ---------------------------------------------------------------------------
  // Accent — restrained lime, used sparingly for highlights.
  // ---------------------------------------------------------------------------
  static const Color lime = Color(0xFFC8F24E);
  static const Color limeDark = Color(0xFF7FA819);

  // ---------------------------------------------------------------------------
  // Surfaces.
  // ---------------------------------------------------------------------------
  static const Color background = Color(0xFFF2F5F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF7F9F8);
  static const Color border = Color(0xFFE1E8E4);
  static const Color borderStrong = Color(0xFFCBD6D0);

  // ---------------------------------------------------------------------------
  // Typography.
  // ---------------------------------------------------------------------------
  static const Color ink = Color(0xFF131C17);
  static const Color inkSoft = Color(0xFF556059);
  static const Color inkMuted = Color(0xFF8A948E);
  static const Color onBrand = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Status.
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFE6F6EC);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFDF1DF);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFBE9E9);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFE8EEFC);
  static const Color neutralSoft = Color(0xFFEDF1EF);

  /// Tint used behind the map surface and image placeholders.
  static const Color mapLand = Color(0xFFE8EFE9);
  static const Color mapWater = Color(0xFFD6E7F3);
  static const Color mapRoad = Color(0xFFFFFFFF);
}
