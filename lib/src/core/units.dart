/// Pustaka konversi unit ukuran (px, mm, cm, m, deg, rad, %) di RelGeo.

import '../geometry/types.dart';

const double mmToPx = 96.0 / 25.4;
const double cmToPx = 96.0 / 2.54;
const double mToPx = (96.0 / 2.54) * 100.0;
const double inToPx = 96.0;
const double degToRad = 3.141592653589793 / 180.0;

double convertToPx(dynamic value) {
  if (value is num) return value.toDouble();

  final strVal = value.toString().trim();
  final match = RegExp(
    r'^([+-]?[\d.-]+)(px|mm|cm|m|in|ip|%|deg|rad)$',
  ).firstMatch(strVal);
  if (match == null) {
    final double? parsed = double.tryParse(strVal);
    if (parsed == null) {
      throw Exception('INVALID_UNIT_VALUE: $strVal');
    }
    return parsed;
  }

  final numVal = double.parse(match.group(1)!);
  final unit = match.group(2)!;

  if (unit == '%') {
    return numVal / 100.0;
  }

  switch (unit) {
    case 'mm':
      return numVal * mmToPx;
    case 'cm':
      return numVal * cmToPx;
    case 'm':
      return numVal * mToPx;
    case 'in':
    case 'ip':
      return numVal * inToPx;
    case 'deg':
      return numVal * degToRad;
    case 'rad':
      return numVal;
    case 'px':
    default:
      return numVal;
  }
}

double convertFromPx(double px, LengthUnit targetUnit) {
  switch (targetUnit) {
    case LengthUnit.mm:
      return px / mmToPx;
    case LengthUnit.cm:
      return px / cmToPx;
    case LengthUnit.m:
      return px / mToPx;
    case LengthUnit.ip:
      return px / inToPx;
    case LengthUnit.px:
      return px;
  }
}

/// Menormalisasi nilai apa pun dengan unit (misal: "12mm") ke double dalam targetUnit.
dynamic normalizeUnit(dynamic value, [LengthUnit targetUnit = LengthUnit.px]) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value.toDouble();

  if (value is List) {
    return value.map((item) => normalizeUnit(item, targetUnit)).toList();
  }

  if (value is Map) {
    return value.map((k, v) => MapEntry(k, normalizeUnit(v, targetUnit)));
  }

  final strVal = value.toString().trim();

  final unitMatch = RegExp(
    r'^([+-]?[\d.-]+)(px|mm|cm|m|in|ip|%|deg|rad)$',
  ).firstMatch(strVal);
  if (unitMatch == null) {
    final parsed = double.tryParse(strVal);
    return parsed ?? value;
  }

  final numericPart = unitMatch.group(1)!;
  final unit = unitMatch.group(2)!;
  final targetUnitStr = targetUnit == LengthUnit.ip ? 'in' : targetUnit.name;
  if (unit == targetUnitStr || (targetUnit == LengthUnit.ip && unit == 'ip')) {
    return double.parse(numericPart);
  }

  final pxValue = convertToPx(strVal);
  return convertFromPx(pxValue, targetUnit);
}
