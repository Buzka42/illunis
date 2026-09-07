# Illunis — Design contract

Derived from what shipped in Phase 1, not from the original brief. If the
code and this file disagree, the code is right and this file is updated.

## Register

Raw data over a realistic sky. The sky is a physically-based render
(Preetham-family Rayleigh/Mie scattering, true solar geometry, a
Lommel–Seeliger moon, catalog stars at visual magnitude, a galactic band, five
naked-eye planets). Stylised only in exposure adaptation and a ~3× moon. Over it sits
an instrument layer: hairlines, a compass scale, altitude circles, the day's
sun and moon paths, astronomical glyphs, ALT/AZ. The ground is a dark matte
field where the surfaces set figures in monospace.

Nothing from the forbidden list: no pills, cards, glass, rings, centred
stacks, stock icons, raster skies, or type that does not come from
`typography.dart`.

## Geometry

- Horizon at `kHorizonFraction` = 0.56 of the height. Off-centre on purpose.
- Compass band 22 px under the horizon, then the 48 px timeline, then the
  surfaces.
- Camera: stereographic, conformal, same projection the shader inverts.
- Nightstand (`DreamShell`) keeps this geometry and leaves the ground almost
  empty: large clock, twilight word, last night's sleep.

## Type

Two families, both bundled:

- **Inter** — words (`ILLUNIS`, JOURNAL, body).
- **JetBrains Mono** — every figure, label, bearing, time. Tabular.

Scale (see `Type` in `core/theme/typography.dart`):

| Slot | Size | Face | Use |
|---|---|---|---|
| `wordmark` | 11 | Inter 600, tracked | ILLUNIS |
| `label` | 9.5 | Mono 500, tracked | SLEEP, SUNSET |
| `micro` | 10 | Mono 400 | units, footer |
| `figure` | 17 | Mono 400 | table values |
| `figureLarge` | 40 | Mono 300 | nightstand clock |
| `clock` | 12 | Mono 400 | header |

Ink (`Inks`): paper `#EEF1F6` at stepped alphas (full / strong / body /
muted / faint / hairline). Warm `#F2C99A` for the live playhead. Cool
`#B9C6E0` for REM and the moon. Negative `#E8A39A` when a vital is in the
bad range. Sky-band overlay ink lerps paper → slate `#1B2433` once the sun
is well up; the ground band is always paper.

## Instrument weights

Caption, not subject. Current values (visual pass 2):

- Horizon 1 px · α 0.26, always light ink
- Compass ticks α 0.32, labels α 0.38, cardinals α 0.7
- Altitude circles 0.5 px · α 0.055, labels α 0.22
- Sun path 0.75 px · α 0.38; moon path α 0.24
- Body ring 0.75 px · α 0.5; readout type α 0.85 / 0.6

Glyphs ☉ ☽ ☿ ♀ ♂ ♃ ♄ are vector paths in `celestial_glyphs.dart`, one stroke,
the same ink as the rings.

## Motion

- `timeOfDay` eases at τ ≈ 0.22 s; vitals at τ ≈ 1.4 s; camera bearing at
  τ ≈ 1.6 s. A preset switch is weather, not a cut.
- Night: grain and star twinkle. Day: the sun's creep only.
- `MediaQuery.disableAnimations` freezes grain and twinkle; the procession
  continues because it is content.
- Nightstand: ±3 px drift over 180 s against OLED burn-in.
- Reduced-motion and the ticker-pause-on-background are battery rules.

## Surfaces

Two pages over one sky. The pager's offset yaws the camera ~8°. Journal is
an empty writing surface. Dashboard is a table: sleep, recovery, strain,
energy, then sun/moon rise and set. Mock data is labelled `MOCK DATA`.
Absence is labelled `NO DATA` and looks like a plain sky.

The timeline is the day as a picture: daylight span, hour ticks, sleep
stages (deep / light / REM / awake), a playhead. Dragging scrubs the same
override the debug sheet uses. `LIVE` returns to the clock.

## Nightstand

The Android screensaver is the sky without the pager. Close finishes the
dream. Preview from the debug sheet on any platform. Set as screensaver
from the same sheet on Android (`Settings.ACTION_DREAM_SETTINGS`).
