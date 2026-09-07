# Illunis — Implementation Plan

Companion to `CURSOR_MANDATE.md`. The mandate says what and how good; this
says how, in what order, and what was decided along the way. Phase 1 is the
five-day Cursor window and is planned in detail. Later phases are sketched only
far enough that Phase 1 does not box them out.

Environment as found on 6 Sep 2026: Flutter 3.44.6 stable (Dart 3.x), Android
SDK 36, one emulator (`Eter_API_36`), no physical Android device attached,
Windows + Chrome available as desktop targets.

Revisions after the first build are planned in their own files:
`docs/VISUAL_PASS_2.md` (planets and their symbols, the day timeline with
sleep, subtler instrument lines, full-resolution sky).

---

## 0. Decisions

Recorded up front because each one closes a door.

### D1. Rendering: fragment shaders + Canvas, with real celestial geometry in Dart

The sky is drawn by **Flutter fragment shaders** (`FragmentProgram`, GLSL,
declared under `flutter: shaders:` in `pubspec.yaml`) composited in a
`CustomPainter`. The **geometry is genuinely 3D** — sun and moon travel on
great-circle arcs over a celestial sphere for a fixed observer latitude, the
moon's terminator is shaded from a sphere normal against the sun direction,
the camera looks at a horizon — but the *rendering* is a 2.5D projection of
that model. Nobody needs a mesh to draw a sun.

Rejected: `flutter_scene` / Flutter GPU. Verified 6 Sep 2026: it requires
Flutter **3.47 stable or newer** (we have 3.44.6) and a per-platform
`FLTEnableFlutterGPU` opt-in. Upgrading the SDK on day one of a five-day
window, on top of an engine whose own README still recommends master-channel
builds, is the wrong risk. It also pulls toward PBR-mesh photorealism, which
is the opposite of the editorial register the mandate asks for. Shaders give
atmospheric scattering, soft gradients, film grain and a moon phase for a
fraction of the cost.

Door kept open: the scene model (§2.2) is renderer-agnostic. A future
`flutter_scene` renderer would consume the same `SkyState` and the same
resolved geometry; nothing above the painter would change.

### D2. One continuous theme, not a light/dark toggle

Every colour in the app — type, hairlines, controls — is derived from the
same `SkyState` the sky renders from. There is no Material light/dark switch.
When the sun sets, the ink changes with it. This is what makes the sky the
shell rather than a wallpaper.

### D3. Project layout follows eter2 where it helps

`app/` holds the Flutter project (eter2 keeps `app/` beside `server/`; a later
AI endpoint will want the same). Inside: `lib/core/<domain>` for logic,
`lib/features/<surface>` for screens. Riverpod for state. `flutter_lints` plus
eter2's three extra rules. Strings live in `core/i18n/strings.dart`, not an
ARB — the analyzer is the completeness check. Fonts are bundled, never fetched.

Copied as **patterns**, not code: the two-surface pager over one shared sky
(`eter_shell.dart`), the "night moves, day is still" motion rule (inverted
here — see §3.4), and the honesty about what a capture inventory is for.

### D4. The 3D layer is dumb — enforced by import rules, not intentions

`lib/core/sky/` may import `dart:math`, `dart:ui`, `flutter/*` and nothing
else from the project except its own files and `core/theme/tokens.dart`. No
Riverpod, no clock, no DateTime arithmetic, no health words. A `test/sky/`
architecture test greps the imports and fails the build if this drifts.

### D5. Mock state is a source, not a hard-coded value

`SkyState` is produced by a `SkyStateSource`. Phase 1 ships three:
clock-driven (real local time, fixed vitals), scrubbing (a full day in 60 s,
debug builds), and presets (named scenarios). Phase 2+ replaces the source;
the sky never learns it happened.

### D6. Typography: new pairing, not Eter's

Eter's Cormorant Garamond + Inter is Eter's voice. Illunis gets a display
serif with more optical contrast and an almanac feel — **Fraunces** (OFL,
variable, `opsz`/`WONK` axes) — paired with **IBM Plex Sans** for text and
**IBM Plex Mono** for figures (tabular by construction, and an almanac's
numbers are set in a monospace). All OFL, bundled under `assets/fonts/`.
Final choice is confirmed on device on Day 4; swapping a family touches one
file (`core/theme/typography.dart`).

