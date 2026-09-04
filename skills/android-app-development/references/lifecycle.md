# The Project Lifecycle

The ordered process every successful app in this corpus actually followed. Each phase has an
**artifact**, an **exit gate**, and a rule about what must not start early. Deviations from this
order are where things went sideways — most often, code written before a spec existed, and test
scenarios written after the bugs had already been found by hand.

```
0 Interview  →  1 Spec  →  1b Design  →  2 Plan  →  3 Implement  →  4 Test scenarios
                                                          ↑              ↓
                                                          └── 5 Audit & fix ──→  6 Beta  →  7 Handoff
```

Phases 3–5 loop. Phases 0–2 (including 1b) happen once, and re-opening them later is a deliberate
act that gets written down, not a drift.

---

## Phase 0 · Interview

**Artifact:** the audience level (Q0) plus the answered question set, in the conversation.
**Reference:** `intake-interview.md`, and `user-calibration.md` for Q0.
**Do not start:** any scaffold, any dependency choice, any repo.

**Ask Q0 first, on its own.** It sets how every later question is worded, how much you explain, and
how much you decide rather than ask. At novice levels ask *fewer* questions and decide more, saying
plainly what you picked — the questions that always need their judgement are Q1 (what it's for),
Q7 (data sensitivity), Q9 (the invariant) and Q10 (who gets it).

**Exit gate:** the answers played back as a summary — in their register, not yours — and explicitly
confirmed.

---

## Phase 1 · `docs/APP_SPEC.md`

The spec is written *for the agent that will build it*, not as a document to admire. Structure that
worked, in this order:

1. **What this is, and what it is not.** Lead with the "not". One paragraph.
2. **Compatibility targets** — a table, with a hard split between *supported* and *actually tested*.
   `minSdk` / `targetSdk` / `compileSdk` / JDK / Gradle / AGP, and where each is declared (a version
   catalog, so nothing can drift). Name the real target hardware and the shipping ABI. **Take the
   values from `platform-currency.md` §1 and record the date you verified them**, rather than from
   memory — and if the distribution answer (Q10) is Play, note that `targetSdk` 36 is a *policy*
   constraint with a date attached, not a preference (§5 there).
3. **The constraints that override everything** — numbered, two or three at most. These are the ones
   that make a later feature request a spec violation rather than a debate.
4. **The named safety/correctness invariant** (interview Q9), phrased so it can be pasted verbatim
   into an audit prompt.
5. **Screens, or surfaces** — one section each: what it shows, what it reads, what rules it must
   honour. Include what each shows **with no data yet**.
6. **Background work** — what runs when the UI isn't up, what schedules it, what it must never do.
7. **Data and permissions** — what's stored, where, and backup eligibility, plus a **permission
   table** with one row per restricted capability and these columns: the permission, **Essential or
   Enhancing**, *why it is classified that way*, what the app does when it is denied, and where it is
   requested (first-run flow or in context). The reasoning column is the one that stops the
   classification being re-litigated at the first denial bug (`permissions-storage-cloud.md`).
8. **What this app must never do** — the verbatim list from the interview.
9. **Needs a decision, not a guess** — every open question, unresolved, attributed to the user.
10. **Answered, so nobody re-opens it** — decisions already made, with their reasons.

Companion artifacts, created here when the interview called for them:

- **`docs/adr/ADR-NNNN-*.md`** for any decision that's expensive to reverse — module boundaries,
  an on-device-vs-cloud split, a wire format, a safety rule. An ADR is cheaper than re-deriving the
  reasoning in six weeks.
- **The audience level, recorded in `CLAUDE.md`** with the reason it was set and any later
  adjustment. A cold session that re-derives the register gets it wrong, and swinging between a
  plain-language session and a jargon-dense one is worse than either consistently
  (`user-calibration.md` §6).
- **`CLAUDE.md`** — write it now, not at the end. It is the orientation handout for every future
  session and subagent: what this is, a *"read these first"* table pointing at the other docs, the
  constraints, the module map with allowed dependency edges, the house rules, and where to ask
  rather than guess. Keeping it current is part of every later phase.

`docs/DESIGN_TOKENS.md` and any mockups are **Phase 1b's** artifacts, not this phase's — the spec
says what the app is, design decides what it looks like.

**Exit gate:** the user has read the spec and confirmed it — particularly §8 and §9.

---

## Phase 1b · Design

**Artifact:** `docs/DESIGN_TOKENS.md`, mockups, and a named design of record.
**Reference:** `design-phase.md`.
**Do not start:** the plan — build order depends on what is being built.

Numbered `1b` rather than renumbered in, so every existing "Phase 4" reference stays correct.

Design flows out of the spec and feeds the plan. Doing it after the plan means re-planning; doing it
after implementation means the design review finds structural problems a mockup would have caught
for free.

- **Tokens before mockups.** And expect to need **semantic tokens of your own alongside the Material
  roles** — in the corpus a single `surfaceVariant` was carrying control keys, cards and a progress
  track, which want opposite things under a high-contrast palette (`design-phase.md` §2).
- **Generate three to five genuinely different directions**, not one proposal or twelve variations.
  Show each in its worst realistic state — no data, longest label, error — because that is where
  designs fail and where a mockup is cheapest to change. Claude Design (`/design`) is the tool.
- **Converge, then name the design of record**, stating which artifact wins when the mockup and the
  spec disagree.
- **Generate the theme from a seed colour**, and structure it as swappable from the first commit
  even when shipping one palette — retrofitting a second palette means touching every screen.
- **Assert contrast in a unit test** rather than reviewing it (`design-phase.md` §5). It is
  arithmetic; it runs on the JVM; it catches palettes and states nobody screenshotted.

**Skip this phase** for a single-screen utility with stock Material 3 and no semantic colour — and
say you are skipping it and why.

**Exit gate:** a design of record the user has seen and confirmed, and `docs/DESIGN_TOKENS.md`
written from it.

---

## Phase 2 · `docs/IMPLEMENTATION_PLAN.md`

The spec says what; the plan says in what order, and what "done" means for each step.

- **The module graph, stated once**, with the allowed dependency edges written as edges. Decide the
  pure-Kotlin domain module here — no `android.*`, no `androidx.*` — because retrofitting purity
  onto a domain module that has accumulated Android imports is far more painful than starting
  clean, and every audit in this corpus flags such an import as Critical.
- **Ordered steps**, each with: what it produces, how you'll know it worked (a command whose output
  you can read), and whether it needs a device.
