# Permissions, Storage, and Cloud Sync

**Contents**

- [Runtime permissions](#runtime-permissions) — the corpus's single most-repeated bug
- [Local storage](#local-storage) · [Schema and migration discipline](#schema-and-migration-discipline)
- [Multi-device sync](#multi-device-sync-phone--watch-or-any-two-clients)
- [Cloud backup / sync](#cloud-backup--sync-google-drive)
- [Cloud LLM / API access](#cloud-llm--api-access-generally)
- [On-device and hybrid inference](#on-device-and-hybrid-inference) — Firebase AI Logic, AppFunctions
- [The "personal APK" exception](#the-personal-apk-live-credentials-exception)

## Runtime permissions

This is the canonical statement of the permission doctrine. `SKILL.md`, `intake-interview.md` Q8,
`lifecycle.md` and `testing-and-bugs.md` all point here rather than restating it.

**Contents:** [The gotcha](#the-gotcha-that-started-this) · [Essential vs enhancing](#essential-vs-enhancing)
· [In context, at the feature](#request-in-context-at-the-feature) · [Degradation contract](#the-degradation-contract)
· [Permanent denial](#permanent-denial-is-real-and-most-designs-ignore-it) · [Standing checklist](#standing-checklist)

### The gotcha that started this

**The single most-repeated gotcha in the corpus: declaring a permission in the manifest is not enough on API 33/34+.** A real-hardware bug report on a Wear OS app nailed the exact failure mode:

> BODY_SENSORS IS PROBABLY NEVER REQUESTED AT RUNTIME. Declaring it in the manifest is not enough on API 33/34. If the app never calls requestPermissions, Health Services will refuse and monitoring cannot start — and no user without adb could ever get past it.

Treat this as a standing audit item, not something you check once: **every restricted API call needs (a) the manifest declaration, (b) an explicit runtime request on first need, and (c) a re-check immediately before the gated action fires, with a visible reason and a route to Settings if denied.** "Missing required runtime permissions before calling restricted APIs" is also a standing line item in the general adversarial audit (see `testing-and-bugs.md`) — don't treat it as Wear-OS-specific.

Corollary from the same bug report, worth generalizing: **a missing optional input should degrade the feature, never silently block it.** ("Missing today's resting HR must not stop monitoring... fall back to the learned profile value, monitor anyway, and show plainly that it's running on last-known rather than today's figure.") The same logic applies to any permission-gated feature — decide explicitly what the degraded-but-functional state looks like when a permission is denied, rather than leaving the feature just... not working.

### Essential vs enhancing

**Classify every permission before designing anything around it.** Two buckets, and the second is
the default:

| | Means | Test |
|---|---|---|
| **ESSENTIAL** | The app's core purpose is impossible without it | A camera app without `CAMERA`. A step counter without `ACTIVITY_RECOGNITION` |
| **ENHANCING** | A feature is degraded; the app remains genuinely useful | Location that stamps a record. Notifications that remind |

**Enhancing is the default, and the burden of proof is on calling anything essential.** The honest
test is: *with this denied, is there still an app here?* If a user could open it, do the main thing,
and get value, it is enhancing — no matter how central it feels to the implementation. Expect the
count of genuinely essential permissions to be small; a manifest where most of them come out
essential is an audit finding, not a description of the app.

> **The anti-pattern, and it is the common one:** a permission classified essential because it was
> convenient to code against. That is how an app becomes uninstallable-in-practice for someone who
> declines one prompt — they hit a wall on first run and never come back. The classification is a
> product decision wearing an engineering disguise.

**Derive the classification, don't ask for it cold.** Reason from the app's stated purpose (intake
Q1), propose the split, and confirm it in plain words. Record the classification *and the reasoning*
in the spec (`lifecycle.md` Phase 1, item 7) — a bare "essential" that nobody can re-derive gets
re-litigated at the first denial bug.

### Request in context, at the feature

**Request each permission at the moment the user invokes the feature that needs it — not at app
startup, and not in a first-run sequence that front-loads every prompt.** This is the documented
workflow — *"Ask for a permission in context, when the user starts to interact with the feature that
requires it"* (<https://developer.android.com/training/permissions/requesting#principles>), whose
step 3 is *"Wait for the user to invoke the task or action in your app that requires access to
specific private user data"* — and it is a Play quality criterion. `Runtime_Permissions` reads *"App
requests runtime permissions when the functionality is requested, rather than during app startup,"*
and its test verifies the requests fire lazily
(<https://developer.android.com/docs/quality-guidelines/core-app-quality>).

The reason is not ceremony. A permission asked in context arrives with its explanation already
built: the user just tapped the thing it is for, so the dialog reads as the obvious next step. A
permission asked on first run has to manufacture a reason for itself against a screen the user has
not seen yet, which is why front-loaded prompts get declined by people who would have granted them
thirty seconds later.

**Where a guided sequence is right:** when one feature genuinely needs several permissions at once —
a run tracker's first "Start" needing location, activity recognition and notifications together.
That sequence is still in context, because the user invoked the feature; it just has more than one
prompt in it. Attaching the same sequence to app launch is the thing the criterion rules out.

When you do run several prompts in a row, the shape that survives contact with users:

- **One explainer per permission, before the system prompt fires.** Plain language: what it is for,
  and what specifically stops working without it. Not "we need location to improve your experience"
  — *"location stamps each entry with where you were; without it entries still save, just without a
  place."*
- **Requested one at a time. Never batched.** A `RequestMultiplePermissions` call presenting three
  dialogs back to back is the batching this forbids, whatever the API allows.
- **Denial never blocks progress.** The Continue control stays enabled.
- **A summary afterwards**, listing exactly what will not work, with a per-item button to try again
  and a **"Continue anyway" that is always enabled**.
- **Skippable in full, and re-reachable from the feature and from Settings** — someone who skipped
  on a train needs a way back that is not a reinstall.

| Situation | Do |
|---|---|
| One permission, one feature | Request it when the feature is tapped. This is the common case |
| Several permissions, one feature | The guided sequence above, fired by that feature |
| A permission for a rarely-used corner of the app | Request it at that corner, never earlier |
| A permission the OS only grants inside a specific flow | Follow the platform's flow; note the deviation and why in the spec |
| Tempted to ask at startup | Something is misclassified. Find the feature that needs it |

Build on the documented workflow — `ContextCompat.checkSelfPermission()`, then
`shouldShowRequestPermissionRationale()` for the educational UI, then
`registerForActivityResult(ActivityResultContracts.RequestPermission())` to launch — rather than a
hand-rolled equivalent:
<https://developer.android.com/training/permissions/requesting> (rationale:
<https://developer.android.com/training/permissions/requesting#explain>).

### The degradation contract

**For an ENHANCING permission, denial must produce all four of these.** Three out of four is a
defect. Play's `Graceful_Degradation` criterion states the floor — *"App gracefully degrades when
users deny or revoke a permission. App shouldn't prevent user access altogether"*
(<https://developer.android.com/docs/quality-guidelines/core-app-quality>) — and the four items are
what meeting it looks like in code:

1. **The surrounding workflow still completes.** A log entry with no position still saves. If the
   save button stops working because location was denied, the classification was wrong or the
   implementation is.
2. **A visible, honest statement of what is missing and why** — *"no position (location denied)"*,
   not a blank field, not a zero, and not a plausible-looking default. A blank field is a value
   computed from nothing wearing a disguise.
3. **An inline control that re-triggers the prompt right there.** Recovering must never require the
   user to find Settings on their own.
4. **Never a hidden control, never a disabled control with no explanation, never a control that does
   nothing.** This is the house rule about silent no-ops (`SKILL.md`), and a permission denial is
   the single most common way an app grows one — the control is right there, it looks live, and
   tapping it does nothing because the permission behind it is gone.

**For an ESSENTIAL permission, "fail closed" does not license a dead end.** Failing closed means not
proceeding without the capability; it does not mean a blank screen. Denial produces a screen that
states what the app cannot do, why the permission is unavoidable (in the app's terms, not the API's),
a button to grant it, and **a route to whatever the app can still do** — a settings screen, an
export, an offline view. `Graceful_Degradation` asks for an alternative use case rather than a wall,
so if you cannot find one, treat that as evidence the classification is wrong before you treat it as
a property of the app. That screen also belongs at the feature, not at launch: an essential
permission does not license a gate in front of the whole app.

### Permanent denial is real, and most designs ignore it

**Two denials is permanent.** After the user taps Deny twice over the app's installed lifetime,
the system dialog never appears again — the platform treats it as "don't ask again"
(<https://developer.android.com/training/permissions/requesting#handle-denial>).

This breaks the naive version of contract item 3: an inline "try again" that calls `launch()` after
a permanent denial **does nothing at all** — the exact dead control the rule forbids, introduced by
the code meant to satisfy it.

So the inline control must branch:

- permission grantable → launch the system prompt;
- permanently denied → deep-link to the app's settings page, and say that is where it now lives.

**Detecting which branch you are in takes one bit of your own state.** The obvious rule —
"`shouldShowRequestPermissionRationale()` is `false` and the permission is not granted, therefore
the prompt is spent" — is wrong, and wrong in the direction that breaks first run. The documented
meaning of that call is the `true` case: it returns `true` when the user has already denied the
request once, and that is your cue to show the educational UI
(<https://developer.android.com/training/permissions/requesting#explain>). `false` is everything
else, and "everything else" includes the fresh install where the app has never asked. An app that
reads `false` as permanent sends a first-time user straight to a Settings deep link for a permission
the system would have granted on a single tap.

So persist a "we have asked for this one before" flag — DataStore, one boolean per permission,
written at the moment you call `launch()` rather than in the result callback, which the process may
not survive. Then:

| Granted | Asked before | `shouldShowRationale` | State | Do |
|---|---|---|---|---|
| yes | — | — | granted | proceed |
| no | no | (don't read it) | never asked | launch the prompt |
| no | yes | `true` | denied once | show the rationale, then launch |
| no | yes | `false` | spent | deep-link to app settings, and say so |

The platform does keep the bit you want — AOSP's implementation ends at
`(flags & FLAG_PERMISSION_USER_SET) != 0`, so a never-asked permission has no `USER_SET` flag and
falls straight through to `false`, the same answer `USER_FIXED`, `POLICY_FIXED`, `SYSTEM_FIXED` and
hard-restricted permissions all return earlier. Apps cannot read those flags without a privileged
permission, which is why you keep your own copy.

Re-check on `onResume()` after a Settings round trip — a permission granted out there produces no
callback in your app, and a stale cached "denied" is another way to grow a dead control.

Test all three not-granted states — see the flags below.

### Standing checklist

Every restricted capability, every audit:

- [ ] Classified **essential** or **enhancing**, with the reasoning recorded in the spec.
- [ ] Manifest declaration **and** a runtime request **and** a re-check immediately before the gated
      action fires.
- [ ] The four-part degradation contract holds for every enhancing permission.
- [ ] The inline retry branches on permanent denial rather than calling `launch()` blindly, using a
      persisted asked-before flag rather than `shouldShowRequestPermissionRationale()` alone.
- [ ] Every request fires from the feature that needs it, not from startup.
- [ ] An essential denial lands on an explaining screen with a way forward, not a dead end.
- [ ] A deny-everything run exists as a test scenario (`testing-and-bugs.md`).

Two traps that make a denial test pass for the wrong reason:

- **Journeys may auto-grant every permission.** If the suite uses Journeys (`ecosystem.md` §3),
  denial scenarios can go green without ever exercising the denial path — precisely where this bug
  class lives. Keep denial cases as ADB tests with explicit `pm revoke`.
- **A once-denied permission is not a permanently-denied one, and they behave differently.** Test
  both. The platform flags them separately, and `dumpsys` shows which state you are actually in:

```bash
adb shell pm revoke <pkg> android.permission.ACCESS_FINE_LOCATION   # denied once
adb shell dumpsys package <pkg> | grep -A1 ACCESS_FINE_LOCATION     # USER_SET vs USER_FIXED
adb shell pm clear-permission-flags <pkg> android.permission.ACCESS_FINE_LOCATION user-set user-fixed
```

The last line is how you get back to a virgin state between runs; `pm clear` also works and resets
everything else with it.

- **LAN discovery may need a runtime permission now.** Recent Android versions have moved
  local-network access behind a user-granted permission. **This is unverified for current AOSP** — it
  was observed in a vendor fork's change list and not confirmed against AOSP behaviour first-hand. If
  the app does mDNS/NSD or any LAN discovery (`panel-remote`'s domain), **check the behaviour on the
  actual target OS version before assuming either way**, and treat a discovery failure on a real
  device as a possible permission problem rather than only a network one. Do not write a permission
  request into the manifest on the strength of this paragraph.


## Local storage

- **Room + sqlite-vec** is the default for anything needing structured local data plus retrieval/search (used for a hybrid BM25 + vector-search RAG pipeline in the most mature app in the corpus).
- **DataStore** for preferences/settings — but audit what actually lives in it. A finding from a real audit: a DataStore holding remembered hostnames, model strings, and hardware serial numbers had no `allowBackup="false"`, `dataExtractionRules`, or `fullBackupContent` — meaning it was silently eligible for Google's automatic cloud backup and cross-device restore. **Decide backup eligibility deliberately for every DataStore/Room file, not by default.** Anything identifying, sensitive, or device-specific should be explicitly excluded from auto-backup; don't let the OS default carry data you didn't intend to sync.
- **Wrap multi-step DB operations (delete-then-reinsert corpus loads, etc.) in a single transaction**, not separate auto-transactions per step — a crash mid-load should never be able to leave a partially-deleted, partially-inserted state.
- **A single malformed row should degrade gracefully, not abort the whole load** — wrap per-row processing in try/catch-continue and validate shape (e.g. blob size / expected dimension for embeddings) before using it, rather than letting one bad row throw out of the entire seed operation.
- For anything downloaded and cached long-term (a multi-hundred-MB on-device model, for instance): verify integrity (SHA-256, gated on whether an expected hash is actually configured — log and skip verification rather than failing closed if it isn't) before marking it ready, and default any large download to **not** proceed over a metered connection unless the user has explicitly opted in.

## Schema and migration discipline

Where there's a database, these rules were each learned by losing something:

- **Export the schema and commit it.** Room's exported `schemas/*.json` is the only input that lets
  a migration be tested against the *real* previous schema rather than someone's recollection of it.
  Committing it turns a wrong migration into a failing test instead of a wiped database.
- **Forbid the destructive-migration fallback.** `fallbackToDestructiveMigration` papers over a bad
  migration by deleting the user's data. Once a version has shipped to a real device, a schema
  change needs a real migration. (Before that point, a stale-database crash on a new build is the
  contract working: `Room cannot verify the data integrity` means uninstall and reinstall, not a
  code bug.)
- **Records are self-describing.** A record snapshots the state that gave it meaning at write time —
  the thresholds in force, the capture bounds used, the catalogue entry's values as they then stood.
  Never look up a mutable catalogue row at *read* time to decide what a past event meant: editing
  that row tomorrow silently rewrites history.
- **Predicates that partition the same data must agree.** In the corpus, three separate queries each
  decided what counted as a purgeable reading; they disagreed once and retention wedged permanently
  after the first logged episode, reporting success every night while the database grew without
  bound. If you have a set like this, say so in the schema doc: change all of them or none.
- **Write down the contract.** A `SCHEMA_CONTRACT.md` with a *non-negotiable rules* section, the
  entity list, and a revision log of hard-won fixes is what stops the next session re-introducing a
  bug that was already paid for.

## Multi-device sync (phone ↔ watch, or any two clients)

- **One side owns the data.** Two copies of a schema on two devices, drifting independently, is how
  records get lost. The corpus's decision was: the phone owns the database; the watch holds a
  bounded in-memory buffer and pushes events. If the second device ever needs its own store, that's
  a deliberate decision, not something that arrives by adding a dependency.
- **Pick the transport by its delivery guarantee, not its convenience.** A fire-and-forget message
  API drops events when the peer is unreachable; anything that must not be lost needs the persisted
  channel plus a disk-backed outbox, so a peer out of range *delays* a write rather than losing it.
- **Staleness is a silent-failure risk.** A device operating on a config snapshot it received days
  ago looks completely healthy. Timestamp what was synced, and make the consuming UI able to say
  it's running on a stale copy.
- **Offline is the design case, not the edge case** — for anything worn, carried, or used away from
  reliable connectivity.
- **Don't share types across the wire that either side may rename.** If the two apps update
  independently, a newer client will at some point talk to an older one; a wire format that depends
  on the domain module turns a rename into a silent protocol change. Give the wire its own module
  that depends on nothing.

## Cloud backup / sync (Google Drive)

The concrete, working feature spec from the corpus, worth reusing close to verbatim for any app that needs cross-device continuity without standing up a backend:

> Does the app have a way to back up (export) and restore (import) data? If so, then create a fixture "backup" that we can import to confirm app reporting/behavior with "lively" data. If not, then add this feature. It should include google drive sync where you can backup to drive and restore from drive.

Two things worth keeping from this that are easy to skip:
1. **Export/import as a local fixture mechanism comes first, cloud sync is layered on top of it** — you get a testable backup format (and a way to seed realistic-looking test data) before you get the harder cloud round-trip. Don't build Drive sync directly against production data paths with no local fixture to validate against.
2. **"In-progress" is a real, document-worthy state.** When a feature is mid-implementation, the explicit instruction was *"document that drive backup is in-progress"* before moving on to unrelated work — don't let a half-built cloud feature sit undocumented where the next session (or subagent) might assume it's finished.

## Cloud LLM / API access generally

From `field-assistant` (cloud inference via a third-party LLM gateway — not Google-specific, and the hardening pattern generalizes to any cloud API client):

- **Bound unbounded response reads.** `response.body?.string()` on an error path reads the entire response into memory with no cap — an attacker-controlled or just-large error body is an OOM risk. Use a bounded read (`response.peekBody(64 * 1024).string()`) when building failure objects from a response body you don't otherwise need in full.
- **Parse numeric fields defensively** — tolerate a field arriving as a float when you expected an int (`intOrNull ?: doubleOrNull?.toInt()`), rather than a silent null/drop.
- **Redact secrets from logging interceptors** — API-key/Authorization headers must not appear even in debug-level HTTP logging; keep production logging at BASIC and gate anything more verbose to debug builds only.
- **A curated model/endpoint ID list should have a verification TODO**, not a blind trust — a wrong slug/ID doesn't fail until the first real call, so flag unverified IDs explicitly rather than silently shipping a guess.
- **Sanitize chat-template control tokens out of anything user-supplied** before it reaches a prompt, especially for an on-device model whose formatter builds the template by string concatenation. Unsanitized turn markers let user text forge a system or assistant turn.
- **A documented spend guardrail that isn't actually enforced is a finding, not a feature.** A cost cap that exists as a settings field and a comment, with nothing reading it on the request path, is worse than no cap: it's a claim of protection. Either wire it to the call site or delete it.
- **Decide the throttle/rate-limit fallback before you hit one.** Which model does it fall back to, does the user get told, and does the fallback persist for the session or just the request? Write the answer into the testing playbook alongside how to force the condition.

## On-device and hybrid inference

`field-assistant`'s hand-rolled on-device/cloud routing is now a first-party API, and anything built new should start there rather than reimplementing the routing layer.

**Firebase AI Logic hybrid inference** switches dynamically between Gemini Nano on-device and cloud Gemini, using ML Kit's Prompt API locally, configured through `OnDeviceConfig` with `InferenceMode.PREFER_ON_DEVICE` or `PREFER_IN_CLOUD`.

**The word `PREFER` is the whole problem, and it is a silent-failure trap of exactly the shape this skill exists to catch.** A preference is not a guarantee. If on-device inference is a *privacy requirement* rather than a performance preference — which is the usual reason anyone wants it — then `PREFER_ON_DEVICE` will happily fall back to the cloud and send the very data the requirement existed to keep local, with nothing on screen to say so.

So, as a standing audit item for any app using hybrid inference:

- **Listen to the model download state and gate the feature on it.** The on-device model is a large download that may be absent, partial, or still arriving.
- **If on-device is a hard requirement, fail loudly rather than degrading to cloud.** Say the feature is unavailable until the local model is ready. Do not silently satisfy the request the other way.
- **Make the routing decision visible** wherever it carries a privacy meaning — the user should be able to tell which path answered.
- This is a specific instance of the general rule in intake Q6: decide what happens offline, rate-limited, or with the model missing, *before* it happens.

Also worth knowing, same platform generation: **AppFunctions** lets an app expose tools and data to system agents (Google ships a `device-ai/appfunctions` skill), the **Structured Output API** replaces brittle parsing of model output — adopt it rather than regex-scraping a response — and **ADK for Android** covers multi-agent workflows.

## The "personal APK, live credentials" exception

One project explicitly bakes live API credentials into the APK, on the record:

> Live credentials are supposed to be baked in. This is on purpose, we bake live credentials since it is not a distributed APK but a personal one.

Treat this as a **confirmed, explicit exception for a specific app**, not a default to assume for any new project. Before applying it: confirm the APK genuinely won't be distributed, shared, or published anywhere (including a public GitHub release page — note the corpus also has a project publishing beta APKs to a GitHub releases page, which is a distribution channel even if informal). If there's any chance of distribution, credentials belong in a build-time-injected config the release pipeline can swap, not baked into source.

**Distribution carries a second question: developer verification.** From 2026-09-30 in Brazil, Indonesia, Singapore and Thailand — and globally through 2027 — apps installed from participating app stores on certified devices must come from a verified developer. Two things follow, and both are good news for the personal-build case:

- **ADB sideloading is unaffected**, and there is an explicit advanced flow for installing from unverified developers. A build you `adb install` on your own device is still just a build.
- **Limited distribution accounts** cover the "a handful of named people" answer to intake Q10: no government ID, no fee, up to **20 devices**. That is the right instrument for most informal sharing, and it is a better answer than a GitHub releases page for anything you'd rather not treat as public distribution.

Record which of these applies in the spec. See `platform-currency.md` §6.
