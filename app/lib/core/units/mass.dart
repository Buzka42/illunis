/// Mass is stored in kilograms. Display follows the profile's units.
library;

const lbPerKg = 2.2046226218;

bool isImperial(String units) => units == 'imperial';

double kgFrom(double value, String unit) {
  switch (unit.toLowerCase()) {
    case 'lb':
    case 'lbs':
    case 'pounds':
    case '#':
      return value / lbPerKg;
    default:
      return value;
  }
}

/// If the line named no unit, the profile decides.
double kgAssuming(double value, String? unit, String profileUnits) {
  if (unit != null && unit.isNotEmpty) return kgFrom(value, unit);
  return isImperial(profileUnits) ? value / lbPerKg : value;
}

String massUnit(String units) => isImperial(units) ? 'LB' : 'KG';

double toDisplayKg(double kg, String units) =>
    isImperial(units) ? kg * lbPerKg : kg;

String formatMass(double kg, String units, {int fractionDigits = 0}) {
  final v = toDisplayKg(kg, units);
  return fractionDigits == 0
      ? v.round().toString()
      : v.toStringAsFixed(fractionDigits);
}
