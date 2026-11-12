# Building and Publishing a Release

Phase 6 (`lifecycle.md`) decides *who gets the build* and proves the artifact is sound. This file is
how the artifact gets **built and published reproducibly** — the half that intake Q10's "a GitHub
releases beta" answer needs and that Play-upload automation does not cover.

Read §1 at **scaffold time**, not at release time. A version scheme is cheap to set up in the first
commit and expensive to retrofit across every module once there are tags in the history. §4 is the
same: both traps are committed on day one and surface weeks later.

**Contents:** [1 · Version single-sourcing](#1--version-single-sourcing) ·
[2 · Tag-triggered release builds](#2--tag-triggered-release-builds) ·
[3 · Signing in CI](#3--signing-in-ci) ·
[4 · Repo hygiene that only breaks on CI](#4--repo-hygiene-that-only-breaks-on-ci)

Distribution identity — developer verification, limited distribution accounts, which channel Q10's
answer implies — is decided in `lifecycle.md` Phase 6 and detailed in `platform-currency.md` §6. It
is not repeated here.

---

## 1 · Version single-sourcing

**The failure this prevents.** `git tag v0.2.0` on a tree whose Gradle files still say `0.1.0`
produces a GitHub Release labelled **v0.2.0** containing an APK that reports **0.1.0**. Nothing
errors. Nothing warns. It surfaces weeks later as a bug report nobody can reproduce, because the
reporter's "version" and the artifact's version are two different facts and neither party knows it.

Two properties of the platform make this worse than a cosmetic mismatch:

> *"The Android system uses the `versionCode` value to protect against downgrades by preventing
> users from installing an APK with a lower `versionCode` than the version currently installed on
> their device."*
>
> *"The `versionName` is the only value displayed to users."*
> — <https://developer.android.com/studio/publish/versioning>

So the number that decides whether an upgrade installs is the one **nobody reads**, and the number
in every bug report is the one the system **ignores**. Any drift between them is invisible from both
sides.

### The rules

- **The app version is declared in exactly one place** — a version catalog entry. Not in each
  module's `build.gradle.kts`, not in a constant, not in a string resource.
- **`versionCode` is derived from `versionName`, never typed by hand.** A hand-typed pair
  eventually disagrees, and per the quotes above the disagreement is undetectable by inspection.
  Derive it (`major*10000 + minor*100 + patch` is the usual shape) so the two cannot separate.
- **`versionCode` may never decrease, so neither may the semver.** A version rollback is not a
  rollback — it is an app that will not install over itself and gives no reason.
- **Every companion module reads the same value.** Phone and Wear ship as a matched pair; two
  versions in one release is undiagnosable, and it compounds the same-key rule in `lifecycle.md`
  Phase 6 — mismatched *and* differently signed fails twice with one symptom.
- **A release build whose git tag disagrees with the declared version fails.** Not warns. A warning
  in a CI log is a warning nobody reads; the whole point is that this class of error is silent.

### Two valid approaches — pick deliberately

| | Catalog-declared + tag check | Derived from `git describe` |
|---|---|---|
| Source of truth | The catalog entry | The tag |
| Can drift? | Yes — the tag check is what catches it | No, structurally |
| Builds from a source tarball with no `.git`? | Yes | **No** — needs a fallback value |
| Bump is | An edit, reviewable in the diff | A tag, invisible in the diff |
| Fits | Anything distributed as source, or built where git may be absent | A repo where every build comes from a checkout |

Neither is the right answer everywhere. Catalog-declared keeps a tarball buildable and puts the
version bump in code review, at the cost of needing the tag check to stay honest. `git describe`
cannot drift by construction, but a build in a container that copied the tree without `.git`
silently produces `0.0.0-unknown` unless you wrote the fallback. **Whichever you choose, write down
which one it is** in `CLAUDE.md` — a later session that guesses wrong will add the mechanism you did
not pick, and then there are two.

---

## 2 · Tag-triggered release builds

The mechanism, and the traps. This is not a CI tutorial — GitHub's own docs are, and they are
current in a way this file will not stay.

**Trigger on a tag push, not on every push to main.** Every push to main is not a release, and a
workflow that builds one teaches everyone to ignore it:

```yaml
on:
  push:
    tags: ['v*']
```

(<https://raw.githubusercontent.com/github/docs/main/content/actions/reference/workflows-and-actions/events-that-trigger-workflows.md>:
*"You can use the `tags` or `tags-ignore` filter to configure your workflow to only run when
specific tags are pushed."*)

### The four traps, in the order people hit them

- **`git push` does not push tags.** This is the single most common "why didn't the release run".
  The tag exists locally, `git log` shows it, GitHub does not have it. `git push --follow-tags`, or
  `git push origin v0.2.0` explicitly.
- **More than three tags at once produces no events at all.** GitHub documents it plainly:
  *"Events will not be created for tags when more than three tags are pushed at once."* Pushing a
  backlog of tags after working offline runs nothing, and there is no error anywhere.
- **The workflow that runs is the one on the commit you tagged**, not the one on `main`. `GITHUB_SHA`
  is the tip commit pushed to the ref. So tagging an older commit runs *that commit's* workflow —
  and if you just added the workflow file and then tagged the release commit from before it, nothing
  runs. Add the workflow, commit it, *then* tag at or after that commit.
- **Build the release variant.** A workflow that runs `assembleDebug` because that is what was in
  the scratch script produces an artifact that will not install on a watch and is debuggable in the
  field (`lifecycle.md` Phase 6).

**Gate the workflow on the artifact check, and let it fail the build:**

```yaml
- run: ${CLAUDE_SKILL_DIR}/scripts/verify-artifact.sh app/build/outputs/apk/release/app-release.apk --release
```

It exits non-zero on a wrong ABI set, a wrong `targetSdk`, a missing v2 signature, or a still-debuggable
build. **A verification step that warns and continues is not a gate** — it publishes the bad artifact
and writes a note about it, which is the silent-failure pattern this skill exists to prevent. Do not
wrap it in `|| true`.

---

## 3 · Signing in CI

**The keystore goes in as a base64 secret and is decoded at build time.** It is never committed,
never echoed, and never left in an uploaded artifact.

Secrets to create, and how to produce their values:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 release.jks` (macOS: `base64 -i release.jks`) |
| `KEYSTORE_PASSWORD` | The store password |
| `KEY_ALIAS` | The alias inside the keystore |
| `KEY_PASSWORD` | The key password |

The decode step writes the file outside the workspace, or into a path the upload step does not glob:

```yaml
- run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > "$RUNNER_TEMP/release.jks"
```

Three things worth stating because each has a quiet failure mode:

- **48 KB is the secret size limit.** A keystore is comfortably inside it; a base64-encoded
  *bundle* of several may not be.
- **Log redaction covers workflow logs, not artifacts.** GitHub redacts recognized secrets from
  logs, and advises *"avoid using structured data as the values of secrets"* to keep that working —
  it says nothing about a keystore you accidentally copied into `build/outputs/` and then uploaded.
  The decode path above is the fix, not the redaction.
- **Never put the credentials in the build file.** Android's own guidance:
  *"the keystore and key password are visible directly in the `build.gradle` file. For improved
  security, you should remove the signing information from your build file"*
  (<https://developer.android.com/build/building-cmdline>). Read them from environment variables in
  `signingConfigs`, so the same build file works locally and in CI with no branch.

**The same-key rule for companion modules is in `lifecycle.md` Phase 6** — both modules must use the
same key or they install fine, run fine, and cannot talk to each other. **In CI the failure mode is
worse:** locally there is one keystore file and it is hard to get this wrong, but two workflows can
reference two different secret names and each will sign successfully, forever, without either
failing. If phone and watch are built by separate workflows, they read the *same* secrets — and the
certificate SHA-256 that `verify-artifact.sh` prints is how you confirm it rather than assume it.

---

## 4 · Repo hygiene that only breaks on CI

Both of these are committed on the first day and are invisible until the build runs somewhere other
than the machine that wrote it — which, for most projects, is the moment this file gets used.

- **`.gitignore` with `*/build/` matches exactly one directory level.** In a multi-module project
  that leaves `build-logic/convention/build/`, `core/ui/build/` and every other nested module's
  output fully untracked-but-exposed — an observed case left 1,671 untracked files, which makes
  `git status` useless and eventually commits build output. Use `**/build/`.
- **`gradlew` committed with CRLF fails on Linux CI** with a bad-interpreter error that names the
  shell, not the line endings. A Windows checkout without `core.autocrlf` handling will do this to
  you. Pin it:

```gitattributes
* text=auto eol=lf
gradlew text eol=lf
*.sh text eol=lf
*.bat text eol=crlf
```

  Add `.gitattributes` in the first commit. Adding it later does not fix already-committed files —
  they need `git add --renormalize .` after.
- **`gradlew` committed from Windows has no executable bit**, and Linux CI fails with
  *"Permission denied"*: `git update-index --chmod=+x gradlew`.

This is the class of bug that makes a build "work on my machine" in the most literal sense: it works
everywhere the file was never re-checked-out, and fails the first time anything else touches it.
