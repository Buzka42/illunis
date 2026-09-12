# Daily and learned insights — v2 contract

Version 1, 2026-09-12. This is the implementation contract for the remaining
Gemini/agy wiring. Local summaries and learned findings now render as letters
on the sky. No new cloud calls or cloud storage are enabled by this UI pass.

## Catalog and cadence

| Insight | Trigger and required inputs | Label | Cadence and silence |
|---|---|---|---|
| Day digest | Confirmed same-day intake, movement, or completed sleep; retain missing fields as null | DAILY · RULE locally; DAILY · AI for a model sentence | Local recomputation on record changes from day one; explicit AI submission only |
| Restedness description | Completed sleep and a provenance-labelled local rule score; training and resting HR only if actually observed and dated | DAILY · AI; numeric score remains a rule calculation | At most once per input revision, two requests per server UTC day; null score when required evidence is absent |
| Learned relationship | Existing statistical sweep result, at least 21 paired days, effect/FDR gates, pair ID, n/r/evidence | LEARNED · LOCAL; future rewording uses LEARNED · AI | Recompute locally on record revision; no daily-summary exemption from the 21-pair gate |

No fabricated first-week history. A model may describe a rule score, but it
does not validate that score or invent a new physiological metric. No medical
claims, causal claims, universal HR cutoffs, training prescriptions, or
bedtime prescriptions. Yesterday's observed surplus can be described when
explicitly dated; it does not justify inventing tonight's bedtime.

One letter is visible at a time. NEXT selects another without animation or
timed rotation. First tap arms dismissal; second dismisses that stable catalog
ID for the current device civil day. Dismissals persist in the local profile.
At the next civil day they cease applying, even after background/resume or
process restart. Debug sky time does not change the dismissal day. Midnight
also refreshes current-day figures while preserving explicit catch-up browsing.

## Worker call map

The existing endpoint accepts POST `{system,user,responseSchema}` with
`x-illunis-call`, `x-illunis-install`, and its configured bearer token.
Systems for `dayDigest` and `restedness` are now pinned and mirrored in
`app/lib/core/ai/prompts.dart`. The client cannot replace those worker systems.

| Product action | Worker call | Input JSON carried as user string | Result |
|---|---|---|---|
| Submit day summary | dayDigest | civilDay, timeZoneOffsetMinutes, revision, confirmed figures with source and observation date; absent quantities null | `{sentence: string}`; ≤140 characters, empty means silent |
| Describe restedness | restedness | civilDay, revision, completed sleep, local rule score/provenance, optional observed training and RHR | `{score: number or null, reason: string}`; score must equal supplied rule score, reason ≤140 characters |
| Reword learned findings | patternInsight | Eligible pair IDs, n, r, evidence and local sentences only | `{sentence: string}`; no new findings or claims |

Important implementation gap: the current worker calls **OpenAI**, despite
the Gemini-first task naming. Gemini/agy must supply a server-side Gemini
adapter before these are presented as Gemini features. Its key belongs only
in worker secrets. Preserve these product schemas and pinned systems across
that adapter; never ship a provider key in the APK. Existing client methods
are plumbing, not consent or automatic scheduling.

Before enabling either new AI action, validate the snapshot server-side,
pin schemas as well as prompts, bound numeric fields, reject unconfirmed or
undated inputs, and validate decoded responses again on the client. Restedness
must reject score changes and non-finite/out-of-range values. Keep local
figures visible on timeout, denial, quota exhaustion, or malformed output.
Hash the eligible snapshot to invalidate cached wording after edits/REVERT.
Aggregate only entries eligible for AI: KEEP LOCAL exclusions must happen
before summation, including sleep amendments. A ready-made daily summary may
contain excluded records and must never be submitted wholesale.

## Cost limits

Implemented worker request caps: dayDigest **2**, restedness **2** per install
per UTC day. Existing overall defaults remain 40 per install and 4,000 global;
patternInsight remains capped at 5. Failed upstream requests consume a
reservation. Current per-isolate locking is not a globally atomic limit;
move reservations to a Durable Object before treating them as a hard spend cap.

Required Gemini adapter limits: ≤2,000 input tokens and ≤128 output tokens per
daily insight; one request per revision, no automatic retries, 15-second
deadline, no call from a repaint or sky tick. At most four daily insight calls
give ≤8,000 input and ≤512 output tokens per install per day. Cost is those
token counts multiplied by the chosen model's verified deployment rates;
no fixed currency claim is made without selecting the model and tariff.
The existing worker's character limits are not token limits. These adapter
token ceilings are a wiring requirement, not a claim about the current worker.

## Consent, retention and deletion matrix

| Tier | Consent | Worker payload storage | Local storage | Deletion / retention |
|---|---|---|---|---|
| Local only (default) | None for local calculations | None; no request | Canonical journal, rollups, wording and dismissal IDs | User DELETE ALL / REVERT; local backup policy remains the sideload policy |
| Submit once (not enabled) | Separate explicit insight-submission consent plus per-submit review; interpretation consent does not grant this | Request memory only; no health payloads in logs, KV, traces, queues, or analytics | Keep chosen response with revision/provenance until replaced or deleted | Release request references after response/timeout; quota metadata expires after 48 h. Upstream retention must be verified and disclosed before activation |
| Cloud history (not enabled) | Additional, separately revocable storage consent; never implied by either other consent | Proposed bounded daily snapshots, no raw prose | Device remains canonical | Proposed 35-day rolling TTL; immediate logical deletion/revocation and purge within 24 h, including derived results; backups must have a documented expiry before activation |

The cloud-history row is a target contract, not existing infrastructure or an
active privacy-policy promise. It requires per-install authenticated identity
and a deletion credential; the shared application token is insufficient.
Provide export/delete endpoints and a verified deletion test before enabling
the choice. Revocation blocks new uploads immediately. Do not promise deletion
from a model provider without a supported, verified mechanism. Complete the
privacy policy, provider retention disclosure and Play Data Safety update
before any Play submission or activation of stored health snapshots.

## Delivery state

Built: local/available digest and learned-letter display, provenance labels,
two-tap persistent dismissal, civil-day reset, pinned daily systems and lower
daily request caps. Remaining: Gemini adapter, bounded/pinned schemas and
response validation, revision cache, separate consents and submission review,
storage identity/deletion/TTL infrastructure. The guide states these gaps;
it does not offer a consent toggle for an unavailable tier.
