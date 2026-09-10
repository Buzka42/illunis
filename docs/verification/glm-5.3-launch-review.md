# Illunis launch-readiness review (glm-5.3)

2026-09-10. READ-ONLY review of `app/lib` (all 57 files) and `server/worker.js`,
plus the Android platform layer (`AndroidManifest.xml`, `MainActivity.kt`,
`IllunisDreamService.kt`), `pubspec.yaml`, and `test/sky/architecture_test.dart`.
Inputs read in full first: `docs/ASTRA_HANDOFF.md`, `docs/HANDOFF.md`,
`docs/DECISIONS.md`, `docs/DESIGN.md`, `docs/BACKEND_PLAN.md`, `PLAN.md`,
`CURSOR_MANDATE.md`. No code was edited; nothing was committed.

## Score

**74 / 100 — Caveats (band 70–84)** for the current launch channel
(single-user, sideloaded debug APK on the ZTE Blade, per `docs/HANDOFF.md`
"Install debug only").

**If the channel is Google Play / public distribution: Risky (50–69)** until
Blocker 3 (consent disclosure) and the Play health/microphone declarations
under "Evidence missing" are resolved. The score is channel-weighted toward
the sideload case because that is what the tree and handoffs describe.

## Blockers (must-fix before launch)

1. **Every cold start rewrites the whole store once per history day, before
   the first frame.**
   `app/lib/main.dart:27-33` (`_openStore` awaits `recomputeSummaries(store)`
   before `runApp`, for both `main` and `dreamMain`) →
   `app/lib/core/health/rollups.dart:29-33` (loops `putSummary` over every
   historical day, outside any transaction) → `app/lib/core/db/store.dart:387-392`
   (`putSummary` calls `_persist()`, a full `toJson()` + staged disk write, per
   call). With D days of history a launch performs D full-store encodes and D
   file writes; at ~6 months that is ~180 sequential writes of a growing file
   blocking first paint, and the same work repeats on every cold
   screensaver start (`main.dart:22-25`). Settings import repeats it
   (`app/lib/features/settings/settings_sheet.dart:108-109`). Fix: wrap the
   boot/import recompute in `store.transaction(...)` (already exists,
   `store.dart:36-50`) and/or recompute only today plus dirty days at boot.

2. **Persistence failures are recorded but never surfaced; the journal can
   silently become memory-only.**
   `app/lib/core/db/store.dart:125-127` sets `lastPersistenceError` — a repo
   grep shows it is **read nowhere** (only written, `store.dart:31,72,91,125,127`).
   `_submit` swallows all log errors (`app/lib/features/journal/journal_page.dart:449-457`,
   `catch (_) {}`), and the settings sheet never displays the field. If a
   write fails (storage full, permissions, I/O error), the user keeps logging
   with zero indication and everything after the failure is lost at process
   death. For an app whose contract is "device is canonical, no account"
   (`docs/BACKEND_PLAN.md` §3), silent canonical-store failure is a launch
   blocker. Fix: surface `lastPersistenceError` on the journal surface (one
   hairline line is enough in the existing voice) and stop swallowing it in
   `_submit`.

3. **The AI consent label does not disclose that health prose leaves the
   device.**
   `app/lib/core/i18n/strings.dart:34` — `aiConsent = 'ALLOW INTERPRETATION'`,
   toggled with no explanation at `app/lib/features/settings/settings_sheet.dart:141-154`.
   The app performs *local* interpretation always, so the label reads as
   enabling the local parser, while it actually gates dispatch of journal
   prose and daily health figures to `ILLUNIS_AI_ENDPOINT` → the Cloudflare
   worker → OpenAI (`app/lib/core/ai/transport.dart:9-10,37-84`;
   `server/worker.js:108-133`). Mechanism is sound (default off, consent +
   age gate checked at dispatch *and* re-checked before applying results,
   `repository.dart:96-98,190,240,255,289`; `transport.dart:47-48`; KEEP LOCAL
   honored end-to-end) — the disclosure copy is the gap. For Play this is a
   hard blocker (informed consent + Data Safety); for the single informed
   owner-user it is a copy fix, but it should still land before anyone else
   holds the phone.

## High-value fixes (ordered)

1. **Measure one full-night DreamService run before trusting the nightstand.**
   `IllunisDreamService.kt:26-28` sets `isInteractive = true` and
   `isScreenBright = true`; the dream then runs the native-resolution
   fragment shader every frame (measured 11.06 ms raster p95 steady-state on
   the Blade, `docs/ASTRA_HANDOFF.md`) for hours while charging. Long-duration
   thermal/battery is explicitly unmeasured ("Remaining validation", same
   file). Mitigations if warm: drop `isScreenBright`, cap dream fps, or freeze
   decorative shader time at night. This becomes Blocker 4 the moment the app
   is distributed to anyone else.
