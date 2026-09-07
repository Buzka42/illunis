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

Production already uses `LocalSkyStateSource` via `illunisOverrides` in
`main.dart`. Wearable sources override the same provider. Do not touch
`core/sky/`; a test (`test/sky/architecture_test.dart`) fails the build if
that directory learns about Riverpod, the clock, a database or a kilocalorie.

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
  db/            JSON AppStore for now (Drift deferred)
  journal/       stamp → local parser → repository → derived records
  nutrition/     household food table, macro math
  strength/      sets, exercise canon, 1RM
  fitness/       disciplines, sessions, progress figures
  health/        rollups, local digest, LocalSkyStateSource
  patterns/      statistics, sweep
  ai/            prompts.dart, transport.dart — the only socket in the app
  i18n/          strings.dart — no ARB; the analyzer is the completeness check
  state/         providers; production source is LocalSkyStateSource
server/
  worker.js      owner-controlled endpoint (Cloudflare Worker), holds the key
```

Riverpod for state. JSON file store, not Drift. `flutter_lints` + the three
extra rules in `analysis_options.yaml`. Strings in Dart. Fonts are bundled;
never add `google_fonts`. The `health` package stays out so Windows desktop
keeps building.

---

## 2. Phases

Production already overrides `skyStateSourceProvider` with
`LocalSkyStateSource` (clock + rollups). Debug presets still overlay.

### Phase 2 — Journal that logs — shipped

JSON `AppStore`, not Drift. Capture, canon, 1RM, dashboard figures, export /
import / delete, REVERT, CONFIRM / DROP, KEEP LOCAL, PREV/NEXT civil days,
local digest, incomplete bedtime + morning wake, Warsaw/Polish speech and
European decimals. See `docs/DECISIONS.md` and `docs/HANDOFF.md`.

Still deferred inside this phase: Drift migrations, a scored food database.

### Phase 2b — AI journal parser — wired, optional

Transport + `server/worker.js` + settings consent + age gate + KEEP LOCAL.
The local parser is canonical. The worker runs only when
`ILLUNIS_AI_ENDPOINT` is set and both gates are on. Food DB spike still waits
on ~40 real dictated meals.

### Phase 3 — Wearables and richer vitals — not started

- `health` package: Health Connect (Android) / HealthKit (iOS). Read: steps,
  active energy, sleep sessions + stages, HR, resting HR, HRV, workouts.
  Per-type permission is the only gate. Write back: weights and **confirmed**
  meals only, filtered by origin so the hub's own data never round-trips.
- Keep the package skipped until this phase so Windows desktop stays
  buildable.
- Rollups already exist from the journal. Wearables fill unknown vitals:
  - `sleepScore` = duration vs personal 30-day median (60%) + efficiency
    (25%) + timing regularity (15%), clamped `0..1`.
  - `recovery` = HRV z-score vs 30-day baseline (blended with RHR inverse),
    mapped through a logistic to `0..1`. Null until 7 days of baseline.
  - `strain` = today's TRIMP-like load / personal 28-day 90th percentile.
  - `energyBalance` = tanh((intake − expenditure, 7-day mean) / 600 kcal).
    Null when intake is unlogged on ≥ 3 of the 7 days.
- Background sync on resume and on leaving; debounced; never on cold start.
- Play Store health-data declarations drafted **when this phase starts**.

### Phase 4 — Patterns — engine shipped, silent

Sweep is in (`minimumPairs = 21`, effect-size floor, Benjamini–Hochberg).
The dashboard shows the wait, not a story. Optional AI summarisation of
*patterns* (never raw logs) under consent. Do not seed fake history.

The night sky catalog pass is **not** this file. It lives in
`docs/SKY_CATALOG.md` and `PLAN.md` §8. Do not restyle `core/sky/` here.

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

## 4. What is left

1. On-device Warsaw dictation pass on the Blade (`docs/HANDOFF.md`). Do not
   invent duration for `went for a run` with no minutes or distance.
2. Drift when the JSON file becomes the bottleneck — same tables, same
   `journalEntryId` revert rule.
3. Wearables (`health` package) without breaking the Windows desktop build.
4. Food DB spike against ~40 real meals; replace `foods.dart` only then.
5. Stellarium/window check of the catalog; precession only if off > 0.5°.
6. A real lunar theory (already deferred in `docs/VISUAL_PASS_2.md`).
7. Do not seed 21 days of fake history so insights can speak.
