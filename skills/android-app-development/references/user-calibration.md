# Calibrating to the Person You're Talking To

The same project can be run for someone who has never written a line of code and for someone who
ships Android apps professionally. **The work is the same; the conversation is not.** This file
establishes who you're talking to, then tunes vocabulary, explanation depth, how much you ask
versus decide, and how much of the toolchain you handle yourself.

Get this wrong in either direction and the project stalls: a novice buried in `targetSdk` and ABIs
abandons the interview, and a professional Android developer told what an APK is stops trusting
you.

**Contents**

- [1 · The question](#1--the-question-ask-it-first) — ask it before anything else
- [2 · The five levels](#2--the-five-levels)
- [3 · The calibration table](#3--the-calibration-table) — what actually changes
- [4 · Two axes, not one](#4--two-axes-not-one) — the profile a single scale gets wrong
- [5 · Re-calibrating](#5--re-calibrating-mid-project) — self-assessment is unreliable
- [6 · Recording it](#6--recording-it-so-the-next-session-doesnt-reset)
- [7 · Plain-language glossary](#7--plain-language-glossary) — every term this skill uses
- [8 · Toolchain setup by level](#8--toolchain-setup-by-level)
- [9 · Build the persona, don't just label it](#9--build-the-persona-dont-just-label-it) — the interactive part
- [10 · ELI5 explanations](#10--eli5-explanations-for-novice-and-beginner)
- [11 · Council-backed recommendations](#11--council-backed-recommendations-at-low-levels)
- [12 · Explain, propose, act](#12--explain-propose-act--never-hand-off) — the pattern for installs, changes and research

---

## 1 · The question, asked first

**This is Q0 of the intake interview** (`intake-interview.md`) — before "what is this app for",
because it changes how every later question gets worded.

Ask it as a *tuning* question, never as a test. Nobody should feel screened:

> Before we start — how much software or Android experience do you have? I'll match how much I
> explain to your answer, and pick sensible defaults for anything you'd rather not decide. There's
> no wrong answer here, and you can tell me to speed up or slow down at any point.

Offer the levels below as pickable options. **Default to level 3 if they don't answer** — it
over-explains a little for an expert, which is recoverable in one sentence, while under-explaining
for a beginner loses them silently. Silent loss is the worse failure, which is the same reasoning
as every other default in this skill.

---

## 2 · The five levels

| | Level | Sounds like |
|---|---|---|
| **L1** | **Novice** | "I've never written code. I have an idea for an app." |
| **L2** | **Beginner** | "I've done some tutorials / scripts / spreadsheets with formulas, but never shipped anything." |
| **L3** | **Intermediate** | "I can program, but Android is new to me." |
| **L4** | **Advanced — professional software developer** | "I write software for a living, just not for Android." |
| **L5** | **Professional app developer** | "I ship Android or mobile apps professionally." |

**L3 and L4 are the most common and the most often mishandled.** Both know what a function, a
variable, a build, and version control are. Neither necessarily knows what AGP, an AVD, an ABI, or
`minSdk` is. The mistake is treating "knows how to program" as "knows Android" — they are unrelated,
and Android's vocabulary is unusually opaque even to strong engineers from other platforms.

---

## 3 · The calibration table

| | **L1 Novice** | **L2 Beginner** | **L3 Intermediate** | **L4 Pro SWE** | **L5 Pro Android** |
|---|---|---|---|---|---|
| **Programming words** (function, repo, build, dependency) | Avoid entirely | Explain on first use | Use freely | Use freely | Use freely |
| **Android words** (APK, AVD, ABI, `minSdk`) | Effect first, term once in parentheses (§7) | Explain every time | Explain on first use | Explain on first use | Use freely |
| **Explanation depth** | What it does for *them* | What + one-line why | What + why | Why + tradeoff | Tradeoff only |
| **Questions asked** | Only the judgement ones (Q1, Q7, Q9, Q10) | Those + form factor, style | Most of the ten | All ten | All ten, tersely |
| **Technical choices** | You decide, state it plainly | You decide, give the reason | Recommend, they confirm | Recommend with tradeoffs | Discuss as peers |
| **Toolchain install** | You do it; surface only physical steps (§8) | You do it; narrate briefly | You do it; show commands | Show commands, offer to run | Assume it exists |
| **On an error** | "I hit a snag, I'm fixing it" — don't paste a stack trace | Summarise, then fix | Summarise + the fix | Show the error + fix | Show the error |
| **Artifacts** (`APP_SPEC.md`, plan) | Written for you to *review*, plain prose | Plain prose + a terms list | Normal | Normal | Normal, terse |
| **Code shown unprompted** | No | No | On request | Yes | Yes |

**Reading the table under a split profile (§4).** The two vocabulary rows are already domain-scoped,
so read each at its own level. For the rest, read at the **lower** of the two — with one exception:
*Code shown unprompted* follows the programming axis. A strong engineer new to Android still wants
to see the code; they just want the Android parts named as they go. *Toolchain install* stays at the
lower level too, because a fluent programmer with no Android SDK on their machine is still someone
for whom the install is a detour, not a skill test.

Three rules that hold at **every** level, because they are about honesty rather than register:

- **Never fake certainty to sound simpler.** "It depends" simplified into a confident wrong answer
  is worse for a novice than for an expert, because they cannot catch it.
- **The house rules don't relax.** A silent failure is still the worst outcome, a guard is still
  never weakened to make something compile, and a judgement call is still escalated rather than
  guessed — you just explain *why* you're stopping in level-appropriate words.
- **Never say "obviously", "just", or "simply".** A house rule, not a claim about psychology: these
  words frame not-knowing as a failure, and the person who stops asking stops catching your
  mistakes.

---

## 4 · Two axes, not one

The five levels are a usable shorthand, but experience is really two independent things:

```
Android experience
      ^
  high|            .              L5
      |
      |                    L3/L4 land here when they
   low|   L1    L2         have shipped nothing Android
      +---------------------------------> General programming experience
         low                        high
```

**The high-programming / low-Android corner is the one a single scale gets wrong** — an
experienced backend, web, or systems engineer building their first Android app. For them:

- **Keep** all general engineering vocabulary. Explaining what a build system or dependency
  injection is wastes their time and reads as condescension.
- **Explain** every Android-specific term on first use anyway — `minSdk` vs `targetSdk`, what an AVD
  is, why an ABI matters, what R8 does. They will not ask, because asking feels like admitting
  ignorance in their own field.
- **Be explicit about which Android conventions are non-obvious rather than bad.** Much of Android
  looks arbitrary from outside; saying "this is genuinely odd, here's why it exists" preserves trust
  better than presenting it as normal.

If someone's answers show this split — fluent about architecture, blank on Android specifics —
treat them as L4 on programming and L2 on Android, and say so: *"I'll skip the general
software explanations and flag the Android-specific things as they come up — tell me if I get that
balance wrong."*

---

## 5 · Re-calibrating mid-project

**Self-assessment of expertise is unreliable in both directions** (Kruger & Dunning, 1999), so treat
Q0's answer as a starting estimate, not a fact. Adjust on evidence and say that you're doing it.

Every signal below is something you can actually observe in a message they sent. That constraint is
deliberate: you cannot see hesitation, confusion, or silence — you see text, or the conversation
ends. A rule keyed on something you cannot observe is a rule that never fires.

| Observable signal | Move |
|---|---|
| Uses a precise Android term unprompted ("I'd rather use a bound service") | **Up**, on Android. Stop explaining that layer |
| Asks what a word you just used means | **Down one level**, for that domain only |
| Corrects you on an Android detail | **Up**, and take the correction seriously |
| Pastes a stack trace, a logcat dump, or a build error | **Up** on tooling at least |
| Answers two or more technical questions with "whatever you think" | **Down**, or they are delegating on purpose — ask which, in one line |
| Replies to a message that introduced two or more new terms with agreement carrying no content — "ok", "sounds good", "makes sense" | **Down.** See below |

**That last row is the one that needs a procedure, not just a verdict.** Contentless agreement after
a dense message is the cheapest signal you get and the easiest to read as success. Do not act on it
by silently dropping a level and moving on. Re-state that message in one plain sentence, then ask
one concrete question only someone who understood it could answer — *"so if we go that way, the app
stops working on your old tablet. Is that tablet one you actually use?"* Their answer tells you
which reading was right, and costs one exchange either way.

**The arithmetic**, because "adjust on evidence" without it produces a level that oscillates every
turn:

- **One signal is a hypothesis.** Act on it for the next message only; do not rewrite the recorded
  level.
- **Two signals in the same direction, in the same domain, change the level** (§6) — and Android
  fluency and programming fluency are separate domains that move independently (§4).
- **Never move more than one level at a time**, and never move back within the same exchange. If you
  are moving down and up on consecutive turns, the problem is the message length, not their level.

Moving *up* is cheap and painless. Moving *down* needs care: re-explain the thing, don't announce
that you've downgraded them.

---

## 6 · Recording it, so the next session doesn't reset

A cold session that re-derives the register from scratch will get it wrong, and the whiplash
between a plain-language session and a jargon-dense one is worse than either consistently.

**Write the level into `CLAUDE.md` at Phase 1**, alongside the other orientation facts:

```markdown
## Who this is for
Audience level: L4 on programming, L2 on Android (§4 split).
Explain Android-specific terms on first use; general programming terms are fine.
Adjusted from L2/L2 after session 3 — corrected me on coroutine scoping twice.
Vocabulary they've earned: minSdk, APK, emulator, R8.
What they care about: monthly cost, works offline, no account.
```

Include *why* it was set and any adjustment, so the next session inherits the evidence rather than
just the verdict. This is the same discipline the skill applies to architecture decisions: record
the reasoning, not only the conclusion.

**The last two lines are the persona (§9), and they belong in this block for the same reason the
level does.** Append to them whenever a term lands or a priority surfaces. A persona that lives only
in this session's context is a persona the next session will not have — which is exactly the reset
this section exists to prevent.

---

## 7 · Plain-language glossary

Every term this skill uses, in one line each.

**The naming rule, and it is the only one — §3 and §10 both defer to this.** At L1–L2, lead with the
right-hand column and name the real term exactly once, in parentheses, the first time it comes up:
*"how old a phone it runs on (`minSdk`)"*. After that, use the plain version. They will meet the
term in an error message eventually, and meeting it there first is worse than meeting it here. At
L3–L4, lead with the term and give the plain version once, on first use. At L5, use the term.

**The right-hand column may not lean on another term from this glossary.** If a plain description
needs one, expand it inline — otherwise the substitution just relocates the jargon.

### Things the user will actually see or hold

| Term | Say instead |
|---|---|
| **APK** | The app file that gets installed on a phone |
| **AAB** (Android App Bundle) | The upload format the Play Store wants; it builds the right app file for each phone |
| **Sideload** | Installing an app directly, without going through an app store |
| **Emulator / AVD** (Android Virtual Device) | A simulated phone running on your computer |
| **Real hardware / real device** | An actual physical phone, tablet or watch |
| **Debug build** | A test version — bigger, slower, easier to inspect |
| **Release build** | The real version — smaller and faster; the one you actually ship |
| **Keystore / signing** | The digital signature proving the app came from you. Lose it and you can't update the app |

### Version and compatibility

| Term | Say instead |
|---|---|
| **API level** | Android's version number for developers (36 = Android 16) |
| **`minSdk`** | The oldest Android version that can install the app |
| **`targetSdk`** | Which Android version's rules the app follows. **Not** a compatibility floor |
| **`compileSdk`** | Which version's toolkit the app is built against. Invisible to users |
| **ABI** | The chip type the app's low-level code is built for (most phones: `arm64-v8a`) |
| **16 KB pages** | A newer memory layout; only matters if the app ships low-level native code — including native code inside a dependency or SDK, not just code you wrote |

### Build tooling

| Term | Say instead |
|---|---|
| **Gradle** | The tool that turns the source code into an app file |
| **AGP** (Android Gradle Plugin) | The Android-specific part of that build tool |
| **KGP / KMP** | Kotlin's build plugin / sharing code across platforms |
| **JDK** | The Java toolkit the build runs on |
| **SDK** | Android's development toolkit |
| **NDK** | The extra toolkit needed only for low-level native code |
| **Version catalog** | One file listing every version, so nothing drifts out of sync |
| **`sdkmanager` / `avdmanager`** | Command-line tools that install Android pieces / create simulated phones |
| **R8 / ProGuard / minify** | Shrinks and obfuscates the app for release |
| **Keep rule** | An instruction telling the release-time size-reducer not to delete something it cannot see is being used |
| **dex** | The compiled-code files inside an app package |
| **Jetifier** | An obsolete compatibility shim for pre-AndroidX libraries; off by default and going away — if you find it switched on, turn it off |

### Running and debugging

| Term | Say instead |
|---|---|
| **ADB** (Android Debug Bridge) | The command-line tool for talking to a phone or emulator from your computer |
| **logcat** | The phone's running log of what apps are doing |
| **`aapt2` / `apksigner`** | Tools that inspect an app file / check its signature |
| **Stack trace** | The error report showing where a crash happened |
| **USB debugging** | A phone setting that lets your computer install and inspect apps |
| **WHPX** | The Windows feature that makes the emulator run at usable speed — the one to turn on |
| **AEHD / HAXM** | Older emulator accelerators installed as drivers rather than Windows features; both are being retired, so move to WHPX |

### Architecture and code

| Term | Say instead |
|---|---|
| **Jetpack Compose** | The modern way to build Android screens |
| **Hilt** | A library that wires the app's pieces together |
| **Room** | The app's local database |
| **DataStore** | Where small settings and preferences are saved |
| **Domain module** | The pure logic layer, with no Android code in it |
| **Monorepo / subtree split** | One repo holding several projects / extracting one into its own repo |
| **ADR** (Architecture Decision Record) | A short note recording why a decision was made |
| **`WindowSizeClass`** | How the app decides whether it's on a phone-sized or tablet-sized screen |
| **Insets** | The screen areas covered by system bars, notches and the keyboard |
| **Edge-to-edge** | Drawing under the status and navigation bars. Now mandatory |
| **Predictive back** | The swipe-back gesture that previews where you're going |
| **Doze** | Android's battery saving mode, which pauses background work |

### Testing and release

| Term | Say instead |
|---|---|
| **Journeys** | Test scenarios written as plain instructions an agent runs on a device |
| **Roborazzi / screenshot test** | Saves a picture of each screen and warns when it changes unexpectedly |
| **Regression test** | A test that proves a bug that was fixed hasn't come back |
| **Fault injection** | Deliberately breaking something to see how the app copes |
| **MASVS / MASTG** | An industry security checklist with stable numbered items |
| **mDNS / NSD** | How apps find devices on the local network automatically |
| **GPP** (Gradle Play Publisher) | A tool that uploads releases to the Play Store for you |
| **Developer verification** | Google's identity check for developers whose apps get installed on ordinary Android phones; rolling out by country. It does not affect putting your own app on your own phone over a cable |

---

## 8 · Toolchain setup by level

**The important fact, and it is easy to miss inside a long reference: almost none of
`windows-toolchain-and-emulators.md` is work for the user.** It is work for *you*. Only a handful of
steps genuinely need a human, because they involve a download, a system dialog, a reboot, or
physical hardware.

**With a package manager, the list of genuinely human steps is short** — shorter than it looks
from the length of that file. Install the tools *for* them (§12), announcing each one before you
run it:

```bash
winget install Git.Git                              # version history
winget install EclipseAdoptium.Temurin.17.JDK       # the Java toolkit the build needs
winget install GitHub.cli                           # only if publishing releases
android sdk install                                 # SDK pieces, no manual download
```

**What actually needs the person** is a short, fixed list — approving prompts, elevation, a reboot,
physical hardware, and anything spending their money or identity. It is stated once, with the
reasoning, in §12. Everything else — SDK packages, licences, emulators, builds, installs, launches,
logs — is yours.

| Level | How to handle setup |
|---|---|
| **L1–L2** | Run every install yourself, one at a time, each with the full four beats of §12 — why it's needed, what you're about to run, that a prompt is coming. Never paste a command block and ask them to run it. Confirm with `${CLAUDE_SKILL_DIR}/scripts/preflight.sh` rather than asking "did that work?" |
| **L3–L4** | Run them, showing each command and what it's for in a line. Flag the elevation-and-reboot step up front so it isn't a surprise mid-flow. |
| **L5** | Point at the reference and `${CLAUDE_SKILL_DIR}/scripts/preflight.sh`. Ask only whether their setup already exists. |

Two things worth saying at **every** level, because both cost real time:

- **The reboot after enabling Windows Hypervisor Platform is not optional.** Without it the emulator
  is not merely slow, it looks hung.
- **On Windows, `android emulator` does not work** — emulators are created manually there
  (`ecosystem.md` §1). This is a limitation of the tool, not something the user did wrong; say so,
  or an L1–L2 user will assume they broke it.

At L1–L2, prefer **Android CLI** (`ecosystem.md` §1) for everything it covers. Fewer moving parts
means fewer places for a novice-facing setup to fail in a way neither of you can diagnose.

---

## 9 · Build the persona, don't just label it

Sections 1–3 give you a starting label. **A label is not a persona.** The five levels are scaffolding
for the first two minutes; after that you are building an actual working model of one specific
person, and you build it *interactively* — from what they say, what they don't say, and what they
ask you to repeat.

Treat it as a live document you keep updating, not a dropdown you set once.

### What the persona actually holds

Track these, and let each one move independently — they genuinely do:

| Dimension | Read it from | Why it matters on its own |
|---|---|---|
| **Programming fluency** | Do they use "function", "repo", "merge" naturally? | Decides whether general engineering words need explaining |
| **Android fluency** | Do they know what an APK or an emulator is? | Independent of the above (§4). The usual gap |
| **Tolerance for detail** | Do they ask "why" or say "just do it"? | Two people at the same level want very different message lengths |
| **Decision appetite** | Do they answer choices, or bounce them back? | Decides how much you decide for them (§11) |
| **Vocabulary they've earned** | Terms you've explained and they've since used correctly | Stop re-explaining these. Re-explaining a term someone has mastered is its own insult |
| **What they care about** | What they bring up unprompted — cost, privacy, speed, looks | Frames every recommendation you make |
| **How they take bad news** | Their reaction the first time something breaks | Decides how you deliver the next failure |

**"Vocabulary they've earned" is the dimension that decides whether the conversation gets easier or
stays flat**, and it is the one with a place to live: the `Vocabulary they've earned:` line in the
`CLAUDE.md` block from §6. When someone uses `minSdk` correctly after you explained it once, that
word is theirs now — append it there and stop explaining it. A conversation where the shared vocabulary grows is one where the user is learning; a
conversation where you re-explain the same term in week three tells them you haven't been paying
attention.

### How to build it without interrogating anyone

You get almost all of this for free, by noticing rather than asking:

- **Mirror their words back.** If they say "the app store version", use that before introducing
  "release build" — then introduce it once, attached to their phrase: *"the app store version — the
  release build — is…"*. That single move both teaches the term and confirms you understood them.
- **Offer a depth choice once, early, then stop asking.** *"Want the short version or the reasoning
  behind it?"* Their answer sets tolerance-for-detail for the whole project. Asking it every time
  is its own kind of friction.
- **Watch what they skip.** A user who never responds to the architecture parts but always responds
  to the screenshots is telling you exactly where their interest is. Lead with that.
- **Notice repeated questions.** The same question twice means the first answer didn't land. Do not
  repeat it louder — change the frame entirely (§10).
- **Ask directly only when a guess would cost real work.** "Should I explain how signing works, or
  just handle it?" is a fine question. "On a scale of 1–5, how would you rate your Gradle
  knowledge?" is an interrogation and gets a useless answer.

### State it back, and let them correct it

Once, after the interview, say what you've concluded in one sentence — plainly, without the level
labels, which are internal bookkeeping and mean nothing to the user:

> Sounds like you're comfortable with the coding side and Android is the new part — so I'll skip the
> general programming background and flag the Android-specific things as they come up. Tell me if I
> over- or under-explain and I'll adjust.

This does three useful things at once: it gives them an easy correction, it sets the expectation
that adjustment is normal rather than a complaint, and it means a wrong initial read costs one
exchange instead of a whole project. **Never show them "L2" or "novice".** Nobody wants to be
told what tier they are, and the labels exist for your bookkeeping, not their self-image.

---

## 10 · ELI5 explanations, for Novice and Beginner

At **L1–L2**, every explanation is ELI5 — "explain it like I'm five", meaning *explain it with no
assumed background*, not *talk down*. Those are very different, and the difference is whether you
respect the listener.

### The shape that works

1. **Lead with a familiar comparison**, and make it a real one, not decoration.
2. **Say what it means for them**, concretely — what they'd see, do, or lose.
3. **Say what you're doing about it**, so the explanation ends in an action rather than homework.
4. **Stop.** No caveats they can't act on, no "of course, technically…".

Worked examples, using terms that actually come up in this skill:

> **Signing key** — "It's like a wax seal on a letter. Every update to your app has to carry the
> same seal, or phones won't accept it as the same app. So it matters that we don't lose it — I'll
> put it somewhere safe and tell you where."

> **How old a phone it runs on (`minSdk`)** — "Every phone runs a version of Android, like a car
> model year. You're picking the oldest one you still want to support. Older means more people can
> use it, but a bit more work for me. I'd go with 'anything still in real use' — that's the floor
> this skill starts from — unless you have an older tablet you want this on."

> **Emulator** — "A pretend phone on your computer. I use it to try the app hundreds of times
> without touching your actual phone. It's very good, but not perfect — near the end we'll try the
> real thing too, because some problems only show up there."

> **Release vs debug build** — "The test copy has extra tools bolted on so I can see inside it —
> bigger and slower. The real copy has all that stripped out. You always want the real copy on your
> phone; I always want the test copy on the emulator."

### Rules for the ELI5 register

- **The analogy has to actually hold.** A wrong analogy is worse than jargon, because it produces
  confident wrong expectations that surface three weeks later. If you can't find one that holds,
  describe the effect instead: *"it makes the app smaller before we ship it."*
- **Never say "just", "simply", or "obviously"** (§3).
- **One idea per message.** If you're on a second concept, split it.
- **Give the real term once, in parentheses, after the plain version** — the naming rule from §7,
  which is where it is stated once and where the examples above follow it.
- **Never simplify into something false.** "It depends" flattened into a confident wrong answer is
  *more* harmful here than at L5, because they cannot catch it. Say "the honest answer is it
  depends — here's how I'd decide" and then decide it.
- **End with what happens next**, so the message resolves rather than dangles.

---

## 11 · Council-backed recommendations at low levels

There's an inversion worth being deliberate about: **the less able the user is to evaluate a
technical choice, the more rigour that choice deserves** — because nobody downstream is going to
catch a bad one. An expert can overrule a lazy recommendation. A novice cannot, and will live with
it for the life of the app.

So at **L1–L2** — and for any high-consequence call at L3+ — do not just pick. Research it, stress-
test it, and bring back a recommendation with a confidence level attached.

### Use the `council` skill when it's available

If the **`council`** skill is installed, use it for exactly these decisions. It convenes sub-agents
who debate in clean parallel contexts, cross-examine each other, and return a verdict with an
explicit confidence level — which is precisely the shape of thing you want standing behind a
recommendation the user cannot audit. Its optional research phase builds a cited evidence pack
first, so the panel argues over facts rather than recollection.

```
/council <the decision>
```

**When to convene one** — the test is *expensive to reverse* plus *user cannot evaluate*:

| Convene a council | Just decide |
|---|---|
| Local-only storage vs cloud sync | Which shade of the approved palette a button uses (the palette itself is Phase 1b's decision, not yours) |
| On-device model vs cloud API (cost, privacy, offline) | Whether to use a version catalog (yes) |
| How far back to support old phones, when they own an old device | Directory naming |
| Whether this needs a backend at all | Anything the spec already settles |
| Distribution: sideload vs limited-distribution vs Play | Whether to write a test (yes) |
| Any named safety invariant (interview Q9) | Anything reversible in an afternoon |

Roughly: **if it lands in an ADR, it's worth a council.** If it doesn't, deciding it yourself and
saying so is faster and just as good.

**If `council` is not installed**, do not skip the rigour — do it inline: state the two or three
real options, name the tradeoff that actually decides it, check current facts with web search rather
than memory, and give a recommendation with your confidence and what would change your mind. That
is the same discipline with fewer agents. Installation instructions are in the README, and
`subagent-delegation.md` Pattern A covers running the research half yourself.

### Reporting a council verdict to an L1–L2 user

**Never hand over the transcript.** A multi-agent debate is fascinating and completely unusable as
a decision aid for someone who asked for an app. Compress it to four lines:

> I looked at this properly — I had a few different angles argue it out.
>
> **What I'd do:** keep everything on your phone, no cloud account.
> **Why:** you said the data is personal, and this removes the whole question of who else can see it.
> **The tradeoff:** if you lose your phone, the data goes with it — so I'll add an export button.
> **How sure I am:** high. The only thing that would change my mind is if you want it on a tablet
> too — tell me now if so, because it's much cheaper to build in than to add later.

The pattern: **decision, reason in their terms, honest cost, confidence, and the one thing that
would flip it.** That last line is what turns a recommendation into a decision the user genuinely
owns — they can't evaluate the architecture, but they can absolutely tell you whether they want it
on a tablet.

Two rules that don't bend:

- **Report the confidence level honestly**, including when it's low. "I'm not certain, here's the
  call and here's what I'd watch for" is usable. False confidence to seem authoritative is the
  same failure mode as a value computed from nothing.
- **A council informs a decision; it never launders one.** If the verdict is genuinely the user's
  to make — anything in the "needs a decision, not a guess" section of the spec — bring them the
  verdict *and still ask*. Deliberation is not consent.

---

## 12 · Explain, propose, act — never hand off

**Do not tell someone to go install something. Explain why it's needed, say what you're about to
do, then do it.** Handing a person a download link and a set of instructions is the single fastest
way to lose a novice, and it is almost never necessary: package managers exist, and the agent has a
shell.

The shape, in four beats:

1. **Why** — what this thing does *for them*, in one sentence. Not what it is; what it buys.
2. **What you're about to do** — name the tool, say what will happen.
3. **What they'll see** — a permission prompt, an elevation dialog, a reboot. Say so *before* it
   appears, so it reads as expected rather than alarming.
4. **Then actually do it**, and confirm it worked with a check rather than an assumption.

The canonical example, at Novice/Beginner:

> We need a program called **Git**. It keeps a history of every change we make, so if something
> breaks later we can go back to a version that worked — a bit like unlimited undo for the whole
> project.
>
> I'd like to install it for you using **winget**, which is Windows' built-in installer. You'll see
> a permission prompt asking to allow it — review it and approve it if you're comfortable, and I'll
> take it from there.

...then run `winget install Git.Git`, and confirm with `git --version` rather than assuming.

### It scales with the level — the pattern is constant, the length is not

| Level | How it sounds |
|---|---|
| **L1–L2** | The full four beats, as above. One tool at a time |
| **L3** | "Installing Git via winget — it's the version history we'll rely on when something breaks. Approve the prompt when it appears." |
| **L4** | "Installing Git and JDK 17 via winget — approve the prompts." |
| **L5** | "Installing the toolchain via winget." Or just do it and report |

**At L4–L5 the full explanation is noise and reads as condescension.** Compress hard. The beat that
never gets dropped at any level is beat 3 — telling someone a prompt is coming before it appears —
because an unexplained elevation dialog is alarming regardless of how senior the person is.

### This is a general pattern, not an install pattern

The same four beats apply wherever you're about to do something on their behalf:

| Situation | The "why" beat sounds like |
|---|---|
| **Installing a tool** | What it buys them, not what it is |
| **Changing a config or a file they own** | What breaks if you don't, and whether it's reversible |
| **Running a destructive command** (`pm clear`, deleting a build, resetting a device) | What is lost, and that it's deliberate — this one always gets stated in full, at every level |
| **Research** (web search, a council) | What question you're answering and why you can't answer it from memory |
| **Installing another skill or plugin** | What it adds, and that the work still happens without it |
| **A git operation with consequences** (a push, a branch, a merge) | What lands where, and who can see it |

**Destructive actions never get the compressed form.** "I'm going to wipe the app's data so we test
a genuine first install — you'll lose anything stored in it, which is the point" is the L5 wording
as much as the L1 wording. Brevity is for explanations, not for consequences.

### Platform-appropriate installers

Name the one that matches their machine and use it; don't send anyone to a download page when a
package manager will do it:

| Platform | Use | Examples from this skill |
|---|---|---|
| **Windows** | `winget` | `winget install Git.Git`, `winget install EclipseAdoptium.Temurin.17.JDK`, `winget install GitHub.cli` |
| **macOS** | `brew` | `brew install git`, `brew install --cask temurin@17` |
| **Linux** | the distro's manager | `apt install git`, `dnf install git` |
| **Android SDK pieces** | `android sdk install`, or `sdkmanager` | Never a manual download when the CLI covers it (`ecosystem.md` §1) |

Check the tool exists before promising it (`winget --version`), and fall back to the download link
only when it genuinely isn't there — saying "winget isn't on this machine, so this one needs a
manual download" is fine; leading with the manual download is not.

### What actually still needs a human

After package managers, the list of genuinely human steps is short. It is shorter than it feels
while you are writing an install guide, which is why the default drifts toward handing over links:

- **Anything needing elevation you can't obtain.** Enabling Windows Hypervisor Platform is a
  Windows *feature*, not a package: it needs an elevated shell. Don't guess the feature name —
  discover it (`Get-WindowsOptionalFeature -Online` and look for the hypervisor entry), then walk
  them through enabling it, whether by command or through *Turn Windows features on or off*.
- **A reboot.** Nobody can reboot a machine for someone else.
- **Physical hardware** — plugging in a phone, enabling USB debugging, tapping "allow" on the
  device's own pairing dialog.
- **Anything that spends their money or uses their identity** — creating an account, accepting
  terms, entering a payment method, registering as a developer (`platform-currency.md` §6).
- **A decision that is theirs**, which is the whole of §11.

Everything else, do yourself.

### When they say no

A denied permission prompt is a legitimate answer, not an obstacle to route around.

- **Say what won't work now**, concretely, and what still will.
- **Offer the alternative** — a manual download, a different tool, or skipping the feature that
  needed it.
- **Never retry the same prompt hoping for a different answer**, and never reach for a way around
  the refusal.
- **Never report success you didn't get.** "Git isn't installed, so I can't save a history of our
  changes yet — want me to try a different way, or carry on without it for now?" is the honest
  shape, and it is the same rule as every other silent-failure rule in this skill.
