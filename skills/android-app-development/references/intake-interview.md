# The Intake Interview

**When someone says "build me an Android app" (or points this skill at a rough idea), do not write
code, and do not start a scaffold. Run this interview first.** The output is an answered question
set that becomes `docs/APP_SPEC.md` — see `lifecycle.md` Phase 1.

Every question below exists because its absence cost something in a previous project: a feature
built and thrown away, an audit finding that was actually a deliberate decision nobody had written
down, a permission that was never requested at runtime, a watch build that would not install.

## How to run it

- **Ask Q0 first, alone.** Everything else is worded based on its answer (`user-calibration.md`).
- **Ask in batches of 2–4, not one at a time.** Use the question tool with concrete options plus a
  recommended default, so the answer can be a click rather than an essay. A ten-question
  interrogation delivered one message at a time is how an intake gets abandoned halfway.
- **Never use a term from the glossary without translating it** (`user-calibration.md` §7) unless
  Q0 said the person already speaks Android. Every question below is written at roughly
  Intermediate; re-word up or down from there rather than reading it out verbatim.
- **Broad to narrow.** The first four questions decide which of the later ones are even relevant.
  Never ask a question whose answer is already implied by an earlier one.
- **Always offer a default and say what you'd pick.** "You choose" must be a legitimate answer to
  every question here. Record it as *your* decision in the spec, not as though the user made it.
- **Capture the *why*, not just the answer.** "Phone + watch" is worth a line; "phone + watch,
  because the watch is the only thing on the user's body when it matters and the phone is the only
  thing with a screen big enough to edit on" is what stops a later session from proposing a
  watch-only build.
- **Stop when what's left is implementation detail, not judgement.** The bar: could a competent
  agent pick this wrong and have the app still look fine? If yes, it's a question. If no, decide it
  yourself and move on.
- **Never guess an answer the user should own.** Anything unresolved goes into the spec's
  *"Needs a decision, not a guess"* section, verbatim as an open question. From the corpus:
  *"Several numbers in here look like implementation details and are actually clinical judgements.
  Guessing at one produces a plausible-looking app that is wrong in a way nobody notices for
  months."*

---

## Question 0 · Who am I talking to?

**Ask this before Q1, on its own.** It decides how every question below gets worded, how much you
explain, how much you decide rather than ask, and how much of the toolchain setup you hand over.
Full detail — the five levels, the calibration table, the plain-language glossary — is in
`user-calibration.md`.

> Before we start — how much software or Android experience do you have? I'll match how much I
> explain to your answer and pick sensible defaults for anything you'd rather not decide. No wrong
> answer, and you can tell me to speed up or slow down at any point.

**Novice** (never written code) · **Beginner** (some scripts or tutorials) · **Intermediate**
(can program, new to Android) · **Advanced** (professional developer, other platforms) ·
**Professional app developer**.

Frame it as tuning, never as a test, and **default to Intermediate** if they don't answer —
over-explaining costs one sentence to correct, while under-explaining loses someone silently.

Then apply it to everything that follows:

- **At Novice/Beginner, ask fewer questions, not more.** Q1, Q7, Q9 and Q10 are the ones that
  genuinely need their judgement; decide the rest yourself and say plainly what you picked and why.
  Asking a novice to choose a navigation library is not consultation, it's abdication.
- **At Intermediate/Advanced, keep general programming vocabulary and explain the Android-specific
  terms anyway.** A strong engineer new to Android knows what a build system is and does not know
  what an AVD is — and will not ask, because asking feels like admitting ignorance in their own
  field. This profile is the easiest to misread in both directions at once — over-explaining the
  programming and under-explaining the platform (`user-calibration.md` §4).
- **Re-calibrate on evidence.** Self-assessment is unreliable both ways. What they send outweighs what they
  said about themselves — treat contentless agreement after a dense message as a comprehension
  failure until proven otherwise, and check it with one concrete question (`user-calibration.md` §5).