---

## 1. What Phase 1 delivers

Open the app and:

1. A full-screen celestial scene — sky, atmosphere, horizon, sun, moon,
   planets, stars — renders from a `SkyState` and moves with it.
2. The scene is an instrument over a realistic sky: asymmetric composition;
   type on the horizon; hairlines and glyphs rather than cards; nothing from
   the mandate's slop list.
3. Two surfaces, Journal and Dashboard, slide over that one sky as a
   horizontal pager. Each holds a **composed placeholder** — real type and
   layout, honest empty states, zero health logic.
4. A 24-hour timeline scrubs the day and shows last night's sleep. Android
   can run the same sky as a screensaver (`DreamService` / nightstand).
5. `flutter analyze` clean, `flutter test` green. `docs/PERF.md` states the
   frame budget and that mid-range Android was not measured this window.
6. `docs/HANDOFF.md` tells the next agent how to plug a real `SkyStateSource`
   in without opening `core/sky/`.

---

## 2. Architecture

### 2.1 Repository layout

```
illunis/
  CURSOR_MANDATE.md
  PLAN.md
  README.md
  docs/
    DESIGN.md                     visual contract, as shipped
    HANDOFF.md                    how to feed the sky real data
    PERF.md                       frame budget and the hardware gap
    VISUAL_PASS_2.md              planets, timeline, resolution
    SKY_CATALOG.md                1:1 night sky: real stars at catalog V
    BACKEND_PLAN.md               brief for the next model
  app/
    shaders/sky.frag              atmosphere, sun, moon, stars, planets
    lib/
      main.dart                   `main` + `dreamMain` entrypoints
      core/sky/                   THE 3D LAYER — dumb by rule
        sky_state.dart            the interface
        celestial_math.dart       ephemeris, projection helpers
        celestial_scene.dart      SkyState → ResolvedScene
        celestial_glyphs.dart     ☉ ☽ ☿ ♀ ♂ ♃ ♄ as strokes
        sky_view.dart             ticker, easing, painters
        sky_painter.dart / sky_shader.dart / sky_overlay_painter.dart
      core/state/                 SkyStateSource, mocks, SleepRecord
      core/theme/                 tokens, typography
      core/platform/              Android host channel (dream / settings)
      features/shell/             pager, header, nightstand
      features/timeline/          24h scrubber + sleep band
      features/journal|dashboard  Phase 1 placeholders
      features/debug/             sheet, capture, frame line
    android/.../IllunisDreamService.kt
  test/sky|state|shell_smoke_test.dart
```

As-planned files that were folded, not forgotten: sun and moon live in
`sky.frag`; stars are in the same pass; Inter + JetBrains Mono replaced the
brief's Fraunces/Plex; sources and presets live in `sky_state_source.dart`.

### 2.2 The state interface

```dart
/// Everything the sky is allowed to know. All fields normalised; none are
/// health records. The layer that produces this owns the meaning; the layer
/// that renders it owns the look.
@immutable
class SkyState {
  const SkyState({
    required this.timeOfDay,      // 0..1 — fraction of the local civil day, 0 = midnight
    required this.moonPhase,      // 0..1 — 0 new, 0.5 full, 1 new again
    required this.sleepScore,     // 0..1 — last night's quality; null = no data
    required this.recovery,       // 0..1 — readiness this morning; null = no data
    required this.strain,         // 0..1 — accumulated load today; null = no data
    required this.energyBalance,  // -1..1 — deficit..surplus over the rolling window; null = no data
    this.daylightFraction = 0.5,  // 0..1 — season proxy; 0.5 = equinox
  });
}
```

Notes that are part of the contract:

- **Nullable vitals.** Absence is rendered as absence (a plain sky), never as
  a zero. This is the eter2 rule — "absence is stated, never filled" — and it
  matters here because the first three weeks of real use will have nothing.
- **No DateTime.** `timeOfDay` is a fraction. The source converts; the sky
  does not know what a Tuesday is.
