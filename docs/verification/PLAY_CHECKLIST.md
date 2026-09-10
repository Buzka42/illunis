# Illunis — Play release checklist (prepared 2026-09-10, sideload is the current channel)

Nothing here is submitted. Each item is filled as far as the tree allows;
owner actions are marked YOU.

## Data Safety answers (from code, verify at submit time)

- Data collected on-device, never leaves unless consent is ON: journal
  text, sleep/activity/food/weight figures, derived day summaries
  (`app/lib/core/db/`, `app/lib/core/health/rollups.dart`).
- Data shared with third parties only when `ALLOW INTERPRETATION` is ON:
  journal prose + daily figures → developer Cloudflare worker → OpenAI
  (`transport.dart:37-84`, `server/worker.js:108-133`). No sharing when off.
- Location: not collected (observer is the Settings home, no GPS).
- Microphone: system speech recognizer only; audio is not recorded or
  stored — words land in the text field (`dictation.dart`).
- Personal info: none collected by design; the user may type anything
  into a free-text journal (say so honestly).
- Security in transit: TLS to the worker; at rest: OS storage only.
- Deletion: `DELETE ALL DATA` in Settings wipes the store on-device.
- Account: none exists.

## Health apps declaration

Sleep, activity, weight, nutrition logging = health features. Declare
them; expect the health-apps review path, not the standard one.

## RECORD_AUDIO rationale (for the declaration + store listing)

"Dictation: the journal microphone transcribes entries via the system
speech recognizer. Denied/missing recognizer falls back to the keyboard."

## APK token risk call

The worker bearer token ships via `--dart-define` (`transport.dart:10`)
and is extractable from the APK. Impact if extracted: burns the shared
quota (40/install/day is client-minted IDs, so the 4000/day global cap
is the real bound). Before Play: per-release token, lower `MAX_GLOBAL`,
pin the three system prompts server-side (HV-1), rotate on abuse.

## Privacy policy

Draft at `PRIVACY_POLICY_DRAFT.md` (same folder). YOU: host it and put
the URL in the store listing + in-app settings link.

## YOU before submit

1. Choose the channel (stays sideload until you say otherwise).
2. Host the privacy policy; add the link to Settings (one `_Line`).
3. Run the overnight thermal measurement (Blocker 4) and keep the numbers.
4. Revisit the backup decision (`docs/DECISIONS.md` → Backup) with a
   per-file consent split if auto-backup + consent migration is
   unacceptable to review.
