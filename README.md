# android-app-development — a Claude Code plugin

A guided workflow for building native Android apps with Claude Code: it turns "build me an Android
app" into a structured interview, a spec, a plan you approve before any code is written, an
agent-executable test suite, an adversarial audit, and a beta release.

It is deliberately **opinionated**. Everything here is distilled from sessions that produced a
working APK, a merged fix, or a documented finding — not from generic Android advice. Where a rule
seems oddly specific, it's because something broke that way once.

## What this is, and what it is not

It is a **process spine**: the gates, the order of work, and the failure modes that recur across
projects. It is **not** an Android API reference, and it deliberately does not try to be one — that
knowledge goes stale in ninety days, and Google now ships [official, maintained agent
skills](https://github.com/android/skills) for it.

So this plugin **routes to those instead of duplicating them.** `references/ecosystem.md` maps each
phase to the Google skill that owns it — `agp-9-upgrade` at scaffold time, `edge-to-edge` for any
UI, `r8-analyzer` before release. **When a Google skill disagrees with something written here, it
wins.** Install this one *alongside* them, not instead of them.

## What's in it

| File | Covers |
|---|---|
| `SKILL.md` | Entry point: the phase table, the version pins, the reference index, the house rules |
| `references/user-calibration.md` | Establishing the user's experience level, then tuning vocabulary, explanation depth and how much to decide for them; plain-language glossary for every term the skill uses |
| `references/intake-interview.md` | Ten broad-to-narrow questions asked before any code, dynamically generated follow-ups, and an optional persona interview |
| `references/design-phase.md` | Design tokens, mockup generation and the converge-on-one loop, seed-colour theme generation, contrast as a unit test, and the three-seat council design review |
| `references/lifecycle.md` | The nine phases (0 through 7, with a 1b), each with an artifact and an exit gate, and a path for building a library |
| `references/platform-currency.md` | Dated version pins, a process for choosing dependencies that work together, the AGP 9 break, API 36 behaviours that break working apps, Play deadlines, developer verification |
| `references/target-sdk-gotchas.md` | What breaks when `targetSdk` goes up, API 31 through 37, plus manufacturer battery behaviour no target warns about |
| `references/ecosystem.md` | Android CLI, the per-phase Google-skill routing table, Journeys, MCP device control, prior art |
| `references/bootstrapping.md` | Starting a project, or extracting one from a monorepo; architecture defaults |
| `references/windows-toolchain-and-emulators.md` | Toolchain install without Android Studio, and phone/tablet/Wear OS emulators |
| `references/testing-and-bugs.md` | The adversarial audit prompt, scoped parallel fix agents, MASVS vocabulary, test plans, scripted journeys, screenshot testing, real-thing tests beside fakes, bug-report structure |
| `references/permissions-storage-cloud.md` | Runtime permissions, local storage, schema/migration discipline, sync, downloads, cloud and LLM hardening, hybrid inference |
| `references/subagent-delegation.md` | Surface selection, research delegation, scoped fix agents, an invariant-anchored review brief, parallel-session integration |
| `references/context-economy.md` | Cutting token use without losing information: `CLAUDE.md` as an index, deny rules for build output, filtering Gradle output to failures and a summary, retrofitting an existing repository |
| `scripts/` | Deterministic checks — preflight, install verification, artifact inspection — and `qrun.js`, a wrapper that prints only what failed |
| `hooks/` | PostToolUse hooks (never blocking): advisory guardrails, and a filter that cuts Gradle output to failures and a summary |

## The process it runs

```
0 Interview  →  1 Spec  →  1b Design  →  2 Plan  →  3 Implement  →  4 Test scenarios
                                                          ↑              ↓
                                                          └── 5 Audit & fix ──→  6 Beta  →  7 Handoff
```

Phase 2's gate is the important one: **the plan is approved before any implementation code is
written.** Reordering a plan is cheap; reordering a codebase is not.

## Installing

**As a Claude Code plugin (recommended):**

```
/plugin marketplace add pdrakeweb/android-app-development-skill
/plugin install android-app-development@pdrakeweb-android
```

This is the path that gets you the `scripts/` and the guardrail hooks as well as the skill itself.

**As a Claude Desktop / claude.ai skill:** download `android-app-development.zip` from the
[latest release](../../releases/latest), then go to **Settings → Capabilities → Skills → Upload a
skill**.

**From source:**

```bash
./build.sh                       # macOS / Linux / Git Bash
```

```powershell
.\build.ps1                      # Windows
.\deploy.ps1 -RestartClaude      # installs into Claude Desktop and restarts it
```

Both produce the same payload and run the same validations — name rules, description length, and
version agreement between `SKILL.md` and `plugin.json`. `build.sh` is what CI runs, so those checks
are enforced on every push rather than only when someone happens to build on Windows.

`deploy.ps1` registers the skill in Claude Desktop's `manifest.json`. That step matters: Claude
Desktop only loads skills listed there, so copying the files alone leaves the skill invisible.

### Optional companion: the `council` skill

At novice and beginner levels this skill does more than translate vocabulary — for decisions that
are **expensive to reverse** (local-only vs cloud sync, on-device vs cloud AI, whether this needs a
backend at all, how far back to support old phones), it researches the choice and brings back a
recommendation rather than handing the user a menu they can't evaluate.

The [`council`](https://github.com/pdrakeweb/council-skill) skill is what backs that up. It convenes
sub-agents who debate in clean parallel contexts, cross-examine each other, and return a verdict
with an explicit confidence level — which is the right shape for a recommendation the user cannot
audit themselves. It is **optional**: without it, the same rigour happens inline with web search,
just with fewer agents.

**Installing it:**

```
/plugin marketplace add pdrakeweb/council-skill
/plugin install council@pdrakeweb-council
```

Or build and upload it — clone [`pdrakeweb/council-skill`](https://github.com/pdrakeweb/council-skill),
run `./build.sh --zip` (Windows: `.\build.ps1 -Zip`), then **Settings → Capabilities → Skills →
Upload a skill**.

It is genuinely optional: with `council` absent, the skill runs the same research inline with web
search and reaches a recommendation the same way — just with fewer agents arguing about it.

### About the hooks

The plugin ships a `PostToolUse` hook that flags known silent-failure patterns — an `adb install`
whose result isn't asserted, an `onBackPressed()` override that `targetSdk` 36 will never call, an
empty `catch` block, `fallbackToDestructiveMigration`. It is **advisory only**: it always exits 0
and never blocks a tool call, because a guardrail that blocks on a false positive just trains you
to disable it. Requires `node` on `PATH`. Delete `hooks/` if you don't want it.

A second hook, `gradle-quiet.js`, lowers what a session costs. A raw Gradle run is usually the
largest thing a session puts into context, and every later turn pays to re-read it. The hook
rewrites Gradle output from the Bash and PowerShell tools before the model sees it: a passing build
becomes its summary lines, a failing build keeps every failed task's output, every compiler error
and the failure report. In testing a 56 KB task listing came back as 2 KB. The full output is
always saved and its path printed, output of 40 lines or fewer is left alone, anything the hook
does not recognise is left alone, and `GRADLE_RAW` anywhere in a command turns it off for that run.
`references/context-economy.md` covers the rest: keeping `CLAUDE.md` short, and deny rules that
keep the file tools out of build intermediates.

## Validating the repo

```bash
bash tools/validate-repo.sh
```

Checks what the house rules imply: shell and hook syntax, the guardrail hook's actual behaviour
(fires on a real pattern, stays silent on the correct form, survives malformed input), JSON
validity of every manifest, `SKILL.md` frontmatter against Anthropic's naming and description
rules, version drift between `SKILL.md` and `plugin.json`, and docs integrity — every referenced
file exists, every `§N` cross-reference resolves, code fences balance, and every script the docs
promise actually ships.

CI runs the same script on every push and pull request, plus `shellcheck` and a smoke test that the
shipped scripts fail cleanly on bad input. Nothing here is bundled into the skill package.

## Scripts

Run them instead of asserting the outcome. Paths below are from the repo root; **inside the skill
they are referenced as `${CLAUDE_SKILL_DIR}/scripts/...`**, which resolves wherever the skill is
installed — a bare `scripts/...` would resolve against the user's own project, which frequently has
a `scripts/` directory of its own.

| Script | Answers |
|---|---|
| `skills/android-app-development/scripts/preflight.sh [dir]` | Does this machine's toolchain match the pins, and what does the project actually declare? |
| `skills/android-app-development/scripts/verify-install.sh <apk> <pkg>` | Did it install, launch, reach the foreground, and survive without crashing? |
| `skills/android-app-development/scripts/verify-artifact.sh <apk> [--release]` | Right ABIs, `targetSdk`, v2+ signature, and not accidentally debuggable? |
| `skills/android-app-development/scripts/fit-emulator-windows.ps1` | Windows: are the emulator windows a person must use on screen and inside the usable area? |

## A note on the examples

The examples cite three apps — `vitals-watch` (phone + Wear OS health alerts), `field-assistant`
(offline-capable tablet assistant with on-device/cloud model routing), and `panel-remote`
(LAN remote control for networked equipment). These are generalized, renamed stand-ins for real
private projects. The lessons and failure modes are real; the names and identifying details are not.

Techniques for circumventing another vendor's licensing, DRM, or device pairing are deliberately
excluded — see the closing section of `references/testing-and-bugs.md`.

## Releasing

Tag it; CI does the rest.

```bash
git tag v0.2.0 && git push origin v0.2.0
```

The `release` workflow validates the repo, builds the package, **refuses to publish if the tag
disagrees with the version in `SKILL.md`**, and attaches the zip to a GitHub Release. It can also
be run manually from the Actions tab.

## Currency

The version pins in `SKILL.md` and `references/platform-currency.md` were **verified 2026-09-04**
against developer.android.com. They have a shelf life measured in weeks. `platform-currency.md` §2
says how to re-verify in three steps, and `scripts/preflight.sh` checks a machine and a project
against them. If this repo's pins are stale, that file is the one to fix.

## Licence

Apache 2.0 — see [LICENSE](LICENSE).