- **Interpolation belongs to `SkyView`.** Sources may emit steps; the view
  eases every field with its own time constant (§3.4) so a jump in state is
  a procession, not a cut.
- The class carries `lerp`, `copyWith`, `==`, and a `debugDescribe()` that
  the debug overlay prints.

### 2.3 The scene model (pure, tested)

`CelestialScene.resolve(SkyState, Size viewport) → ResolvedScene` computes:

- Sun and moon **direction vectors** on the celestial sphere from
  `timeOfDay`, `daylightFraction` and a fixed observer latitude, then their
  projected screen positions and apparent radii through a simple camera
  (horizon at a designed, off-centre height — never the vertical middle).
- The **moon's lit fraction and terminator orientation** from `moonPhase`
  and the sun direction.
- **Atmosphere parameters**: sun altitude → sky palette keyframes (astronomical
  night → nautical → civil → golden → day), haze density, horizon glow width,
  star visibility.
- **State-driven parameters** (§3.3): clarity, warmth, stillness, weight.
- **Palette for the chrome** (`palette.dart` consumes this): ink, paper,
  accent, hairline — guaranteed to pass 4.5:1 for body text against the
  worst-case region of the sky at that moment.

All of it is unit-tested without a widget: sun at zenith at noon on equinox,
below horizon at midnight, moon full when `moonPhase == 0.5`, palette
contrast holds across a 24-h sweep at 15-minute steps and across every preset.

### 2.4 Mock sources and presets

Presets are the design's test cases as much as the code's:

| Preset | sleep | recovery | strain | energy | Sky should read as |
|---|---|---|---|---|---|
| `restedMorning` | 0.9 | 0.85 | 0.1 | 0.0 | crisp, clear, high moon fading, cool ink |
| `overreached` | 0.4 | 0.3 | 0.9 | -0.4 | hazed, hot corona, low contrast, heavy |
| `surplusWeek` | 0.7 | 0.6 | 0.3 | 0.8 | warm, full, horizon sits high |
| `deficitWeek` | 0.6 | 0.5 | 0.6 | -0.8 | thin, cool, horizon low, sparse stars |
| `noData` | null | null | null | null | plain, honest sky; time only |
| `equinoxSweep` | fixed | fixed | fixed | fixed | scrub source; the 24-h reference |

Debug builds expose a source switcher behind a long-press on the wordmark.
It is a `kDebugMode` widget subtree, not a product surface.

---

## 3. Design direction

The full contract is written into `docs/DESIGN.md` on Day 4–5 from what
actually shipped. This section is the brief the build starts from.

### 3.1 Register: the instrument (revised 6 Sep 2026)

Direction changed from "almanac/mystical" to **raw data over a realistic
sky**. The sky is a physically-based render — Preetham-family scattering,
true solar/lunar geometry for the observer, a Lommel–Seeliger moon with the
correct terminator, a sidereal star field, the galactic band — stylised only
in exposure adaptation and a 3× moon. Over it sits an instrument layer:
horizon with a compass scale, altitude circles, the day's sun and moon paths
with hour ticks, and a live ALT/AZ readout beside each body. The ground is
a dark matte field where the surfaces set their figures in a monospace.
Fonts: Inter (words) + JetBrains Mono (every figure).

Built: `app/` runs on Windows/Android/iOS, `flutter analyze` clean, 17 tests.
Review captures with `flutter run --dart-define=ILLUNIS_CAPTURE=<dir>`;
tweak live from the debug sheet (long-press the wordmark in debug builds).
Backend work is specified separately in `docs/BACKEND_PLAN.md`.

### 3.2 The forbidden list, made checkable

From the mandate, plus what the Eter audit caught. Every PR against
`features/` or `core/theme/` walks it:

- No pill or capsule buttons. Controls are text with a hairline, or a mark.
- No cards, no glass panels, no blur-behind. Surfaces are the sky.
- No rings, donuts, arcs-as-gauges, progress circles. Fulfilment is a figure
  and a sentence, or a mark on the horizon.
