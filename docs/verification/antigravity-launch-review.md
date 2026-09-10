# Illunis Launch-Readiness Code Review (Antigravity)

**Date**: 2026-09-10  
**Scope**: READ-ONLY audit of `app/lib/` (57 files), `server/worker.js`, `app/android/`, `app/shaders/`, and test suites.  
**Primary References Audited**: `docs/ASTRA_HANDOFF.md`, `docs/HANDOFF.md`, `docs/DECISIONS.md`, `docs/DESIGN.md`, `docs/BACKEND_PLAN.md`, `PLAN.md`, `CURSOR_MANDATE.md`.  
**Execution Policy**: Zero code edits made, zero commits created.

---

## 1. Score & Launch Band

### Score: **84 / 100**  
### Band: **Ready with Blockers** (Caveats Band: 70–84)

* **Target Deployment**: Single-user, sideloaded release/debug build on the ZTE Blade A72 (`docs/HANDOFF.md`).
* **Public / Play Store Channel**: **72 / 100 (Caveats / High Risk)** pending privacy disclosure copy, Android Auto-Backup rules, and TalkBack semantics.

The app's foundational architecture is in an exceptional state: the sky seam is completely decoupled from state and health semantics, the J2000 astronomical ephemeris matches JPL Horizons within arcminutes, the custom fragment shaders execute within frame budget on low-end silicon, Polish dictation parsing handles complex Slavic declensions, and the Cloudflare worker enforces strict fail-closed security and rate limits. 

However, **three functional and state blockers** directly threaten layout stability, journal data integrity, and the core "absence is never filled" mandate, and must be addressed before daily-driver launch.

---

## 2. Blockers (Must Fix Before Launch)

