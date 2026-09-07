# Illunis

Lifestyle pattern-detection fitness app. Tracks health stats, journal, nutrition,
and strength training — then surfaces data-driven trends and advice.

- **Journal** — AI-assisted logging of activity, food, workouts
- **Dashboard** — live goal fulfilment + collected-data trends
- **Signature** — a physically-rendered sky as the app's living shell: sun,
  moon, the five naked-eye planets under their astronomical symbols, and a
  24-hour timeline that scrubs the day and shows last night's sleep

Status: **1.0** in `app/`. Journal logs on-device (offline parser; optional
AI through `server/worker.js`). Unconfirmed food and sessions stay out of
totals until CONFIRM. Dashboard and sky read daily rollups. Patterns stay
silent until 21 paired days. Long-press JOURNAL / DASHBOARD for settings
(units, home, export, import, consent, delete). The parser folds Polish
and comma decimals (`82,4 kg`). See `PLAN.md`, `docs/DESIGN.md`,
`docs/HANDOFF.md`, `docs/PERF.md`, `docs/VISUAL_PASS_2.md`,
`docs/BACKEND_PLAN.md`, `docs/DECISIONS.md`.

## Run

```bash
cd app
flutter run                       # any device; debug builds have the sky debug sheet
flutter run --dart-define=ILLUNIS_CAPTURE=/tmp/cap   # writes review PNGs across a day
flutter run --dart-define=ILLUNIS_DREAM=true         # nightstand composition (any device)
flutter analyze && flutter test
```

Drag the timeline under the horizon to scrub the day; tap `LIVE` to return
to the clock. Debug builds: long-press `ILLUNIS` for day of year, latitude,
moon phase, vitals presets, a nightstand preview, and (on Android) a jump
to screensaver settings.

**Android screensaver.** Settings → Display → Screen saver → Illunis. It
runs while the phone is docked or charging. Close finishes the dream.

Related: `../eter2` (pattern engine + AI-transport lessons), Hyper Planner workout app.
