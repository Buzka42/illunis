# Illunis v2 — UI Overhaul + Weather + Wearables + AI Insights

Owner-directed scope, 2026-09-10. This is POST-launch work: nothing here
changes the 84/100 sideload verdict. Read `CURSOR_MANDATE.md`, `PLAN.md`,
`docs/DESIGN.md`, `docs/DECISIONS.md`, `docs/BACKEND_PLAN.md`,
`docs/HANDOFF.md`, `docs/ASTRA_MANDATE.md`, `docs/ASTRA_HANDOFF.md` first.

Design law carries over unchanged: no pills/cards/rings/glass, instrument
voice (Inter + JetBrains Mono, hairlines, glyphs), sky seam stays dumb,
nullable-absence everywhere, debug sheet debug-only.

## Closed doors this plan REOPENS (owner has approved; record in DECISIONS)

1. **GPS / location.** Was: Settings home only, no GPS. Now: weather needs
   a place. Recommendation: onboarding offers Settings-home (default,
   current behavior) or device GPS fix; GPS used ONLY to fetch weather,
   never stored, never leaves the device except as lat/lon inside a
   weather-API request. If GPS is refused, fall back to home.
2. **Health Connect.** Was: Phase 3, `health` package skipped to keep
   Windows buildable. Now: wearables are a headline feature. Consequence:
   Android-only data path behind a platform interface; Windows/desktop
   keeps journal-calculated figures. Do NOT break `flutter analyze` on
   desktop — gate with conditional imports, same pattern as dictation
   fallback (mic → keyboard).
3. **Server-side health data.** Was: device is canonical, no account, no
   developer DB. Now: optional cloud store for daily insights. This is the
   biggest decision in the file: it needs its own consent distinct from
   interpretation consent, a retention/deletion story, Data Safety
   updates, and the privacy policy rewrite BEFORE any Play submission.
   Default stays local-only; cloud is opt-in per insight tier.

## E1 — Compact no-scroll surfaces (GPT Astra builds)

- Journal and Dashboard each fit their surface with zero scrolling on the
  Blade (1080×2412, minus nav). Pack dense; cut air, not legibility.
- Drop the bottom bar. Journal/Dashboard switch becomes slide-only on the
  existing pager (yaw stays). MUST preserve entry points the bar
  currently hosts: Settings (long-press surface title stays), debug sheet
  (long-press ILLUNIS stays) — restate them in the onboarding so the
  gestures are discoverable without chrome.
- Dashboard content, in order: weather strip (E2) → life stats (E3) → sun/
  moon figures (keep) → performance metrics (E5). Insights section is
  DELETED from Dashboard; insights live on the sky (E4).
- Journal stays a writing surface + pending dock (148 dp clamp stays) +
  day list; compact the same way.

## E2 — Weather module (GPT builds UI + timeline; data seam first)

- Onboarding lets the user pick the weather source (e.g. Open-Meteo
  default vs alternatives; owner decides the list). No keys in repo; no
  runtime fetch in `core/sky/`.
- Display: current + 24 h projection, sunrise/sunset (already have),
  current/projected temp, precipitation chance. Rain/snow/hail renders
  OVER the timeline as subtle glyphs; presence/size follows intensity ×
  probability. Follows the existing `SkyWeather` nullable pattern: null =
  unobserved, renders clear-looking; a met-data `SkyStateSource` plugs in
  with zero `core/sky/` changes (same seam Astra documented).
- Weather fetch + normalization lives OUTSIDE the sky seam, same as
  `LocalSkyStateSource`. Cache last good observation; stale policy is the
  source's job (suggest: >3 h = null it back to absence).

## E3 — Life stats (data: Gemini/agy; display: GPT)

Six tiles, each with an explicit source, chosen in onboarding and
changeable in Settings:

1. **Calories burned** — wearable OR journal-calculated (suggest journal
   when the wearable is low-grade; say so in onboarding copy).
