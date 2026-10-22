import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Presentation formatters for distance, power, energy, money and ratings.
abstract final class Formatters {
  /// `1240` → `1.2 km`, `320` → `320 m`, null → `—`.
  static String distance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  /// `150` → `150 kW`.
  static String power(double kw) => '${kw.round()} kW';

  /// `39.5` → `€0.395/kWh` (currency comes from [AppConstants]).
  static String price(double perKwh, {String? currency}) {
    final symbol = currency ?? AppConstants.currencySymbol;
    return '$symbol${perKwh.toStringAsFixed(2)}/kWh';
  }

  /// `18.4` → `18.4 kWh`.
  static String energy(double kwh) => '${kwh.toStringAsFixed(1)} kWh';

  /// Money with two decimals, e.g. `€12.40`.
  static String money(double amount, {String? currency}) {
    final symbol = currency ?? AppConstants.currencySymbol;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Battery capacity, e.g. `60 kWh`.
  static String battery(double kwh) =>
      '${kwh.toStringAsFixed(kwh % 1 == 0 ? 0 : 1)} kWh';

  /// Rating label — only call when rating data actually exists.
  static String rating(double rating) => rating.toStringAsFixed(1);

  /// `95` → `1 h 35 min`.
  static String duration(int minutes) {
    if (minutes <= 0) return '0 min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  /// `8.4` → `+8.4%` style signed helper for deltas.
  static String signedPercent(double value) {
    final sign = value.isNegative ? '' : '+';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  /// Name initials for avatars, e.g. `Ada Lovelace` → `AL`.
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }
}
