# Illunis — Performance budget

Final A–C profile, 2026-09-10. All 17 fixed scenes fit the 16.7 ms steady-state
frame budget on the Blade V 5G, native 1080×2412, DPR 3, Impeller Vulkan.
Maximum raster p95 was 11.057 ms; maximum build p95 was 8.069 ms. This is a
short scene benchmark, not a sustained battery/thermal or all-interactions
certification. First-use stalls remain, reported separately below.

## Pipeline and costs

- Native-resolution `sky.frag` plus Canvas catalog; no intermediate image,
  downsample, upscale, background readback or fullscreen blur.
- Null/clear weather skips its pass. Other weather adds one premultiplied
  native shader pass after the catalog and before instrument ink. At exactly
  full coverage, hidden atmosphere/catalog work is skipped above the horizon;
  ground illumination is retained.
- Three generated 1254×1254 cloud density textures replace expensive procedural
  cloud noise. Stratus/cumulus blend through `cumulus`, high clouds through
  `cirrus`. Exact 0/1 endpoints skip unused samples. Rain/snow each use two
  sparse depth layers. Coverage/occlusion survives quiet precipitation.
- Texture PNGs total 6,564,725 bytes; decoded RGBA is approximately 18.0 MiB
  per engine, excluding GPU copies/driver overhead. Programs and textures load
  once per engine. Each view reuses and disposes its own shader instances.
- Catalog magnitude response and equatorial bases are cached. Direct matrix
  rotation avoids spherical trig round trips per star. Faint points remain
  bounded to 24 logarithmic alpha bins × two tints; no stars were removed.
- Unchanged scenes are reused, avoiding figure rebuilds for decorative twinkle.
  Equivalent atmosphere powers use multiplication/square roots; invisible
  solar disks, zero-strength scattering and negligible off-band galactic noise
  skip work. No resolution or clear-sky fidelity reduction was used.
- Sky ticker stops in hidden/paused, continues inactive, and freezes decorative
  time for reduced motion. Nightstand's ±3 px/180 s drift follows the same
  lifecycle/reduced-motion rules. Actual long-duration DreamService memory and
  battery have not been measured.

If future devices miss budget, preserve native sky fidelity and cloud
coverage, reducing precipitation/detail first. No adaptive quality controller
is claimed. Asset/shader load failure uses simplified Canvas sky/cloud/fog;
precipitation is unavailable in that fallback.

## Blade V 5G — final profile

Serial 20240920122; reported physical size 1080×2412 and density 480 dpi.
Production shaders/widgets, fixed Warsaw source and in-memory record. Each
final sample spans four seconds; 235–362 frames were recorded. Refresh rate
can exceed 60 Hz. All listed raster and build p95 values are below 16.7 ms.

| Scene | Raster p50 ms | Raster p95 ms | Build p95 ms | Warmup raster max ms |
|---|---:|---:|---:|---:|
| clear_noon | 10.698 | 11.057 | 5.158 | 656.491 |
| golden_set | 2.223 | 2.65 | 5.237 | 13.282 |
| civil_twilight | 7.947 | 9.389 | 4.641 | 29.1 |
| nautical_twilight | 2.419 | 3.503 | 7.39 | 16.231 |
| astronomical_twilight | 3.303 | 4.874 | 7.827 | 15.145 |
| night_moon | 3.601 | 5.285 | 7.818 | 21.226 |
| weather_cloudy | 3.182 | 3.375 | 6.262 | 21.132 |
| weather_cirrus | 3.22 | 6.62 | 6.233 | 20.042 |
| weather_overcast | 3.194 | 3.688 | 6.278 | 21.568 |
| weather_rain | 3.167 | 3.954 | 6.18 | 21.52 |
| weather_fog | 3.182 | 3.503 | 6.22 | 20.441 |
| weather_snow | 3.205 | 4.049 | 6.172 | 21.228 |
| overcast_night | 3.207 | 3.47 | 6.288 | 21.629 |
| dashboard | 4.193 | 5.684 | 6.375 | 18.635 |
| journal | 4.152 | 4.809 | 6.276 | 20.468 |
| dashboard_rain | 4.236 | 4.621 | 6.323 | 13.3 |
| nightstand | 4.338 | 7.21 | 8.069 | 12.391 |

