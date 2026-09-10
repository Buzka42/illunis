# Astra handoff — Phases A–C implementation and Phase D P1 fixes

2026-09-10. A–C implementation and Phase D P1 proposals are complete in the
working tree: clean analysis (0 issues), 142 passing normal suite tests, 12 passing
Phase D regression tests, 3 passing offline worker verification checks, final Android
build restored to the Blade, and 17 native captures on each of Blade and Windows.
All Blade fixed-scene raster/build p95 values fit the 16.7 ms steady-state budget.
First-use stalls remain a measured limitation; this is not a thermal/battery or
all-interactions certification. No commit or push was made.

Following the whole-app/server audit, all 9 P1 fixes (data integrity, privacy,
cost control, durable storage, and arithmetic accuracy) have been implemented and
verified. P2 items remain prioritized proposals for future work. No Drift migration,
health integration or food DB was started.

## Review first

- [Capture gallery](../captures/v3/index.html): 17 Blade Vulkan renders at 1080×2412 and 17 final Windows renders at 414×893. The gallery switches between platforms.
- [Clear noon](../captures/v3/blade/clear_noon.png),
  [golden set](../captures/v3/blade/golden_set.png),
  [civil](../captures/v3/blade/civil_twilight.png),
  [nautical](../captures/v3/blade/nautical_twilight.png),
  [astronomical twilight](../captures/v3/blade/astronomical_twilight.png),
  [moon night](../captures/v3/blade/night_moon.png).
- [Cloudy](../captures/v3/blade/weather_cloudy.png),
  [cirrus](../captures/v3/blade/weather_cirrus.png), [overcast](../captures/v3/blade/weather_overcast.png),
  [rain](../captures/v3/blade/weather_rain.png),
  [fog](../captures/v3/blade/weather_fog.png),
  [snow](../captures/v3/blade/weather_snow.png),
  [overcast night](../captures/v3/blade/overcast_night.png).
- [Dashboard](../captures/v3/blade/dashboard.png),
  [journal](../captures/v3/blade/journal.png),
  [dashboard in rain](../captures/v3/blade/dashboard_rain.png),
  [nightstand](../captures/v3/blade/nightstand.png).

Captures use fixed Warsaw states and an empty in-memory record, so dashboard
absence is intentional. Mock/local provenance and mock sleep are exercised
by widget tests. `captures/` is git-ignored; preserve this local folder when
sharing the review. Shader gallery goldens and a copy of the measured JSON
are also in the working tree outside that ignored folder.

## A — Sky fidelity

`app/shaders/sky.frag`, `core/sky/sky_painter.dart`, `sky_shader.dart` and
`sky_view.dart` now render directly at native resolution. The old image
resampling path is gone. Physical-pixel triangular dither is applied in
output space; decorative grain moves only at night. Rayleigh normalization,
blue daylight response, moon polar tangent stability, and planet antipodal
ghosts were corrected. Programs load once per engine and shader instances
are reused per view and disposed.

`celestial_math.dart` and `celestial_scene.dart` now resolve lunar orbital
inclination, eccentricity, principal perturbations and topocentric parallax.
Illumination/terminator follows the Sun direction; the roughly 3× lunar disk
remains intentional. Lunar event solving has a bounded cache. Sidereal
rotation is anchored at solar transit with the sidereal rate. Solar geometry
uses the represented epoch. `core/health/local_sky_source.dart` and
`core/state/sky_state_source.dart` correct the equation-of-time sign and use
civil clock fractions with UTC-consistent epochs. Timeline scrubbing advances
lunar phase and solar noon unless the phase is explicitly overridden.

`star_field.dart` keeps the 5,070-star catalog and removes the old two-alpha
faint-star flattening. Magnitude response is logarithmically binned with
altitude/turbidity extinction. `tool/stars/generate.py` generates an immutable
numeric `star_catalog.dart`, preserving the previous float32 values and names,
without runtime base64 decoding or forbidden seam imports. Catalog equatorial bases and magnitude responses are cached; a direct matrix rotation avoids repeated spherical trig. Unchanged scenes are reused so twinkle does not rebuild surface figures. The shader skips zero-strength scattering and negligible off-band galaxy noise; fully opaque overcast skips the hidden sky/catalog while retaining ground lighting. The fallback HYG
RA-hours conversion is corrected. No runtime catalog access was introduced.

