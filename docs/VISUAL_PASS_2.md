# Illunis — Visual Pass 2

Brief from review of Phase 1 (6 Sep 2026): the look is right; make the sky
higher-resolution, the instrument lines subtler, add the other visible
celestial bodies with their standard symbols, and add a timeline that scrubs
the day and shows last night's sleep. This file is the plan; the checkboxes
are the state of the work.

## 1. Resolution

- [x] Raise the shaded-pixel budget from ~1.15 MP to ~2.4 MP
      (`SkyView.shadePixelBudget`). A 1080×2400 phone now renders the sky at
      ~0.96× instead of 0.66×; desktop and tablets at 1.0×. Minimum scale
      0.6 so a 1440p phone still gets ≥ 0.75×.
- [x] Upscale with `FilterQuality.high` when the scale is below 1 (cubic;
      cheaper than the pixels it saves).
- [x] Star and planet cores are sized in *target* pixels so they stay
      sub-2px points rather than soft blobs after upscaling.
- [ ] Measure on Android before shipping the budget; if p95 raster exceeds
      the frame, the budget is the one number to lower (`docs/PERF.md`).

## 2. Lines

Everything in the instrument layer drops roughly one weight and one step of
alpha; the sky is the subject, the annotation is the caption.

| Element | Before | After |
|---|---|---|
| Horizon | 1 px · α .38 | 1 px · α .26 |
| Compass ticks | α .55 | α .32 (labels α .38, cardinals α .7) |
| Altitude circles | .75 px · α .10 | .5 px · α .055, labels α .22 |
| Sun path | 1 px · α .62 | .75 px · α .38, ticks α .38, dots α .09 |
| Moon path | 1 px · α .42 | .75 px · α .24 |
| Body ring + leader | 1 px · α .70 | .75 px · α .5 |
| Readout type | α .95 / .72 | α .85 / .6 |

## 3. Celestial bodies

- [x] **Ephemeris.** Keplerian mean elements + rates (Schlyter) for Mercury,
      Venus, Mars, Jupiter, Saturn, and the Sun's own longitude from the same
      model; heliocentric → geocentric → equatorial → horizontal. Accuracy
      ~1° for the epoch ±50 y, which the eye cannot fault at this scale.
      `SkyState` gains `epochDays` (days since J2000.0 at local midnight);
      `dayOfYear` stays for the almanac line. Still no `DateTime` in
      `core/sky/`.
- [x] **Rendering.** Each planet is a point of light in the shader with its
      own tint (Mars rust, Venus white, Jupiter cream, Saturn pale straw,
      Mercury grey) and a brightness that follows a rough visual magnitude
      (Venus −4, Jupiter −2, Mars/Saturn/Mercury ~ +0.5…+1). Points fade
      with sky luminance like stars and are extinguished near the horizon.
- [x] **Symbols.** The standard astronomical glyphs — ☉ ☽ ☿ ♀ ♂ ♃ ♄ — drawn
      as vector paths in `core/sky/celestial_glyphs.dart`, one stroke weight,
      tinted from the instrument ink. No font, no bitmap: they are crisp at
      any density and they match the ring-and-hairline vocabulary exactly.
      The Sun and Moon readouts lead with their glyph; each planet above the
      horizon gets its glyph beside the point with a name label and ALT.
- [x] **Visibility rule.** A planet's glyph appears when it is above the
      horizon and the sky is dark enough for its magnitude (Venus and
      Jupiter from civil twilight, the rest from nautical). Its point in the
      shader follows the same rule so the annotation never points at nothing.
- [ ] Later: the Moon from a real lunar theory instead of the phase-driven
      ecliptic placement (Schlyter's perturbation series is ~2° and cheap).
      Needs `moonPhase` to become an output rather than an input; deferred
      because the debug slider relies on it.

## 4. Timeline

A 24-hour scrubber on the ground band, directly under the compass scale,
present on both surfaces.

- [x] **Track.** Hairline across the width; hour ticks, taller at 00/06/12/18
      with labels; the daylight span between sunrise and sunset drawn as a
      brighter segment with soft twilight ends, so the bar is itself a
      picture of the day.
- [x] **Sleep.** Last night's sleep as a band above the track, split across
      midnight when it wraps. Phases, when known, are adjacent segments:
      deep tallest and brightest, light mid, REM mid with the cool tint,
      awake a gap. A `SLEEP 7h 36m` label at the band's start. Mock data via
      `sleepRecordProvider`; `noData` preset shows no band.
- [x] **Playhead.** A live marker at the current time. Dragging anywhere on
      the bar scrubs `timeOfDay` through the same overrides the debug sheet
      uses, so the sky, readouts, header clock and paths all follow. A time
      label rides above the playhead while scrubbing. `LIVE` appears at the
      right while scrubbing; tapping it returns to the clock.
- [x] **Layout.** Horizon moves from 0.60 to 0.56 of the height to make room;
      surfaces lose most of their top padding because the timeline now
      separates them from the sky.
- [ ] Later: a second row of markers for logged events (workouts, meals)
      once the journal writes them — same vocabulary, one tick per entry.

## 5. Verification

- `flutter analyze` clean, `flutter test` green (new: planet elongation
  bounds, epoch conversion, sleep-band midnight split).
- Capture matrix with `--dart-define=ILLUNIS_CAPTURE` reviewed as a contact
  sheet: dawn with Venus, dusk with Jupiter/Saturn, night, noon.
