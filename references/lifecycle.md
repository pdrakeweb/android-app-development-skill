# The Project Lifecycle

The ordered process every successful app in this corpus actually followed. Each phase has an
**artifact**, an **exit gate**, and a rule about what must not start early. Deviations from this
order are where things went sideways — most often, code written before a spec existed, and test
scenarios written after the bugs had already been found by hand.

```
0 Interview  →  1 Spec  →  2 Plan  →  3 Implement  →  4 Test scenarios
                                            ↑              ↓
                                            └── 5 Audit & fix ──→  6 Beta  →  7 Handoff
```

Phases 3–5 loop. Phases 0–2 happen once, and re-opening them later is a deliberate act that
gets written down, not a drift.

---

## Phase 0 · Interview

**Artifact:** answered question set (in the conversation).
**Reference:** `intake-interview.md`.
**Do not start:** any scaffold, any dependency choice, any repo.

**Exit gate:** the answers played back as a summary, and explicitly confirmed.

---

## Phase 1 · `docs/APP_SPEC.md`

The spec is written *for the agent that will build it*, not as a document to admire. Structure that
worked, in this order:

1. **What this is, and what it is not.** Lead with the "not". One paragraph.
2. **Compatibility targets** — a table, with a hard split between *supported* and *actually tested*.
   `minSdk` / `targetSdk` / `compileSdk` / JDK / Gradle, and where each is declared (a version
   catalog, so nothing can drift). Name the real target hardware and the shipping ABI.
3. **The constraints that override everything** — numbered, two or three at most. These are the ones
   that make a later feature request a spec violation rather than a debate.
4. **The named safety/correctness invariant** (interview Q9), phrased so it can be pasted verbatim
   into an audit prompt.
5. **Screens, or surfaces** — one section each: what it shows, what it reads, what rules it must
   honour. Include what each shows **with no data yet**.
6. **Background work** — what runs when the UI isn't up, what schedules it, what it must never do.
7. **Data and permissions** — what's stored, where, backup eligibility, every restricted capability
   and its denied-state behaviour.
8. **What this app must never do** — the verbatim list from the interview.
9. **Needs a decision, not a guess** — every open question, unresolved, attributed to the user.
10. **Answered, so nobody re-opens it** — decisions already made, with their reasons.

Companion artifacts, created here when the interview called for them:

- **`docs/DESIGN_TOKENS.md`** — colours, type scale, metrics, and any semantic palette (alert
  ladders, state colours). Include a *"rules that are not decoration"* section: if colour carries
  meaning, state how form reinforces it so the meaning survives a glance and colourblindness.
- **Mockups / artboards**, if chosen. State explicitly which is the design of record when the
  mockup and the spec text disagree.
- **`docs/adr/ADR-NNNN-*.md`** for any decision that's expensive to reverse — module boundaries,
  an on-device-vs-cloud split, a wire format, a safety rule. An ADR is cheaper than re-deriving the
  reasoning in six weeks.
- **`CLAUDE.md`** — write it now, not at the end. It is the orientation handout for every future
  session and subagent: what this is, a *"read these first"* table pointing at the other docs, the
  constraints, the module map with allowed dependency edges, the house rules, and where to ask
  rather than guess. Keeping it current is part of every later phase.

**Exit gate:** the user has read the spec and confirmed it — particularly §8 and §9.

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
  State it explicitly each time rather than assuming it's implied. See
  `windows-toolchain-and-emulators.md` for the emulator mechanics and
  `bootstrapping.md` for the architecture defaults.
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

## Phase 4 · Test scenarios in `tests/`

Written as Markdown an **agent** can execute against an emulator, not as prose a human has to
interpret. This is the artifact that turns "I clicked around and it seemed fine" into an objective
pass/fail, and it's what makes a regression detectable months later.

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
| Empty and first-run state | The no-data screens say so rather than rendering a number computed from nothing |
| Soak | Repeat the flap/recover cycle N times; compare fd/thread/memory before and after |

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
   safety invariant restated verbatim. Not "review this code."
2. **Partition the findings by file**, dispatch one scoped fix-agent per partition, each with a hard
   allowlist and an explicit "another agent owns X" (see `subagent-delegation.md`).
3. **Integration build**, then **re-run the Phase 4 suite** — not a spot check.
4. **Add a regression test for every fix that corrected a *silent* failure.** A silent failure that
   regresses is invisible again; this is the highest-value test category in the corpus and the one
   most often skipped.

**Exit gate:** zero unresolved Critical/High findings, or each one explicitly accepted in writing
with a reason.

---

## Phase 6 · Beta release

- **Ship the release build, never the debug one** — especially to a watch. In this corpus a debug
  watch APK (33 MB of dex across 16 files) would not install on real hardware; minified it was 2.8 MB
  in one dex. Do not let a plausible wrong theory (architecture, ABI) eat an afternoon: check the
  artifact directly with `aapt2 dump badging`.
- **Verify the signature**, and that a v2 signature is present — v1-only fails to install on modern
  API levels. If there's a companion (watch, second app), **both must use the same key**, or they
  install fine, run fine, and can't talk to each other with nothing on screen to say why.
- **Keep-rule discipline for R8.** Anything reflective or serialized needs keep rules, and a
  stripped serializer is a classic silent failure — it surfaces as a wrong user-facing message about
  a file that is perfectly intact. Re-run the round-trip test after any keep-rule change.
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