- **"What is built" / "What is NOT built, in the order it matters"** — kept accurate as work
  proceeds. This is what makes a cold session productive in ten minutes instead of an hour.
- **"Rules that are not negotiable while you work"** — a short list, repeated from the spec. In the
  corpus these read like: *never weaken a guard to make something compile*; *don't delete a test to
  make the suite pass*; *these three predicates must agree — change all three or none*.
- **Where a judgement is required rather than a correction, stop and ask.** Say so in the plan, so
  the instruction survives into whichever session hits it.

**Exit gate:** the user approves the plan before any implementation code is written. This is the
single most valuable gate in the process — it is much cheaper to reorder a plan than a codebase.

---

## Phase 3 · Implement

A normal build-review-fix loop, with three rules that come straight from what worked:

- **Every pass ends with a real build and a real run on an emulator** — not "should work now".
  State it explicitly each time rather than assuming it's implied. **Run
  `${CLAUDE_SKILL_DIR}/scripts/verify-install.sh <apk> <package>`**, which asserts on `Success`, launches, confirms a
  live PID and the foreground activity, and checks the crash buffer — turning "I tested it" from a
  claim into an exit code. See `windows-toolchain-and-emulators.md` for the emulator mechanics and
  `bootstrapping.md` for the architecture defaults.
