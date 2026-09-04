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
| `references/intake-interview.md` | Ten broad-to-narrow questions asked before any code, plus dynamically generated follow-ups |
| `references/lifecycle.md` | The eight phases, each with an artifact and an exit gate |
| `references/platform-currency.md` | Dated version pins, the AGP 9 break, API 36 behaviours that break working apps, Play deadlines, developer verification |
| `references/ecosystem.md` | Android CLI, the per-phase Google-skill routing table, Journeys, MCP device control, prior art |
| `references/bootstrapping.md` | Starting a project, or extracting one from a monorepo; architecture defaults |
| `references/windows-toolchain-and-emulators.md` | Toolchain install without Android Studio, and phone/tablet/Wear OS emulators |
| `references/testing-and-bugs.md` | The adversarial audit prompt, scoped parallel fix agents, MASVS vocabulary, test plans, screenshot testing, bug-report structure |
| `references/permissions-storage-cloud.md` | Runtime permissions, local storage, schema/migration discipline, sync, cloud and LLM hardening, hybrid inference |
| `references/subagent-delegation.md` | Surface selection, research delegation, scoped fix agents, parallel-session integration |
| `scripts/` | Deterministic checks — preflight, install verification, artifact inspection |
| `hooks/` | Advisory PostToolUse guardrails (never blocking) |

## The process it runs

```
0 Interview  →  1 Spec  →  2 Plan  →  3 Implement  →  4 Test scenarios
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

**From source, on Windows:**

```powershell
.\build.ps1                      # produces android-app-development.zip
.\deploy.ps1 -RestartClaude      # installs into Claude Desktop and restarts it
```

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

**Installing it** — clone [`pdrakeweb/council-skill`](https://github.com/pdrakeweb/council-skill),
build the package, and upload it:

```bash
git clone https://github.com/pdrakeweb/council-skill
cd council-skill
./build.sh --zip          # Windows: .\build.ps1
```

Then **Settings → Capabilities → Skills → Upload a skill** and pick the resulting `council.zip`. On
Windows, `.\deploy.ps1 -RestartClaude` installs it into Claude Desktop directly.

> Two caveats, both accurate as of this writing. The council repository is **private**, so the links
> above will 404 unless you have access. And unlike this repo, it ships no `.claude-plugin/`
> manifest, so there is no `/plugin marketplace add` path for it yet — build-and-upload is the
> install route. Neither is a blocker: **the skill degrades cleanly**, doing the same research
> inline with web search when `council` isn't present.

### About the hooks

The plugin ships a `PostToolUse` hook that flags known silent-failure patterns — an `adb install`
whose result isn't asserted, an `onBackPressed()` override that `targetSdk` 36 will never call, an
empty `catch` block, `fallbackToDestructiveMigration`. It is **advisory only**: it always exits 0
and never blocks a tool call, because a guardrail that blocks on a false positive just trains you
to disable it. Requires `node` on `PATH`. Delete `hooks/` if you don't want it.

## Scripts

Run them instead of asserting the outcome:

| Script | Answers |
|---|---|
| `scripts/preflight.sh [dir]` | Does this machine's toolchain match the pins, and what does the project actually declare? |
| `scripts/verify-install.sh <apk> <pkg>` | Did it install, launch, reach the foreground, and survive without crashing? |
| `scripts/verify-artifact.sh <apk> [--release]` | Right ABIs, `targetSdk`, v2+ signature, and not accidentally debuggable? |

## A note on the examples

The examples cite three apps — `vitals-watch` (phone + Wear OS health alerts), `field-assistant`
(offline-capable tablet assistant with on-device/cloud model routing), and `panel-remote`
(LAN remote control for networked equipment). These are generalized, renamed stand-ins for real
private projects. The lessons and failure modes are real; the names and identifying details are not.

Techniques for circumventing another vendor's licensing, DRM, or device pairing are deliberately
excluded — see the closing section of `references/testing-and-bugs.md`.

## Currency

The version pins in `SKILL.md` and `references/platform-currency.md` were **verified 2026-09-04**
against developer.android.com. They have a shelf life measured in weeks. `platform-currency.md` §2
says how to re-verify in three steps, and `scripts/preflight.sh` checks a machine and a project
against them. If this repo's pins are stale, that file is the one to fix.

## Licence

Apache 2.0 — see [LICENSE](LICENSE).