2. **Calorie intake** — journal (unchanged parser path).
3. **Steps** — wearable/phone pedometer, plus manual journal entry
   (`parser.dart` learns `steps`/`kroki` + number words; same bounds
   discipline as other quantities).
4. **Sleep** — wearable; journal stays the fallback and the canonical
   record when both exist (journal wins ties — it is reviewed text).
5. **Resting HR** — wearable only; absence = `—`, never estimated.
6. **Active minutes** — wearable OR derived from logged sessions.
7. **Restedness** — AI-evaluated from sleep/training/HR (E4); labelled by
   provenance (AI vs rule) the way MOCK/LOCAL are labelled today.

Health Connect bridge is Android-only behind a platform interface;
desktop falls back to journal-derived figures without breaking the build.

## E4 — Sky-letter insights + AI system (GPT designs, Gemini/agy wires)

- Insights render AS LETTERS ON THE SKY through the day (instrument
  voice, `typography.dart`, never cards). One insight visible at a time
  or a quiet rotation — GPT decides, compactness wins.
- Dismiss: first tap arms (`tap again to dismiss` microcopy), second tap
  dismisses that insight. Dismissed stays dead until the next civil day;
  all insights reset at midnight rollover (respect the civil-day source,
  not 24 h arithmetic).
- **Scope rule vs the 21-day mandate:** daily AI insights (restedness,
  "yesterday's surplus + tonight's bedtime") are NOT learned patterns and
  may run from day one on submitted/available data; *learned* correlations
  ("sleep → performance") stay silent until 21 paired days. Keep the two
  visually distinct so the silence promise stays legible.
