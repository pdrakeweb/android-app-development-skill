# Context economy: spending fewer tokens on the same work

How to set a project up so that sessions and subagents read what the task needs and nothing else.
Three levers account for nearly all of the avoidable cost in an Android project: what loads on every
session (§1), what the file tools can wander into (§2), and what build tools print (§3). §4 covers
subagents, §5 retrofits an existing repository, §6 says how to check that it worked.

Everything here keeps the full information one step away. Nothing is deleted; it is moved out of
the default path. A saving that makes an agent guess is not a saving (§7).

## 1. `CLAUDE.md` is an index, not a library

`CLAUDE.md` loads into every session and every subagent, and a "read first" list in it is followed
literally. Measured on a real app repository: a numbered read-first list of ten documents came to
about 120 KB, roughly 30K tokens, paid at the start of every session and again by every subagent
before any work began. Tiering it cut the mandatory reading to two documents, about 15 KB.

The shape that works:

- **Under about 100 lines.** What the project is, how to build and run it, the named invariants
  verbatim, the working rules, and the index below. Detail lives in `docs/`.
- **At most two documents are mandatory**, and they are the short ones: principles (with the
  never-do list) and the engineering practices (definition of done, tests, guards). Everything else
  is opened when the task touches it.
- **An index by task, with section numbers**, not a list of files:

  ```markdown
  ## Read first (tiered)

  Always, every session and subagent: `docs/VISION.md` and `docs/ENGINEERING.md`.

  Open on demand, and read the named section rather than the file. Not having opened a doc is
  never a licence to guess: if the task touches its subject, open it.

  | When the task touches | Open |
  |---|---|
  | Behaviour, screens, permissions, open questions | `docs/APP_SPEC.md` (§9 open, §10 settled) |
  | Limits, gates, clinical defaults | `docs/SAFETY.md` §3-7 |
  | Who decided what, re-opening a question | `docs/DECISIONS.md` (grep the D-number) |
  | Modules, data model, storage | `docs/ARCHITECTURE.md` §3-5 |
  ```

- **Invariants stay verbatim in `CLAUDE.md`.** They are the one thing every prompt needs, and the
  house rule is to paste them into every audit and fix prompt. Never replace them with a pointer.
