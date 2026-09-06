# Illunis — Cursor Architectural Mandate (Fable 5.1)

> Open-ended on purpose. Fable plans the implementation. This file states the
> vision, the quality bar, and the boundaries — not the how.

## 1. Vision

Illunis is a lifestyle pattern-detection fitness app — what Eter was originally
supposed to be before it became astrology-oriented. It tracks everything
health-related and detects patterns purely from data:

- "you slept poorly → your gym performance degraded significantly"
- "caloric surplus for weeks but strength isn't growing"

Two screens, nothing more in v1:

1. **Journal** — the input. AI-assisted logging: dictate an activity and the
   journal identifies it, estimates calories burned, logs it to the day. Same
   for food (calories/macros) and full gym workouts (exercises as
   sets × weight × reps, with per-exercise 1RM progress tracking).
2. **Dashboard** — the output. Live goal-fulfillment display plus collected-data
   trends that get smarter as data accumulates.

The app's soul is the **procession of sun and moon**: a 3D visualization that
is the living shell of the whole app — time of day, recovery, strain and
balance expressed as celestial motion on screen.

## 2. Phase 1 — the 3D UI shell. Top notch. Perfect.

This is the entire 5-day Cursor window. Nothing else matters until this sings.

- Design and build the sun/moon procession 3D experience to a premium,
  editorial standard — the kind of thing people screenshot. This is the app's
  identity; generic is failure.
- **Not AI slop:** no capsule/pill buttons, no generic glassmorphic cards, no
  donut/ring fitness gauges, no dead-centre symmetric template stacks. Bespoke,
  crafted, cohesive with a day/night celestial theme. (Hard lesson from Eter —
  don't repeat it.)
- Fable owns all technical choices: rendering approach, shaders, day/night
  transitions, motion feel, performance budget (target: smooth 60fps on
  mid-range Android, sane battery cost).
- **The 3D layer is dumb on purpose.** It renders from a minimal state
  interface — e.g. timeOfDay, sleepScore, strain, recovery, energyBalance —
  fed by MOCK data in Phase 1. Zero parsing, zero database, zero health logic
  inside the 3D layer. If the backend isn't ready, the sky still moves.
- Deliverable: fresh repo scaffolded (Flutter, following the eter2 project
  layout conventions where they help), 3D shell running on mock state,
  `flutter analyze` clean.

## 3. Later phases — orientation only, NOT Phase 1

Listed so the architecture doesn't box them out. Do not build these now:

- **AI journal parser** — structured extraction of activity/food/workouts from
  dictation; exercise normalization against a canonical list; 1RM calculation
  (Epley/Brzycki); food-calorie database decision (OpenFoodFacts vs USDA).
- **Wearable integration** — Health Connect / HealthKit sync, permissions,
  background sync. (Known native-bridge pain — scheduled for opencode after
  the Cursor window.)
- **Trend/memory engine** — daily/weekly rollups fed into pattern detection.
  Never raw logs in context. Reference: `../eter2` pattern statistics
  (`minimumPairs = 21` — the first learned pattern can't exist before ~day 21,
  design onboarding honesty around that), the `aiTransportProvider`/consent
  seam, and the "gate intelligence, never the record" rule (journal + logging
  always free and offline).
- **Exercise canon** — steal from the Hyper Planner `plans/INDEX.md`.

## 4. Constraints & anti-goals

- Fresh repo, no astro/entitlement cruft carried over from eter2. Copy patterns,
  not code, unless the code is clean.
- Health data is sensitive: keep the on-device vs cloud-AI line and Play Store
  health declarations in mind from day one.
- v1 anti-goals: no social features, no auto-generated training plans, no
  coaching marketplace.
- Verify (once scaffolded): `flutter test` + `flutter analyze` clean.

## 5. Definition of done for Phase 1

Open the app → the sun/moon procession is unmistakably premium, moves with
mock state, holds 60fps, analyzer clean, and a second agent could plug the real
data interface in without touching the 3D layer.
