# Illunis — Astra Sky Mandate (GPT Astra 6, via Codex)

> Open-ended on purpose. Astra owns the how. This file states the goal, the bar, and the boundaries.
> Read `CURSOR_MANDATE.md`, `PLAN.md`, `docs/DESIGN.md`, `docs/DECISIONS.md`, `docs/HANDOFF.md` first. If code and docs disagree, code is right.

## 0. The one sentence

Make the sky indistinguishable from looking up: the highest-resolution, most physically-honest night/day sky a mid-range Android can hold at 60fps — then make weather real (cloud, rain, fog, snow) behind a seam a future met-data source can drive.

Everything else is secondary. The sky is ~70% of this task.

## 1. Non-negotiables (do not break)

- Sky seam: `app/lib/core/sky/` stays dumb. It may import `dart:math`, `dart:ui`, `flutter/*`, its own files, `core/theme/tokens.dart` — nothing else. No Riverpod, no `DateTime.now`, no kcal, no health words. `test/sky/architecture_test.dart` enforces this; keep it green.
- `SkyState` (`app/lib/core/sky/sky_state.dart`) is the only interface. Extend it, don't bypass it. Weather arrives as **new nullable field(s)** on `SkyState` (e.g. condition + intensity/coverage), null = clear/unknown, same absence-rendered-as-absence rule as vitals. Never zero-for-unknown.
- One continuous theme (PLAN D2): all ink derives from the same `SkyState`. No light/dark toggle.
- Observer stays `Settings` home. No GPS. No runtime catalog fetch — catalog ships bundled (`tool/stars/generate.py`, HYG v3, see `docs/SKY_CATALOG.md`).
- Design law: NO AI slop. No capsule/pill buttons, no glassmorphic cards, no ring gauges, no dead-centre symmetric stacks. Instrument layer = hairlines, glyphs, mono figures. New figures go in `core/theme/typography.dart` in the existing voice (Inter words + JetBrains Mono figures).
- Patterns stay silent until 21 paired days. Journal + logging always free/offline; gate intelligence, never the record. Long-press surface switch = export/delete (see PLAN.md).
- SKY DEBUG SHEET / scrub presets debug-builds only. Never ship them in release.
- Target: ZTE Blade V 5G (20240920122, Android 14, 1080x2412, Impeller Vulkan) + Windows/Chrome desktop. 60fps, sane battery (grain/twinkle freeze under `disableAnimations`, ticker pause on background, nightstand ±3px/180s OLED drift — see DESIGN.md).
- Verify: `cd app && flutter analyze && flutter test`. No commit, no push unless the person asks.

## 2. Phase A — Sky fidelity (the real task)

Push the existing fragment-shader + Canvas stack (`app/shaders/sky.frag`, `sky_painter.dart`, `celestial_scene.dart`, `celestial_math.dart`) as far as it honestly goes:

- Resolution + banding: kill gradient banding at full-res (dither/grain strategy that survives Impeller Vulkan on the Blade, not just desktop). Full-res sky — no half-res composite upscaling artifacts.
- Atmosphere: Preetham-family Rayleigh/Mie already there — tighten it. True solar geometry, believable twilight progression (civil/nautical/astronomical), horizon extinction, sun disk + glow that reads at noon and at set without restyling the shell.
- Night: catalog stars at visual magnitude (no double-draw — hashed field was removed so Sirius draws once), correct sidereal angle from `epochDays` + `solarNoon`, procedural Milky Way until a texture is justified, Lommel-Seeliger moon with true phase/terminator from sun direction (~3x moon size stays), five naked-eye planets with vector glyphs (see `celestial_glyphs.dart`, VISUAL_PASS_2).
- Motion: keep the easing contract (timeOfDay τ≈0.22s, vitals ≈1.4s, bearing ≈1.6s). Preset switch = weather, not a cut. Night grain + twinkle, day creep only.
- Judge against reality: pick Warsaw 52.23°N, compare sun altitude/azimuth + sunrise/sunset + moon phase against an ephemeris/Stellarium window. Note any residual >0.5° (precession door in DECISIONS opens only on that evidence).

## 3. Phase B — Weather (simulated now, met-data later)

Build the visual system now; the data hookup comes later. No API keys, no network fetch, no GPS in this pass.

- Conditions, minimum: clear / cloudy (coverage-driven stratus + cumulus character) / rain / fog / snow. Overcast must convincingly swallow stars/moon/sun disk; fog is a horizon/depth phenomenon, not a fullscreen blur; rain/snow read as atmosphere, not emoji particles.
- Drive entirely through the new `SkyState` weather field(s) + debug presets/scrub (same pattern as existing sky presets). A future `SkyStateSource` fed by meteorological data plugs in with zero `core/sky/` changes — document that seam in the handoff.
- Keep the instrument legible under all conditions (readout/type alphas in DESIGN.md are the floor, not the ceiling). Sky-band overlay ink lerp (paper→slate) must still work under cloud.
- Perf: weather must not collapse the frame budget on the Blade. State the cost in `docs/PERF.md` if you move it.

## 4. Phase C — De-slopify + premium pass (surfaces only, sky untouched)

With the sky frozen, perfect the two surfaces over the one shared sky (pager yaws camera ~8°):

- Journal: an empty writing surface, honest empty states. Dashboard: table (sleep, recovery, strain, energy, sun/moon rise/set), `MOCK DATA` label stays where mock. SLEEP/STRAIN never hidden (0 = rest, null = `—`).
- Remove anything slop-adjacent; tighten type/hairline weights to DESIGN.md values; keep horizon at 0.56, compass band + 48px timeline geometry. Nightstand (`DreamShell`) keeps its near-empty ground: large clock, twilight word, last night's sleep.

## 5. Phase D — Whole-app audit + proposal (do not build yet)

Read the whole `app/lib` + `server/` (Cloudflare worker, `ILLUNIS_AI_ENDPOINT` + consent + age gate still required before it enriches anything). Then write the proposal inside the handoff: ordered list, each item = problem, evidence (file:line), proposed change, risk, verify step. Expected hunting grounds: journal parser edge cases (Polish genitives, comma decimals), rollups/strain honesty, import/export (JSON clipboard in, CSV out), settings-sheet clipping on the Blade nav bar, background/ticker battery behavior. Do not start Drift, the `health` package, or a food DB — those doors are closed in DECISIONS.md.

## 6. Deliverables

1. Sky + weather in the tree, `flutter analyze` clean, full `flutter test` green (extend `test/sky/` — geometry goldens, weather-state rendering, architecture import test).
2. Screenshots to `captures/` (or `captures/v3/` if v2 is occupied): clear noon, golden set, civil/nautical/astro twilight, night with moon, each weather condition, both surfaces + nightstand. Desktop captures acceptable; note which are Blade captures.
3. `docs/ASTRA_HANDOFF.md`: what changed (files), sky-vs-reality check results, weather seam (fields + preset names + how met-data plugs in), perf notes + frame budget, the Phase-D proposal list, and exact verify output. The person returns with illunis-dev to review handoff + screenshots together.

## 7. Order of work

A → B → C → D → screenshots + handoff. If fidelity and weather collide on perf, fidelity wins and weather degrades gracefully (coverage first, particle density second). Ask nothing; decide, note it in the handoff.
