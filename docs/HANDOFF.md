# Illunis — Handoff: feeding the sky

The 3D layer is finished and dumb. You plug data in. You do not restyle it.

Read `CURSOR_MANDATE.md` for the product, `PLAN.md` for architecture,
`docs/BACKEND_PLAN.md` for the backend phases, `docs/DESIGN.md` for the visual
contract. This file is only the seam.

## The seam

```
SkyStateSource.states  →  skyStateProvider  →  SkyView  →  shader + overlay
                              ↑
                       skyOverridesProvider   (debug / timeline scrub only)
```

`SkyState` (`app/lib/core/sky/sky_state.dart`) is the whole interface to
`core/sky/`. Fields:

| Field | Range | Meaning |
|---|---|---|
| `timeOfDay` | 0..1 | civil clock; 0 = local midnight |
| `dayOfYear` | 1..366 | almanac line only |
| `epochDays` | days since J2000.0 at local midnight | sun + planets |
| `latitudeDeg` | degrees, N positive | observer |
| `moonPhase` | 0..1 | 0 new, 0.5 full |
| `solarNoon` | 0..1 | meridian transit; default 0.5 |
| `sleepScore` | 0..1 or null | last night |
| `recovery` | 0..1 or null | this morning |
| `strain` | 0..1 or null | load today |
| `energyBalance` | −1..1 or null | rolling surplus/deficit |

Null vitals render as a plain sky. Never send zero for "unknown".

Sleep stages are a separate object, `SleepRecord` via `sleepRecordProvider`
(`app/lib/core/state/sleep_record.dart`). Hours are relative to the displayed
day's midnight (last night's 23:10 is `-0.83`). Empty `segments` draws a
duration band only; `null` record draws nothing. The dashboard SLEEP figure
and the timeline read the same provider.

## How to plug in

1. Implement `SkyStateSource` (`app/lib/core/state/sky_state_source.dart`).
2. Override the provider. Do not edit `LiveMockSource` in place.

```dart
runApp(ProviderScope(
  overrides: [
    skyStateSourceProvider.overrideWith((ref) {
      final source = HealthConnectSource(/* ... */);
      ref.onDispose(source.dispose);
      return source;
    }),
    sleepRecordProvider.overrideWith((ref) {
      return ref.watch(lastNightSleepProvider);
    }),
  ],
  child: const IllunisApp(),
));
```

3. Emit at least once a second so the clock hand moves. Emit immediately
   when a rollup changes. The view eases; you may step.
4. Convert timezone, longitude and the equation of time into `solarNoon`.
   The sky derives sunrise/sunset from that plus latitude; the dashboard
   figures come from the same `ResolvedScene`, so get it right once.
5. `moonPhase` from your ephemeris, or `moonPhaseFor(utc)` in
   `celestial_math.dart` (~1%).
6. `epochDays` from `epochDaysForDate(year, month, day)` at local midnight.
   Do not pass a `DateTime` into `core/sky/`.

## What you must not do

- Import Riverpod, `dart:io`, features, or theme from `lib/core/sky/`.
  `test/sky/architecture_test.dart` fails the build if that directory learns
  a kilocalorie or `DateTime.now`.
- Restyle the shell. New figures go in `core/theme/typography.dart` in the
  existing voice. No cards, pills, rings, or glass.
- Put raw wearable minutes into `SkyState`. Roll up first.

## Nightstand

Android screensaver is `IllunisDreamService`. It runs the `dreamMain`
entrypoint (`lib/main.dart`) into `DreamShell`. Same providers, same sky.
A real source override applies there automatically because it is the same
process when the app is already alive, and the same `ProviderScope` wiring
when the dream starts cold — so put the override in `main`/`dreamMain`'s
shared `_boot`, not only in `IllunisShell`.
