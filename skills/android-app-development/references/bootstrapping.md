# Bootstrapping an Android Project

**Contents:** [Before anything](#before-anything-pin-the-toolchain) ·
[Pattern A — clone a spec](#pattern-a--clone-a-spec-and-implement) ·
[Pattern B — extract from a monorepo](#pattern-b--extract-a-sub-project-from-a-monorepo) ·
[Architecture defaults](#architecture-defaults-worth-setting-from-the-first-commit)

## Before anything: pin the toolchain

**Read `platform-currency.md` §1 and run `${CLAUDE_SKILL_DIR}/scripts/preflight.sh` before you scaffold.** A cold
session working from training data will produce an AGP 8-era project that does not build under the
current toolchain, and the errors do not name the real cause. This is the cheapest failure in the
whole process to avoid and the most expensive to debug after the fact.

The two things most likely to be wrong out of memory: **AGP 9 no longer applies the Kotlin Android
plugin** (Kotlin is built in, and the old plugin is incompatible with the new DSL), and **Gradle
9.6.0 is the minimum**. Install Google's `agp-9-upgrade` skill (`ecosystem.md` §2) and let
it own the details.

### Prefer `android create` over a hand-written scaffold

Google's Android CLI generates from official, maintained templates:

```bash
android sdk install          # component-level, no Android Studio needed
android create               # scaffold from an official template
android init                 # install the android-cli skill so agents can drive it
#                              (the CLI itself: `ecosystem.md` §1 — install it before any of this)
```

This is strictly better than reconstructing a `build.gradle.kts` from memory, because the template
tracks the toolchain and your memory does not. See `ecosystem.md` §1 — including the verified
Windows limitation: **`android emulator` does not work on Windows**, so AVDs stay manual there
(`windows-toolchain-and-emulators.md` §3).

Two proven starting patterns follow, both taken near-verbatim from prompts that worked.

## Pattern A — Clone-a-spec-and-implement

Used when there's already a planning/spec repo (even a rough one) and the actual code doesn't exist yet.

> Clone [repo URL] into a subdir of Source and evaluate the implementation spec/planning docs, fix where needed then begin implementation of both the Android phone app and the associated watch app if needed.

Key structural elements worth keeping if you adapt this:
- **Evaluate before implementing** — the spec gets a real review pass, not a skim. "Fix where needed" is explicit permission to correct the spec itself, not just follow it blindly.
- **Ask about companion targets up front** ("...and the associated watch app if needed") rather than discovering a Wear OS module is needed halfway through.
- The natural next prompt in this pattern is: *"Do a full review then continue implementation and build APKs when done"* — review-then-build-then-APK is the expected unit of work, not "write some code."

## Pattern B — Extract a sub-project from a monorepo

Used when a project started as a subdirectory of a larger repo and has grown enough to deserve its own home (this is exactly how `panel-remote` came out of the research repo it started in).

Diagnostic step first — don't assume, check:

> Run `git log --oneline -10`, `ls`, and inspect the project layout. Determine whether [project] is a subdirectory within a larger monorepo ([parent]) or if this entire repo IS the [project] app. This determines whether you need a subtree split or a simple clone+push.

Then, once confirmed as a subdirectory:

> ok, create a new subdir in source for [project] and clone it there. we can just work from that and remove the [project] subdir from [parent] now.

Notes:
- This is a `git subtree`-style extraction, not a fresh `git init` — history matters, don't lose it.
- Clean up the source location (`remove the ... subdir from [parent]`) as part of the same task, not a follow-up — otherwise you end up with two copies drifting apart.
- If the extracted project is going to be shared, reused, or built by anyone other than the original author, add clean-room/licensing documentation (`CLEAN-ROOM.md`, `LICENSE`, `NOTICE`) at extraction time, especially if any part of the original codebase involved reverse-engineering or protocol reimplementation — see the note in `testing-and-bugs.md` about keeping that separate from general app-development technique.

## Architecture defaults worth setting from the first commit

Pulled from what the audits in this corpus treat as load-bearing, not optional:

- **A pure-Kotlin `:domain` module that imports nothing from `android.*` or `androidx.*`.** Audits explicitly flag any Android import in `:domain` as a Critical architecture violation. Decide this at bootstrap time — retrofitting purity onto a domain module that's already accumulated Android imports is much more painful than starting clean.
- **Jetpack Compose + Hilt** is the default stack across every app in the corpus. minSdk 28 was the observed floor; `compileSdk`/`targetSdk` track `platform-currency.md` §1 rather than being decided here. Room + sqlite-vec for anything needing local hybrid search/retrieval.
- **Navigation 3** is the current navigation answer — install Google's `navigation/navigation-3` skill and pin the catalog version rather than improvising a nav graph. Deciding this at scaffold time is much cheaper than migrating later.
- **Handle window insets from the first screen.** At `targetSdk` 36 edge-to-edge is mandatory and cannot be opted out of, so content draws under the system bars whether the layout is ready or not. This is not polish deferred to a later pass — it is a correctness requirement from the first commit, and Google ships an `edge-to-edge` skill for it. Same for **predictive back**: build on `OnBackPressedDispatcher` / `BackHandler`, never `onBackPressed()`, which is no longer called at all (`platform-currency.md` §4).
- **A single non-negotiable safety/correctness invariant, named explicitly in `CLAUDE.md` or an ADR**, if the app has one (see the SKILL.md house rules). Write it down before the first audit, not after the first violation.
- Decide the **on-device vs. cloud routing story** up front if the app does any LLM/AI work locally — the most mature app in the corpus (`field-assistant`) routes between a quantized on-device model and a cloud API behind one UI, with the routing decision itself treated as safety-critical code (see the emergency-content invariant).
