import '../db/records.dart';

/// Named observer sites. No location permission — the person picks a home.
class HomePlace {
  const HomePlace(this.id, this.label, this.latitudeDeg, this.longitudeDeg);
  final String id;
  final String label;
  final double latitudeDeg;
  final double longitudeDeg;
}

const kHomePlaces = <HomePlace>[
  HomePlace('warsaw', 'WARSAW', 52.23, 21.01),
  HomePlace('london', 'LONDON', 51.51, -0.13),
  HomePlace('paris', 'PARIS', 48.86, 2.35),
  HomePlace('new-york', 'NEW YORK', 40.71, -74.01),
  HomePlace('los-angeles', 'LOS ANGELES', 34.05, -118.24),
  HomePlace('sao-paulo', 'SAO PAULO', -23.55, -46.63),
  HomePlace('cape-town', 'CAPE TOWN', -33.93, 18.42),
  HomePlace('tokyo', 'TOKYO', 35.68, 139.69),
  HomePlace('sydney', 'SYDNEY', -33.87, 151.21),
  HomePlace('reykjavik', 'REYKJAVIK', 64.15, -21.94),
];

HomePlace matchingHome(Profile p) {
  for (final h in kHomePlaces) {
    if (p.homePlace == h.id) return h;
  }
  HomePlace best = kHomePlaces.first;
  var bestD = double.infinity;
  for (final h in kHomePlaces) {
    final d =
        (h.latitudeDeg - p.latitudeDeg).abs() +
        (h.longitudeDeg - p.longitudeDeg).abs();
    if (d < bestD) {
      best = h;
      bestD = d;
    }
  }
  return best;
}

HomePlace nextHome(Profile p) {
  final cur = matchingHome(p);
  final i = kHomePlaces.indexOf(cur);
  return kHomePlaces[(i + 1) % kHomePlaces.length];
}
