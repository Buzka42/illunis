# Illunis — Backend Coding Plan

For the model that builds everything *behind* the sky. Read
`CURSOR_MANDATE.md` for the product, `PLAN.md` for the architecture, and this
file for what to build, in what order, and where the lines are.

The UI shell (`app/lib/core/sky/`, `app/lib/features/`) is finished to a
visual standard and is **not yours to restyle**. You plug data into it. If a
surface needs a new figure, you add the figure in the existing voice
(`core/theme/typography.dart`) and you do not add a card, a pill, a ring or a
gradient to hold it.

---

## 0. The one seam you plug into

```dart
// app/lib/core/state/sky_state_source.dart
abstract class SkyStateSource {
  Stream<SkyState> get states;
  Future<void> dispose();
}
```

`SkyState` (`app/lib/core/sky/sky_state.dart`) is the whole interface to the
3D layer: `timeOfDay`, `dayOfYear`, `latitudeDeg`, `moonPhase`, `solarNoon`,
and four nullable vitals in `0..1` (`sleepScore`, `recovery`, `strain`) and
`-1..1` (`energyBalance`). Null means unknown and renders as a plain sky.

Replace `LiveMockSource` by overriding `skyStateSourceProvider` in
`ProviderScope(overrides: [...])`. Do not touch `core/sky/`; a test
(`test/sky/architecture_test.dart`) fails the build if that directory learns
about Riverpod, the clock, a database or a kilocalorie.

Rules for the values you emit:

- `timeOfDay` is the **civil** clock fraction. Put longitude, time zone and
  the equation of time into `solarNoon` (fraction of the day when the sun
  transits). The sky derives sunrise/sunset from it; the readouts on screen
  come from the same place, so get it right once.
- `latitudeDeg` from the last known coarse location, else the profile's home
  city, else `52.23`. **No location permission prompt for this.**
- `moonPhase` from the source's ephemeris if it has one, else
  `moonPhaseFor(DateTime)` in `core/sky/celestial_math.dart` is good to ~1%.
- Vitals from **daily rollups**, never from raw minutes. Recompute at most
  every few minutes; the view eases anyway.
- Emit on a timer (≤ 1 s) so the clock hand moves; emit immediately on any
  rollup change.

---

## 1. Layout to extend (eter2 conventions)

```
app/lib/core/
  db/            Drift schema, AppDatabase, migrations, retention
  journal/       capture → interpretation contracts → derived records
  nutrition/     food entries, macro math, database adapter
  strength/      workouts, sets, exercise canon, 1RM
  health/        Health Connect / HealthKit adapters, rollups
  patterns/      statistics, sweep, candidates
  ai/            prompts.dart, transport.dart — the only socket in the app
  i18n/          strings.dart — no ARB; the analyzer is the completeness check
  state/         providers; the SkyStateSource implementation lives here
server/
  worker.js      owner-controlled endpoint (Cloudflare Worker), holds the key
```

Riverpod for state, Drift for the store, `flutter_lints` + the three extra
rules in `analysis_options.yaml`. Strings in Dart. Fonts are bundled; never
add `google_fonts`.

---

## 2. Phases

### Phase 2 — Journal that logs (device-only, no AI yet)

1. **Schema (Drift).** `Profiles` (single row: units, home place/lat/lon,
   `language`, consent timestamps — all nullable), `JournalEntries` (text,
   `status`, `excludedFromAi`, `extractionJson`, `appliedAt`),
   `ActivityEntries`, `NutritionEntries` (`confirmed`, `source`,
   `journalEntryId`, `metadataJson`), `StrengthWorkouts` → `StrengthSets`
   (exercise id, weight, reps, rpe?), `DaySummaries`, `WeightEntries`.
   Every derived row carries `journalEntryId` so `revertJournalEntryRows(id)`
   can delete everything one page produced.
2. **Capture.** Text field + `speech_to_text` dictation on the Journal
   page's writing line (`features/journal/journal_page.dart` already has the
   line and the mic mark; wire it, do not redraw it). Entries save locally,
   instantly, offline. Logging is never gated by consent, network or account.
3. **Exercise canon.** Import from Hyper Planner `plans/INDEX.md` into
   `core/strength/canon.dart`: id, display name, aliases, primary muscles,
   `isCompound`. Normalisation is alias → id with a fuzzy fallback (Jaro–
   Winkler ≥ 0.88) and an explicit "unknown exercise, keep as typed" path.
4. **1RM.** Epley `w(1 + r/30)` and Brzycki `w · 36/(37 − r)`; store both,
   display Epley, and only for `reps ≤ 10`. Per-exercise progress = best
   estimated 1RM per day.