2. **Decide Android backup semantics explicitly.** The manifest
   (`AndroidManifest.xml:4-8`) omits `allowBackup`/`dataExtractionRules`, so
   the default **on** applies: the full health JSON (`illunis.json`) uploads
   to the user's Google auto-backup. That is currently the only automatic
   backup (good for durability), but it also means `aiConsentAt` +
   `ageAtLeast16` silently ride along on device migration — while clipboard
   import deliberately does *not* transfer them (`store.dart:450-461`).
   Decide, then write `allowBackup` + `dataExtractionRules`/`fullBackupContent`.
3. **Harden the worker's prompt-trust and note its meter race.**
   `server/worker.js:91-97` forwards arbitrary client-supplied
   `system`/`user`/`responseSchema` — a bearer token extracted from the APK
   (`transport.dart:10`, `--dart-define`) turns the worker into a metered
   OpenAI proxy (install IDs are client-minted, `worker.js:65-67`, so the
   40/install cap is not the real bound; 4000/day global is). Pin the three
   known system prompts server-side per `x-illunis-call`, and consider a
   lower `MAX_GLOBAL`. Also note the promise mutex (`worker.js:9-32`) only
   serializes within one isolate; Cloudflare KV is eventually consistent
   across isolates, so the cap is approximate under true concurrency.
4. **Wrap the settings sheet async paths in `mounted` checks and give every
   actionable word `Semantics(button: true)`.** `settings_sheet.dart:100-114`
   calls `setState` after awaits without `mounted` (dismiss during a slow
   clipboard/save throws in debug); the only semantics node in the app is the
   Settings wordmark (`illunis_shell.dart:212-214`). The mic mark
   (`journal_page.dart:541-552`), KEEP LOCAL toggle (`:524-539`), PREV/NEXT,
   CONFIRM/DROP/REVERT are invisible to TalkBack.
5. **Cap and scroll the pending dock.** `journal_page.dart:90-137` renders
   unbounded pending rows (P2-16, still open); 10+ unconfirmed estimates will
   cover the pager on the Blade.
6. **Split sky/weather resource loading.** `sky_shader.dart:34-43` loads both
   programs and all three cloud textures all-or-nothing, so clear-sky startup
   waits for weather resources and any weather asset failure disables the
   native sky shader entirely (P2-18; first-use stalls 656 ms Blade /
   1354 ms Windows already measured).
7. **Gate the source timer on lifecycle and skip per-frame `setState` under
   reduced motion.** `local_sky_source.dart:16-24` ticks every second with no
   lifecycle gate; `sky_view.dart:99-135` runs `setState` every frame even
   when `disableAnimations` freezes shader time (P2-18).
8. **DST/civil-day fixes (P2-14).** `app_providers.dart:56` caches
   `DateTime.now()` without a day-change dependency; `marks.dart:4-7` and
   journal navigation use elapsed-24h arithmetic across DST transitions.

## Evidence checked

- **Analyzer / tests / worker, run today by this review:**
  - `cd app && flutter analyze` → `No issues found! (ran in 4.1s)`
  - `flutter test` → `00:16 +142: All tests passed!`
  - `flutter test tool/astra_phase_d_audit_test.dart` → `00:01 +12: All tests passed!` (P1-1…P1-9 regressions)
  - `node docs/verification/astra-phase-d-worker.mjs` → 3/3 offline worker checks pass (fail-closed 500, 401, serialized quota 200/429)
- **Data durability:** staged writes with `.tmp`→`.bak`→rename and `.bak`
  fallback on load (`store.dart:52-129`); atomic validated import that
  preserves local `installId`/consent/age (`store.dart:400-489`); `transaction`
  batching exists and `log()` uses it (`repository.dart:61-93`,
  `store.dart:36-50`); recompute is chronological from earliest affected day
  (`rollups.dart:12-34`); sleep amendments revert correctly
  (`store.dart:202-261`); same-day mass resolves to the latest logged entry
  via append order (`store.dart:575-593` — note: list order, not a timestamp
  sort as the Astra handoff words it; equivalent for app-produced data).
- **Privacy (KEEP LOCAL, consent, age gate):** exclusion enforced in parser
  path, `summaryForAi`/`dailyLoad(forAi: true)` for digests, insights and
  pattern inputs (`rollups.dart:61-78`); sleep eligibility includes wake and
  quality amendment IDs (`store.dart:270-287`); enrich/digest/insight
  re-verify consent, age, entry existence and exclusion *after* the network
  returns (`repository.dart:184-222,224-251,253-307`); transport re-checks
  and bounds payloads (`transport.dart:44-84`); worker never logs payloads and
  holds the only key (`worker.js:1-8,108-148`); local parser remains the
  record and logging is never gated on consent.
