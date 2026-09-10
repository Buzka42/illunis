# Illunis — True night sky

Current through Astra A–C, 2026-09-09. See [ASTRA_HANDOFF.md](ASTRA_HANDOFF.md)
for independent reference results and [PERF.md](PERF.md) for measured cost.

## Geometry and appearance

The Sun and five naked-eye planets use epoch-based orbital geometry. Planets
retain low-precision elements and approximate magnitudes. The Moon now uses
an inclined eccentric orbit with principal perturbations and topocentric
parallax; phase/terminator is resolved against the Sun direction. An explicit
phase override remains available for debug review. Warsaw Sun/Moon alt/az
errors at sampled times on five 2026 dates are below 0.13°, and solar rise/set
errors below one minute against JPL Horizons. This does not certify all dates
or independently validate planet and bright-star residuals.

Stars use the bundled HYG v3 catalog, V ≤ 6.0 (5,070 entries), J2000 RA/Dec,
visual magnitude and B−V tint. No shader hash field doubles the catalog.
Sidereal orientation shares the Sun/planet frame, with transit-anchored solar
RA and sidereal rotation rate. The observer remains Settings home; no GPS.
At night the camera follows a risen, lit Moon or otherwise faces south.

The Milky Way is procedural around the real galactic pole. Exposure, grain,
twinkle and the roughly 3× lunar disk are intentional stylizations; lunar
texture is procedural; clouds now sample generated stratus/cumulus/cirrus density assets. Weather is implemented as state-driven
simulation, not a current observation or a light-pollution map.

## Catalog generation and rendering

`tool/stars/generate.py` writes `app/lib/core/sky/star_catalog.dart`: immutable
numeric data, no runtime fetch or decoding imports in the renderer. Regeneration
preserves the source float32 values and 20 name indices. The HYG fallback RA
column is in hours, while rarad is already radians. Attribution/source details
are included with the generator and generated data.

Magnitude starts from Pogson flux, 10^(-0.4 ΔV), with a perceptual display
response. Faint stars use 24 logarithmic opacity bins × two tints via Canvas
`drawPoints`; bright stars have separate cores. Altitude/turbidity air-mass
extinction, twilight, lunar glare and bounded twinkle modify visibility.
Catalog-only trigonometry and intensity are cached; each frame rotates their equatorial bases directly. All points are native resolution and render after the atmosphere shader.
Weather then occludes them before the instrument is painted. No half-resolution
composite is used. See PERF for total frame costs; an isolated ≤1 ms catalog
budget on the Blade has not been measured for this revision.

The sky seam only imports dart:math, dart:ui, Flutter, its own files and theme
tokens. Catalog data, geometry and drawing know nothing about providers,
health records or network sources.

## Observer and clock

`timeOfDay` is a civil clock fraction. `epochDays` supplies its UTC-consistent
midnight basis, and `solarNoon` encodes longitude/zone/equation of time. The
source uses the offset at the represented instant to preserve UTC across DST.
The equation-of-time sign is corrected. Scrubbing moves orbital phase and
solar noon together unless an explicit phase override is selected.

## Verification

Geometry tests cover Sirius, Polaris, seasonal Orion visibility, horizon
projection and sidereal rotation. Additional tests pin magnitude response,
air-mass extinction and immutable catalog data. Independent offline JPL
fixtures check Sun/Moon geometry, illumination and solar events. Production
shader pixel tests exercise weather occlusion/fog; three golden galleries
cover clear/twilight, weather and Moon/overcast. The recursive architecture
test enforces the seam. Full A–C suite: 142 passing tests.

The J2000 catalog is not precessed. Its ~0.4° epoch difference in 2026 remains
a known approximation; a bright-star Stellarium/window comparison at home is
still outstanding. No >0.5° bright-star residual was established in this pass,
so precession was not added. Aberration and positional atmospheric refraction
remain deferred; solar event times use the conventional horizon allowance.

## Still deferred

- Real meteorological source and freshness policy; light-pollution data.
- Satellites, ISS and aircraft.
- Optional constellation/name overlays.
- Photometric colour beyond B−V tint and the display response.
- Bright-star window comparison and device-driven precession decision.
- Physical-panel banding judgment, interactive stress and battery endurance. Final fixed-scene Blade Vulkan p95 fits 16.7 ms; see PERF.md.

The existing instrument geometry and hairline voice remain. This pass improves
sky fidelity and occlusion while preserving the shared surface layout.
