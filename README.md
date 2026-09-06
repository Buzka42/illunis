# Illunis

Lifestyle pattern-detection fitness app. Tracks health stats, journal, nutrition,
and strength training — then surfaces data-driven trends and advice.

- **Journal** — AI-assisted logging of activity, food, workouts
- **Dashboard** — live goal fulfilment + collected-data trends
- **Signature** — a physically-rendered sun/moon sky as the app's living shell,
  annotated like an instrument

Status: Phase 1 (UI shell) built in `app/` on mock data. See `PLAN.md` for
architecture and decisions, `docs/BACKEND_PLAN.md` for the backend brief,
`CURSOR_MANDATE.md` for the original vision.

## Run

```bash
cd app
flutter run                       # any device; debug builds have the sky debug sheet
flutter run --dart-define=ILLUNIS_CAPTURE=/tmp/cap   # writes review PNGs across a day
flutter analyze && flutter test
```

Debug builds: long-press `ILLUNIS` to scrub time, day of year, latitude,
moon phase and vitals presets.

Related: `../eter2` (pattern engine + AI-transport lessons), Hyper Planner workout app.
