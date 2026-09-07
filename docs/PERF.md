# Illunis — Performance budget

Target: 60 fps on mid-range Android (Impeller). One number to lower if a
device cannot hold the frame: `SkyView.shadePixelBudget` (currently 2.4e6
device pixels of shader work per frame).

## What actually runs per frame

| Layer | What | Bound |
|---|---|---|
| Atmosphere, sun, moon, grain, galactic band | one fragment program, `shaders/sky.frag` | shade budget above |
| Catalog stars (`V ≤ 6.0`, ~5,070) | Canvas points after the shader blit, native resolution | ≤ 1 ms; drop cutoff 6.0 → 5.5 before shrinking cores |
| Instrument (horizon, paths, glyphs, readouts) | `SkyOverlayPainter` in the same `CustomPaint`, full resolution | cheap; cached `TextPainter`s |
| Chrome (header, surfaces, timeline) | widgets; timeline is its own painter | repaints on scrub / 1 Hz clock |

Resolution: if the view × DPR is under the budget, the shader writes
straight into the layer at 1:1. Above it, the picture is recorded at
`scale ∈ [0.6, 1]` and upscaled with `FilterQuality.high`. Shader planet
cores are sized in *target* pixels (`uPixelScale`) so they stay points
after the upscale. Catalog stars are painted after the blit, so they stay
sharp at native resolution.

The ticker lives in `SkyView`. It stops in `paused` / `hidden`; it keeps
going in `inactive` (unfocused desktop window) and while a DreamService
holds the engine in `resumed`.

No per-body `CustomPaint` widgets; no second shader pass; Canvas fallback
if `FragmentProgram.fromAsset` fails (`SkyPainter._paintFallback`).

## Measurement

How to take it:

1. Debug build, long-press `ILLUNIS`. The sheet's `FRAME` line is
   p50/p95 raster and build in milliseconds over the last ~180 frames.
2. For a profile run: `flutter run --profile -d <device>`, DevTools
   Performance, raster thread.

Taken:

| Device | Build | p50 raster | p95 raster | Notes |
|---|---|---|---|---|
| Windows desktop, 430×932 window | debug | not logged | not logged | Capture sequences (10 frames across a day) completed without dropped-shader fallback; the window is vsynced. Debug is not the budget. |
| `Eter_API_36` emulator | — | — | — | Not attached during this window. |
| ZTE Blade V 5G (`20240920122`), 1080×2412, Impeller Vulkan | debug | ~3.6 ms idle; ~14.7 ms on first frames | ~3.9 ms idle; ~15.4 ms on first frames / pager | Mid-range Android, home city 52.23°N. Idle raster is under 16.6 ms. Debug build/p95 spikes are JIT, not the 60 fps budget. Catalog cutoff stays 6.0 until a **profile** run is over ~10 ms raster p95. |

The gap to the mandate's "60 fps on mid-range Android" is a **profile**
measurement, not the debug numbers above. Conservative choices already in
the code: shade budget, scale floor 0.6, ticker paused off-screen, one
shader pass. Catalog stars are Canvas after that pass. If p95 raster exceeds ~10 ms on a phone, lower
`SkyView.shadePixelBudget` before changing anything else; if the catalog
is the miss, drop the faint cutoff from 6.0 to 5.5 before shrinking cores.

Nightstand (`DreamService`) is a second Flutter engine. Expect similar
raster cost plus ~40–80 MB RAM. It only runs while the screensaver is
visible (typically charging / docked).