- No dead-centre symmetric stacks. The horizon is off-centre; the lockup is
  aligned to a margin; the sun's arc breaks symmetry by design.
- No stock icons for concepts we can draw (a sun, a moon, a mic). Code-drawn
  marks, one stroke weight, tinted from the palette.
- No raster backgrounds. The sky is computed; it must never be a JPEG.
- No `headlineMedium` slips: every `TextStyle` in the app comes from
  `typography.dart` (a test asserts the `TextTheme` is fully defined).

### 3.3 State → sky mapping (hypotheses to tune on device, Day 3)

| Input | Visual variable | Why this pairing |
|---|---|---|
| `timeOfDay` | sun/moon position, palette, star visibility | the ground truth of the metaphor |
| `moonPhase` | terminator, moon brightness | real; people will check it against the window |
| `recovery` | **clarity** — haze density, star sharpness, moon halo | recovered = you can see far |
| `strain` | **heat** — corona size, warmth of the low sky, faint shimmer near the sun | load is heat |
| `sleepScore` | **stillness** — grain amplitude, star twinkle rate, moon drift | poor sleep = a restless night sky |
| `energyBalance` | **weight** — horizon height and the ground plane's density | surplus fills the frame from below; deficit thins it |
| `null` anything | that variable at its neutral value, no marker | absence is not a low score |

Rules: each input drives one visual variable primarily. Two inputs never
fight over the same knob. Every mapping is monotonic so the sky is readable
without a legend, and every neutral value produces a sky that is simply
beautiful — an empty first day must not look like a bad day.

### 3.4 Motion

- **Procession, not animation.** The sun moves at real time by default; in a
  minute of watching, you notice it has moved. The scrub source exists so
  the whole arc can be reviewed in a minute.
- **Night moves, day rests** — the eter2 rule inverted for a sky: stars
  twinkle and grain breathes at night; in full day the only motion is the
  sun's creep and a slow atmospheric drift. This is also the battery rule.
- **State changes ease with per-field time constants**: `timeOfDay` follows
  the clock; vitals ease over ~2 s with a gentle curve; a preset switch is a
  weather change, never a cut.
- **Reduced motion** (`MediaQuery.disableAnimations`) freezes twinkle, grain
  and shimmer; the procession itself continues because it is content.
- **Lifecycle**: the ticker stops when the app is not resumed
  (`AppLifecycleListener`). A backgrounded sky costs nothing.

---

## 4. Performance budget

Target: 60 fps on mid-range Android (Impeller, Vulkan or GLES), under ~10 ms
raster per frame, no per-frame allocations in Dart above the ticker.

| Layer | Approach | Budget |
|---|---|---|
| Sky atmosphere | one full-screen fragment shader, analytic gradients + 2–3 noise taps, **no loops/raymarching**; rendered through a `Transform.scale` of a lower-resolution `CustomPaint` (0.6–0.75×) with `FilterQuality.low` | ≤ 4 ms |
| Stars | precomputed once per viewport size; `drawRawPoints` for the field, `drawAtlas` for the ~40 bright ones; twinkle via a per-frame alpha table, not per-star paints | ≤ 1 ms |
| Moon | shader on a `drawCircle` sized to the disc only | ≤ 0.5 ms |
| Sun | shader on a bounded rect around the disc + corona | ≤ 1 ms |
| Horizon + grain | one `drawRect` with a shader gradient; grain is *inside* `sky.frag`, not a second pass | ≤ 1 ms |
| Chrome | ordinary widgets inside a `RepaintBoundary`, repainted only on palette change | ~0 |

Measurement, not belief: `flutter run --profile` on `Eter_API_36` with
DevTools frame chart; `SchedulerBinding.addTimingsCallback` logged to the
debug overlay (p50/p95 raster + build). Results and the hardware they came
from go into `docs/PERF.md`. **Risk noted below: the emulator is not a
mid-range phone.**

Fallback: if `FragmentProgram.fromAsset` fails on a device, `SkyPainter`
degrades to Canvas gradients with the same palette — less atmosphere, same
composition. The app never shows a black screen because a GPU is odd.

---

## 5. Schedule — five days

