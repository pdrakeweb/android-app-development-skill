# The Agent Tooling Ecosystem

Google now ships an official agent-first Android toolchain. This skill's value is the **process
spine** — the interview, the gates, the audit discipline. Their value is **API-level ground truth
that goes stale in ninety days**. Do not absorb theirs into this one; route to it.

The rule: **when a Google skill covers the thing you're about to do, install it and defer to it.**
When it disagrees with anything written here, it wins.

**Contents**

- [1 · Android CLI](#1--android-cli-the-default-toolchain-path) — the default toolchain path
- [2 · Google's `android/skills`](#2--googles-androidskills-per-phase-routing) — per-phase routing table
- [3 · Journeys](#3--journeys-agent-executable-e2e-tests) — agent-executable E2E tests
- [4 · Device control from an agent](#4--device-control-from-an-agent) — MCP options beyond raw ADB
- [5 · Prior art](#5--prior-art-worth-installing-alongside)

---

## 1 · Android CLI, the default toolchain path

`android` is Google's official command-line entry point for agent-driven Android work. It replaces
most of what `windows-toolchain-and-emulators.md` does by hand. Google reports it cuts agent token
usage by >70% and completes tasks ~3x faster than an agent driving Android Studio.

| Command | Does |
|---|---|
| `android sdk install` / `list` / `update` | Component-level SDK installs — no Android Studio |
| `android create` | Scaffold a project from an official template |
| `android emulator` | Create, list, start, stop AVDs |
| `android run` | Build and deploy to a device or emulator |
| `android describe` | Analyse a project, emit structure/build metadata |
| `android docs` | Search and fetch from the Android knowledge base |
| `android skills add <name>` | Install a Google skill into the project (§2) |
| `android init` | Install the `android-cli` skill so agents know how to drive it |
| `android layout` / `screen capture` / `screen resolve` | UI hierarchy as JSON, screenshots, coordinate resolution |

**`android layout` and `screen resolve` deserve attention** — they are a first-party replacement for
the fragile "dump the UI XML and derive tap coordinates" helper in `lifecycle.md` Phase 4. Prefer
them where available.

### Windows: a real limitation, verified

**`android emulator` is disabled on Windows**, and downloading the CLI from PowerShell is not
supported. This was an open question worth settling, and the answer is no.

So on Windows, split the work:

| Job | On Windows, use |
|---|---|
| SDK install, project creation, deploy, docs, skills | **Android CLI** |
| **Creating and booting AVDs** | **`avdmanager` / `emulator` by hand** — `windows-toolchain-and-emulators.md` §3–4 |

The manual path in that reference is therefore **not** legacy on Windows. It is the supported path
for the emulator half of the job. On macOS and Linux, `android emulator` covers it.

### Telemetry

Android CLI reports command invocations, non-positional option *names*, predefined system option
values (emulator template names, agent names — `GEMINI`, `CLAUDE`, `CODEX`), and anonymised stack
traces. It does **not** report command output, file paths, Maven coordinates, or custom project
names. Worth a sentence to whoever owns the project if it's private; not a reason to avoid it.

---

## 2 · Google's `android/skills`, per-phase routing

<https://github.com/android/skills> — Apache 2.0, ships `.claude-plugin`, `.codex-plugin` and
`.agents/plugins` manifests. Google's stated scope is deliberately narrow: they target
**"use cases and workflows where evaluations show LLMs underperform"** and explicitly *skip*
well-covered ground like basic Compose practice. That is why this table has holes — the holes are
where a model already does fine.

Install into the current project:

```bash
android skills add r8-analyzer --project=.
android skills add --all            # everything, for every detected agent
```

**Install at the phase that needs it, not all at once** — an invoked skill's body competes for the
same context budget as this one.

| Phase / situation | Google skill | Fills |
|---|---|---|
| 2–3 · Scaffold, or an AGP 8→9 migration | `build-system/agp/agp-9-upgrade` | The AGP 9 break (`platform-currency.md` §3). **The single most valuable one to install.** |
| 2–3 · Architecture defaults | `navigation/navigation-3` | Navigation choice at scaffold time |
| 3 · Any UI at all, targeting API 36 | `system/edge-to-edge` | Now mandatory (`platform-currency.md` §4) |
| 3 · Compose work that is *not* routine | `jetpack-compose` | Deliberately excludes basics |
| **1b · Generating or changing the theme** | `jetpack-compose/theming/styles` | Current theming APIs — install for the design phase (`design-phase.md` §4) |
| **1b/3 · Any multi-form-factor layout** | `jetpack-compose/adaptive` | `WindowSizeClass` and adaptive layout. Most P0s in the corpus's design review were adaptive-layout failures |
| 4 · Test setup | `testing/testing-setup` | Wiring the suite (`testing-and-bugs.md`) |
| 5 · Release-quality audit | `performance/r8-analyzer` | R8/keep-rule analysis — **no equivalent here** |
| 5 · Performance findings | `profilers/android-profiler` | Profiling — **no equivalent here** |
| 5 · Security audit | `security/android-intent-security` | Intent surface (`permissions-storage-cloud.md`) |
| 6 · Beta release | `play` | Play submission mechanics |
| Wear OS work | `wear/wear-compose-m3` | The `vitals-watch` domain |
| On-device AI / system agents | `device-ai/appfunctions` | The `field-assistant` domain |
| Camera / media / identity / TV / XR | `camera/camerax`, `media/media3-cast-integration`, `identity`, `tv/leanback-to-compose-tv-migration`, `xr/display-glasses-with-jetpack-compose-glimmer` | Domains this skill doesn't cover |
| Driving the CLI itself | `devtools/android-cli` | Installed by `android init` |

Two adjacent sets worth knowing: **`Kotlin/kotlin-agent-skills`** (JetBrains' official Kotlin
skills, including AGP 9 migration for KMP) and **`skydoves/android-skills-mcp`**, which wraps
`android/skills` as an MCP server with a bundled offline snapshot — useful if you'd rather not
install files into every project.

---

## 3 · Journeys, agent-executable E2E tests

Journeys are Google's file format for natural-language end-to-end tests: `*.journey.xml`, where each
step is a descriptive action or an assertion a model evaluates against what it sees on the device.
Created in Android Studio via **New > Journey Test**, wired as a Gradle test suite:

```kotlin
testSuites { create("journeysTest") { targetVariants += listOf("demoDebug") } }
```

This is the same artifact `lifecycle.md` Phase 4 describes as `tests/NN-*.md`, except it is
machine-parseable, CI-reportable, and portable into Studio's results panel (per-step screenshots,
the action taken, and the model's reasoning).

### Running them without Google's backend

Studio's Journeys execute on Google's infrastructure. **`fornewid/journeys-test`** is a Gradle
plugin that runs the same files on a local device using *your* CLI agent, reporting results as
ordinary JUnit/Gradle tests — no cloud auth, no specific backend. Directory, extension and task
name match Studio, so one set of files works in both.

```kotlin
journeys {
    agentCommand.set("claude --no-session-persistence --allowedTools 'Bash(android *)' 'Bash(adb *)' -p")
}
```

Run with `./gradlew journeysTest`.

### Limitations to encode before you rely on it

- **Journeys need the device to themselves.** The plugin serialises execution within and across
  builds (10-minute queue timeout) because two agents tapping at once on one screen is nonsense. It
  assumes a single attached device; set `ANDROID_SERIAL` per invocation for more.
- **Permissions may be granted automatically.** Studio's Journeys grant all app permissions by
  default when testing a journey. That **silently defeats every runtime-permission test case** —
  which is the single most-repeated bug class in this corpus
  (`permissions-storage-cloud.md`). Verify the behaviour of whichever executor you use, and if
  permissions are auto-granted, **keep the permission-denial scenarios as ADB tests**, where you
  control grant state with `pm revoke` / `pm clear`.

### So which format?

**Journeys are the default for feature-behaviour scenarios.** Keep the Markdown ADB plans from
Phase 4 for what Journeys cannot express, which is a real list:

- runtime-permission grant/deny states (above);
- fault injection against an external peer — refuse, hang, starve, disappear;
- LAN rig work and anything needing a real device on real Wi-Fi;
- ARM-target verification and artifact-shape checks (`aapt2 dump badging`, ABI lists, dex counts);
- toolchain and build-config guards;
- soak tests comparing fd/thread/memory before and after.

Both feed the same gate: every scenario ends PASS, FAIL, or BLOCKED.

---

## 4 · Device control from an agent

The raw-ADB harness in `lifecycle.md` Phase 4 is the most fragile part of this skill — it derives
tap coordinates from UI dumps and breaks on layout changes. Better options, in order of fit:

- **Maestro + Maestro MCP** — YAML flows that are deterministic and reviewable, which suits the
  "every fixed silent failure gets a regression test" rule better than natural-language journeys do.
  Speaks MCP directly to Claude Code. Exposes `launch_app`, `run_flow`, `tap_on`, `take_screenshot`,
  `inspect_view_hierarchy`, `list_devices`, `start_device`, `input_text`, `check_flow_syntax`,
  `query_docs`.
- **`mobile-mcp`** — platform-agnostic; drives the native accessibility tree, falling back to
  screenshot coordinates only where a11y labels are missing. No vision model needed in snapshot
  mode. Good when the app has decent accessibility labelling (and it surfaces when it doesn't).
- **`scrcpy-mcp`** — 36 tools spanning screenshots, input, apps, UI automation, shell, files,
  clipboard and video streaming: `claude mcp add android -- npx scrcpy-mcp`. The right pick for a
  live bug-repro session against real hardware, which is where the corpus's sharpest reports came
  from (`testing-and-bugs.md` §4).

**Also consider Android CLI's own `android layout` and `android screen resolve`** (§1) before
reaching for a third-party MCP server — first-party, already installed, no extra moving parts.

---

## 5 · Prior art worth installing alongside

None of these do lifecycle, gates, or an intake interview — which is precisely what this skill is
for. They are complements, not substitutes. Install one *with* this skill when its domain matches.

| Repo | What it adds |
|---|---|
| `rcosteira79/android-skills` | Android + KMP skills: architecture, Compose, coroutines, networking, persistence, DI, testing, debugging, Gradle |
| `Drjacky/claude-android-ninja` | Modular architecture, Navigation 3 with a pinned catalog, Room 3 (`androidx.room3`), Material 3 with 8dp spacing tokens, edge-to-edge, predictive back |
| `hamen/compose_skill` | An evidence-based Compose audit: 0–100 score, per-category scores, top-three fixes, every deduction cited to an official page |
| `skydoves/android-skills-mcp` | `android/skills` as an MCP server + CLI packager, bundled offline snapshot, `npx`-runnable |
| `Kotlin/kotlin-agent-skills` | JetBrains' official Kotlin skills, incl. AGP 9 migration for KMP |

**The one convention worth stealing outright** is `hamen/compose_skill`'s: **cite every finding to a
specific official page.** A finding with a citation survives a disagreement; a finding without one
gets argued about or silently reverted. Adopt it in the audit report format
(`testing-and-bugs.md` §1) — it costs a URL per finding and it is the cheapest credibility this
process has.
