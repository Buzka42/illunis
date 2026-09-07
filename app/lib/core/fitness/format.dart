/// Figures for movement. Seconds are the store unit; the surface talks
/// mm:ss and km.
library;

String formatPace(double secPerKm) {
  if (secPerKm <= 0 || secPerKm > 3600) return '—';
  final s = secPerKm.round();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

String formatKm(double km) {
  if (km >= 10) return km.toStringAsFixed(1);
  return km.toStringAsFixed(2);
}

String formatMinutes(double minutes) {
  final m = minutes.round();
  if (m < 60) return '$m';
  final h = m ~/ 60;
  final r = m % 60;
  if (r == 0) return '${h}h';
  return '${h}h ${r.toString().padLeft(2, '0')}';
}

double? parsePace(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final m = RegExp(r"(\d+)[:.'](\d{2})").firstMatch(raw);
  if (m == null) return null;
  final total = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  if (total < 90 || total > 900) return null;
  return total.toDouble();
}

double? paceSecPerKm({required double km, required double minutes}) {
  if (km <= 0 || minutes <= 0) return null;
  return (minutes * 60) / km;
}

double? kmFromUnit(double n, String unit) {
  final u = unit.toLowerCase();
  if (u == 'mi' || u == 'miles' || u == 'mile') return n * 1.609344;
  if (u == 'm' || u == 'meter' || u == 'meters') {
    if (n < 50) return null;
    return n / 1000.0;
  }
  if (u == 'k' || u == 'km') return n;
  return null;
}