Exact values/states: [Blade JSON](verification/astra-blade-profile.json).
Before optimization the same device reached 25.981 ms raster p95 under
overcast night. After the initial texture pass, astronomical twilight still
reached 18.175 ms. Equivalent atmosphere simplifications brought the final
sample to 4.874 ms. See the [earlier baseline](verification/astra-blade-before-optimization.json)
and [initial texture run](verification/astra-blade-texture-initial.json).
These are sequential runs, not a controlled thermal A/B experiment.

## Windows — final profile

430×932 outer window; render/capture 414×893, DPR 1. Maximum raster p95
2.315 ms; maximum build p95 2.900 ms. Same 17 fixed scene definitions.

| Scene | Raster p50 ms | Raster p95 ms | Build p95 ms |
|---|---:|---:|---:|
| clear_noon | 0.995 | 1.22 | 2.396 |
| golden_set | 0.821 | 0.941 | 2.057 |
| civil_twilight | 0.837 | 1.104 | 2.433 |
| nautical_twilight | 1.352 | 1.59 | 2.586 |
| astronomical_twilight | 1.529 | 1.743 | 2.74 |
| night_moon | 1.636 | 1.907 | 2.83 |
| weather_cloudy | 1.131 | 1.42 | 2.828 |
| weather_cirrus | 1.169 | 1.435 | 2.32 |
| weather_overcast | 1.131 | 1.364 | 2.273 |
| weather_rain | 1.145 | 1.38 | 2.271 |
| weather_fog | 1.176 | 1.403 | 2.279 |
| weather_snow | 1.162 | 1.388 | 2.3 |
| overcast_night | 1.338 | 1.625 | 2.308 |
| dashboard | 1.442 | 1.772 | 2.292 |
| journal | 1.748 | 2.229 | 2.363 |
| dashboard_rain | 1.751 | 2.076 | 2.386 |
| nightstand | 1.893 | 2.315 | 2.9 |

Exact values/states: [Windows JSON](verification/astra-windows-profile.json).
These are whole-frame timings, not isolated incremental weather costs.

## Startup, method and limits

**First-use latency remains visible.** Final warmup raster maxima were
656.491 ms on the Blade and 1354.822 ms on Windows; Windows first overcast
also reached 968.773 ms. They coincide with initial shader/texture use.
These runs do not isolate compilation, upload and driver startup costs.
Settled p95 values must not be interpreted as a stall-free startup promise.

The harness waits two seconds (an extra two when selecting Journal), then
samples four seconds. It retries up to three samples if fewer than 120 frames
arrive or a raster frame exceeds 100 ms. Discarded/warmup frames are retained
as a separate maximum. The first locked-phone attempt had no frames and was
discarded; every published final scene has a valid nonempty sample. The JSON
contains only the final samples, not a full chronological frame trace.

Native PNGs were inspected for clear gradients, twilight, cloud detail,
occlusion, readout legibility and surfaces. PNG inspection cannot certify the
physical panel's banding response. Interactive pager/scrub stress, actual
DreamService operation, thermal endurance, battery, Chrome, and a repeat
startup trace remain outside this short capture benchmark. Reduced motion and
background behavior have automated widget coverage.

## Reproduce

From `app`:

```powershell
flutter run --profile -d windows -t tool/astra_capture.dart --dart-define=ASTRA_CAPTURE_DIR=C:/Users/Arawn/Documents/illunis/captures/v3/windows
flutter run --profile -d 20240920122 -t tool/astra_capture.dart --dart-define=ASTRA_CAPTURE_DIR=/sdcard/Android/data/com.illunis.illunis/files/astra-v3
```

Keep the phone unlocked and Illunis visible. The harness uses an in-memory
store and is not imported by product entrypoints; it refuses release mode.
Restore the normal app after capture with `flutter build apk --debug` and
`adb -s 20240920122 install -r build/app/outputs/flutter-apk/app-debug.apk`
(from `app`). The normal build was restored successfully after this run.

For interactive profiling use `flutter run --profile -d <device>` and
DevTools. Debug sheet counters are not a release benchmark. See
[Flutter performance guidance](https://docs.flutter.dev/perf/ui-performance)
and [fragment shader support](https://docs.flutter.dev/ui/design/graphics/fragment-shaders).

Historical pre-A–C Blade debug readings (~3.6/3.9 ms idle p50/p95) used the
removed resolution-budget path and are not evidence for the current revision.
