import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Reusable text styles. Component themes provide the base [TextTheme];
/// these are the named styles used across feature widgets.
abstract final class AppTextStyles {
  static const String _fontFamily = 'Roboto';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 27,
    height: 1.15,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    height: 1.25,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.3,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static const TextStyle bodySoft = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.inkSoft,
  );

  static const TextStyle meta = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11.5,
    height: 1.2,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle price = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.2,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 1.2,
    letterSpacing: -0.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}