- **A safety document is mandatory for the work it governs.** Say so in the index ("anything under
  I-1 opens `SAFETY.md`"), so on-demand never becomes optional for the rule that matters most.
- **Docs are written to be read in part.** Each opens with a two or three line summary, uses
  numbered headings, keeps sections self-contained, and is split once it passes about 400 lines.
  A doc that can only be understood whole will be read whole.
- **Check the section numbers.** An index that cites `§3, §4, §7` when the subject also lives in §5
  and §6 sends an agent past the part it needed. List the headings (`grep '^## '`) before writing
  the row, and again when a doc is restructured.

Write the index when `CLAUDE.md` is first written (Phase 1), and re-check it at handoff (Phase 7).

## 2. Keep the file tools out of build output

Build directories hold thousands of generated and intermediate files. Search tools mostly skip
them already because they are in `.gitignore`; the deny rules below close the remaining path, an
explicit read or listing. Put this in the project's `.claude/settings.json` and commit it:

```json
{
  "permissions": {
    "deny": [
      "Read(**/build/intermediates/**)",
      "Read(**/build/.transforms/**)",
      "Read(**/build/tmp/**)",
      "Read(**/build/kotlin/**)",
      "Read(**/build/kspCaches/**)",
      "Read(**/build/classes/**)",
      "Read(**/build/libs/**)",
      "Read(**/build/resources/**)",
      "Read(**/.gradle/**)",
      "Read(**/.kotlin/**)",
      "Read(**/node_modules/**)"
    ]
  }
}
```

- **Do not deny all of `build/`.** `build/reports` (lint, test and problem reports),
  `build/test-results`, `build/outputs` (screenshot diffs, the APK path) and `build/generated`
  (KSP and Room output) are what a session needs when something fails. A deny rule cannot be
  overridden by an allow rule, so a blanket deny removes them for good.
- **Check for real source under these names first.** A package or module called `build`, `tmp` or
  `kotlin` under a `build/` path would be hidden: `git ls-files | grep -E '(^|/)build/'` should
  print nothing.
- **Settings load from the directory the session was started in.** A session started in a parent
  folder holding several repositories reads the parent's `.claude/settings.json`, not each
  repository's. If that is how the machine is used, put the same file in the parent.
- These rules cover the file tools. A shell `cat` of the same path is not stopped by them, which is
  one more reason for §3.

## 3. Filter build output where it is produced

A raw Gradle run is the largest single item most sessions put into context, and every later turn
pays to re-read it. Measured: a `tasks --all` listing was 56 KB and came back as 2 KB; a compile
failure buried in 600 lines of task headers came back as 16 lines with both compiler errors intact.

Truncation is not a substitute. Past about 30 KB the harness keeps only the *head* of the output
and saves the rest to a file, and a Gradle failure is at the *end*. An agent then sees the first
few hundred task headers, no error, and re-runs the build or reads the saved file whole.

There are two tools, and they do the same job at different points:

| | Plugin hook `gradle-quiet.js` | `${CLAUDE_SKILL_DIR}/scripts/qrun.js` |
|---|---|---|
| Who gets it | Anyone with this plugin installed. Nothing to set up | Anyone; copy it into the project as `tools/qrun.js` |
| How | Rewrites Gradle output after the command ran, before the model sees it | Wraps the command: `node tools/qrun.js -- ./gradlew :core:test` |
| Covers | Gradle, from the Bash and PowerShell tools | Any command: Gradle, `adb install`, instrumented tests |
| Full log | Path printed on the last line | `build/qrun/`, path printed |
| Exit code | Untouched, the command already ran | The wrapped command's own |

Use the hook when the plugin is installed and add `qrun.js` to a repository whose other
contributors, CI agents or cloud sessions will not have the plugin. Both keep, on a failure: every
failed task's output, compiler errors with file and line, failed tests with the assertion and first
frames, and the "What went wrong" block. Both print a summary on success. The hook leaves output
of 40 lines or fewer alone, and leaves everything alone when it does not recognise what it was
given. Put `GRADLE_RAW` anywhere in a command to see that run unfiltered.

Rules that go in the generated `CLAUDE.md` (the block is in `bootstrapping.md`):

- Fix from the printed failure. For more, grep the saved log with a narrow pattern, or read it
  with an offset and limit. Do not re-run a build to "see more".
- Never dump a log whole. `adb logcat -d -t 200 *:E`, or a tag or pid filter with a line cap.
- Scope the build: one module or one test (`:core:test --tests X`) before a full `check`.
- A filter is a guard, and **a guard you have never seen fail is not yet a guard.** After changing
  either script, plant a compile error and confirm the error line survives. Check for the
  compiler's own `e: ...File.kt:3:38` line: Gradle repeats the file location in its failure
  report, so a filter that drops every error line still appears to "name the file".

## 4. Subagents pay the whole bill again

A subagent starts with `CLAUDE.md` and whatever the prompt tells it to read. "Read the docs, then"
in a delegation prompt spends the §1 saving once per subagent.

- The prompt carries the task, the invariants verbatim, and exact paths with section numbers.
- Ask for the conclusion and a pointer, not the trail: "report under 200 words, write detail to
  `audit/<name>.md`".
- Fan out for independent work, not for reading. Five subagents that each read the spec cost five
  specs. `subagent-delegation.md` has the prompt shapes.

## 5. Retrofitting an existing repository

In this order; each step is independently useful and takes minutes.

1. **Measure.** `wc -c` the files `CLAUDE.md` tells every session to read. Divide by four for a
   rough token count. That is the fixed cost per session and per subagent.
2. **Tier the read-first list** (§1). Keep the invariants where they are.
3. **Add the deny rules** (§2), after the `git ls-files` check.
4. **Filter build output** (§3): install the plugin, or copy `qrun.js` in and add the
   tool-output block to `CLAUDE.md`.
5. **Fix the handoff docs.** A handoff file with its own "read these seven documents in order"
   list undoes step 2 for the session that reads it. Point it at the index instead.
6. **Check** (§6), then commit `CLAUDE.md` and `.claude/` together so the next clone has both.

## 6. Checking that it worked

- **Deny rules:** list a denied folder with the file tools and a readable one beside it
  (`build/kotlin` and `build/test-results`). The first should come back empty or refused, the
  second should not.
- **Output filter:** run a long Gradle command (`./gradlew tasks --all`). The output should end
  with a `[gradle-quiet]` line, or `qrun:` should lead it, and be a few dozen lines.
- **A failure still reads as a failure:** plant a compile error, build, and confirm the file, line
  and message are all in what came back. Remove it.
- **Read-first:** start a fresh session, ask it what it read before answering, and compare with
  the index.

## 7. What not to save on

- **Invariants, the safety document for safety work, and decisions already made.** Skipping these
  costs a wrong build, which costs more than every saving here combined.
- **Verification.** `verify-install.sh`, a planted violation, a scenario run. Shorter output from
  a check is the goal; skipping the check is not.
- **Failure detail.** If a filter hides the line that names the cause, widen the filter. The full
  log path is always printed so that this is a grep, not a rebuild.
