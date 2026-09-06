# Illunis

Lifestyle pattern-detection fitness app. Tracks health stats, journal, nutrition,
and strength training — then surfaces data-driven trends and advice.

- **Journal** — AI-assisted logging of activity, food, workouts
- **Dashboard** — live goal fulfilment + collected-data trends
- **Signature** — a physically-rendered sky as the app's living shell: sun,
  moon, the five naked-eye planets under their astronomical symbols, and a
  24-hour timeline that scrubs the day and shows last night's sleep

Status: Phase 1 (UI shell) built in `app/` on mock data, visual pass 2 done.
See `PLAN.md` for architecture and decisions, `docs/VISUAL_PASS_2.md` for
the latest pass, `docs/BACKEND_PLAN.md` for the backend brief,
`CURSOR_MANDATE.md` for the original vision.

## Run

```bash
cd app
flutter run                       # any device; debug builds have the sky debug sheet
flutter run --dart-define=ILLUNIS_CAPTURE=/tmp/cap   # writes review PNGs across a day
flutter analyze && flutter test
```

Drag the timeline under the horizon to scrub the day; tap `LIVE` to return
to the clock. Debug builds: long-press `ILLUNIS` for day of year, latitude,
moon phase and vitals presets.

Related: `../eter2` (pattern engine + AI-transport lessons), Hyper Planner workout app.
