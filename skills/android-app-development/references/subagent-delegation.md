# Delegating to Subagents

**Contents:** [Choosing a surface](#choosing-a-surface-before-choosing-a-subagent) ·
[A — Research delegation](#pattern-a--research-delegation) ·
[B — Scoped parallel fix agents](#pattern-b--scoped-parallel-fix-agents) ·
[C — Parallel sessions](#pattern-c--parallel-sessions-on-feature-branches-and-the-integration-pass) ·
[When to use which](#when-to-use-which)

Two distinct subagent patterns show up in the corpus, for two different jobs. Don't conflate them — a research subagent and a fix subagent want different prompt shapes.

## Choosing a surface, before choosing a subagent

A subagent is one of several places project guidance can live, and they have genuinely different costs. Anthropic's own breakdown:

| Surface | Context cost | Survives compaction | Good for |
|---|---|---|---|
| **`CLAUDE.md`** | Loaded at session start, memoized, **high** | Re-read after compaction | A short orientation handout. Keep it short — everything in it is paid for on every session |
| **Rules** | Re-injected on compaction; path-scopeable | Yes | Guidance that must apply to specific directories |
| **Skills** | Name + description at start; body on invocation, against a **shared budget across invoked skills, oldest dropped first** | — | Teaching a workflow. This skill, and the Google ones |
| **Subagents** | **Zero** until called; returns only a summary | N/A | Isolating a big search or a scoped fix |
| **Hooks** | Bypass compaction entirely | Yes | **Enforcement** |

The practical rule: **enforce with hooks or permissions, teach with skills, isolate with subagents, and keep `CLAUDE.md` short.**

That last distinction matters for this skill specifically. Several house rules are *enforcement*, not guidance — "every implementation pass ends with a real build and a real test", "never weaken a guard to make something compile". Prose that the model may or may not honour on turn forty is the wrong shape for those. Two better shapes, both shipped here:

- **Deterministic scripts** (`${CLAUDE_SKILL_DIR}/scripts/`) — `verify-install.sh` turns "I tested it" from a claim into a command with an exit code, and `preflight.sh` catches an AGP-8-era scaffold before the first build and exits 1 when anything needs attention.
- **Hooks** (`hooks/` in this plugin, opt-in) — fire on the tool call itself, so they cannot be forgotten mid-session.

The shared-budget detail is also why `ecosystem.md` says to install Google's skills **at the phase that needs them** rather than all at once: every invoked skill body competes with this one for the same space.

## Pattern A — Research delegation

Used to answer a bounded, verifiable factual question (does this hardware/API actually support X?) and write the answer to a doc, without polluting the main session's context with the research trail.

Structure of a research-subagent prompt that worked well (condensed):

```
Research question, to be answered with citations and written up as a Markdown document.

CONTEXT
[Why this question matters — the product/user situation motivating it.]

THE QUESTION
[The precise question, including what would count as a real answer vs. a non-answer.]

WHAT TO INVESTIGATE
[Numbered list of specific sub-questions, naming the specific APIs/SDKs/vendors
to check — not "look into sensors" but "does AndroidX Health Services expose
this DataType? Enumerate what it does expose."]

OUTPUT
Write the answer to `[exact file path]`. Structure it as:
- A direct answer in the first three sentences. Lead with the bottom line.
- What the hardware/API can actually do.
- What a third party can actually get at, with exact API names and blockers.
- Candidate approaches, ranked, each with honest confidence and caveats.
- A clear recommendation: is this worth building, what would it take, what
  should NOT be claimed.
- Sources, as a list of URLs with what each supports.

STYLE
- Long explanatory prose that says *why*, not just what. No bullet-only summaries.
- Be rigorously honest about uncertainty — [state why overclaiming would be
  costly for this specific use case]. If the answer is "you cannot do this,"
  say that plainly and early.
- Do not invent API/constant names. If you can't verify something exists,
  say it's unverified rather than guessing.

Use web search extensively. Verify against primary sources rather than blog
posts where possible. Report back a short summary of the bottom line.
```

What makes this work:
- **The question states what would count as a real vs. fake answer.** ("Establish which watch models have BIA... and how it is measured.") A vague research prompt gets a vague answer; naming the specific verification bar gets a verifiable one.
- **"Do not invent API names" is explicit**, and paired with an explicit allowance to say "unverified" rather than filling a gap with a plausible-sounding guess. For anything hardware/API-capability-related, this instruction pays for itself.
- **The style guidance calibrates honesty to stakes** — a research question feeding a health-adjacent feature decision gets told explicitly that an overstated capability is worse than a clear no. Match this calibration to what's actually riding on the answer.
- **"Report back a short summary"** keeps the parent session's context clean — the subagent does the deep dive, the main thread gets the bottom line plus a pointer to the full doc.

## Pattern B — Scoped parallel fix agents

Covered in depth in `testing-and-bugs.md` §2 — the short version, as a checklist for writing one:

- [ ] Exact file list this agent may touch, stated as an allowlist
- [ ] Explicit "do NOT touch [X], another agent owns it"
- [ ] Each finding by ID with file:line and the specific fix shape (not just the symptom)
- [ ] "Read fully before editing; apply fixes precisely and minimally, preserving behavior/comments/style"
- [ ] Any standing safety/architecture invariant, restated verbatim if this module touches it
- [ ] "Report which findings you fixed and any cross-file impact — do not edit outside your file list"

Dispatch enough of these in parallel to cover every finding from an audit pass, partitioned so no two agents' file lists overlap. This is the pattern that makes a 60+-finding audit tractable in a single session rather than a slow sequential slog.

## Pattern C — Parallel sessions on feature branches, and the integration pass

Distinct from both of the above: multiple *sessions* (not subagents) working the same repo on
separate feature branches, reconciled later by a dedicated integration pass. This is how the largest
app in the corpus was built — a scaffold session followed by numbered feature sessions, merged in
batches.

What makes it work:

- **One scaffold session lands first, and everything else branches off it.** Two sessions opened
  against the same workspace at the same time is a real occurrence, not a hypothetical. The
  resolution that worked: the second session *detected* the scaffold already in flight, asked which
  path to take rather than proceeding, and stood down when told to adopt the existing one. Record
  that provenance in `CLAUDE.md` — "anything you find on disk traces back to X + the session merges
  in `git log`" — or the next cold session cannot tell which of two plausible histories is real.
- **The integration pass is its own phase with its own artifact** (`INTEGRATION_NOTES.md`), and it
  runs in a fixed order: merge → parallel code review in batches → fixes → re-run tests → build the
  APK. Recording the phases *and their results* is what lets the next pass start from evidence
  instead of re-reviewing merged work.
- **"Branches still in flight (deliberately un-merged)" is a required section.** An un-merged branch
  with no note attached is indistinguishable from an abandoned one, and gets either re-implemented
  or deleted. Say which it is and why it's waiting.
- **Duplicate implementations are the characteristic failure of this pattern.** Two sessions solving
  the same problem on two branches both merge cleanly and both work; the audit finds three parallel
  partly-wired implementations of one client, where a binding mistake silently selects the unsafe
  one. Make "grep for a second implementation of anything this branch touched" an explicit step of
  every integration pass, and prune to one per an ADR rather than leaving the loser in the tree.

## When to use which

Research delegation: the question has a factual answer that exists somewhere (docs, source code, published research) and the main session doesn't need to see the search process, just the conclusion and the doc it produced.

Fix-agent delegation: you already have a concrete, itemized list of changes (from an audit) that can be partitioned into non-overlapping file sets. If the "fixes" aren't itemized yet — if it's still "go figure out what's wrong and fix it" — do the audit pass first; don't skip straight to fix agents on a vague mandate.
