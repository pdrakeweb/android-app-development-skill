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

**The single most-repeated gotcha in the corpus: declaring a permission in the manifest is not enough on API 33/34+.** A real-hardware bug report on a Wear OS app nailed the exact failure mode:

> BODY_SENSORS IS PROBABLY NEVER REQUESTED AT RUNTIME. Declaring it in the manifest is not enough on API 33/34. If the app never calls requestPermissions, Health Services will refuse and monitoring cannot start — and no user without adb could ever get past it.

Treat this as a standing audit item, not something you check once: **every restricted API call needs (a) the manifest declaration, (b) an explicit runtime request on first need, and (c) a re-check immediately before the gated action fires, with a visible reason and a route to Settings if denied.** "Missing required runtime permissions before calling restricted APIs" is also a standing line item in the general adversarial audit (see `testing-and-bugs.md`) — don't treat it as Wear-OS-specific.

Two additions to the standing checklist:

- **Journeys may auto-grant every permission.** If the test suite uses Journeys (`ecosystem.md` §3), permission-denial scenarios can pass without ever exercising the denial path — the test reports green precisely where this bug class lives. Keep denial cases as ADB tests with explicit `pm revoke`.
- **LAN discovery may need a runtime permission now.** Recent Android versions have moved local-network access behind a user-granted permission. **This is unverified for current AOSP** — it was observed in a vendor fork's change list and not confirmed against AOSP behaviour first-hand. If the app does mDNS/NSD or any LAN discovery (`panel-remote`'s domain), **check the behaviour on the actual target OS version before assuming either way**, and treat a discovery failure on a real device as a possible permission problem rather than only a network one. Do not write a permission request into the manifest on the strength of this paragraph.

Corollary from the same bug report, worth generalizing: **a missing optional input should degrade the feature, never silently block it.** ("Missing today's resting HR must not stop monitoring... fall back to the learned profile value, monitor anyway, and show plainly that it's running on last-known rather than today's figure.") The same logic applies to any permission-gated feature — decide explicitly what the degraded-but-functional state looks like when a permission is denied, rather than leaving the feature just... not working.

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

**Distribution now carries a second question: developer verification.** From 2026-09-30 in Brazil, Indonesia, Singapore and Thailand — and globally through 2027 — apps installed from participating app stores on certified devices must come from a verified developer. Two things follow, and both are good news for the personal-build case:

- **ADB sideloading is unaffected**, and there is an explicit advanced flow for installing from unverified developers. A build you `adb install` on your own device is still just a build.
- **Limited distribution accounts** cover the "a handful of named people" answer to intake Q10: no government ID, no fee, up to **20 devices**. That is the right instrument for most informal sharing, and it is a better answer than a GitHub releases page for anything you'd rather not treat as public distribution.

Record which of these applies in the spec. See `platform-currency.md` §6.