Each day ends with `flutter analyze` clean and a commit. Nothing carries over
silently; what slipped is written in the day's commit message.

### Day 1 — Skeleton that already moves

- `flutter create app` (Android + iOS + Windows for desktop iteration; web
  off). Pin `sdk: ^3.x` to the installed Dart; `analysis_options.yaml` from
  eter2 (`prefer_const_constructors`, `prefer_single_quotes`, `avoid_print`).
- `SkyState`, `CelestialScene` with sun/moon arcs and the day palette
  keyframes, unit tests including the 24-h contrast sweep.
- `sky.frag` v1: altitude-driven gradient, horizon glow. `SkyView` with a
  ticker and interpolation. Sun and moon as flat discs at the right places.
- `IllunisShell`: pager with two empty pages over one `SkyView`.
- Clock source + scrub source + debug switcher. Architecture test (D4).
- **Gate:** the sky is on screen, the sun crosses it in the scrub, analyzer
  clean.

### Day 2 — The sky earns the word "premium"

- Atmosphere: Rayleigh/Mie-flavoured approximation (analytic, no loops);
  twilight bands; horizon haze; grain baked into `sky.frag`.
- `moon.frag`: sphere normal shading, terminator softness, limb darkening,
  earthshine on the dark side at night. `sun.frag`: corona and warmth that
  respond to altitude.
- Star field: hemisphere distribution rotated with `timeOfDay`, magnitude
  curve, extinction near the horizon, fade with sun altitude.
- Horizon and ground plane with the designed off-centre height.
- **Gate:** the `equinoxSweep` at dusk is something you would screenshot
  without any type on it.

### Day 3 — The sky means something

- Implement §3.3 mappings; wire the presets; tune each variable against its
  preset pair (`restedMorning` vs `overreached`, `surplusWeek` vs
  `deficitWeek`) side by side.
- Per-field easing constants; reduced-motion; lifecycle ticker.
- `palette.dart`: chrome colours derived from the resolved scene; contrast
  test across presets × 24 h.
- **Gate:** a stranger shown two presets can say which person slept badly.

### Day 4 — Type, surfaces, and the frame budget

- Bundle fonts; `typography.dart` with the full `TextTheme` and the
  completeness test.
- Shell header: wordmark lockup and the almanac line (date, rise/set from the
  scene model — no external astronomy yet), code-drawn.
- Journal placeholder: page, date heading, an honest first-day sentence, the
  writing affordance as a hairline and a mark. Dashboard placeholder: the
  day's figures set as an ephemeris table, empty when `noData`.
- Profile on the emulator; apply resolution scaling and any paint reductions;
  write `docs/PERF.md`.
- **Gate:** forbidden-list walk passes on every surface; p95 raster under
  budget on the emulator.

### Day 5 — Polish, proof, handoff

- Capture inventory: 320×568, 390×844, 430×932, 600×960 dp × text scale 1.0
  and 2.0 × {dawn, noon, dusk, night} × {noData, overreached}. Review as
  contact sheets; fix what the sheets show.
- `docs/DESIGN.md` derived from what shipped; `docs/HANDOFF.md` with the
  exact steps to add a real `SkyStateSource`.
- README updated; `flutter test` and `flutter analyze` clean; tag `phase-1`.
- **Gate:** the mandate's §5 definition of done, checked line by line.

---

## 6. Verification

Continuous:

- `flutter analyze` — zero issues, including infos.
- `flutter test` — scene math, state contract, palette contrast, source
  behaviour, architecture rule, shell smoke test (pumps the shell with each
  preset, asserts no exceptions and a defined `TextTheme`).

Manual, recorded in `docs/PERF.md` and the capture sheets:

- Profile run on `Eter_API_36`; frame timings p50/p95.
- Visual walk of the capture matrix against the forbidden list.
- Reduced-motion and text-scale 2.0 walks.

Not done in Phase 1 and said so: golden tests (the sky is time-varying and
shader output differs by GPU — pin the scene model, not pixels), physical
mid-range Android measurement (no device attached; see risks).

---

## 7. Risks