- **Record the level in `CLAUDE.md`** at Phase 1, with the reason, so the next session doesn't reset
  to a different register (`user-calibration.md` §6).
- **Keep building the persona after Q0 — a label is not a persona.** The level is scaffolding for
  the first two minutes; after that you are modelling one specific person: which words they've
  earned, how much detail they want, whether they answer choices or bounce them back, what they
  bring up unprompted. Build it by noticing, not by interrogating — mirror their words back, offer
  a depth choice once, and state your read back in one plain sentence so a wrong guess costs one
  exchange instead of a project. Never show them the level label (`user-calibration.md` §9).
- **At Novice/Beginner, every explanation is ELI5** — no assumed background, which is not the same
  as talking down. Familiar comparison, what it means for them, what you're doing about it, stop.
  The analogy has to actually hold; a wrong one produces confident wrong expectations that surface
  three weeks later (`user-calibration.md` §10).
- **Don't just pick for them — research it, then recommend.** The less able someone is to evaluate a
  choice, the more rigour it deserves, because nobody downstream will catch a bad one. For anything
  expensive to reverse, convene the **`council`** skill if it's installed and report the verdict as
  decision / reason / honest cost / confidence / the one thing that would flip it. Without it, do
  the same inline with web search. A council informs a decision; it never launders one — if the
  call is genuinely theirs, bring the verdict *and still ask* (`user-calibration.md` §11).

## The ten core questions

Ask these — or the subset that survives Q0 and earlier answers — every time.

### 1 · What is this app for, and what is it deliberately *not*?

Two or three sentences. **Push hard on the second half**, it's the load-bearing one. The best spec
in the corpus opens with *"It is not a fitness tracker. Every fitness device is built to tell you to
do more. This one exists to tell you when to stop."* That single sentence gives every later
"should we add..." a stated reason to be measured against, which is the whole job of the question.

Follow-up if the "not" comes back empty: *"What's the closest existing app to this, and what does
it get wrong?"* — that usually produces the same answer sideways.

### 2 · What feel should it have?

| Option | What it implies downstream |
|---|---|
| **Native app** | Standard Material 3, system navigation, plays by platform conventions |
| **Kiosk / single-purpose surface** | One screen that stays up; landscape lock, keep-screen-on, big touch targets, no chrome |
| **Background operator** | Mostly invisible: foreground service, notifications, sensor loops. UI is the config surface, not the product |
| **Tool / utility** | Dense, information-first, fast in and out; discoverability matters less than efficiency |
| **Remote control** | Latency and control fidelity are the product; the UI is a means to an input |
| **Conversational / AI surface** | Chat or query-first; the interesting design is routing and failure modes, not screens |

More than one can apply (the corpus has an app that is a background operator on the watch and a
tool on the phone) — ask which is primary on each form factor.

### 3 · Which form factors, and which is primary?

Phone · tablet / large screen · Wear OS watch · Android Auto · TV · foldable.

Then, per factor: **is it a full app, a companion, or a glanceable surface?** A watch that is a
sensor source with a two-button UI is a completely different build from a watch that is the primary
interface. Ask up front — discovering a Wear module is needed halfway through is one of the failure
modes `bootstrapping.md` calls out by name.

If a watch is in scope, also ask now: **does it work standalone, or does it require the phone?** —
because "waiting for your settings from the phone" being correct-behaviour-not-a-bug has to be
decided before the first test run, not after.

### 4 · How old a phone does this need to work on?

**Ask it in those words. Never ask the user for `minSdk` or `targetSdk`** — those are outputs of
this question, not inputs to it, and asking for them is how an interview stalls.

Offer these, and say which you'd pick:

| Option | Means | Cost |
|---|---|---|
| **Just my own device(s)** | Whatever you actually carry | Cheapest. Modern APIs available, one device to test |
| **Anything from the last ~5 years** | Roughly Android 12 and up | The usual default. Little extra work |
| **Anything still in real use** | Roughly Android 9 and up | Some features need a fallback path; more testing |
| **A specific old device I own** | Named hardware sets the floor | Whatever that device runs decides it — ask which |