5. **Dashboard rows.** Replace the mock figures in
   `features/dashboard/dashboard_page.dart` with real ones through providers.
   Keep the row component; add rows for `TRAINING` (sets · volume) and
   `INTAKE` (kcal · P/C/F). Absent = `—`, never `0`.
6. **Retention and controls.** `deleteAllLocalData()`, `exportLocalData()`
   (JSON + CSV, no network), per-entry delete with revert.

### Phase 2b — AI journal parser

Copy eter2's transport shape exactly, not its code:

- The app builds `system` + `user` + `responseSchema`; posts to the owner's
  endpoint with `x-illunis-install` (16 random bytes, header only, never in
  the body) for metering. **No model key ships in the app.**
- The endpoint (`server/worker.js`) authenticates, checks `call ∈ {…}`,
  meters per install then globally, forwards the triple **unchanged**, returns
  `{"raw": text}`, never repairs JSON, never logs the payload.
- Each contract owns its parser and rejects out-of-range values; estimates
  land as `confirmed: false`, `source: 'ai-estimate'`, excluded from totals
  until the person confirms. Calls: `journalInterpretation` (one entry →
  activities / foods / workouts with confidence + assumptions), `dayDigest`
  (bounded per-day summary for later pattern context).
- Consent: `aiConsentAt` nullable timestamp on the profile, re-read on every
  call. Age gate ≥ 16. Per-entry `KEEP LOCAL`.
- Food calorie database: spike both OpenFoodFacts (offline dump, larger,
  messier) and USDA FoodData Central (cleaner, US-centric, API) against 40
  real dictated meals; pick by hit-rate on generic foods. Decision recorded
  in `docs/DECISIONS.md`.

### Phase 3 — Wearables and the real SkyStateSource

- `health` package: Health Connect (Android) / HealthKit (iOS). Read: steps,
  active energy, sleep sessions + stages, HR, resting HR, HRV, workouts.
  Per-type permission is the only gate. Write back: weights and **confirmed**
  meals only, filtered by origin so the hub's own data never round-trips.
- Rollups into `DaySummaries` / `DailyVitals`. Then the source:
  - `sleepScore` = duration vs personal 30-day median (60%) + efficiency
    (25%) + timing regularity (15%), clamped `0..1`.
  - `recovery` = HRV z-score vs 30-day baseline (blended with RHR inverse),
    mapped through a logistic to `0..1`. Null until 7 days of baseline.
  - `strain` = today's TRIMP-like load / personal 28-day 90th percentile.
  - `energyBalance` = tanh((intake − expenditure, 7-day mean) / 600 kcal).
    Null when intake is unlogged on ≥ 3 of the 7 days.
- Background sync on resume and on leaving; debounced; never on cold start.
- Play Store health-data declarations drafted **when this phase starts**.

### Phase 4 — Patterns

- Daily/weekly rollups feed a correlation sweep across every measured pair.
  Reuse the *statistics* from eter2 `core/patterns/statistics.dart`:
  `minimumPairs = 21`, an effect-size floor, Benjamini–Hochberg across the
  whole sweep. Nothing is shown before it can honestly be said; the
  onboarding says so.
- Patterns store structured evidence and are worded at display time, in the
  same instrument voice (`TYPE.label` eyebrow + one sentence). No chat.
- Optional AI summarisation of *patterns* (never raw logs) under consent.

---

## 3. Non-negotiables

- Device is canonical. No account required for anything in Phases 2–4.
- Model output is never mirrored to any cloud. Journal prose crosses to an
  endpoint only under a separate consent, bounded, with `KEEP LOCAL` honoured.
- No social, no auto-generated plans, no marketplace.
- `flutter analyze` clean, `flutter test` green, `dart format` applied, on
  every commit. The architecture test stays.
- Visual changes go through the forbidden list in `PLAN.md` §3.2. If you
  believe a surface needs a new element, propose it in `docs/UI_REQUESTS.md`
  with a screenshot of the exact negative space; do not improvise it.

---

## 4. First week, concretely

1. Drift schema + `AppDatabase` + migration test. Profiles, journal, strength,
   nutrition, day summaries.
2. `LocalSkyStateSource` reading `DaySummaries`/`DailyVitals` (all null at
   first) and the real clock/location → override `skyStateSourceProvider`.
   Ship this early: it proves the seam.
3. Writing line → text capture → `JournalEntries`; entry list on the Journal
   page under the date, in the existing type.
4. Strength parsing from plain text (`"bench 80x5x3"`, `"squat 100 kg 5 reps"`)
   with the canon; 1RM; `TRAINING` row on the dashboard.
5. Export + delete-all in a plain settings sheet (long-press the surface
   switch, mirror of the debug sheet's style).