- **Run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh` once at the start of a cold session.** A JDK, Gradle or AGP mismatch
  produces configuration-time errors that never name the real cause, and an AGP 8-era scaffold does
  not build at all under AGP 9 (`platform-currency.md` §3).
- **A first compile of a never-compiled module is its own step**, and its output is worth reading
  carefully: work errors in the order reported, smallest edit first, re-running after each rather
  than batching. Distinguish a **typo** from a **design error** — the corpus's best worked example
  is a module where three compiler errors in one function were all one design error, and fixing
  them mechanically would have left a signal permanently dead.
- **Pin every version in one place** (a Gradle version catalog), so the Kotlin compiler and its
  annotation processors cannot drift apart.

Keep `CLAUDE.md`, the plan's built/not-built sections, and any schema contract current as you go.
A doc updated at the end of the session is a doc written from memory.

**Exit gate:** the feature builds, installs, launches, and has been driven by hand at least once.

---

## Phase 4 · Test scenarios

Written so an **agent** can execute them against an emulator, not as prose a human has to
interpret. This is the artifact that turns "I clicked around and it seemed fine" into an objective
pass/fail, and it's what makes a regression detectable months later.

### Pick the format first

**Default to Journeys (`src/journeysTest/*.journey.xml`) for feature-behaviour scenarios.** Same
idea as the Markdown format below, but machine-parseable, reportable as ordinary JUnit/Gradle
tests, and runnable both in Android Studio and locally against your own agent via
`fornewid/journeys-test`. Wiring in `ecosystem.md` §3.

**Keep the Markdown ADB format for what Journeys cannot express** — and check this list before
assuming a scenario fits:

| Keep as an ADB test | Because |
|---|---|
| Runtime permission grant/deny | A Journey may auto-grant every permission, so the denial path is never exercised and the test passes for the wrong reason |
| Fault injection against a peer | Needs a scriptable way to make the peer refuse/hang/starve/vanish |
| LAN / discovery / real-rig work | The emulator cannot do multicast or unsolicited inbound UDP at all |
| ARM verification, artifact shape | `${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh`, not a UI flow |
| Toolchain and build-config guards | Not a device behaviour |
| Soak (fd/thread/memory before-after) | Needs process-level measurement |

Both formats feed the same gate. Whichever you use, the harness conventions below still apply —
they are about *rigs and evidence*, not about file format.

### `tests/README.md` — the shared harness

Every test file depends on it, so it comes first:

- **The rigs.** Name each one (emulator + simulated peer / real device + simulated peer / real
  device + real hardware), what each can prove, and — importantly — **what each cannot**. A test
  needing a rig you don't have is **BLOCKED, not FAIL**; never let an environment gap masquerade as
  a defect, and never substitute a weaker rig's pass for a stronger rig's requirement.
- **Arch tags**, if the app ships to ARM: `any` / `arm64` / `device`. An x86_64 emulator pass is not
  evidence for an `arm64`-tagged test.
- **Shared variables** exported once — `ADB`, `PKG`, `ACT`, `APK` — so every step below is
  copy-pasteable without re-deriving paths.
- **Common commands**: build, install (**asserting on `Success`** — `adb install` reports failure on
  stderr, so an unasserted pipeline makes a rejected install look identical to a good one), reset to
  first-run state (`pm clear`), launch, force-stop, screenshot via `exec-out`, foreground check via
  `topResumedActivity`, UI dump, input injection, crash check.
- **A tap-by-label helper** that derives coordinates from a UI dump, so layout changes don't stale
  every test.
- **The traps that have produced confidently wrong results**, spelled out. Two universal ones:
  *confirm which app is actually in front before believing a screenshot*, and *never conclude
  anything from an absence of events* — a system dialog silently swallows injected taps and logs
  nothing, so "no response" can mean "the tap never arrived."

### `tests/NN-<area>.md` — one file per feature area

Numbered so they can be run in order for a full pass, or individually. Each scenario:

```
### N.M <short title>
- SETUP: the rig, and the exact state required before starting
- STEPS: numbered, with the commands to run
- EXPECTED: what should happen, concretely
- VERIFY: the objective check — a log line, a UI-dump string, a named screenshot
- PASS/FAIL: PASS if <condition>. FAIL if <condition>. BLOCKED if <rig gap>.
```

Coverage worth having in every project, from the corpus's suite:

| Area | What it pins |
|---|---|
| Build, install, launch | Clean build, unit tests green, install asserts `Success`, first launch has no crash, expected permissions and no unexpected prompt |
| Toolchain guards | Regressions in build config that silently break things (plugin conflicts, wrapper/AGP version pairings) |
| Artifact shape | The APK carries every shipping ABI; signature version; release-build size and dex count |
| Each feature surface | One file per screen or subsystem |
| Lifecycle | Rotation, background/resume, back stack, cold start, process death |
| Failure and resilience | Every way the app's dependencies can fail — refused, hung, starved, vanished — and what the user sees for each |
| Permission denial | A **deny-everything** run: revoke every permission, cold-start, and drive the main flow. Each enhancing denial leaves the workflow completing with a visible reason and a working inline retry; each essential denial explains itself and offers a way forward. Also run the *permanently* denied state, where the system prompt no longer appears |
| Empty and first-run state | The no-data screens say so rather than rendering a number computed from nothing. Worth a **screenshot test** (`testing-and-bugs.md` §3b) — this invariant is visual, and a golden image checks it directly |
| Soak | Repeat the flap/recover cycle N times; compare fd/thread/memory before and after |
| Platform behaviour at `targetSdk` 36 | Insets handled with edge-to-edge forced on; predictive back leaves no orphaned `onBackPressed()` guard; a portrait-locked layout survives a landscape tablet window (`platform-currency.md` §4) |

**Fault injection is worth building** when the app depends on something external. A scriptable way
to make the peer fail on demand (refuse, hang, starve, disappear) is what turns resilience from an
untested claim into a test file. Assert against the app's own named constants (retry budgets,
timeouts, backoff) so an expectation and the code can't drift apart silently.

**Exit gate:** the suite runs end to end, and every result is PASS or an explicitly recorded
BLOCKED/FAIL.

---

## Phase 5 · Adversarial audit, then scoped parallel fixes

Full detail in `testing-and-bugs.md`; the shape is:

1. **Adversarial audit** against the named defect classes, with a mandated output format, and the
   safety invariant restated verbatim. Not "review this code." **Cite an official page per
   finding**, and where the app holds sensitive data, use **MASVS control IDs** as the finding
   vocabulary so a name means the same thing in every session (`testing-and-bugs.md` §1b).
   Google's `r8-analyzer`, `android-profiler` and `android-intent-security` skills cover release
   quality, performance and the intent surface — areas with no equivalent here (`ecosystem.md` §2).
2. **Partition the findings by file**, dispatch one scoped fix-agent per partition, each with a hard
   allowlist and an explicit "another agent owns X" (see `subagent-delegation.md`).
3. **Design review, if the app has a UI** — screenshot every reachable screen and state, then run
   the three-seat council over the set (`design-phase.md` §6). A code audit and a design review find
   disjoint defect sets, so this is not covered by step 1. Weight findings by how many seats reached
   them independently, and convert every P0/P1 into a Phase 4 scenario (`design-phase.md` §7).
4. **Integration build**, then **re-run the Phase 4 suite** — not a spot check.
5. **Add a regression test for every fix that corrected a *silent* failure.** A silent failure that
   regresses is invisible again; this is the highest-value test category in the corpus and the one
   most often skipped.

**Exit gate:** zero unresolved Critical/High findings, or each one explicitly accepted in writing
with a reason.

---

## Phase 6 · Beta release

- **Decide the distribution identity before building.** Intake Q10's answer also determines
  whether **developer verification** applies (`platform-currency.md` §6). ADB sideloading to your
  own device is unaffected; a **limited distribution account** — no ID, no fee, up to 20 devices —
  covers "a handful of named people"; Play means the `targetSdk` policy deadlines bind. Write down
  which one this is, so a later session neither panics into registering an account it doesn't need
  nor ships into a channel it hasn't qualified for.
- **Ship the release build, never the debug one** — especially to a watch. In this corpus a debug
  watch APK (33 MB of dex across 16 files) would not install on real hardware; minified it was 2.8 MB
  in one dex. Do not let a plausible wrong theory (architecture, ABI) eat an afternoon: check the
  artifact directly. **`${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh <apk> --release` does this in one command** —
  ABIs, `targetSdk`, signature scheme, dex count, and whether the build is still debuggable.
- **Verify the signature**, and that a v2 signature is present — v1-only fails to install on modern
  API levels. If there's a companion (watch, second app), **both must use the same key**, or they
  install fine, run fine, and can't talk to each other with nothing on screen to say why. The
  script prints the certificate SHA-256 for exactly this comparison.
- **Wear OS, if in scope:** 64-bit is required by Play since 2026-09-15 for anything shipping native
  code (both 32- and 64-bit, not a replacement), and Watch Face Format is required for watch faces.
  `targetSdk` floor is 35, not 36 (`platform-currency.md` §7).
- **Keep-rule discipline for R8.** Anything reflective or serialized needs keep rules, and a
  stripped serializer is a classic silent failure — it surfaces as a wrong user-facing message about
  a file that is perfectly intact. Re-run the round-trip test after any keep-rule change.
- **Automate the upload if this goes to Play more than once.** **Gradle Play Publisher** builds,
  uploads and promotes bundles and listings with `track`, `releaseStatus`, `userFraction` and
  `updatePriority` config. **Pin the right major: GPP 3.13.0 for AGP 7–8, 4.x for AGP 9+** — with
  the pins in `platform-currency.md` that means 4.x. `fastlane supply` is the established
  alternative. (`gplay`, a newer Go CLI positioned for agentic flows, is unproven — don't put a
  release path on it yet.) Google's `play` skill covers the submission mechanics.
- **Publish, then document the diagnostics.** The recurring closing instruction in the corpus is:
  *implement the recommendations, publish a beta, push all the code, and make sure the debug
  commands are documented in the docs folder before pushing everything up.* The `adb` commands used
  to diagnose something belong in `docs/DEBUGGING.md` the same day they were useful.
- **Real-hardware testing starts here, and it is not optional.** Expect the bug reports that come
  back to be sharper than anything the emulator surfaced. `testing-and-bugs.md` §4 has the report
  structure worth asking for.

**Exit gate:** the build is installed on the real target device, launched, and exercised.

---

## Phase 7 · Handoff and reproducibility

Written so a *different* session on a *different* machine could pick this up cold:

- **`CLAUDE.md`** current: read-these-first table, constraints, module map, house rules.
- **`docs/EMULATOR.md`** (or equivalent): compatibility targets, the full toolchain install, the
  verified emulator matrix, and the build/install/launch sequence. This skill's
  `windows-toolchain-and-emulators.md` is the generic version to adapt.
- **`docs/DEBUGGING.md`**: diagnosing the real device — permissions, silent failures, install
  errors, and what each answer means.
- **A revisions log** (`HANDOFF.md` in the corpus): what changed, what it found, and what remains
  open. The sections that earn their keep are *"open questions — these need the user's decision, not
  yours"* and *"do not regress these"*.
- **Schema/migration contract**, if there's a database: export the schema and commit it, forbid the
  destructive migration fallback, and write down the rules that were learned the hard way.

**Exit gate:** a cold session, given only the repo, can build, run, and test the app without asking
a question that's already answered somewhere in it.