- **Worker cost control:** fail-closed on missing `ILLUNIS_TOKEN`/`METER`/
  `OPENAI_API_KEY` (`worker.js:44-52`); bearer auth (`:54-57`); call allowlist
  (`:61-64`); 32-hex install ID (`:65-67`); 64 KB request bound pre- and
  post-read (`:70-83`); per-field size caps (`:95-97`); 40/install/day and
  4000/day caps with 48 h TTL (`:100-106`); 15 s `AbortController` upstream
  timeout (`:109-110`); 64 KB response bound (`:141-143`).
- **Release/debug boundary:** debug sheet guarded at entry
  (`sky_debug_sheet.dart:17`; `illunis_shell.dart:134-136`;
  `dream_shell.dart:139-141`); weather overrides applied only in
  `kDebugMode` (`sky_state_source.dart:264-269`); timeline scrubbing gated
  `!kReleaseMode` (`timeline_bar.dart:51,70-79`); capture harness and
  FrameBudget debug-only (`capture.dart:35`, `frame_budget.dart:14`,
  `main.dart:36`); mock sleep reachable only via presets, which release
  cannot set (`sleep_record.dart:95-118`). Minor hardening note:
  `SkyOverrides.apply` still applies time/day/lat/moon overrides
  unconditionally if state were ever set (`sky_state_source.dart:252-263`) —
  defense-in-depth would gate at `apply` too.
- **Mandate constraints:** `test/sky/architecture_test.dart` enforces the dumb
  sky seam (import + health-word grep) and passes (in the 142); no Drift, no
  `health` package, no food DB in `pubspec.yaml` (verified dependencies:
  riverpod, path_provider, path, http, speech_to_text only); patterns silent
  until 21 paired days (`statistics.dart:102-127` with `minimumPairs: 21`,
  `sweep.dart:194-198`, dashboard wait copy `dashboard_page.dart:214-232`);
  BH family now built from all n≥21 candidates before the presentation
  threshold (`statistics.dart:108-126`); grep for
  Card/pill/ring/glass/blur widgets in `app/lib` returns nothing; SLEEP and
  STRAIN always visible with `—` for absence (`dashboard_page.dart:89-111`);
  nullable vitals and nullable weather preserved through `SkyState`/lerp
  (`sky_state.dart:55-69,117-144`); `timelineMarksProvider` stays on today
  (`app_providers.dart:227-230`).
- **Android permissions:** only `INTERNET` + `RECORD_AUDIO`
  (`AndroidManifest.xml:2-3`); no location (observer is the Settings home,
  per `docs/DECISIONS.md`); recognizer `queries` block appropriate
  (`:57-65`); mic falls back to keyboard when denied
  (`dictation.dart:32-58`); DreamService correctly permission-gated and
  portrait-locked (`:32-45`, `:15`); hardware-appraisal fixes verified in
  code (opaque sheets `settings_sheet.dart:20-27`, CSV RFC 4180 + formula
  neutralization `store.dart:506-523`, genitive `>= 4` `foods.dart:724`,
  nap `godz`/comma decimals `parser.dart:58-61,216-227,547-570`).

## Evidence missing

- One overnight DreamService thermal/battery measurement (the single biggest
  unknown; see High-value 1).
- Interactive pager/scrub stress, real DreamService lifecycle on-device, and
  physical-panel banding judgment (acknowledged open in
  `docs/ASTRA_HANDOFF.md`).
- Independent validation of the custom incomplete-beta p-value routine and
  correlated-series behaviour (P2-13 verify note).
- Startup tracing (cold/warm) separating store recompute from shader/texture
  load (P2-18).
- TalkBack / keyboard / 2× text walkthroughs (only an isolated layout test
  exists for the settings sheet).
- Play launch artifacts (not in repo, expected): Data Safety form, health
  apps declaration, `RECORD_AUDIO` rationale, privacy policy URL, and the
  APK-shipped worker token risk assessment.
- Long-duration (21+ day) real-use data: none exists yet by design — do not
  seed history.

## Next action

Fix Blockers 1 and 2 first — both are small, mechanical changes to the same
file pair (`main.dart`/`rollups.dart` wrapped in `store.transaction`, and
surfacing `lastPersistenceError`): they remove the only paths where the
canonical record can be lost or the app can age into multi-second starts.
Then land the consent copy (Blocker 3, one string + one line under the
toggle), and run the overnight nightstand measurement before setting
Illunis as anyone's screensaver. Re-run `flutter analyze` + the 154 tests
after each change; this review's baseline is quoted above.
