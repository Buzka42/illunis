# Illunis — Performance budget

Target: 60 fps on mid-range Android (Impeller). One number to lower if a
device cannot hold the frame: `SkyView.shadePixelBudget` (currently 2.4e6
device pixels of shader work per frame).

## What actually runs per frame

| Layer | What | Bound |
|---|---|---|
| Atmosphere, sun, moon, stars, planets, grain | one fragment program, `shaders/sky.frag` | shade budget above |
| Instrument (horizon, paths, glyphs, readouts) | `SkyOverlayPainter` in the same `CustomPaint`, full resolution | cheap; cached `TextPainter`s |
| Chrome (header, surfaces, timeline) | widgets; timeline is its own painter | repaints on scrub / 1 Hz clock |

Resolution: if the view × DPR is under the budget, the shader writes
straight into the layer at 1:1. Above it, the picture is recorded at
`scale ∈ [0.6, 1]` and upscaled with `FilterQuality.high`. Star and planet
cores are sized in *target* pixels (`uPixelScale`) so they stay points
after the upscale.

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
| Physical mid-range Android | — | — | — | None attached. First task after the window. |

The gap to the mandate's "60 fps on mid-range Android" is that it has not
been measured on that class of hardware. Conservative choices already in
the code: shade budget, scale floor 0.6, ticker paused off-screen, one
shader pass. If p95 raster exceeds ~10 ms on a phone, lower
`SkyView.shadePixelBudget` before changing anything else.

Nightstand (`DreamService`) is a second Flutter engine. Expect similar
raster cost plus ~40–80 MB RAM. It only runs while the screensaver is
visible (typically charging / docked).
