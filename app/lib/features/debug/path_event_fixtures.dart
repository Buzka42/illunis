import 'package:flutter/foundation.dart';

import '../../core/journal/path_events.dart';
import '../../core/sky/sky_state.dart';

/// Preset debug scenarios exercising the path event geometry pipeline.
enum PathEventFixtureId {
  dawn('Dawn', 'Sunrise with breakfast & morning run'),
  noon('Noon', 'Midday sun with lunch & walk'),
  dusk('Dusk', 'Sunset twilight with dinner & ride'),
  moonlit('Moonlit', 'High moonlit night with late stroll'),
  moonless('Moonless', 'New moon dark night (0% lit)'),
  overcast('Overcast', 'Heavy overcast sky with indoor training'),
  denseOverlaps('Dense overlaps', 'Multiple coincident events at identical instant');

  const PathEventFixtureId(this.title, this.description);
  final String title;
  final String description;
}

/// A self-contained debug fixture pairing a celestial [SkyState] with [PathEvent]s.
@immutable
class PathEventFixture {
  const PathEventFixture({
    required this.id,
    required this.state,
    required this.events,
  });

  final PathEventFixtureId id;
  final SkyState state;
  final List<PathEvent> events;

  static const String testDay = '2026-03-21';

  static PathEventFixture get(PathEventFixtureId id) {
    switch (id) {
      case PathEventFixtureId.dawn:
        return _buildDawn();
      case PathEventFixtureId.noon:
        return _buildNoon();
      case PathEventFixtureId.dusk:
        return _buildDusk();
      case PathEventFixtureId.moonlit:
        return _buildMoonlit();
      case PathEventFixtureId.moonless:
        return _buildMoonless();
      case PathEventFixtureId.overcast:
        return _buildOvercast();
      case PathEventFixtureId.denseOverlaps:
        return _buildDenseOverlaps();
    }
  }

  static List<PathEventFixture> getAll() => [
    for (final id in PathEventFixtureId.values) get(id),
  ];

  static PathEventFixture _buildDawn() {
    // Dawn: ~06:15 local time (equinox sunrise ~06:00)
    const t = 0.26;
    return PathEventFixture(
      id: PathEventFixtureId.dawn,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.25,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'dawn-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 6, 15),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null, // Unknown duration never invented
          kcal: 420,
          provenance: PathEventProvenance.journal,
          label: 'Breakfast Oats',
        ),
        PathEvent(
          recordId: 'dawn-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 6, 45),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 35),
          kcal: 320,
          provenance: PathEventProvenance.journal,
          label: 'Morning Run',
        ),
      ],
    );
  }

  static PathEventFixture _buildNoon() {
    // Noon: solar culmination 12:00
    const t = 0.5;
    return PathEventFixture(
      id: PathEventFixtureId.noon,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.25,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'noon-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 12, 15),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 750,
          provenance: PathEventProvenance.journal,
          label: 'Lunch Bowl',
        ),
        PathEvent(
          recordId: 'noon-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 12, 45),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 40),
          kcal: 180,
          provenance: PathEventProvenance.journal,
          label: 'Midday Walk',
        ),
      ],
    );
  }

  static PathEventFixture _buildDusk() {
    // Dusk: ~18:20 sunset twilight
    const t = 0.765;
    return PathEventFixture(
      id: PathEventFixtureId.dusk,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.35,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'dusk-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 18, 30),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 850,
          provenance: PathEventProvenance.journal,
          label: 'Evening Dinner',
        ),
        PathEvent(
          recordId: 'dusk-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 19, 0),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 45),
          kcal: 390,
          provenance: PathEventProvenance.journal,
          label: 'Sunset Ride',
        ),
      ],
    );
  }

  static PathEventFixture _buildMoonlit() {
    // Moonlit: 22:15, 50% moon phase (bright gibbous/half moon)
    const t = 0.927;
    return PathEventFixture(
      id: PathEventFixtureId.moonlit,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.5,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'moonlit-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 21, 30),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 220,
          provenance: PathEventProvenance.journal,
          label: 'Late Snack',
        ),
        PathEvent(
          recordId: 'moonlit-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 22, 0),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 30),
          kcal: 140,
          provenance: PathEventProvenance.journal,
          label: 'Moonlit Stroll',
        ),
      ],
    );
  }

  static PathEventFixture _buildMoonless() {
    // Moonless: 01:20 deep night, moonPhase 0.0 (new moon, 0% lit)
    const t = 0.055;
    return PathEventFixture(
      id: PathEventFixtureId.moonless,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.0,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'moonless-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 0, 30),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 90,
          provenance: PathEventProvenance.journal,
          label: 'Midnight Chamomile',
        ),
        PathEvent(
          recordId: 'moonless-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 1, 0),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 20),
          kcal: 60,
          provenance: PathEventProvenance.journal,
          label: 'Night Stretching',
        ),
      ],
    );
  }

  static PathEventFixture _buildOvercast() {
    // Overcast: 14:15, cloud coverage 1.0
    const t = 0.594;
    return PathEventFixture(
      id: PathEventFixtureId.overcast,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.25,
        weather: SkyWeather(cloudCoverage: 1.0, cumulus: 0.2, rain: 0.35),
      ),
      events: [
        PathEvent(
          recordId: 'overcast-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: DateTime(2026, 3, 21, 14, 0),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 350,
          provenance: PathEventProvenance.journal,
          label: 'Tea & Brioche',
        ),
        PathEvent(
          recordId: 'overcast-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: DateTime(2026, 3, 21, 14, 30),
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 60),
          kcal: 540,
          provenance: PathEventProvenance.journal,
          label: 'Gym Session',
        ),
      ],
    );
  }

  static PathEventFixture _buildDenseOverlaps() {
    // Dense overlaps: multiple coincident events at the exact same instant (12:30)
    const t = 0.521;
    final sharedInstant = DateTime(2026, 3, 21, 12, 30);
    return PathEventFixture(
      id: PathEventFixtureId.denseOverlaps,
      state: const SkyState(
        timeOfDay: t,
        dayOfYear: 80,
        epochDays: 9576.0,
        latitudeDeg: 52.23,
        moonPhase: 0.25,
        weather: SkyWeather.clear(),
      ),
      events: [
        PathEvent(
          recordId: 'dense-intake-1',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: sharedInstant,
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 600,
          provenance: PathEventProvenance.journal,
          label: 'Main Dish',
        ),
        PathEvent(
          recordId: 'dense-intake-2',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: sharedInstant,
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 200,
          provenance: PathEventProvenance.journal,
          label: 'Side Salad',
        ),
        PathEvent(
          recordId: 'dense-intake-3',
          civilDay: testDay,
          kind: PathEventKind.intake,
          timestamp: sharedInstant,
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: null,
          kcal: 250,
          provenance: PathEventProvenance.journal,
          label: 'Protein Shake',
        ),
        PathEvent(
          recordId: 'dense-burn-1',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: sharedInstant,
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 45),
          kcal: 380,
          provenance: PathEventProvenance.journal,
          label: 'Strength Workout',
        ),
        PathEvent(
          recordId: 'dense-burn-2',
          civilDay: testDay,
          kind: PathEventKind.burn,
          timestamp: sharedInstant,
          timestampBasis: PathTimestampBasis.logAnchored,
          duration: const Duration(minutes: 15),
          kcal: 85,
          provenance: PathEventProvenance.journal,
          label: 'Cool-down Stretch',
        ),
      ],
    );
  }
}
