# The Design Phase

Design sits between the spec and the plan: **Phase 1b**. The spec says what the app is; design
decides what it looks like and how it is themed; the plan then orders the build. Doing it after the
plan means re-planning, and doing it after implementation means the design review finds structural
problems that a mockup would have caught for free.

It is numbered `1b` rather than renumbered into the sequence so that every existing "Phase 4"
reference in this skill stays correct.

**Contents**

- [1 · When this phase applies](#1--when-this-phase-applies)
- [2 · Design tokens first](#2--design-tokens-first) — and why Material roles alone are not enough
- [3 · Mockups and the feedback loop](#3--mockups-and-the-feedback-loop) — generating options, converging on one
- [4 · Generating the theme](#4--generating-the-theme) — seed colour to `ColorScheme`
- [5 · Contrast is a test, not an opinion](#5--contrast-is-a-test-not-an-opinion)
- [6 · The design review](#6--the-design-review) — the council-over-screenshots method
- [7 · Turning findings into tests](#7--turning-findings-into-tests)
- [8 · Tooling](#8--tooling)

---

## 1 · When this phase applies

Run it when **any** of these is true (intake Q2, Q3, Q5):

- the app has more than two screens;
- colour carries meaning rather than decoration — an alert ladder, a state indicator, anything where
  the palette is a safety mechanism;
- it ships to more than one form factor, or to a screen the user cannot control the lighting of;
- the user asked for a particular look, or said "make it not ugly".

**Skip it** for a single-screen utility with stock Material 3 and no semantic colour. Say you are
skipping it and why, rather than silently omitting it — a later "why does this look like a default
template" is a design decision nobody recorded.

At novice levels this phase is where the user contributes most usefully: **people who cannot review
an architecture can absolutely review a picture.** Weight the interaction accordingly
(`user-calibration.md` §9).

---

## 2 · Design tokens first

`docs/DESIGN_TOKENS.md` comes before any mockup. It is the vocabulary the mockups and the code both
speak, and writing it first stops the mockup from encoding decisions nobody made.

It holds: the palette with every colour named by **role**, the type scale, spacing and metric
constants, and a *"rules that are not decoration"* section stating what form does when colour
carries meaning — so the meaning survives a glance, colourblindness, and bright sun.

### Material's colour roles are not enough on their own

This is the highest-value lesson in the corpus's design work, and it is not obvious in advance.

In `panel-remote`, a single Material role — `surfaceVariant` — ended up carrying the control keys,
the settings cards, and a progress track at the same time. Those want **opposite things** in a
high-contrast palette: a key should be a dark slab with light content, while a card must stay light
so its dark text reads. One role cannot be both, and the attempt produced either washed-out keys or
invisible card text depending on which way it was pushed.

The fix is a **semantic token set of your own, alongside the Material scheme** — an `@Immutable`
data class supplied through a `CompositionLocal`:

```kotlin
@Immutable
data class ControlColors(
    val keyFill: Color,          // resting key
    val keyContent: Color,       // glyphs and labels on a resting key
    val keyPressedFill: Color,
    val keyPressedContent: Color,
    val keyBorder: Color,        // zero width where the fill alone separates it
)

val LocalControlColors = staticCompositionLocalOf { DarkControls }
```

Two things this buys, beyond fixing the collision:

- **Each palette can state its own control contrast, and that becomes checkable** (§5). A Material
  role shared by three purposes cannot be asserted about meaningfully.
- **The name says the job.** `keyFill` cannot drift into meaning something else the way
  `surfaceVariant` did.

**Rule:** when one Material role is being asked to serve two purposes that would diverge under any
palette you might add later, split it out as a named semantic token now.

---

## 3 · Mockups and the feedback loop

The loop that works: **generate several distinct options → get reactions → converge on one → name it
the design of record.** Not one polished proposal, and not twelve.

### Generate options, not a proposal

Produce **three to five genuinely different directions**, not variations on one. Each should be
defensible and take a different position on the thing the app is actually about — density vs
calm, chrome vs content, dark vs light, literal vs abstract. A single proposal gets rubber-stamped;
five near-identical ones exhaust the reviewer.

Show each option:

- on the **primary surface** and one **secondary** one, so layout is being judged, not just palette;
- in the **worst realistic state** — no data yet, the longest label, an error — because that is
  where designs fail and where a mockup is cheapest to change;
- at the **real target size**, phone and tablet if both ship (intake Q3).

### Get reactions the useful way

Do not ask "which do you like?" Ask questions whose answers are actionable:

- *"Which of these would you be happy looking at for an hour?"*
- *"Point at anything that looks like it does something it doesn't."*
- *"Which one is wrong, and what makes it wrong?"* — rejection is more informative than approval.
- At novice levels, offer the ELI5 frame: *"these are the same app wearing different clothes;
  nothing here is decided yet."* (`user-calibration.md` §10)

**Record what the rejection was about, not just which one lost.** "Too busy" is a token decision —
spacing and type scale — that will otherwise be re-litigated at implementation.

### Converge and name the design of record

Pick one, state what it borrowed from the others, then write the decision down. **State explicitly
which artifact wins when the mockup and the spec text disagree** — this is the single most common
source of "the app doesn't match the design" later. Record it in the spec, and open an ADR if the
choice constrains the architecture (a kiosk layout, a locked orientation, a custom control surface).

Then update `DESIGN_TOKENS.md` from the winner. Mockups are throwaway; the token file is not.

---

## 4 · Generating the theme

Do not hand-pick hex values. Generate the scheme from a **seed colour**, then adjust.

- **Material Theme Builder** (<https://m3.material.io/theme-builder>) is the interactive route: pick
  a seed, export a Compose `Theme.kt` / `Color.kt`.
- **`material-color-utilities`** is the programmatic route, and the one to prefer in an agent
  workflow because it is reproducible and diffable: convert the seed to HCT, build a
  `SchemeTonalSpot` (or another scheme class) for light/dark at a chosen contrast level, and read
  the roles off it. **MaterialKolor** is the Kotlin Multiplatform port of the same library, usable
  directly from Compose.
- Google's **`jetpack-compose/theming/styles`** skill owns the current Compose theming API surface —
  install it for this phase rather than working from memory (`ecosystem.md` §2).

### Plan for more than one palette

`panel-remote` ships three — a default dark, a **high-contrast** variant for bright sunlight, and a
**night** variant that preserves dark adaptation — selected by an enum passed to the theme:

```kotlin
@Composable
fun AppTheme(palette: Palette = DefaultPalette, content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalControlColors provides controlsFor(palette)) {
        MaterialTheme(colorScheme = schemeFor(palette), content = content)
    }
}
```

**Structure the theme as swappable from the first commit even if you ship one palette.** In the
corpus this arrived as a design-review finding — *"single fixed dark theme has no sunlight-legible
variant"* — and retrofitting it meant touching every screen. A `palette` parameter that only ever
takes one value costs nothing now and is the whole migration later.

Dynamic colour (Material You) is a separate decision: it hands the palette to the user's wallpaper,
which is delightful for a consumer app and disqualifying for anything where colour carries meaning.
Decide it here, explicitly.

---

## 5 · Contrast is a test, not an opinion

**The highest-leverage thing in this phase.** Contrast is arithmetic, so assert it in a unit test
rather than arguing about it in a review.

Compute the WCAG relative-luminance ratio for **every foreground/background pairing the app
actually draws**, per palette, and fail the build below threshold:

| | Body text | Large text and icons |
|---|---|---|
| **AA** | 4.5:1 | 3:1 |
| **AAA** | 7:1 | 4.5:1 |

Hold a high-contrast palette to **AAA**, not AA. The corpus's reasoning is worth keeping: in an
office the only cost of raising contrast is raising contrast; on a device used in bright sun or in
the dark, the cost of getting it wrong is someone unable to read the screen when it matters.

Two things this test catches that a screenshot review does not: a palette variant nobody
screenshotted, and a token pairing that only occurs in a state nobody reached. It runs on the JVM
with no device.

Be honest about what it proves: it is arithmetic on colour values, not a measurement of a screen in
a room. It is a floor, not a substitute for looking at the thing on real hardware in real light.

---

## 6 · The design review

Once screens exist, review them. This is the **post-build** half of the phase and it belongs
alongside the Phase 5 audit — a code audit and a design review find disjoint defect sets.

The method that produced the corpus's best design output is a **council over screenshots**.

### Capture first

Screenshot **every reachable screen** on each target form factor, through the real app, and record
them as a numbered inventory with the device, resolution, density, orientation and API level stated
per device. See `${CLAUDE_SKILL_DIR}/scripts/verify-install.sh` for getting the app up, and the
toolchain reference for `exec-out screencap`.

Cover the states, not just the screens: empty, loading, connected, error, mid-edit with the keyboard
up, and each orientation.

> **Name the debug-build artifacts explicitly, inline.** A debug overlay, an fps counter, a test
> pattern, a simulator transport tag — all of these look like design defects to a reviewer who
> doesn't know they aren't shipped. The corpus's inventory calls them out at the top *and* wherever a
> finding depends on telling them apart. Without that note the review generates confident findings
> about UI that does not exist.

Record what you could **not** capture and why. A gap named is a gap; a gap unnamed reads as coverage.

### Three seats, then cross-examination, then a judge

If the **`council`** skill is installed, this is exactly its shape (`ecosystem.md`, and
`user-calibration.md` §11). Seats that worked:

| Seat | Owns |
|---|---|
| **Visual Design** | Hierarchy, spacing, type, colour, consistency, brand coherence |
| **UX / Usability** | Task completion, discoverability, error recovery, visibility of system status |
| **Android Platform** | Material 3 fidelity, `WindowSizeClass` and adaptive layout, insets and edge-to-edge, touch targets, predictive back, IME |

Run it in three rounds:

1. **Independent** — each seat reviews the full set without seeing the others.
2. **Cross-examination** — each seat receives the others' findings and **must name and either rebut
   or concede at least one specific claim.** This step is not ceremony. In the corpus it caught a
   critic's claim of three inconsistent button styles, which on re-checking the source was one
   button captured in a Material ripple/pressed frame. Screenshots of transient states — ripples,
   focus rings, IME animations — are misread as design defects, and cross-examination is what
   catches that before it reaches the verdict.
3. **Judge** — sees the full transcript but **not** the screenshots, and synthesises one prioritised
   list. Withholding the images is deliberate: the judge rules on the strength of the argument, not
   on a fresh impression.

### Corroboration is the severity signal

**Weight a finding by how many seats reached it independently, by different methods.** A defect
found by visual inspection *and* usability heuristics *and* platform diagnosis is the strongest
signal this format produces; a single-seat observation is a suggestion.

Grade P0 (release-blocking) / P1 / P2 / P3 (polish), and give every finding: the screenshot
filenames it rests on, a concrete fix naming the actual API, an effort estimate, and **which seats
raised it**.

### Two sections that earn their keep

- **Ruling on any severity disagreement.** When two seats grade the same thing differently, rule
  explicitly and say why. The corpus's example: a disabled primary button filed P3 (low contrast) by
  Visual and P1 (primary action fails silently) by UX — ruled **P1**, with the contrast observation
  folded in as a symptom of the same missing-validation gap rather than a separate finding.
- **"Needs a product decision, not a design fix."** Some findings' size depends on an unanswered
  product question. In the corpus, two P0 layout defects were either a multi-week adaptive rebuild
  or a one-line orientation lock depending on whether phone was genuinely a shipping form factor —
  which nothing in the app or its docs settled. **Flag it and refuse to estimate until it is
  answered**, rather than guessing and estimating the guess.

Also worth a line: **anything deliberately not a defect.** The corpus notes that the absence of a
`NavigationBar` was architecturally correct for a three-route app and was raised only for
completeness. Without that note the next reviewer files it again.

---

## 7 · Turning findings into tests

A design finding that is only prose regresses invisibly. Convert each P0/P1 into a numbered scenario
in `tests/` in the normal Phase 4 format — SETUP / STEPS / EXPECTED / VERIFY / PASS/FAIL
(`lifecycle.md` Phase 4).

Design findings are more testable than they look:

| Finding | Becomes |
|---|---|
| Controls overlap in compact-height landscape | Force the window size, dump the UI, assert no two control bounds intersect |
| Touch targets below the minimum | Assert every interactive node's bounds are ≥ the stated dp on both axes |
| Panel wastes space on a tablet | Assert the panel's measured size differs between compact and expanded windows |
| A dropped connection can read as live | Assert the state treatment is present and persistent after the failure is injected |
| Contrast | The unit test in §5 — no device needed |

**You do not need a second AVD to test a compact-height window.** `adb shell wm size` and
`wm density` reshape the current one; reset both afterwards in the scenario's cleanup step. That
technique is what makes adaptive-layout findings cheap to regression-test.

---

## 8 · Tooling

| Tool | Use it for | Notes |
|---|---|---|
| **Claude Design** (`/design`) | Generating and iterating mockups as artboards on one canvas | Best fit for §3. Publishes a canvas the user can pan/zoom, and where saving is enabled, edit directly — which turns "give feedback" into "move the thing". Screen flows and multiple options side by side are exactly its shape |
| **Material Theme Builder** | Interactive seed → scheme, exports Compose `Theme.kt` | Web tool; hand-off is a file, not a pipeline |
| **`material-color-utilities` / MaterialKolor** | Programmatic seed → scheme | Prefer in an agent workflow: reproducible, diffable, scriptable across palettes |
| **Google `jetpack-compose/theming/styles`** | Current Compose theming APIs | Install for this phase (`ecosystem.md` §2) |
| **Google `jetpack-compose/adaptive`** | `WindowSizeClass` and adaptive layout | Install before any multi-form-factor layout work — most P0s in the corpus's review were adaptive-layout failures |
| **Google `system/edge-to-edge`** | Insets, system bars | Mandatory at `targetSdk` 36 (`platform-currency.md` §4) |
| **`hamen/compose_skill`** | Scored Compose audit with every deduction cited | A cheaper single-pass alternative to the full council for a UI-light app (`ecosystem.md` §5) |
| **`council`** | The three-seat design review in §6 | Optional; without it, run the three seats as sequential passes yourself and keep the cross-examination step |

**Claude Design is the right tool for mockups and the wrong tool for the theme.** It produces HTML
artboards, not a Compose `ColorScheme` — so use it to decide *what the app should look like*, then
generate the actual theme from a seed colour (§4) and hand-write the semantic tokens (§2). Treating
an artboard's CSS as a source of truth for Android theming is how a design ends up approximated
rather than implemented.
