# Illunis — Launch Plan (aggregated pre-launch review)

2026-09-10, ~22:00. Aggregator: illunis-dev (muse spark). Inputs: GLM 5.3
review (74/100, verified claim-by-claim), Antigravity review
(`antigravity-launch-review.md`, 84/100 sideload / 72 Play — its §6 fixes
confirmed in the tree), Astra A–C + Phase-D handoff (P1 done, P2 open).
All work committed and pushed to `master`. Kimi K3 contributed nothing
(shared opencode-go quota dried up mid-run, retry stalled, killed).

## Verdict

**84/100 — ready with blockers cleared, sideload channel** (single
informed owner-user, debug APK on the Blade, per `docs/HANDOFF.md`).
**Play / public distribution: 72/100, not cleared** until the owner
actions (hosted policy URL, channel call) plus the overnight thermal run
land. Every fix below was confirmed in code during aggregation, and the
full suite is green: `flutter analyze` clean, 151 `flutter test` green,
12 audit probes green, 4/4 worker checks green (incl. prompt-pinning).

## Blockers — all cleared

1. **Boot recompute did D full-store writes before first frame** (GLM).
   `recomputeSummaries` now wraps the day loop in `store.transaction`
   (`rollups.dart:30`) — one write per boot/import.
2. **Persistence failure was silent** (GLM). `_submit` no longer swallows
   (`journal_page.dart:486-492`); store + submit failures surface as a
   `NOT SAVED` hairline line under the writing line (`:528, :639`).
3. **Consent copy hid cloud transmission** (GLM + Antigravity, converged).
   Landed stronger: `ALLOW CLOUD INTERPRETATION` + disclosure subline
   (`strings.dart:34-36`, `settings_sheet.dart:145`).
4. **Pending dock overflowed the pager on 8–11 item meals** (Antigravity).
   `JournalPending` clamped to 148 dp max + scrolls
   (`journal_page.dart:99-145`). Covered by `launch_blockers_test.dart`.
5. **Tap-to-edit silently duplicated records** (Antigravity).
   `replacesEntryId` + `EDITING` chip with `DROP`; submit atomically
   reverts-then-replaces (`app_providers.dart:89-93`,
   `journal_page.dart:219,446-477`). Covered by `launch_blockers_test.dart`.
6. **Stale sleep leaked into today** (Antigravity). `todaySummaryProvider`
   gates `lastSleep()` to today/yesterday only; older stays null (`—`).
   Covered by `launch_blockers_test.dart`.

## High-value fixes — landed

- HV-1 worker prompt-trust: three system prompts pinned server-side per
  call (`server/worker.js`, commit `2bd130e`); client `system`/`user` no
  longer forwarded blindly. `MAX_GLOBAL` still at 4000/day; KV/mutex cap
  remains approximate across isolates — accepted, noted.
- HV-2 sky/weather resource split: clear-sky program compiles
  independently; weather-asset failure falls back to canvas weather
  instead of killing the native sky (`sky_shader.dart`, `sky_painter.dart`,
  commit `03f9ae2`).
- HV-3 lifecycle + reduced motion: `SkyStateSource.setSuspended` with real
  suspend in both sources; shell drives it from app lifecycle; `SkyView`
  repaints ~10 fps under `disableAnimations` while easing continues.
- HV-4 TalkBack + `mounted`: `Semantics(button,label)` on mic, KEEP LOCAL,
  PREV/NEXT, CONFIRM/DROP/REVERT, settings rows; async `setState` guarded
  in the settings sheet.
- HV-5 DST: `timeOfDayFraction` now civil hour/minute/second arithmetic —
  no 23/25-hour drift (`marks.dart`).

## Still open (not code)

- **Overnight DreamService thermal run.** Logging loop active
  (`thermal-night.csv`, 5-min samples); phone keeps dropping off USB
  (known transport flakiness). Needs: Blade on charger + Illunis
  screensaver + stable USB for one night. Then decide: drop
  `isScreenBright`, cap dream fps, or freeze decorative time.
- **Play owner actions** (`PLAY_CHECKLIST.md`): host `PRIVACY_POLICY_DRAFT.md`,
  add URL to listing + Settings, channel call, per-file backup split if
  review demands it. Backup decision recorded (`DECISIONS.md` → Backup):
  auto-backup stays on as the only durability story for sideload.
- **Astra P2 remainder** (post-launch sequencing): unknowns/freshness P2-10,
  Polish corpus vs 40 real meals P2-11, stats validation P2-13, release
  scrub gate P2-15.

## Explicitly not launch work

Drift migration, `health`-package/Health Connect, food DB (OFF vs USDA
before the 40-meal corpus), star precession, constellation lines, GPS —
all still closed per `docs/DECISIONS.md`. No seeding of history.

## Verify per change

`cd app && flutter analyze && flutter test` after each item; debug APK
reinstall via the HANDOFF `adb` sequence (never `flutter install`).
Current baseline (2026-09-10 ~22:00): analyze clean, 151 + 12 green,
worker 4/4 offline. Fresh `app-debug.apk` with all fixes is installed on
the Blade; data preserved.
