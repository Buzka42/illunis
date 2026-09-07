# Illunis — True night sky

The person should be able to look from the phone to the window and see the
same stars, at the same brightness. This file is the spec for what shipped
and what is still deferred.

## What is true today

- **Sun and naked-eye planets** use an ephemeris (Schlyter mean elements)
  from `SkyState.epochDays`. Accuracy ~1°.
- **Moon** is still phase-driven on the ecliptic. A real lunar theory is a
  separate later item (`docs/VISUAL_PASS_2.md` §3).
- **Stars** are the HYG v3 catalog, `V ≤ 6.0` (~5,070), drawn as Canvas
  points from J2000 RA/Dec at catalog V. Sidereal rotation is the same
  angle the planets use. The hashed field in `sky.frag` is gone.
- **Milky Way** is a procedural band around a real galactic pole vector, not
  a photograph.
- **Observer.** Home latitude and longitude on the profile. No GPS.
- **Night look.** By day the camera still follows the sun. At night it
  follows a risen, lit moon; otherwise it faces south so the catalog is
  in the window, not the azimuth of a sun that has already set.

## Goal

At the current civil time, from the chosen home, the night sky shows the
stars that are actually above the horizon, each drawn from its catalog
visual magnitude. Orion in January at 21:00 in Warsaw is Orion. Sirius is
the brightest star. Polaris sits on the pole.

Stylisation that stays: exposure adaptation, a ~3× moon, grain, a little
twinkle. Stylisation that goes: invented star positions and invented
brightness.

## Catalog

- **Source.** Yale Bright Star Catalog (BSC5) or the HYG subset of Hipparcos
  + Yale. Public domain / attribution as the chosen file requires. Bundled
  in the app; never fetched at runtime.
- **Epoch.** J2000.0 right ascension and declination. Visual magnitude `V`.
  Optional B−V for tint (blue-white → orange).
- **Limit.** Draw every star with `V ≤ 6.0` (~5,000, naked-eye). Keep the
  rest of the file for a later fainter pass if the budget allows, but do not
  draw below 6.0 in v1 — that is binocular sky, and it fights the instrument.
- **Generate, do not hand-type.** A small script (`tool/stars/` or similar)
  reads the source and writes a compact Dart or binary table
  (`app/lib/core/sky/star_catalog.g.dart`). The table is RA, Dec, V, B−V.
  Named stars (Sirius, Polaris, …) may carry a Bayer/proper name for tests
  and a later label pass; v1 does **not** draw names. The sky is a window,
  not a chart.
- **Precession.** ~0.4° from J2000 to 2026. Ship J2000 first. If a
  Stellarium check at the home city is off by more than half a degree on
  a bright star, apply IAU 1976 precession from `epochDays`. Aberration and
  refraction are out of v1 except the horizon extinction already used for
  planets.

## Rendering

Stars return to **points**, as `PLAN.md` §4 originally budgeted, instead of
a per-pixel hash.

- Resolve equatorial → horizontal with the existing sidereal angle and
  latitude in `CelestialScene` (same frame as the planets).
- Project with `SkyCamera`. Drop anything below the horizon and anything
  extinguished by twilight (same ramp as today's `starVis`).
- Size and flux from Pogson: `flux ∝ 10^(-0.4 (V - V0))`. A mag-0 star is
  a small core; mag 6 is almost a grain. Horizon extinction matches planets.
- Paint with `drawRawPoints` (field) and a slightly larger core for the
  brightest ~40. Twinkle is a per-frame alpha table, not per-star `Paint`
  objects. Budget: **≤ 1 ms**, same as §4.
- **Remove** (or dim to dust fainter than the catalog cutoff) the hash
  `stars()` in `sky.frag`. Two fields on top of each other would double
  Sirius and invent neighbours. The procedural galaxy band may stay, aligned
  to the same galactic pole, until a texture is justified.
- `core/sky/` stays dumb: the catalog is data, the math is RA/Dec →
  direction, the painter draws points. No `DateTime`, no Riverpod, no
  health words.

## Observer and clock

Already in place:

- `timeOfDay` is the civil clock.
- `latitudeDeg` from the home place.
- `solarNoon` already carries longitude / zone / equation of time, and
  sidereal time is derived from the solar hour angle plus the sun's RA.

The catalog pass must **not** invent a second clock. If Stellarium and the
app disagree on hour angle, fix `civilSolarNoon` / sidereal once; both the
planets and the stars will move together.

## Tests (no goldens)

Pin the scene model, not pixels:

- Sirius (α CMa) is the brightest catalog star drawn.
- Polaris declination is within 1° of the north celestial pole.
- A winter evening at 52°N (e.g. 6 Jan 21:00, Warsaw) has Orion's belt
  above the southern horizon; a June evening at the same place does not.
- No catalog star is projected below the horizon.
- Sidereal rotation still matches the existing `celestial_scene_test`
  (solar vs sidereal day).
- Architecture test still forbids `DateTime.now` and health imports in
  `core/sky/`.

Manual: one night, home city, face south, compare to Stellarium (or the
window) at the same time. The bright pattern must be the same. That check
is the gate, not a screenshot of a hashed field.

## What 1:1 does not mean (v1)

- Cloud, weather, or a light-pollution map.
- Satellites, ISS, aircraft.
- Star names and constellation lines on the instrument (a later optional
  overlay, off by default).
- A real lunar theory (already deferred).
- Photometric colour beyond a B−V tint.
- GPS. Home city is the observer.

## Order of work

1. [x] Pick the catalog file and write the generator; commit the generated table.
2. [x] Resolve + project + tests for Sirius / Polaris / Orion season.
3. [x] Canvas point field; kill or demote shader hash stars.
4. [x] Magnitude curve and twilight/horizon extinction on device.
5. [ ] Stellarium/window check at the default home; precession only if needed.
6. [ ] Frame timings into `docs/PERF.md`. If p95 misses, drop the faint cutoff
   from 6.0 to 5.5 before shrinking cores.

Do not restyle the instrument layer while doing this. The sky gets true
stars; the hairlines stay as they are.
