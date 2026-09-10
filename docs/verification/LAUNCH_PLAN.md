# Illunis — Launch Plan (aggregated pre-launch review)

2026-09-10. Aggregator: illunis-dev (muse spark 1.3). Inputs: GLM 5.3
launch-readiness review (`glm-5.3-launch-review.md`, verified claim-by-claim
against the tree below), Astra A–C + Phase-D handoff (`ASTRA_HANDOFF.md`,
P1 implemented, P2 open), current working tree (`master`, uncommitted
Astra work, analyzer clean per GLM run today). Kimi K3 burned two runs
(first wrote no report, retry stalled 3 h with zero progress) and was
killed; Antigravity's parallel review is still pending and folds in on
arrival — it can only subtract from this score, not add.

## Verdict

**74/100 — launchable with caveats, sideload channel only** (single
informed owner-user, debug APK on the Blade, per `docs/HANDOFF.md`).
**Play / public distribution: not cleared (Risky)** until Blockers 3–5
are resolved. Nothing below contradicts the Astra handoff; it converges
with it. The three blockers were independently re-verified in code during
aggregation (cited lines read, not trusted).

## Blockers (in order, each independently verifiable)

1. **Boot recompute does D full-store writes before first frame.**
   `app/lib/main.dart:27-33` awaits `recomputeSummaries(store)` before
   `runApp` (both `main` and `dreamMain`); `rollups.dart:29-33` loops
   `putSummary` per history day outside any transaction; `store.dart:387-392`
   `_persist()`s per call. Fix: wrap boot/import recompute in the existing
   `store.transaction(...)` (`store.dart:36-50`) and/or recompute only today
   + dirty days. Verify: cold-start trace + `flutter test`.
2. **Persistence failure is silent; the journal can become memory-only
   without telling the user.** `lastPersistenceError` is written
   (`store.dart:31,72,91,125,127`) and read nowhere; `_submit` swallows
   (`journal_page.dart:449-457`, `catch (_) {}`). Fix: one hairline
   error line on the journal surface in the existing voice + stop
   swallowing in `_submit`. Verify: failure-injection test, 2× text.
3. **AI consent copy does not disclose health prose leaving the device.**
   `strings.dart:34` (`ALLOW INTERPRETATION`) reads as the local parser
   switch; it actually gates journal prose → worker → OpenAI. Mechanism
   is sound (off by default, consent+age re-checked after network
   returns, KEEP LOCAL end-to-end). Fix: honest label + one disclosure
   line under the toggle. Verify: copy review on the Blade.
4. **No overnight DreamService thermal/battery measurement exists.**
   `isScreenBright + isInteractive` runs the native-res shader all night
   while charging; steady-state p95 (11 ms) is not an endurance result.
   Fix: one full-night run, then decide (drop `isScreenBright`, cap dream
   fps, or freeze decorative time). Nobody else's phone gets the
   screensaver before this.
5. **Play artifacts missing** (only if Play is the channel): Data Safety
   form, health-apps declaration, `RECORD_AUDIO` rationale, privacy
   policy URL, APK-shipped worker-token risk call. Plus decide backup
   semantics: manifest omits `allowBackup`, so Google auto-backup of the
   full health JSON (including consent/age stamps) is silently on while
   clipboard import deliberately excludes them — write
   `allowBackup` + `dataExtractionRules` either way.

## High-value fixes (after blockers, in order)

1. Worker prompt-trust: pin the three system prompts server-side per
   `x-illunis-call` (`server/worker.js:91-97` forwards client-supplied
   prompts; token is APK-extractable, IDs client-minted). Lower
   `MAX_GLOBAL` consideration; note KV/mutex cap is approximate.
2. Sky/weather resource split: `sky_shader.dart:34-43` all-or-nothing
   load makes clear-sky startup wait for weather assets; any weather
   failure kills the native sky. Load independently; degrade gracefully.
3. Lifecycle-gate the source timer (`local_sky_source.dart:16-24`) and
   skip per-frame `setState` under reduced motion (`sky_view.dart:99-135`).
4. TalkBack/keyboard pass: only one `Semantics` node exists app-wide;
   mic, KEEP LOCAL, PREV/NEXT, CONFIRM/DROP/REVERT invisible. Plus
   `mounted` guards on settings-sheet async paths.
5. Cap + scroll the pending dock (`journal_page.dart:90-137`); DST-safe
   civil-day source (P2-14); CSV/share already fixed — confirm on Blade.
6. Astra P2 remainder as sequenced there (unknowns/freshness P2-10,
   Polish Corpus P2-11 against the ~40 real dictated meals, stats
   validation P2-13, release scrub gate P2-15, settings lifecycle P2-17).

## Explicitly not launch work

Drift migration, `health`-package/Health Connect, food DB (OFF vs USDA
before the 40-meal corpus), star precession, constellation lines, GPS —
all still closed per `docs/DECISIONS.md`. No seeding of history.

## Status (illunis-dev build pass, 2026-09-10)

Implemented + verified (`flutter analyze` clean, 142 tests green):

- Blocker 1: `recomputeSummaries` now wraps the day loop in
  `store.transaction` (`rollups.dart:30-36`) — one write per boot/import.
- Blocker 2: `_submit` no longer swallows (`journal_page.dart:457-462`);
  store + submit failures surface as a `NOT SAVED` hairline line under
  the writing line (`:496-498, :568-577`).
- Blocker 3: consent toggle carries `S.aiConsentNote`
  (`strings.dart:35-36`, `settings_sheet.dart:145,191-219`).
- HV-3 (lifecycle/reduced motion): `SkyStateSource.setSuspended` added
  with real suspend in `LiveMockSource`/`LocalSkyStateSource`
  (no-op in the debug capture harness); `IllunisShell` drives it from
  app lifecycle; `SkyView` throttles repaints to ~10 fps under
  `disableAnimations` while easing continues.

Still open: Blocker 4 (overnight DreamService thermal run — phone not on
USB as of 01:00; fresh `app-debug.apk` with all fixes built and waiting),
Blocker 5 remaining owner actions (host policy URL, channel call — paper
side done: PLAY_CHECKLIST.md, PRIVACY_POLICY_DRAFT.md, backup decision in
DECISIONS.md), HV 1–2, 4–6, Antigravity review fold-in.
No commit, no push.

## Verify per change

`cd app && flutter analyze && flutter test` after each item; debug APK
reinstall via the HANDOFF `adb` sequence (never `flutter install`);
one Blade walkthrough of the Blockers 1–3 fixes before anything else
ships. Baseline quoted from GLM's today run: analyze clean (4.1 s),
142 + 12 green, worker 3/3 offline.
