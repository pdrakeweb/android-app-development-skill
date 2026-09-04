# android-app-development — a Claude skill

A guided workflow for building native Android apps with Claude Code: it turns "build me an Android
app" into a structured interview, a spec, a plan you approve before any code is written, an
agent-executable test suite, an adversarial audit, and a beta release.

It is deliberately **opinionated**. Everything here is distilled from sessions that produced a
working APK, a merged fix, or a documented finding — not from generic Android advice. Where a rule
seems oddly specific, it's because something broke that way once.

## What's in it

| File | Covers |
|---|---|
| `SKILL.md` | Entry point: the phase table, the reference index, and the house rules |
| `references/intake-interview.md` | Ten broad-to-narrow questions asked before any code, plus dynamically generated follow-ups |
| `references/lifecycle.md` | The eight phases, each with an artifact and an exit gate |
| `references/bootstrapping.md` | Starting a project, or extracting one from a monorepo; architecture defaults |
| `references/windows-toolchain-and-emulators.md` | Fresh-Windows toolchain install (no Android Studio) and phone/tablet/Wear OS emulators |
| `references/testing-and-bugs.md` | The adversarial audit prompt, scoped parallel fix agents, ADB test plans, bug-report structure |
| `references/permissions-storage-cloud.md` | Runtime permissions, local storage, schema/migration discipline, sync, cloud and LLM hardening |
| `references/subagent-delegation.md` | Research delegation, scoped fix agents, and parallel-session integration |

## The process it runs

```
0 Interview  →  1 Spec  →  2 Plan  →  3 Implement  →  4 Test scenarios
                                            ↑              ↓
                                            └── 5 Audit & fix ──→  6 Beta  →  7 Handoff
```

Phase 2's gate is the important one: **the plan is approved before any implementation code is
written.** Reordering a plan is cheap; reordering a codebase is not.

## Installing

**From a release:** download `android-app-development.zip` from the
[latest release](../../releases/latest), then in Claude Desktop or claude.ai go to
**Settings → Capabilities → Skills → Upload a skill**.

**From source, on Windows:**

```powershell
.\build.ps1                      # produces android-app-development.zip
.\deploy.ps1 -RestartClaude      # installs into Claude Desktop and restarts it
```

`deploy.ps1` registers the skill in Claude Desktop's `manifest.json`. That step matters: Claude
Desktop only loads skills listed there, so copying the files alone leaves the skill invisible.

## A note on the examples

The examples cite three apps — `vitals-watch` (phone + Wear OS health alerts), `field-assistant`
(offline-capable tablet assistant with on-device/cloud model routing), and `panel-remote`
(LAN remote control for networked equipment). These are generalized, renamed stand-ins for real
private projects. The lessons and failure modes are real; the names and identifying details are not.

Techniques for circumventing another vendor's licensing, DRM, or device pairing are deliberately
excluded — see the closing section of `references/testing-and-bugs.md`.

## Licence

Apache 2.0 — see [LICENSE](LICENSE).