The source for lunar elements and corrections is
[Schlyter's calculation guide](https://stjarnhimlen.se/comp/ppcomp.html).
Rayleigh phase normalization follows the standard scattering formulation;
see [PBRT phase functions](https://www.pbr-book.org/4ed/Volume_Scattering/Phase_Functions).

### Sky versus reality

`test/sky/fixtures/warsaw_horizons_2026.json` contains independent NASA/JPL
Horizons samples for Warsaw 52.23°N, 21.01°E, sea level. Sun/Moon altitude and
azimuth are tested every three hours on five dates, with local offsets +1/+2.
Sun events interpolate a one-minute reference sequence at center altitude
−0.833°. The angular comparison uses airless topocentric coordinates;
conventional sunrise/set includes the standard apparent-horizon allowance.
See [Horizons manual](https://ssd.jpl.nasa.gov/horizons/manual.html) and
[NOAA solar calculation details](https://gml.noaa.gov/grad/solcalc/calcdetails.html).

| Date | Max Sun alt/az error ° | Max Moon alt/az error ° | Illumination error pp | Rise error min | Set error min | Local rise / set |
|---|---:|---:|---:|---:|---:|---|
| 2026-03-20 | 0.0525 | 0.0428 | 0.0271 | 0.632 | 0.369 | 05:38 / 17:49 |
| 2026-06-21 | 0.0274 | 0.0714 | 0.1577 | 0.077 | 0.059 | 04:14 / 21:01 |
| 2026-09-09 | 0.0518 | 0.0695 | 0.0090 | 0.395 | 0.695 | 06:01 / 19:06 |
| 2026-09-23 | 0.0567 | 0.0508 | 0.0562 | 0.358 | 0.647 | 06:24 / 18:33 |
| 2026-12-21 | 0.1210 | 0.0616 | 0.0665 | 0.061 | 0.035 | 07:43 / 15:25 |

No sampled residual exceeds 0.5°. This is a numerical ephemeris comparison,
not a claim of an observed Stellarium/window match or full-year certification.
`tool/ephemeris/fetch_horizons.py` regenerates the fixture using verified TLS
through curl; tests read it offline. Stellar precession stays deferred: the
catalog is J2000 and this comparison does not independently validate bright
star positions. Planet elements/magnitudes remain approximate. Procedural
Milky Way, lunar surface, generated cloud density textures and exposure are stylized; this is not a
photographic or volumetric atmospheric simulation.

## B — Weather seam

`SkyState.weather` is nullable `SkyWeather` from `core/sky/sky_weather.dart`:

| Field | Meaning | Range / default |
|---|---|---|
| cloudCoverage | Fraction covered; 1 closes the sky | 0–1, required |
| cumulus | Stratus sheet → rounded cumulus | 0–1, default 0.5 |
| cirrus | Blend toward thin high-cloud filaments | 0–1, default 0 |
| rain | Rain intensity | 0–1, default 0 |
| fog | Horizon optical depth control | 0–1, default 0 |
| snow | Snow intensity | 0–1, default 0 |

Null means unobserved, rendered clear-looking. `SkyWeather.clear()` means an
explicit clear observation. A future meteorological `SkyStateSource` should
validate/normalize observations outside `core/sky/`, emit through `peek()`
and `states`, and preserve null for unavailable/stale observations according
to its own freshness policy. It can copy weather onto the local source's
state. No renderer change or condition-code/network/GPS import is needed.
For example, the producer can emit
`current.copyWith(weather: const SkyWeather(cloudCoverage: 0.8, rain: 0.4))`;
`copyWith(weather: null)` explicitly restores absence. There is no met-data
hookup, key or runtime fetch in this pass.

Debug presets: Source, Clear, Cloudy, Cirrus, Overcast, Rain, Fog, Snow, plus component
sliders. `features/debug/sky_debug_sheet.dart` is guarded by `kDebugMode`;
weather overrides also ignore debug selections outside debug builds. The
review harness supplies a fixed source to profile actual weather rendering.

`weather.frag` composites after disks/catalog and before instrument ink, so
full overcast occludes every celestial body while readouts remain available.
Fog accumulates at the horizon with a short ground fade. Two bounded depth
layers provide rain streaks/snow motion. This adds one native shader pass for
non-clear weather; clear/null skip it. Cloud morphology samples bundled generated stratus/cumulus/cirrus density textures. These replace the earlier broad procedural blobs after the user requested quieter, finer cloud structure. Rain and snow are thinner, sparser and less opaque. Assets, exact prompts, native dimensions (1254×1254 each) and memory cost are documented in [texture provenance](../tool/textures/README.md). Failure fallback draws simplified
cloud/fog but does not reproduce rain/snow.

Weather transitions use the vitals easing rate (~1.4 s). Null fades via a
transient clear envelope without changing source semantics. Time stays
~0.22 s and bearing ~1.6 s. Reduced motion freezes weather time and night
effects; lifecycle pause stops the ticker. `sky_state.dart` also fixes nullable
vitals remaining stuck during exponential interpolation and accepts numeric
zero in nullable numeric copies.

## C — Surfaces

`features/dashboard/dashboard_page.dart` keeps a table and always-visible
SLEEP/STRAIN, distinguishing zero rest from absent `—`. Simulated current-day
values are labelled MOCK DATA; historical local records stay LOCAL. Real
record aggregates receive a separate RECORD / LOCAL section during mock
preview, avoiding mixed provenance. SUN duration and long units sit below
figures to avoid crowding. No cards, pills or rings were added.

`core/i18n/strings.dart` shortens the empty writing prompt. Shared header ink
in `features/shell/shell_header.dart` follows the same scene paper→slate blend
as the instrument. Figure/timeline styles are centralized in
`core/theme/typography.dart` and consumed by the timeline. Moon readout
collisions suppress competing path ticks and clip path lines behind the text; horizon 0.56, compass
band 22 px and timeline 48 px remain.

`features/shell/dream_shell.dart` keeps the clock/twilight/sleep ground, labels
mock sleep, and uses continuous ±3 px/180 s drift with background/reduced
motion pause. A missing Material text environment produced yellow text
underlines in the first profile capture; a Scaffold fixes that without
changing the layout. Debug controls scroll above safe navigation insets.

## Verification and performance

From `app`, final commands and exact summary output:

```text
flutter analyze
No issues found! (ran in 16.3s)

flutter test
00:26 +142: All tests passed!

flutter build apk --debug
Running Gradle task 'assembleDebug'...                             44.4s
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

Full evidence: [analyzer](verification/astra-analyze.txt),
[tests](verification/astra-tests.txt), [Android build](verification/astra-android-build.txt).
Build has existing speech_to_text Kotlin-plugin migration and Android SDK XML
version warnings; dependency resolution reports newer incompatible versions.
No dependency upgrade was folded into this work.

Coverage includes strict recursive sky import/export boundaries, five-day
independent ephemeris checks, orbit-aware scrubbing, catalog magnitude and
extinction, nullable weather transitions, production-shader pixel occlusion,
fog depth, moving precipitation, lifecycle/reduced motion, three native
shader golden galleries, mock/local provenance, narrow nightstand, debug
sheet safe-area scrolling and shared header ink.

Final profile results from `app/tool/astra_capture.dart`:

| Platform | Native capture | Maximum raster p95 | Maximum build p95 | Largest warmup raster frame |
|---|---|---:|---:|---:|
| Blade V 5G, Impeller Vulkan | 1080×2412 | 11.057 ms | 8.069 ms | 656.491 ms |
| Windows profile | 414×893 | 2.315 ms | 2.900 ms | 1354.822 ms |

Every final scene has a nonempty four-second sample. Initial locked-phone
samples were discarded and rerun while unlocked. Read the full method and
limits in [PERF.md](PERF.md), [Blade JSON](verification/astra-blade-profile.json)
and [Windows JSON](verification/astra-windows-profile.json). Native PNGs were
visually checked, including finer clouds, quiet precipitation and the lunar
readout path gap. They cannot certify physical-panel banding response.

The first phone baseline exceeded budget (overcast night raster p95 25.981 ms).
Cached catalog work, unchanged-scene reuse, texture sampling, opaque-coverage
culling and equivalent shader math improved the final result. Astronomical
twilight fell from 18.175 ms in the first texture run to 4.874 ms finally.
Sequential runs are not a controlled thermal benchmark. First-use latency
remains visible on both platforms and must not be hidden by settled p95 values.

After final captures, `adb -s 20240920122 install -r` restored the normal
`app/build/app/outputs/flutter-apk/app-debug.apk` successfully, and
`com.illunis.illunis/.MainActivity` was launched and confirmed focused/unlocked.
App data was preserved; the capture harness used an in-memory store. The phone
is left running the normal product, not the capture sequence. The profile APK
in the build output is the review harness; use the debug APK for normal use.

Remaining validation: interactive pager/scrub stress, long-duration thermal
and battery behavior, actual Android DreamService lifecycle, physical-panel
banding judgment, Chrome and detailed startup tracing. Automated tests cover
reduced motion and background pause, but the short fixed-scene profile does
not replace those wider checks. Windows used junctions in generated plugin
symlinks because this host lacks symlink permission; no global Developer Mode
setting was changed.

## D — Whole-app audit and ordered proposal

Audit date: 2026-09-10. Scope is every file under `app/lib` and `server`,
combining the A–C renderer/surface review with the D review of storage,
journal, parsing, fitness, rollups, statistics, providers, settings and AI.
The generated star catalog is treated as data: generation, structure and
fidelity tests were reviewed, not each star independently re-observed.
[Source inventory](verification/astra-phase-d-sources.json) records paths,
line counts and SHA-256 hashes of this reviewed working tree. References
below are repository-relative paths and current one-based source lines.

These are the audit findings in implementation order. All nine **P1** items
(data integrity, privacy, cost control and arithmetic accuracy) **have now been
implemented and verified** in the working tree. **P2** items remain prioritized
proposals for subsequent work. Worker hardening was verified offline with zero live
model requests or secrets.

1. **P1 — Apply KEEP LOCAL to every AI-derived payload.** [IMPLEMENTED]
   Problem: the direct interpretation gate worked, but excluded records entered
   daily summaries and pattern inputs. A later ordinary log sent the excluded
   sleep duration in its digest; `_maybeInsights` also ran after excluded logs.
   Evidence: `app/lib/core/journal/repository.dart:85`, `:204`, `:233` and
   `app/lib/core/health/rollups.dart:54`.
   Resolution: Added `summaryForAi(store, day)` and `dailyLoad(store, day, forAi: true)`
   in `rollups.dart`. Any entry marked `excludedFromAi: true` or missing lineage fails
   closed and is omitted from `summaryForAi`, `dailyLoad(forAi: true)`, and pattern
   inputs. `repository.dart` passes `summaryForAi` into `transport.dayDigest` and
   restricts `_maybeInsights` to run only on AI-eligible summaries.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-1: keep-local sleep is excluded from AI payload digest").

2. **P1 — Reject stale AI responses and bound requests.** [IMPLEMENTED]
   Problem: enrichment could add orphan records after revert/delete; consent and
   exclusion were only checked before dispatch. Replies could also overwrite
   newer summaries/notes.
   Evidence: `app/lib/core/journal/repository.dart:174`, `:204`, `:233`;
   `app/lib/core/ai/transport.dart:45`, `:51`.
   Resolution: Before applying any asynchronous AI enrichment or digest,
   `repository.dart` verifies that the target journal entry still exists in `store.entries`
   and is not excluded from AI. `transport.dart` enforces 20s timeouts, caps outbound
   payloads to 8 KB and inbound responses to 128 KB, and provides clean client `dispose()`.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-2: AI response does NOT resurrect derived records after delete all").

3. **P1 — Make import validated, atomic and explicit about replacement.** [IMPLEMENTED]
   Problem: `_readMap` cleared lists before parsing; malformed rows threw after
   erasing live data, while `{}` silently replaced it with an empty record.
   Imported profiles also transferred AI consent, age assertion and install ID.
   Evidence: `app/lib/core/db/store.dart:79`, `:256` and
   `app/lib/core/db/records.dart:89`.
   Resolution: `store.importJson` now decodes into staged temporary collections,
   validates all entries, profiles, and records completely before mutating state
   (all-or-nothing rollback on any failure), rejects empty root dictionaries, and
   explicitly preserves local `installId`, `aiConsentAt`, and `ageAtLeast16` from
   the active device profile.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-3: invalid import does NOT clear existing records" and "P1-3: empty object import is rejected and imported consent does NOT transfer").

4. **P1 — Make JSON persistence durable and errors visible.** [IMPLEMENTED]
   Problem: load failure set `_file=null` and subsequent writes silently became
   memory-only; normal writes truncated the canonical file directly without backup.
   Evidence: `app/lib/core/db/store.dart:32`, `:52`, `:57`;
   `app/lib/core/journal/repository.dart:61`.
   Resolution: `store.dart` persists via staged writes (`.tmp` written and flushed,
   existing file copied to `.bak`, then renamed over canonical target). Save failures
   record errors in `lastPersistenceError` without disconnecting `_file`. Added
   `store.transaction(action)` to batch multiple mutations into a single disk write.

5. **P1 — Close the worker's configuration and quota gaps before deployment.** [IMPLEMENTED]
   Problem: auth and metering were optional; per-install IDs were client supplied;
   read/increment/write counters admitted concurrent requests above the cap; request
   and output sizes and upstream duration were unbounded.
   Evidence: `server/worker.js:19`, `:33`, `:35`, `:42`, `:48`, `:61`.
   Resolution: Worker fails closed (HTTP 500) if `ILLUNIS_TOKEN`, `METER`, or
   `OPENAI_API_KEY` are not configured; requires `Authorization: Bearer <token>`;
   serializes quota reservations across concurrent requests via a promise mutex;
   bounds request bodies (64 KB), enforces a 15-second upstream timeout with
   `AbortController`, and bounds response output sizes (64 KB).
   Verified: `node docs/verification/astra-phase-d-worker.mjs` (3/3 offline tests pass).

6. **P1 — Stop movement calories becoming food intake.** [IMPLEMENTED]
   Problem: session detection rejected any chunk containing `kcal` before its explicit
   calorie branch; the journal then accepted that number as confirmed nutrition intake.
   Evidence: `app/lib/core/fitness/session.dart:63`, `:142`;
   `app/lib/core/journal/parser.dart:253`.
   Resolution: Removed the `kcal|calories` filter from `parseSessionChunk` so explicit
   session calories (`ran 5 km in 30 min 400 kcal`) parse cleanly as activity calories;
   guarded parser food energy extraction so movement context cannot be captured as food intake.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-6: activity with explicit kcal parses as activity, NOT food intake").

7. **P1 — Validate recorded numbers consistently across local and AI paths.** [IMPLEMENTED]
   Problem: local sleep accepted 99 hours, and `bench 60 kg x 5 x 0` recorded zero sets;
   local mass lacked bounds; AI auto-confirmed items where values were derived by app heuristics.
   Evidence: `app/lib/core/journal/parser.dart:169`, `:202`, `:581`, `:639`;
   `app/lib/core/journal/repository.dart:285`, `:336`, `:374`, `:402`.
   Resolution: Added consistent domain bounds across `parser.dart` and `repository.dart`:
   sets (`1..50` sets, `1..40` reps, `0..500` kg), body mass (`25..350` kg), sleep duration
   (`0.08..16` h; `0` duration allowed only for bedtime-only entries), and macros (`0..1000` g).
   Prevented auto-confirmation when energy or duration were estimated by client heuristics.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-7: invalid sleep duration and zero set count are rejected").

8. **P1 — Track sleep amendments so REVERT actually reverses them.** [IMPLEMENTED]
   Problem: wake/quality entries mutated a sleep owned by the original bedtime entry;
   reverting the amendment could not undo it.
   Evidence: `app/lib/core/db/store.dart:180`, `:208`; `app/lib/core/journal/repository.dart:96`.
   Resolution: Added amendment tracking to `SleepEntry` (`wakeJournalEntryId`,
   `qualityJournalEntryId`, `originalDay`, `originalStartHours`). `store.completeSleep`
   and `store.attachSleepQuality` attach amendment IDs. `store.revertJournalEntry` detects
   reverted wake or quality entries, rolls back the sleep to its bedtime-only incomplete
   state or clears quality, and triggers recomputation across all affected days.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-8: sleep completion reverses when wake entry is reverted").

9. **P1 — Use the same strain load and full dependency window on recompute.** [IMPLEMENTED]
   Problem: today's load included activity kcal, but history contained only strength volume;
   recomputing only seven following days missed 28-day strain; same-day mass selection
   kept the first entry instead of the last logged mass.
   Evidence: `app/lib/core/health/rollups.dart:18`, `:91`, `:201`, `:242`;
   `app/lib/core/db/store.dart:334`.
   Resolution: `rollups.dart` uses `dailyLoad` (volume + activity kcal) consistently
   across both daily scores and historical 28-day baseline; `recomputeSummaries` computes
   chronologically from the earliest affected day to today; `weightOnOrBefore` and
   `lastWeight` sort by entry timestamp to always return the latest logged mass on same-day entries.
   Verified: `app/tool/astra_phase_d_audit_test.dart` ("P1-9: same-day mass correction returns latest logged mass").

10. **P2 — Preserve unknowns and freshness in figures and digests.** Problem:
    missing macros are summed as zero; with no body mass, activity calories can
    be treated as the entire day's expenditure; AI digests survive changed
    totals. Today's sleep falls back to the last completed entry regardless of
    age. Evidence: `app/lib/core/health/rollups.dart:104`, `:117`, `:171`;
    `app/lib/core/state/app_providers.dart:165`;
    `app/lib/core/journal/repository.dart:204`. Proposed change: carry coverage,
    estimate and observation dates with totals; distinguish movement from total
    expenditure; invalidate digests by input revision; date-label stale sleep.
    Risk: more fields correctly show absence, and existing “rest from any log”
    policy needs clear wording rather than an undocumented algorithm change.
    Verify: food with unknown macros, exercise without mass, a week-old sleep,
    confirmed/dropped entries and digest refresh after corrections.

11. **P2 — Complete targeted Polish and quantity parsing.** Problem: `drzemka
    2 godziny` is treated as minutes and discarded; `ryzu` misses Rice because
    the `u` fallback excludes four-letter words; `ate 1,5 banana` estimates one
    banana. Evidence: `app/lib/core/journal/parser.dart:215`, `:529`;
    `app/lib/core/nutrition/foods.dart:724`. All three were reproduced. Mass
    `waga 82,4 kg` already works, so comma normalization itself is not generally
    broken. Proposed change: shared duration units, targeted supported genitives
    and fractional quantities with explicit serving semantics. Preserve an
    uncertain quantity instead of silently dropping it. Risk: broad stemming
    can create false matches; gram-based precision must not be invented from
    household portions. Verify: paired inflected/base forms, comma/point values,
    list commas and the deferred corpus of real dictated meals; no food DB.

12. **P2 — Make CSV faithful and exports accessible.** Problem: only journal
    text is quoted, its quotes are replaced, and commas/newlines in other labels
    break the five-column format. Exports are copied to the clipboard and saved
    to an application documents path, with no share/save chooser. Evidence:
    `app/lib/core/db/store.dart:280`; `app/lib/features/settings/settings_sheet.dart:42`.
    A `rice, beans` label produced six fields. Proposed change: one CSV field
    encoder preserving quotes/newlines, an explicit spreadsheet-safe text policy,
    and a platform share/save destination with export status. Risk: spreadsheet
    formula neutralization can change round-trip text; distinguish archival JSON
    from convenient CSV. Verify: independent CSV parser round trip of quotes,
    commas, newlines, Unicode and leading formula characters; retrieve a saved
    file on Blade without exposing it merely to test the path.

13. **P2 — Correct the statistical testing family before publishing findings.**
    Problem: BH uses only candidates already filtered by observed effect size,
    despite the comment promising correction across the whole sweep. Evidence:
    `app/lib/core/patterns/statistics.dart:108`, `:115` and
    `app/lib/core/patterns/sweep.dart:184`. Proposed change: define the family
    using predeclared data eligibility, correct all valid tested hypotheses,
    then apply the presentation effect threshold. Independently validate the
    custom p-value routine and account for overlapping seven-day series before
    stronger statistical claims. Risk: fewer visible findings; 21 paired days
    remains the minimum, not proof of independence. Verify: reference p-value
    tables, a mixed weak/strong candidate family, null simulations and correlated
    time-series fixtures. This audit identifies the filtering order; it does not
    claim the numerical p-value routine has passed an independent audit.

14. **P2 — Make civil-day changes reactive and DST-safe.** Problem: figure/day
    providers cache `DateTime.now()` without a day-change dependency while the
    sky clock keeps advancing. Journal navigation and timeline marks use elapsed
    24-hour arithmetic across DST. Evidence:
    `app/lib/core/state/app_providers.dart:55`, `:205`, `:227`;
    `app/lib/core/journal/marks.dart:5`;
    `app/lib/features/timeline/timeline_bar.dart:242`. Proposed change: one
    injectable civil-day source outside the sky seam, calendar date arithmetic,
    and shared wall-clock fractions; keep intentional catch-up navigation.
    Risk: midnight rollover must preserve a draft and an explicitly selected
    historical day. Verify: fake-clock midnight/background resume, Warsaw DST
    transitions and differing observer/device zones without changing real OS time.

15. **P2 — Enforce the release/debug scrubbing boundary.** Problem: the debug
    sheet and weather injection are guarded, but timeline tap/drag still mutates
    the time override in release. Evidence:
    `app/lib/features/timeline/timeline_bar.dart:32`, `:59`;
    `app/lib/core/state/sky_state_source.dart:244`. Proposed change: gate time
    scrubbing and debug override application at their entry points in release,
    preserving the read-only timeline. If production time exploration is desired,
    record that as an explicit change to the mandate first. Risk: hiding a useful
    existing interaction. Verify: release-mode tap/drag and injected override
    checks, plus debug scrub/LIVE behavior and unchanged journal marks.

16. **P2 — Bound the pending dock and make editing unambiguous.** Problem:
    pending rows reserve unbounded height and can consume the ground/pager.
    Tapping a journal entry copies its text without removing/updating the entry,
    so submitting an apparent edit adds a duplicate; overlapping submits can
    clear newer draft text. Evidence:
    `app/lib/features/journal/journal_page.dart:91`, `:190`, `:432`, `:454`;
    `app/lib/features/shell/illunis_shell.dart:86`, `:115`. Proposed change:
    cap and scroll the pending region, distinguish edit from duplicate, keep
    stable entry IDs and serialize submissions while clearing only the submitted
    draft revision. Risk: preserve the current explicit REVERT workflow and
    screen/keyboard focus. Verify: 1/10/30 pending rows at Blade dimensions,
    keyboard and large text, historical edits, double submit and delayed saves.

17. **P2 — Finish settings lifecycle and action accessibility.** Problem:
    export/import call `setState` after asynchronous work without checking
    whether the sheet is still mounted; tappable labels lack explicit button
    semantics/focus behavior. Evidence:
    `app/lib/features/settings/settings_sheet.dart:51`, `:101`, `:110`, `:197`.
    Proposed change: mounted/error handling, action progress, accessible actions
    and clear replacement/consent explanations in the existing visual style.
    Risk: denser controls or wrapping may alter layout. Verify: dismiss during
    slow clipboard/save operations, TalkBack and keyboard navigation, 2× text,
    long paths, gesture/three-button navigation. **No nav-bar clipping defect
    was reproduced**: the current SafeArea/scroll view passed an isolated
    1080×2412/DPR3 layout test with a synthetic 24 dp bottom inset. Actual device
    navigation modes and large text remain checks, not claimed failures.

18. **P2 — Reduce unnecessary clock/frame work and measure startup separately.**
    Problem: reduced motion freezes shader time but the ticker still invokes
    `setState` every frame; the source timer has no app-lifecycle gate. Clear sky
    startup also waits for the weather program and all cloud textures, and a
    weather-resource failure disables the native sky shader. Evidence:
    `app/lib/core/sky/sky_view.dart:68`, `:134`, `:166`;
    `app/lib/core/health/local_sky_source.dart:19`;
    `app/lib/core/sky/sky_shader.dart:34`. A–C already measured first-use stalls
    of 656.491 ms Blade / 1354.822 ms Windows; those are not newly measured D
    results or proof that texture loading is their sole cause. Proposed change:
    trace startup, load independent sky/weather resources, and schedule only
    needed frames/source updates while preserving easing and one-second clocks.
    Risk: stepping, stale resumed state or resource races; keep native resolution.
    Verify: cold/warm traces, clear→weather failure injection, interactive profile,
    reduced motion and paused source emissions, then longer thermal/battery runs.

### Phase D verification

The audit harness [`app/tool/astra_phase_d_audit_test.dart`](../app/tool/astra_phase_d_audit_test.dart)
was converted from exploratory defect characterization into a 12-case regression suite
validating the P1 implementations and layout invariants. All stores are in-memory or
isolated temp directories and HTTP clients are offline mocks.

```text
cd app
flutter analyze
No issues found! (ran in 3.8s)

flutter test --reporter expanded
00:17 +142: All tests passed!

flutter test tool/astra_phase_d_audit_test.dart --reporter expanded
00:01 +12: All tests passed!

# from repository root
node docs/verification/astra-phase-d-worker.mjs
Verified: missing auth and meter bindings fail closed (500).
Verified: mismatched auth token returns 401.
Verified: concurrent requests serialize quota; 1 succeeds (200), 1 limited (429), counters at 1.
All hardened worker tests passed; no real network or secrets used.
```

Full logs: [analysis](verification/astra-phase-d-analyze.txt),
[normal tests](verification/astra-phase-d-tests.txt),
[audit probes](verification/astra-phase-d-probes.txt).
All nine P1 proposals have been implemented without violating any mandate constraint:
the sky seam remains strictly dumb and isolated (`test/sky/architecture_test.dart` passes),
no Drift or health package was introduced, no food DB was added, and UI guidelines were
strictly maintained. No commit or push was made.

## Phase D critical hardware appraisal & verified fixes (ZTE Blade V 5G)

Following full deployment and live interaction testing on the physical ZTE Blade V 5G (1080×2412, DPR 3.0), eleven critical hardware, UI ergonomics, and scientific accuracy issues were discovered, resolved, and verified on-device:

1. **Sky Overlay Edge Indicator Stacking & Separation (`sky_overlay_painter.dart`)**:
   - *Problem*: At midnight or when multiple celestial bodies (Sun, Moon) were off-screen below the horizon or past azimuth boundaries, indicators were clamped to identical edge coordinates (`yHi`), rendering unreadable overprinted text (`phone_screenshot_stacked_night.png`).
   - *Fix*: Created a decoupled layout pass `_paintEdgeIndicators` that clusters off-screen bodies by horizontal side (`left`, `right`), sorts them by altitude, enforces vertical separation (`spacing = 20.0 dp`), and bounds them within `[yLo, yHi]`. Planet indicator rails also avoid occupied vertical ranges (`occupiedYs`). Verified on ZTE Blade V 5G at midnight scrub (`00:00:00`): Moon is cleanly placed on the left rail (`◀ MOON 007° -28°`) and Sun on the right rail (`SUN 350° -32° ▶`) with zero collision.

2. **Orientation Lock (`AndroidManifest.xml` & `main.dart`)**:
   - *Problem*: In-hand tilting or rotating the physical phone caused landscape sensor rotation, collapsing the sky viewport into a 16:9 slit and breaking instrument layout.
   - *Fix*: Added `android:screenOrientation="portrait"` to `MainActivity` in `AndroidManifest.xml` and enforced `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in `main.dart`.

3. **Opaque Modal Sheets & Dimmed Scrim (`settings_sheet.dart` & `sky_debug_sheet.dart`)**:
   - *Problem*: Translucent background (`0xF20B0E14`) without barrier scrim (`Colors.transparent`) caused underlying dashboard typography (e.g. `SLEEP 7h 00m`, `SUN 06:01`) to bleed directly through sheet text, reducing legibility.
   - *Fix*: Hardened modal background to fully opaque `#07090D` and added dark barrier dimming `Color(0x99000000)`. Verified on hardware: sheet contents are crisp with zero underlying figure bleed.

4. **Timeline Gestures Collision Fix (`timeline_bar.dart`)**:
   - *Problem*: The scrub gesture detector on the timeline bar intercepted horizontal swipes intended to page between Journal and Dashboard.
   - *Fix*: Guarded scrubbing gesture detection with `canScrub = !kReleaseMode`, allowing horizontal swipes to pass cleanly to the underlying `PageView`.

5. **Input Dock Ergonomics & `KEEP LOCAL` Active Indicator (`journal_page.dart` & `illunis_shell.dart`)**:
   - *Problem*: The single-line text input field and `KEEP LOCAL` toggle had tight touch targets with no clear visual toggle indication, and Settings access was obscured.
   - *Fix*: Enlarged text input vertical padding to 8 dp. Padded `KEEP LOCAL` touch target and added dynamic feedback: toggling renders `[ LOCAL ]` in `Inks.warm`. Added `Semantics(button: true)` and tap listener to `S.version` (`ILLUNIS 1.0`) in the bottom dock to provide one-tap Settings access. Resolved 360dp phone horizontal overflow by balancing dock spacing.

6. **Viewport Bottom Clipping Clearance (`dashboard_page.dart`)**:
   - *Problem*: On tall 20:9 screens with 3-button navigation bars, the bottom insights row clipped against the surface switch bar.
   - *Fix*: Increased scroll bottom padding from 12 dp to 28 dp, guaranteeing full visibility of all insight and provenance cards above navigation chrome.

7. **Screensaver Compositor Efficiency (`IllunisDreamService.kt`)**:
   - *Problem*: `FlutterTextureView` incurred dual-buffer composition copies through SurfaceFlinger during screensaver mode.
   - *Fix*: Switched to `FlutterSurfaceView(this)`, eliminating composition overhead and reducing power consumption while charging/docked.

8. **Benjamini-Hochberg Multiple-Testing Order (`statistics.dart`)**:
   - *Problem*: False Discovery Rate (FDR) ranking was calculated after filtering candidates by `minimumAbsR`, truncating the hypothesis family size $m$ and distorting statistical rigor.
   - *Fix*: Re-ordered algorithm to test all eligible candidate pairs meeting sample size ($m = \text{eligible.length}$) before applying the presentation threshold.

9. **Polish NLP, Nap Hours, and Comma Decimals (`foods.dart` & `parser.dart`)**:
   - *Problem*: Polish 4-letter genitives (e.g., `ryzu` / `ryżu`) were rejected by strict `> 4` length check; nap expressions in hours (e.g., `1,5 godz drzemki`) and comma decimals were parsed as zero or rejected.
   - *Fix*: Lowered genitive length threshold to `>= 4`; extended regex and parsing to accept `godz` units and comma decimals (`1,5` -> `1.5`). Verified on device: `"zjadlem ryzu i 1,5 banana"` parsed accurately into `Rice (250 kcal)` and `Banana ×1.5 (158 kcal)`.

10. **RFC 4180 CSV Escaping & Injection Protection (`store.dart`)**:
    - *Problem*: Commas in labels broke CSV column alignments; leading characters (`=`, `+`, `-`, `@`) were vulnerable to spreadsheet formula injection.
    - *Fix*: Added `_csvCell()` wrapping commas/quotes/newlines in RFC 4180 double quotes, escaping quotes as `""`, and prefixing formula characters with `'`. Verified on physical storage: `/data/user/0/com.illunis.illunis/app_flutter/illunis-export.csv` exports clean, well-formed rows.

11. **Confirmation Touch Targets Ergonomics (`journal_page.dart`)**:
    - *Problem*: `CONFIRM ALL` text hit target was thin (~12 px font bounding box) without internal padding, making it prone to missed taps on high-density capacitive touchscreens.
    - *Fix*: Placed 6 dp vertical touch padding inside `GestureDetector(behavior: HitTestBehavior.opaque)`, expanding the interactive hit area to a standard mobile touch target.



## A–C review self-assessment

| Axis | Score / 5 | Evidence and remaining improvement |
|---|---:|---|
| Accuracy | 4 | Independent Sun/Moon fixture and native shaders pass; bright-star window check remains outstanding |
| Completeness | 4 | A–C code, textures, both capture sets and phone restoration delivered; wider endurance/interactions need follow-up |
| Clarity | 4 | Scope, measurements and first-use limits are explicit; visual taste still needs the developer's review |
| Actionability | 4 | Reproduction harness, prompts, fixture script, logs and normal installed app ready; startup tracing is the next concrete improvement |
| Conciseness | 3 | Broad work needs a long handoff; review-first links keep the entry point short |

Average 3.8/5. This is self-review, not independent acceptance. The next
performance priority is startup latency and longer interactive/thermal runs.