| Risk | Likelihood | Response |
|---|---|---|
| No physical mid-range Android to measure on | certain | Budget conservatively (§4), measure on the emulator, document the gap in `PERF.md`, and name a device test as the first task after the window. If a phone appears mid-week, Day 4 profiling moves onto it. |
| Fragment shader compile/runtime differences across Android GPUs | medium | Keep shaders to a conservative GLSL subset (no dynamic loops, no derivatives-dependent branching); Canvas fallback path exists from Day 1. |
| Full-screen shader too expensive at native resolution | medium | Resolution scaling designed in, not bolted on; grain lives in the same pass; stars are not a shader. |
| "Premium" drifts into generic | medium | Presets and the forbidden-list walk are gates, not suggestions; Day 2 gate is a screenshot judgement, taken honestly. |
| Scope creep into health logic during the window | medium | D4 architecture test; anything that needs a DateTime or a kcal goes in a `docs/LATER.md` note instead of the code. |
| Font pairing disappoints on device | low | One file to change; decide by end of Day 4, not Day 5. |
| Flutter 3.44 → newer SDK drift | low | Do not upgrade during the window. Revisit `flutter_scene` only after Phase 1 is tagged and measured. |

---

## 8. Later phases — orientation only

Listed so Phase 1 leaves the right seams. Phase 2 logging, the local
parser, rollups, and the pattern sweep are in the tree; Drift, wearables
and a scored food database are not.

**Phase 2 — Journal that logs.** Shipped on a JSON file store
(`AppStore`); Drift remains deferred. Text + `speech_to_text` on the
existing mic mark. Device canonical, no account. Local parser is the
record; optional AI through `server/worker.js` (eter2 transport shape)
under consent + age gate + per-entry KEEP LOCAL. Estimates land
`confirmed: false` until CONFIRM. Exercise canon and Epley/Brzycki 1RM
on device. Food table is household generics; OpenFoodFacts vs USDA waits
on ~40 real dictated meals (`docs/DECISIONS.md`).

**Phase 3 — Wearables.** Health Connect / HealthKit through the `health`
package, background sync, per-type permissions as the only gate. Known
native-bridge pain; scheduled for opencode after the Cursor window, as the
mandate says. The `SkyStateSource` for real data is written here:
`sleepScore`, `recovery`, `strain` from daily rollups, never from raw
minutes. The journal already feeds `LocalSkyStateSource` from rollups;
this phase replaces unknown vitals with wearable ones.

**Phase 4 — Patterns.** Sweep is in (`minimumPairs = 21`, effect-size
floor, Benjamini–Hochberg). The dashboard tells the truth that nothing
can be said before roughly day 21. Gate intelligence, never the record.

**True night sky (parallel, `core/sky`).** Landed as HYG v3 catalog points
(`V ≤ 6.0`) on the existing sidereal angle; the shader hash is gone. At
night the camera faces south, or a risen lit moon, so the catalog is in
the window. Manual Stellarium/window check and optional precession remain.
Spec: `docs/SKY_CATALOG.md`.

**Throughout.** Health data is sensitive: on-device is canonical, cloud is an
optional mirror under separate consent, model output is never mirrored, and
the Play Store health declarations are drafted when Phase 3 starts, not when
it ships. Anti-goals stand: no social, no auto-generated plans, no
marketplace.

---

## 9. Definition of done — Phase 1

Straight from the mandate, made checkable:

- [x] Open the app → the sun/moon procession fills the screen and is
      unmistakably designed; the dusk frame is screenshot-worthy without type.
- [x] The scene moves with mock state: scrub sweeps a day; presets are
      distinguishable by a stranger.
- [x] `docs/PERF.md` states the budget, how to measure, and the gap to
      real hardware. `Eter_API_36` and a physical phone were not attached;
      p95 on mid-range Android is the first task after this window.
- [x] `flutter analyze` clean; `flutter test` green; architecture test passes.
- [x] Forbidden-list walk on the visual-pass-2 capture matrix (phone window,
      1.0 text). Text scale 2.0 was not recaptured this window.
- [x] `docs/HANDOFF.md` lets a second agent add a real `SkyStateSource`
      without touching `core/sky/`.
- [x] Tagged `phase-1`.
