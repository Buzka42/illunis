# Illunis — Handoff

Next session: keep capture honest on the Blade, collect ~40 real dictated
meals before scoring OpenFoodFacts vs USDA. Do not restyle the sky.

Read `CURSOR_MANDATE.md` for the product, `PLAN.md` for architecture,
`docs/DECISIONS.md` for closed doors, `docs/BACKEND_PLAN.md` for deferred
backend, `docs/DESIGN.md` for the visual contract. The sky seam is at the
end of this file.

Repo: `https://github.com/Buzka42/illunis` (private). Branch `master`.
Application id: `com.illunis.illunis`.

---

## Status (8 Sep 2026)

Phase 1 sky and Phase 2 on-device journal are in the tree. The last pushed
sky+journal commit is `7ada496`. After that: stamps, spoken Polish (genitives,
accusatives, measure prefixes, verbs), sleep belonging, comma decimals,
a scrolling settings sheet, and Blade capture tests. `flutter analyze` clean;
**120** tests green.

Debug APK installed and verified live on the ZTE Blade V 5G (`20240920122`):
- `RECORD_AUDIO` permission granted and active.
- Dictation and text capture verified: sleep (`spalem siedem godzin`),
  multi-food estimates with dock confirm (`zjadlem dwa jajka i chleb`),
  and conditioning sessions (`bylem na silowni 45` -> Strain 1.00 LOAD).
- Timeline and dashboard rollups update live on-device with Impeller 60+ fps.

Production sky already reads rollups (`LocalSkyStateSource` via
`illunisOverrides` in `main.dart`). Patterns stay silent until 21 paired
days. Do not seed fake history.

---

## Device — ZTE Blade V 5G

Serial `20240920122`, Android 14, 1080×2412, Impeller Vulkan, home city
Warsaw 52.23°N, carrier Orange. System nav `[0,2268][1080,2412]` — do not
tap around `y ≈ 2320`. USB transport id changes; the device often goes
`offline`.

**Install debug only.** `flutter install` tries a missing release APK and
uninstalls the app.

```bash
cd app
flutter build apk --debug
adb kill-server
adb start-server
adb devices -l
adb -s 20240920122 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 20240920122 shell monkey -p com.illunis.illunis -c android.intent.category.LAUNCHER 1
```

First mic tap asks for `RECORD_AUDIO`. Long-press JOURNAL / DASHBOARD for
settings. Long-press ILLUNIS for the debug sheet (debug builds).

---

## Journal capture

Stamp → local parser → repository → derived rows. Device is canonical.
Logging is never gated on AI or consent.

| Piece | Where |
|---|---|
| Clock / period / yesterday / last night | `app/lib/core/journal/stamp.dart` |
| Food, sleep, sets, weight | `app/lib/core/journal/parser.dart` |
| Night belonging, wake complete, quality attach | `app/lib/core/journal/repository.dart` |
| Latin fold + `82,4` decimals | `app/lib/core/i18n/fold.dart` (`foldSpoken`) |
| Mic locale, 60 s listen | `app/lib/core/journal/dictation.dart` |
| Catch-up, yesterday pending, incomplete bed | `app/lib/core/state/app_providers.dart` |
| Writing line, dock, ListView journal | `app/lib/features/journal/journal_page.dart` |
| Settings (scrolls, JSON import) | `app/lib/features/settings/settings_sheet.dart` |

**Catch-up.** PREV/NEXT turns it on. `yesterday` / `last night` reveals that
civil day and does **not** turn catch-up on, so the next unstamped line uses
the clock. Unconfirmed food and activity from yesterday sit on today's dock.
CONFIRM ALL confirms every day shown.

**Sleep.** Quality-only does not invent hours. Incomplete bedtime
(`went to bed at 23:10`) stores duration 0 until `woke at 6:45`. Hours
belong to the wake morning. An evening bedtime logged before noon is last
night. `last night slept 7h` stays the morning they said it; `last night
ate pizza` is yesterday. Journal shows yesterday's open bed as `BED  23:10`.

**Food / movement.** Unconfirmed estimates stay out of totals and strain.
Trivial drinks (≤ 10 kcal) auto-confirm. Named compounds do not split.
Endurance still needs a unit (`ran 45` is empty; `ran 45 min` / `ran 5k`
is a session). `went for a run` with no minutes or distance must stay empty.

**Try on the Blade**

```
spałem siedem godzin
zjadłem dwa jajka i chleb
ryż z kurczakiem
owsianka na śniadanie
byłem na siłowni 45
82,4 kg
biegłem 5,2 km
7,30 ran 5k
went to bed at 23:10
```

---

## Do not

- Restyle `core/sky/` or invent cards, pills, rings, glass.
- Import Riverpod, kcal, or `DateTime.now` into `core/sky/`.
- Use `flutter install` on the Blade.
- Hide SLEEP or STRAIN (0 is rest; null is unknown / pending).
- Turn KEEP LOCAL **on** from an existing row (crowds the Blade). Clearing
  it from the list is already there.
- Change `timelineMarksProvider` off **today**.
- Seed 21 days of fake history.
- Start Drift, the `health` package, or a real food DB (see
  `docs/DECISIONS.md`).
- Commit or push unless the person asks.

---

## Next (ordered)

1. Keep capture honest during daily use on the Blade; collect ~40 real
   dictated meals before scoring OpenFoodFacts vs USDA.
2. Maintain capture boundaries: no invented duration for quality-only nights
   or unit-less runs.
3. Wearables (Health Connect / HealthKit) / Drift / OFF vs USDA / Stellarium
   precession only when those doors open in `docs/DECISIONS.md`.

`ILLUNIS_AI_ENDPOINT` + consent + age gate still required before the worker
enriches a page. The local parser is the record.

---

## The sky seam

The 3D layer is finished and dumb. You plug data in.

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

### How to plug in

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
   Catalog stars (`docs/SKY_CATALOG.md`) use that same sidereal angle.
   Do not add a second clock.
5. `moonPhase` from your ephemeris, or `moonPhaseFor(utc)` in
   `celestial_math.dart` (~1%).
6. `epochDays` from `epochDaysForDate(year, month, day)` at local midnight.
   Do not pass a `DateTime` into `core/sky/`.

### What you must not do to the sky

- Import Riverpod, `dart:io`, features, or theme from `lib/core/sky/`.
  `test/sky/architecture_test.dart` fails the build if that directory learns
  a kilocalorie or `DateTime.now`.
- Restyle the shell. New figures go in `core/theme/typography.dart` in the
  existing voice. No cards, pills, rings, or glass.
- Put raw wearable minutes into `SkyState`. Roll up first.

### Nightstand

Android screensaver is `IllunisDreamService`. It runs the `dreamMain`
entrypoint (`lib/main.dart`) into `DreamShell`. Same providers, same sky.
A real source override applies there automatically because it is the same
process when the app is already alive, and the same `ProviderScope` wiring
when the dream starts cold — so put the override in `main`/`dreamMain`'s
shared `_boot`, not only in `IllunisShell`.