### Blocker 1: Unbounded Pending Region Crushes PageView Layout on High-Density Meals
* **Evidence**: 
  - [`app/lib/features/journal/journal_page.dart:98-101`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L98-L101)
  - [`app/lib/features/shell/illunis_shell.dart:86-88`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/shell/illunis_shell.dart#L86-L88)
  - [`app/lib/features/shell/illunis_shell.dart:115-118`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/shell/illunis_shell.dart#L115-L118)
* **Problem**: 
  In `illunis_shell.dart`, the bottom ground region is strictly bounded to `final groundH = constraints.maxHeight * 0.44;` (on a 1600×720 or 2412×1080 screen, this yields ~300–450 dp). In `journal_page.dart`, `JournalPending.heightFor(pending)` computes height strictly as `pending * 40.0 + 28.0` with no upper clamp or internal scroll view. 
  When a user logs a multi-component meal (e.g., soup, main course, side, dessert, beverage) or dictates a compound intake containing 8–11 items, `JournalPending` expands to 350–470 dp. This exceeds `groundH`, triggering a Flutter `RenderFlex` overflow exception, breaking the `PageView` layout, and pushing the `CONFIRM` / `DROP` action buttons off-screen and rendering them unclickable.
* **Required Fix**:
  Clamp `JournalPending` height to a maximum fraction of ground height (e.g. `min(pending * 40.0 + 28.0, groundH * 0.45)`), wrap the list of pending items in a `SingleChildScrollView`, and ensure `JournalPage` entries list padding accounts for this clamped height.

---

### Blocker 2: Ambiguous Journal Entry Tap Duplication Without Update Semantics
* **Evidence**:
  - [`app/lib/features/journal/journal_page.dart:188-197`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L188-L197)
  - [`app/lib/features/journal/journal_page.dart:432-458`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L432-L458)
* **Problem**:
  In `_EntryTile`, tapping an existing entry invokes `onSelect: (entry) => _controller.text = entry.rawText`. This places the raw text of the logged item back into the active input line. To the user, this standard interaction pattern signals "tap to edit/correct an entry" (e.g. fixing a typo or changing quantity). 
  However, `_submit` always executes `repo.log(text, localOnly: keepLocal);`, which mints an entirely new `JournalEntry` ID and appends it to the store. It does **not** update or replace the existing entry. The original entry remains in the database, silently doubling the recorded calories, macros, or sets unless the user knows to separately long-press the entry to invoke `revert`. In a privacy-first, local-canonical health app, silent record duplication is a direct data corruption hazard.
* **Required Fix**:
  Explicitly distinguish between starting a new draft and editing an existing entry. Either track `_editingEntryId` so `_submit` updates/replaces the record, or render a clear indicator (e.g., `REPEAT: "..."`) so the user understands that submitting will log an additional entry rather than modifying the existing one.

---

### Blocker 3: Stale Multi-Day Sleep Leaks into Today's Dashboard Figures
* **Evidence**:
  - [`app/lib/core/state/app_providers.dart:164-165`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/state/app_providers.dart#L164-L165)
  - [`app/lib/core/db/store.dart:160-165`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/db/store.dart#L160-L165)
  - [`app/lib/features/dashboard/dashboard_page.dart:90-101`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/dashboard/dashboard_page.dart#L90-L101)
* **Problem**:
  In `todaySummaryProvider`, the provider checks `if (today) { sleep ??= store.lastSleep(); }`. In `store.dart`, `lastSleep()` returns `_sleeps.values.last`. If a user does not log sleep for several days (e.g., over a weekend or during travel), `lastSleep()` returns a record from 3, 5, or 14 days ago. 
  `DashboardPage` then displays that ancient sleep duration and quality as today's sleep. This is a direct violation of the foundational design mandate: *"Absence is stated, never filled. Nullable vitals stay null. We do not invent a baseline... If sleep is absent, the dashboard shows `—`."*
* **Required Fix**:
  Only fall back to `lastSleep()` if the record's wake timestamp falls within the current civil morning or within a reasonable threshold (e.g. completed within the past 18 hours). If no sleep was logged for last night, `summary.sleepHours` must remain `null` and render as `—`.

---

### Blocker 4: AI Consent Copy Does Not Disclose Off-Device Health Prose Transmission
* **Evidence**:
  - [`app/lib/core/i18n/strings.dart:34`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/i18n/strings.dart#L34)
  - [`app/lib/features/settings/settings_sheet.dart:141-154`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/settings/settings_sheet.dart#L141-L154)
  - [`app/lib/core/ai/transport.dart:44-84`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/ai/transport.dart#L44-L84)
  - [`server/worker.js:108-133`](file:///C:/Users/Arawn/Documents/illunis/server/worker.js#L108-L133)
* **Problem**:
  In settings, the toggle is titled simply `ALLOW INTERPRETATION` (`S.aiConsent`). Because Illunis already contains extensive on-device parsing for Polish and English, users reasonably assume this toggles deeper local algorithmic heuristics. 
  In reality, enabling this toggle authorizes network transmission of journal raw text, daily calorie rollups, macro breakdowns, and strain metrics to `ILLUNIS_AI_ENDPOINT`, routed through the Cloudflare Worker to OpenAI. While the underlying security architecture is robust (default off, age-gated, per-call consent verification, `KEEP LOCAL` respected), the UI fails to provide informed consent regarding third-party cloud data transmission.
* **Required Fix**:
  Update the settings label or provide an explanatory subline clarifying that enabling interpretation sends journal text and daily load metrics to the cloud AI service (e.g., `ALLOW CLOUD INTERPRETATION · ON/OFF` with explanatory text).

---

## 3. High-Value Fixes (Prioritized)

1. **Unmeasured Long-Duration Overnight Thermal/Battery Performance in DreamService**:
   - [`app/android/app/src/main/kotlin/com/illunis/illunis/IllunisDreamService.kt:26-28`](file:///C:/Users/Arawn/Documents/illunis/app/android/app/src/main/kotlin/com/illunis/illunis/IllunisDreamService.kt#L26-L28)
   - `IllunisDreamService` sets `isInteractive = true` and `isScreenBright = true`, causing the native fragment shader to execute continuously at full resolution on the nightstand while charging. While frame time is verified at ~11 ms on the ZTE Blade, 8-hour continuous thermal accumulation has not been profiled. Mitigate if necessary by dimming the screen or capping screensaver redraw frequency.
2. **Missing Async `mounted` Safety in Settings Sheet**:
   - [`app/lib/features/settings/settings_sheet.dart:42-55`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/settings/settings_sheet.dart#L42-L55), [`:100-114`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/settings/settings_sheet.dart#L100-L114)
   - `_copyJson`, `_copyCsv`, and `_import` call `setState()` after asynchronous file and clipboard operations without verifying `if (!mounted) return;`. Dismissing the sheet during clipboard operations throws runtime exceptions in debug mode.
3. **Wall-Clock Fraction Drift on Daylight Saving Time (DST) Transitions**:
   - [`app/lib/core/journal/marks.dart:4-7`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/journal/marks.dart#L4-L7)
   - `timeOfDayFraction` divides `at.difference(midnight).inMilliseconds` by `86400000.0`. On 23-hour or 25-hour DST transition days, timeline marks drift relative to the 24-hour axis ticks. Use civil hour/minute arithmetic (`(at.hour * 3600 + at.minute * 60 + at.second) / 86400.0`) instead of duration difference.
4. **AI Digest Invalidation on Modified Daily Records**:
   - [`app/lib/core/health/rollups.dart:248-251`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/health/rollups.dart#L248-L251)
   - `keepAi` preserves existing AI digests across subsequent rollups even if entries for that day are subsequently edited, deleted, or appended, leaving outdated narrative digests attached to altered daily summaries.
5. **Accessibility / Semantics Gaps for Voice and Primary Actions**:
   - [`app/lib/features/journal/journal_page.dart:531-558`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L531-L558)
   - The microphone button (`_MicMark`), `KEEP LOCAL` toggle, and action buttons (`CONFIRM`, `DROP`, `REVERT`) lack explicit `Semantics(button: true, label: ...)` wrappers, preventing accessible interaction via TalkBack.
6. **Split Shader Asset Loading for Clear-Sky Resilience**:
   - [`app/lib/core/sky/sky_shader.dart:34-43`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/sky/sky_shader.dart#L34-L43)
   - Both shader programs (`sky.frag`, `weather.frag`) and three cloud textures are loaded concurrently in `Future.wait`. Any error in weather texture loading causes the entire native sky shader pipeline to fail closed to the fallback painter.

---

## 4. Evidence Checked vs. Evidence Missing

### A. Evidence Checked (Executed and Verified Live)

#### 1. Static Analysis (`flutter analyze`)
Run inside `app/` on 2026-09-10:
```
Analyzing app...                                                
No issues found! (ran in 10.4s)
```

#### 2. Full Test Suite (`flutter test`)
Run inside `app/` on 2026-09-10:
```
00:15 +87: C:/Users/Arawn/Documents/illunis/app/test/shell_smoke_test.dart: every TextTheme slot is defined by the product type
00:17 +88: C:/Users/Arawn/Documents/illunis/app/test/sky/architecture_test.dart: core/sky imports nothing above its station
00:20 +89: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: ephemeris epoch days match J2000 and a known JD
00:20 +90: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: ephemeris the Sun crosses the equator at the March equinox
00:20 +91: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: ephemeris inner planets keep to their maximum elongation
00:20 +92: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: ephemeris planets resolve to unit directions and sensible magnitudes
00:20 +93: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: ephemeris a planet below the horizon or in daylight is not visible
00:20 +94: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: sun is at the zenith at noon on the equinox at the equator
00:20 +95: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: sun is below the horizon at midnight in the temperate zone
00:20 +96: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: sun rises in the east and sets in the west
00:20 +97: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: sun summer day is long, winter day is short at 52°N
00:20 +98: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: sun never sets at 80°N in June
00:20 +99: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: moon is full opposite the sun
00:20 +100: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: moon new moon travels with the sun
00:20 +101: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: moon phase from date is in range and advances
00:20 +102: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: stars sidereal time advances with the clock
00:20 +103: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: stars Sirius is the brightest catalog star
00:20 +104: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: stars Polaris sits on the north celestial pole
00:20 +105: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: stars Orion's belt is up on a January evening at 52°N, not in June
00:20 +106: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: stars catalog stars above the horizon project into the sky half
00:20 +107: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: camera project and unproject round-trip
00:20 +108: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: camera horizon is a straight line at the principal point
00:20 +109: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: camera noon at 52°N still faces the sun
00:20 +110: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: camera a new-moon night looks south so Orion is in the window
00:20 +111: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: camera a risen full moon takes the night camera
00:20 +112: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: state lerp takes the short way round midnight
00:20 +113: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: state a null vital snaps instead of fading through a number
00:20 +114: C:/Users/Arawn/Documents/illunis/app/test/sky/celestial_scene_test.dart: state absent vitals leave the atmosphere neutral
00:21 +115: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: timeline follows the lunar orbit unless phase is explicitly scrubbed
00:21 +116: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: Warsaw 2026-03-20 agrees with JPL Horizons
EPHEMERIS 2026-03-20: sunMax=0.0525deg moonMax=0.0428deg illuminationMax=0.0271pp sunriseError=0.632min sunsetError=0.369min sunrise=05:38 sunset=17:49
00:21 +117: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: Warsaw 2026-06-21 agrees with JPL Horizons
EPHEMERIS 2026-06-21: sunMax=0.0274deg moonMax=0.0714deg illuminationMax=0.1577pp sunriseError=0.077min sunsetError=0.059min sunrise=04:14 sunset=21:01
00:21 +118: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: Warsaw 2026-09-09 agrees with JPL Horizons
EPHEMERIS 2026-09-09: sunMax=0.0518deg moonMax=0.0695deg illuminationMax=0.0090pp sunriseError=0.395min sunsetError=0.695min sunrise=06:01 sunset=19:06
00:21 +119: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: Warsaw 2026-09-23 agrees with JPL Horizons
EPHEMERIS 2026-09-23: sunMax=0.0567deg moonMax=0.0508deg illuminationMax=0.0562pp sunriseError=0.358min sunsetError=0.647min sunrise=06:24 sunset=18:33
00:21 +120: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: Warsaw 2026-12-21 agrees with JPL Horizons
EPHEMERIS 2026-12-21: sunMax=0.1210deg moonMax=0.0616deg illuminationMax=0.0665pp sunriseError=0.061min sunsetError=0.035min sunrise=07:43 sunset=15:25
00:21 +121: C:/Users/Arawn/Documents/illunis/app/test/sky/ephemeris_reference_test.dart: civil clock preserves UTC and day number without DST duration arithmetic
00:23 +122: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: clear_twilight native shader reference
00:23 +123: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: clear_twilight native shader reference
00:23 +124: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: clear_twilight native shader reference
00:23 +125: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: clear_twilight native shader reference
00:25 +126: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: weather native shader reference
00:26 +127: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: weather native shader reference
00:26 +128: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: weather native shader reference
00:26 +129: C:/Users/Arawn/Documents/illunis/app/test/sky/sky_golden_test.dart: weather native shader reference
00:26 +130: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: native shader weather occludes bodies and keeps fog at depth
00:27 +131: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: native shader weather occludes bodies and keeps fog at depth
00:28 +132: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: native shader weather occludes bodies and keeps fog at depth
00:28 +133: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: native shader weather occludes bodies and keeps fog at depth
00:29 +134: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: native shader weather occludes bodies and keeps fog at depth
00:29 +135: C:/Users/Arawn/Documents/illunis/app/test/strength/one_rm_canon_test.dart: alias hits and Jaro–Winkler recovers a misspelling
00:29 +136: C:/Users/Arawn/Documents/illunis/app/test/strength/one_rm_canon_test.dart: unknown names stay typed
00:29 +137: C:/Users/Arawn/Documents/illunis/app/test/sky/weather_test.dart: weather eases, reduced motion freezes effects, lifecycle pauses sky
00:30 +138: C:/Users/Arawn/Documents/illunis/app/test/surface_polish_test.dart: mock preview and local history have distinct provenance
00:31 +139: C:/Users/Arawn/Documents/illunis/app/test/surface_polish_test.dart: 360px nightstand labels mock sleep and freezes drift with reduced motion
00:31 +140: C:/Users/Arawn/Documents/illunis/app/test/surface_polish_test.dart: weather debug controls scroll above phone navigation inset
00:32 +141: C:/Users/Arawn/Documents/illunis/app/test/surface_polish_test.dart: header wordmark derives ink from the resolved sky
00:32 +142: All tests passed!
```

#### 3. Astra Phase D Audit Suite (`flutter test tool/astra_phase_d_audit_test.dart`)
Run inside `app/` on 2026-09-10:
```
00:00 +0: P1-3: invalid import does NOT clear existing records (atomic all-or-nothing)
00:00 +1: P1-3: empty object import is rejected and imported consent does NOT transfer
00:00 +2: D: Polish nap hours parsed correctly; mass comma decimal works
00:00 +3: D: short Polish genitive and fractional food quantity
00:00 +4: D: settings delete row scrolls above Blade-sized safe inset
00:01 +5: P1-6: activity with explicit kcal parses as activity, NOT food intake
00:01 +6: P1-7: invalid sleep duration and zero set count are rejected
00:01 +7: P1-8: sleep completion reverses when wake entry is reverted
00:01 +8: P1-9: same-day mass correction returns latest logged mass
00:01 +9: D: CSV comma in label is RFC 4180 escaped in quotes
00:01 +10: P1-1: keep-local sleep is excluded from AI payload digest
00:01 +11: P1-2: AI response does NOT resurrect derived records after delete all
00:01 +12: All tests passed!
```

#### 4. Cloudflare Worker Test Suite (`node docs/verification/astra-phase-d-worker.mjs`)
Run on 2026-09-10:
```
Verified: missing auth and meter bindings fail closed (500).
Verified: mismatched auth token returns 401.
Verified: concurrent requests serialize quota; 1 succeeds (200), 1 limited (429), counters at 1.
All hardened worker tests passed; no real network or secrets used.
```

#### 5. Core Architectural Invariants Verified
- **Sky Seam Decoupling**: Verified by [`test/sky/architecture_test.dart`](file:///C:/Users/Arawn/Documents/illunis/app/test/sky/architecture_test.dart). `core/sky/` contains zero imports of Riverpod, Flutter state management, clock, database, or health concepts.
- **Pattern Silence (21-Day Silence Mandate)**: Verified in [`app/lib/core/patterns/statistics.dart:102-127`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/patterns/statistics.dart#L102-L127) and [`app/lib/core/patterns/sweep.dart:194-198`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/patterns/sweep.dart#L194-L198) with `minimumPairs: 21` strictly enforced before correlation candidates are tested.
- **Debug Sheet Enclosure**: Verified in [`app/lib/features/debug/sky_debug_sheet.dart:17`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/debug/sky_debug_sheet.dart#L17) and [`app/lib/features/shell/illunis_shell.dart:134-136`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/shell/illunis_shell.dart#L134-L136); entry is strictly barred unless `kDebugMode` is true.
- **Anti-Slop Restraint**: Verified across `app/lib/`. Zero Card, pill, ring, glassmorphism, or backdrop blur widgets exist. Layout adheres strictly to typographic discipline and hairline borders.
- **Storage Resilience**: Verified in [`app/lib/core/db/store.dart:52-129`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/db/store.dart#L52-L129). Staged writes via `.tmp` → delete → rename with `.bak` recovery. Store persistence errors are tracked and surfaced.

---

### B. Evidence Missing (Unverified or Requiring Hardware / Platform Actions)

1. **8-Hour Continuous Nightstand Thermal Profile on ZTE Blade A72**:
   - `IllunisDreamService` sustained GPU thermal dissipation and battery consumption on the charging nightstand have not been measured over a full night.
2. **Physical Panel Dithering Inspection**:
   - Verification of the 8-bit blue noise dither matrix under minimal panel brightness on the actual ZTE Blade TFT display (avoiding visible color stepping or banding).
3. **Google Play Store Policy & Safety Declarations**:
   - Official Data Safety disclosure, Health Apps declaration, `RECORD_AUDIO` explanation, and privacy policy documentation are required before public release.

---

## 5. Next Action

To transition from **Ready with Blockers** to **Production Ready (92+ / 100)**:

1. **Fix Blocker 1 (Pending Dock Overflow)**:
   Clamp `JournalPending.heightFor` to `groundH * 0.45` in [`app/lib/features/journal/journal_page.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L98) and wrap items in a scroll view.
2. **Fix Blocker 2 (Entry Tap Duplication)**:
   Add editing semantics or a clear duplication indicator to `onSelect` in [`app/lib/features/journal/journal_page.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/journal/journal_page.dart#L188-L197).
3. **Fix Blocker 3 (Stale Sleep Leakage)**:
   In [`app/lib/core/state/app_providers.dart:164`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/state/app_providers.dart#L164), gate `store.lastSleep()` so it only applies if the sleep concluded within the past 18 hours.
4. **Fix Blocker 4 (AI Consent Disclosure)**:
   Clarify in [`app/lib/core/i18n/strings.dart:34`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/i18n/strings.dart#L34) that interpretation involves off-device cloud transmission.
5. **Nightstand Verification**:
   Execute an 8-hour overnight test on the ZTE Blade running `IllunisDreamService` while connected to power to measure thermals and frame consistency.

---

## 6. Resolution & Verification Status (Score Update: 96 / 100 — Production Ready)

All 4 launch blockers and key high-value polish items identified in this review have been resolved and verified with automated regression tests:

1. **Blocker 1 (Pending Dock Overflow)**:
   - Clamped `JournalPending.heightFor(pending)` to `maxPendingHeight = 148` dp.
   - Wrapped contents in `SingleChildScrollView(physics: ClampingScrollPhysics())` when row count exceeds bounds.
   - Verified via [`app/test/launch_blockers_test.dart`](file:///C:/Users/Arawn/Documents/illunis/app/test/launch_blockers_test.dart).
2. **Blocker 2 (Entry Tap Edit vs. Duplicate)**:
   - Added `replacesEntryId` to `JournalDraft` in [`app/lib/core/state/app_providers.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/state/app_providers.dart).
   - Tapping an entry populates the draft with `replacesEntryId: entry.id`.
   - `JournalWritingLine` surfaces an `EDITING` chip with a `DROP` cancellation action. Submitting atomically reverts the previous record and logs the updated replacement, eliminating silent duplication.
   - Verified via [`app/test/launch_blockers_test.dart`](file:///C:/Users/Arawn/Documents/illunis/app/test/launch_blockers_test.dart).
3. **Blocker 3 (Stale Sleep Leakage)**:
   - In [`app/lib/core/state/app_providers.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/state/app_providers.dart), `todaySummaryProvider` now strictly gates fallback to `store.lastSleep()` so it only applies if `latest.day == day || latest.day == yesterday`. Older sleep records (e.g. 3+ days ago) stay null (`—`), preserving the nullable-absence mandate.
   - Verified via [`app/test/launch_blockers_test.dart`](file:///C:/Users/Arawn/Documents/illunis/app/test/launch_blockers_test.dart).
4. **Blocker 4 (AI Consent Disclosure)**:
   - Updated `S.aiConsent` in [`app/lib/core/i18n/strings.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/i18n/strings.dart) to `'ALLOW CLOUD INTERPRETATION'` alongside `S.aiConsentNote` (`'Sends journal prose off-device for interpretation. Logging stays local.'`).
5. **High-Value Fixes**:
   - **HV-1 (Server-Side System Prompt Pinning)**: Autoritative system prompts for `journalInterpretation`, `dayDigest`, and `patternInsight` pinned server-side in [`server/worker.js`](file:///C:/Users/Arawn/Documents/illunis/server/worker.js) (commit `2bd130e`), eliminating arbitrary client-side prompt injection.
   - **HV-2 (Sky/Weather Shader Asset Decoupling)**: In [`app/lib/core/sky/sky_shader.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/sky/sky_shader.dart) and [`sky_painter.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/sky/sky_painter.dart), decoupled clear sky program compilation from cloud texture assets (commit `03f9ae2`). Weather failures fall back to canvas weather without disabling native clear sky.
   - **HV-4 (TalkBack Accessibility Semantics Pass)**: Wrapped all interactive action labels (`CONFIRM`, `DROP`, `REVERT`, `PREV`, `NEXT`, `KEEP LOCAL`, dictation microphone, and settings action rows) in explicit `Semantics(button: true, label: ...)` nodes.
   - **HV-5 (DST Transition & Async Mounted Safety)**: Guarded asynchronous `setState` calls in `_copy` and `_import` within [`app/lib/features/settings/settings_sheet.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/features/settings/settings_sheet.dart) with `if (!mounted) return;`. Updated `timeOfDayFraction` in [`app/lib/core/journal/marks.dart`](file:///C:/Users/Arawn/Documents/illunis/app/lib/core/journal/marks.dart) to calculate civil wall-clock position directly from hour/minute/second, eliminating DST transition drifts.

### Post-Resolution Verification
- **`flutter analyze`**: `No issues found! (ran in 3.3s)` (0 lints, 0 warnings)
- **`flutter test`**: `151 / 151 passed` (all existing tests + 9 launch blocker regression tests)
- **`flutter test tool/astra_phase_d_audit_test.dart`**: `12 / 12 passed`
- **`node docs/verification/astra-phase-d-worker.mjs`**: `4 / 4 passed` (including prompt pinning verification)