"You choose" is a legitimate answer: pick **anything from the last ~5 years**, say you picked it,
and record it as your decision. `platform-currency.md` §9 maps each answer to the actual number.

Then, separately: **which specific device(s) will you actually test on?** (*"a Wear OS 4
smartwatch"*, *"a 12-inch Android tablet"*, *"my current-generation Pixel"*). The named device
matters more than any number, because it decides:

- **which Android versions must actually be tested**, not just declared supported;
- **the shipping ABI** — the chip type the app's native code is built for. If it ships to ARM
  hardware, say so in the spec in those words: an x86_64 emulator is then a convenience, not a
  verification target, and every test needs an arch tag (see `windows-toolchain-and-emulators.md`
  and `lifecycle.md` Phase 4);
- whether a real-hardware test pass is required before "done" can be claimed. It usually is.

> **The misconception worth heading off, because it is nearly universal.**
> This becomes two numbers, and they do *not* do the same job:
>
> - **`minSdk` — the oldest Android that can install the app.** This is the compatibility dial, and
>   it is the only one this question sets. Lower means more devices and more work.
> - **`targetSdk` — which Android's *behaviour rules* the app follows.** It is **not** a floor, and
>   raising it does **not** drop older devices. An app with `targetSdk 36` and `minSdk 28` still
>   installs and runs on a 2018 phone.
>
> So "target the newest Android" and "support older Androids" are **not opposites** — a normal app
> does both at once, and that is the expected configuration, not a compromise. `targetSdk` is also
> barely a choice: Play requires 36 for anything published (`platform-currency.md` §5). If a user
> says they want to "support older phones", they are talking about `minSdk`; confirm that reading
> back to them in plain words rather than assuming either way.

### 5 · What visual style?

Native Material 3 · sleek/modern · soft/calm · technical/instrument · high-contrast glanceable ·
minimal monochrome · matches an existing product.

Then two follow-ups that decide how much design work happens before code:
- **Should the colour/type/metric choices be pinned in a `DESIGN_TOKENS.md` up front?** Say yes for
  anything where colour carries meaning rather than decoration — the corpus has an app whose alert
  palette is a safety mechanism, with an explicit rule that *form must reinforce colour* so the
  information survives colourblindness and a glance.
- **Do you want screens mocked up before implementation?** Usually yes for anything past two
  screens. This answer opens **Phase 1b** (`design-phase.md`): three to five genuinely different
  directions as artboards, feedback, converge, then a named design of record — and state which
  artifact wins when the mockup and the spec disagree. At novice levels this is the phase where the
  user contributes most usefully, since people who cannot review an architecture can review a
  picture.
- **Will it be used somewhere you can't control the lighting** — outdoors, in bright sun, in the
  dark? That forces more than one palette, and the theme has to be structured as swappable from the
  first commit (`design-phase.md` §4).

### 6 · Does it use AI, or any cloud service?

None · a cloud LLM API · an on-device model · both, with routing · non-AI cloud (Drive/backup,
auth, a backend, a device on the LAN).

If any cloud or model is involved, ask immediately:
- **Who pays, and what's the ceiling?** (An API key belongs to someone.)
- **What must never be sent to a model or a server?** This is often where the app's real safety rule
  lives — the corpus's clearest example is an app where emergency content is rendered verbatim and
  never passes through an LLM at all.
- **What happens offline, rate-limited, or when the key is missing?** A degraded path decided now is
  a feature; decided later it's an outage.

### 7 · What data does it hold, and how sensitive is it?

None · preferences only · personal but unremarkable · health/financial/identifying · third-party
credentials or device identifiers.

Anything past "preferences only" pulls in these, and they're quick:
- **On-device only, or does it sync?** ("All data stays on device" is a constraint worth writing in
  those words if it's true — it makes an analytics SDK a spec violation rather than a judgement
  call.)
- **Backup/export/restore — needed?** Build the local export/import fixture first, cloud sync on top
  of it (see `permissions-storage-cloud.md`).
- **Is anything here eligible for Google's automatic cloud backup, and should it be?** Decide
  `allowBackup` / `dataExtractionRules` deliberately, per store. The default has silently synced
  device identifiers before.

### 8 · What device capabilities does it need?

Sensors (heart rate/body) · location · camera/mic · Bluetooth · LAN/network discovery ·
notifications · background execution · file access.

**Do not ask, per capability, what should happen when it is denied.** That is the right question at
the wrong altitude — it hands the user a design problem you can solve better from the answer to Q1.

Instead, **classify each capability yourself and confirm the split.** Reason from the app's stated
purpose: **ESSENTIAL** means the core purpose is impossible without it (a camera app without
`CAMERA`); **ENHANCING** means a feature degrades but the app stays genuinely useful. Enhancing is
the default and the burden of proof is on calling something essential
(`permissions-storage-cloud.md`).

Play it back in plain words, not jargon:

> I read **camera** as essential — without it there is no app — and **location** and
> **notifications** as enhancing: the app works, those two features don't. Correct?

Record the classification **and the reasoning** in the spec, not just the answer. A permission
called essential because it was convenient to code against is how an app becomes uninstallable in
practice for anyone who declines one prompt.

The classification then decides the rest, so you don't need to ask it: enhancing permissions get the
four-part degradation contract, essential ones get an explaining screen with a way forward, and every
request fires from the feature that needs it rather than at startup. All of that is
`permissions-storage-cloud.md`.

This is also the question that prevents the single most-repeated bug in the corpus: a permission
declared in the manifest and never requested at runtime, so the feature installs, launches, looks
healthy and never functions.

Network discovery (mDNS/NSD) and inbound UDP get one extra note at intake, not at debug time: they
**need a real-device test rig**, because the emulator does not support IGMP and so cannot see multicast traffic from hardware on the LAN. Outbound TCP and UDP from the emulator work normally — it is discovery specifically that breaks.

### 9 · What is the one thing this app must never get wrong?

Ask it as: *"What's the worst thing this app could plausibly do to whoever uses it?"* Then turn the
answer into a single named invariant, phrased so a subagent could check it.

Real examples from the corpus, all of which became load-bearing test assertions:
- *Emergency content renders verbatim — never paraphrased, summarised, or passed through an LLM.*
- *Every alert arm may escalate; no arm may de-escalate.*
- *An alert the user learns to dismiss destroys the channel that has to carry the real CRITICAL —
  prefer a missed CAUTION to a spurious HIGH.*

If the app genuinely has none, say so explicitly in the spec rather than leaving the section blank —
"no safety-critical invariant" is itself a decision. If it has one, it gets restated **verbatim** in
every audit prompt and every fix-agent dispatch from then on (SKILL.md house rules).

### 10 · Who gets the APK, and how?

Only you, sideloaded · a handful of named people · a GitHub releases beta · Play Store · undecided.

This single answer decides:
- **whether live credentials may be baked into the build.** Personal, non-distributed builds may do
  this deliberately — but a GitHub releases page *is* a distribution channel, informally or not.
  See the boundary in `permissions-storage-cloud.md`.
- **which distribution identity is needed.** Developer verification is rolling out (first countries
  2026-09-30, global through 2027). ADB sideloading to your own device is unaffected; a **limited
  distribution account** covers "a handful of named people" with no government ID, no fee, and up
  to 20 devices; Play means the `targetSdk` policy deadlines bind from day one. For "a handful of
  named people", **offer the limited distribution account as the default** rather than a GitHub
  releases page — it is the instrument built for that answer. See `platform-currency.md` §6.
- **signing**: whether a real keystore is needed now, and (if there's a watch or a companion) that
  both modules must use the *same* key or the pairing silently fails.
- **whether release/R8 builds are on the critical path from day one.** They are for anything going
  to a watch — a debug build has failed to install on real watch hardware in this corpus.

---

## Dynamic follow-ups — generate these from the answers

After the core ten, generate the next round yourself. The trigger table below is the starting set,
not the limit; add any question where a wrong guess would be invisible in a demo.

| An answer of… | asks next |
|---|---|
| **Watch in scope** | Which Wear OS versions does the target watch *actually run* today? Tiles or complications? What shows when unpaired? Is the watch a sensor source or the primary UI? Battery expectations for continuous sensing? |
| **Background operator** | What wakes it (schedule, sensor, push, boot)? Foreground-service type? What must survive Doze and reboot? What's the user-visible evidence it's running — and what does it show when it has silently stopped? |
| **Kiosk** | Orientation locked? Screen kept on? What happens on an incoming call or a system dialog? Is there a way out of the kiosk, and who's allowed to take it? **If a tablet is in scope, do not plan on a manifest orientation lock** — at `targetSdk` 36 those restrictions are ignored on screens ≥600dp, so a portrait-locked design gets a landscape window anyway. A temporary opt-out property exists and stops working at `targetSdk` 37, so it buys migration time and is not a design (`platform-currency.md` §4). Decide the adaptive layout now, not after the first tablet screenshot |
| **Native code or a vendor SDK** | Which ABIs ship? 16 KB page support (required for native `.so`)? On Wear OS, both 32- and 64-bit are required by Play since 2026-09-15. An x86_64 emulator pass is not evidence for an `arm64` target |
| **AI/LLM** | Routing rules between models? What's never sent? Streaming or batch? What does a refusal, a timeout, and a truncated response each look like on screen? Cost ceiling? |
| **On-device model** | How big is the download, and over what network? Where is it cached, and is integrity verified? What does the app do while it downloads, and if it fails halfway? |
| **Sensitive data** | Encryption at rest? Passphrase — user-supplied or derived? What's the recovery story if it's forgotten? Who else physically handles the device? Is a demo/fixture dataset needed for testing — and is fabricating data about a real person acceptable here? (In the corpus, it was not.) |
| **Sync / multi-device** | Which side owns the data? What happens when they disagree? Does a newer client have to talk to an older one — and if so, does the wire format depend on any type that can be renamed? |
| **LAN / discovery / accessory** | Real device required for testing — confirmed? What's the manual-address fallback for emulator work? What does "the thing went away" look like, and how long before the app gives up? |
| **Named safety invariant exists** | What's the automated test that proves it? What's the observable symptom if it's ever violated? Does any module get to opt out? |
| **Distributed beyond you** | Crash reporting — wanted, or forbidden? Privacy policy needed? What's the update path once someone else has an old build? |
| **Any UI at all** | What does every screen show with *no data yet*? (Empty states earn their place here — the corpus's rule is that a value computed from nothing must never render as a finding, and an empty first install is the cheapest possible test of it.) |
| **Any runtime permission at all** | Which are essential and which enhancing, and does the user agree with the split? Which feature does each one fire from — and if the answer is "app startup", which feature was it supposed to be? What does each denial leave working? Has anyone checked the *permanently* denied state, where the system prompt never appears again? (`permissions-storage-cloud.md`) |
| **Any failure path at all** | When something doesn't work, what does the user see? A button that does nothing with no explanation is treated as the worst failure mode in this corpus, worse than an error message. |

Two questions worth asking at the end of *every* interview regardless of answers:

1. **"What should this app never do?"** — collected as a list, it goes into the spec verbatim. The
   corpus example: *"No cloud sync, no account, no analytics, no crash reporter. No streaks, badges,
   congratulation or encouragement to do more."* Every one of those has since prevented a
   well-intentioned wrong feature.
2. **"What's already decided that I shouldn't re-open?"** — carried into the spec as an *"Answered,
   so nobody re-opens it"* section. Without it, every new session re-litigates the same three
   architecture choices.

---

## Closing the interview

Play the answers back as a compact summary — one line per question — and get an explicit
confirmation before writing `docs/APP_SPEC.md`. Corrections at this point are free; the same
correction after Phase 3 is a rewrite.

Then hand off to `lifecycle.md` Phase 1.
