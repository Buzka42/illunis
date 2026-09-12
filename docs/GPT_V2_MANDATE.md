# GPT / Astra v2 implementation status

Started 2026-09-11 from `PLAN_V2.md`. Existing Gemini data-track edits are
preserved. No commits or pushes.

## First delivered increment: E5 calorie dots

The 48 dp timeline displays confirmed intake in muted green and confirmed
activity burn in muted red. Radius and opacity increase with calories and
saturate at 1,000 kcal. Separate lanes preserve intake and burn logged at
the same time; the sun path and sky seam are unchanged.

`app/lib/features/timeline/calorie_marks.dart` aggregates each journal page
by direction. Placement uses the page's civil-clock timestamp. It does not
infer meal times, distribute wearable daily totals, or invent basal burn.
Pending, non-positive, non-finite, orphaned, and other-day values are omitted.
Confirmed estimates follow the journal's existing confirmation contract.
Screen-reader semantics state direction, calories, time, and timestamp origin.
Date selection follows the current civil day on scene updates; browsing an
older journal page does not change the track.

Verification: four new tests cover aggregation/direction, absence filtering,
bounded visual weight, and a 360 dp-wide / 48 dp-high timeline with semantics.
Full `flutter test --reporter expanded`: **193 passed**. Blade hardware
walkthrough and v4 captures remain outstanding.

## Subsequent delivery — 2026-09-12

- E1: compact Dashboard and paginated Journal, bottom navigation removed,
  title long-press Settings and debug wordmark gesture retained. Ordinary
  Blade layout does not scroll; short windows and enlarged text retain an
  accessibility scroll fallback. Pending confirmation stays bounded at 148 dp.
- E2 display: current weather, 24-hour forecast sheet, explicit source/refresh,
  and rain/snow/hail timeline symbols. Epoch timestamps preserve instants;
  missing temperatures remain absent. Source/home changes invalidate old
  observations and in-flight requests. See `WEATHER_V2.md`.
- E3 display: burn, intake, steps, sleep, resting heart rate, active minutes,
  restedness and strain, with source labels and supported source preferences.
  Wearable connect/refresh uses the existing bridge. Sleep remains journal-first.
- E4: daily summaries and eligible learned findings render above the horizon.
  Two taps dismiss a letter; dismissal persists and resets on the next civil
  day. Learned findings require 21 paired days. Daily summaries do not.
  `AI_SYSTEM_DESIGN.md` records finalized prompts, budgets, consent and deletion
  design, and backend gaps. Worker daily-summary/restedness prompts are pinned.
- E5: compact performance rows use existing rollups; tapping the 1RM row
  cycles exercises.
- E6: skippable first-run guide with persisted version and Settings re-entry;
  gesture explanations, source preferences, wearable nudge, weather controls,
  and honest descriptions of currently available consent controls.
- Civil-day rollover updates today's figures, timeline and letter dismissals
  while retaining a deliberately selected catch-up date.

## Verification and remaining integration

Automated coverage includes Blade-size surface pagination, large pending queues,
Settings/guide access, source persistence, calorie marks, midnight rollover,
letter eligibility/dismissal, weather mapping and stale request rejection.
Widget captures are in `captures/v4/`; these are not device screenshots.
Current test/analyzer output is recorded under `docs/verification/v2-*`.
Full suite on 2026-09-12: **201 tests passed**, including first-run guide
completion/reload. The hardened worker harness also passed with mocked network.

No Android device was attached for a Blade walkthrough. Physical-device layout,
Health Connect permission flow, thermal measurements and live forecast behavior
still need device verification. GPS selection is not implemented; weather uses
the Settings home. Forecast cache is in memory and refresh is explicit.

Gemini Flash transport, validated structured responses, new three-tier cloud
consents, cloud persistence and remote deletion are not enabled by this work.
The guide does not represent those planned capabilities as available.

Cloud storage remains a design/wiring task, not an enabled feature. The
owner-approved reopened doors in PLAN_V2 must be recorded in DECISIONS when
their implementation lands, with the actual retention/deletion behavior.