- Data flow: insights compute either on-device from the local store, or
  — if the user opts into cloud storage (closed-door #3) — from submitted
  snapshots via the worker. Journal-submit-for-insights (no stored history)
  is the middle tier: one-shot, retained only per the retention policy.
- GPT delivers an `AI_SYSTEM_DESIGN.md`: insight catalog (trigger, inputs,
  provenance label, cadence), Gemini call map (which insight → which
  worker call + schema), prompt-pinning additions to `server/worker.js`
  (extend the 2bd130e pattern — every new call gets a pinned prompt), cost
  caps per insight, and the retention/deletion matrix for the three tiers.
- Owner provides the Gemini key at build time: worker env for cloud calls,
  never in the repo, never in the APK (same rule as the current worker
  token — and note the token-extractability call in PLAY_CHECKLIST.md
  applies to any key shipped client-side, so prefer worker-side calls).

## E5 — Timeline calorie dots + performance metrics

- Timeline shows intake/burn placement through the day: intake green dots,
  burn red dots, dot weight/alpha scales with kcal. Same hairline voice;
  dots sit on the existing 48 px timeline, sun path untouched.
- Performance tracking: per-exercise 1RM (Epley/Brzycki already in tree),
  plus rolling volume/strain baselines (28-day window exists) surfaced as
  compact figures, not charts. New metrics need the same honesty rules:
  absence = `—`, estimates excluded, provenance labelled.

## E6 — Onboarding tutorial

Short, skippable, re-runnable from Settings. Must teach: slide-only
navigation + long-press gestures (Settings/debug), the 21-day silence
promise, KEEP LOCAL, the two/three AI data tiers with separate consents,
per-stat source choice (with the low-grade-wearable nudge), weather
source + GPS choice. Functional copy only, zero fluff.

## Task split + run order (Gemini-first, decided 2026-09-10)

GPT limits reset ~40 min after this writing, so **Gemini/agy runs first
on the data layer**, GPT follows on UI. Rule: Gemini stays off anything
GPT's UI will redefine (no layouts, painters, or `typography.dart`).

**Gemini/agy brief (paste-ready):**

> Illunis v2 data track (agy, READ-ONLY first, then build). Repo:
> `C:/Users/Arawn/Documents/illunis`. Read `docs/PLAN_V2.md` first, then
> `docs/DECISIONS.md`, `docs/BACKEND_PLAN.md`, `docs/HANDOFF.md`.
> Build ONLY these (GPT owns all UI/display):
> 1. Health Connect bridge (Android-only) behind a platform interface
>    with journal-derived fallback so desktop still analyzes/builds
>    (conditional imports; dictation-fallback pattern). Sources: steps,
>    sleep, resting HR, active minutes, calories burned. Journal wins
>    ties. Absence stays null end-to-end.
> 2. Steps in the journal parser (`steps`/`kroki` + number words + comma
>    decimals, same bounds discipline; tests included).
> 3. Weather data seam: source-agnostic fetcher (default Open-Meteo,
>    switchable via string pref for onboarding to own later) + cache +
>    staleness rule (>3 h → null). Emits onto the nullable `SkyWeather`
>    pattern; no `core/sky/` changes, no GPS yet, no keys in repo.
> 4. Worker AI plumbing: extend the `2bd130e` pinned-prompt pattern with
>    stub calls for `restedness` + `dayDigest` (schemas + caps +
>    fail-closed; prompts finalized by GPT's design doc).
> 5. Performance rollups: 1RM + rolling volume/strain baselines as pure
>    store functions with absence/`—` honesty; no display code.
> Verify: `cd app && flutter analyze && flutter test` green, new tests
> per item. No commits, no pushes. Report: files changed, test delta,
> and the exact interfaces GPT's UI must consume (provider names,
> function signatures).

**GPT mandate** (`docs/GPT_V2_MANDATE.md`, written when limits reset):
E1 + E2-UI + E4-render + E5-dots + `AI_SYSTEM_DESIGN.md` (finalizes the
worker prompts Gemini stubbed), screenshots to `captures/v4/`, same
verify, no commits. Complex coding overflow also goes to GPT only if agy
stalls — default stays agy.

## Verify per track

`cd app && flutter analyze && flutter test` after each item; new tests
for: no-scroll layout at Blade dimensions (overflow assertions),
timeline dots, insight dismiss/reset state machine, source-choice
persistence, Health Connect absence fallback, staleness → null weather.
Blade walkthrough before anything merges to the launch line.

## V2 status (assessed 2026-09-12, illunis-dev)

GPT finished its track. Tree: 26 modified files + 3 new modules
(`wearables/`, `fitness/performance/`, `civil_day.dart`), ALL
UNCOMMITTED. Verify: analyze clean, **201/201 tests green** (50 new:
surfaces, calorie marks, rollover, letters/dismissal, weather seam,
Open-Meteo mapping, guide).

Landed: E1 compact surfaces + slide-only (bottom bar gone, long-press
entry points retained), E2 weather display + timeline glyphs +
Open-Meteo source/cache/3 h-staleness, E3 stat tiles + bridge interface,
E4 sky letters + two-tap dismiss + civil-day reset + pinned
dayDigest/restedness prompts with per-call caps, E5 calorie dots +
performance rollups, E6 versioned guide, `AI_SYSTEM_DESIGN.md` contract,
DECISIONS updated. Sky seam untouched, no new platform deps.

NOT done (in order): (1) real Health Connect native calls —
`MainActivity` channel is stubbed (false/null), so wearables read as
absent everywhere; biggest remaining coding item. (2) No Blade
walkthrough: no-scroll density, sky letters, dots, weather sheet are
widget-tested only; `captures/v4/` has 2 widget captures, zero device
shots. (3) Worker still calls OpenAI — no Gemini adapter. (4) Cloud
tiers/consents/retention are design-only, correctly not exposed in UI.
(5) GPS not implemented (Settings home only — per plan recommendation).

Launch-line note: the 84/100 verdict covers committed `master`, NOT this
working tree. V2 inherits no verdict until Blade walkthrough + commit.
Phone still runs the pre-v2 debug APK; thermal logging stalled with the
USB drops.
