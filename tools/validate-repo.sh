#!/usr/bin/env bash
# validate-repo.sh — the checks this repo's own house rules imply.
#
# Repo-level validation, NOT part of the shipped skill: build.ps1 packages only
# skills/<name>/, so nothing here reaches a user's install.
#
# It encodes the checks that were being run by hand, because a check that lives
# in someone's memory is exactly the kind of claim this skill tells you not to
# trust. Runs locally with no arguments; CI calls the same script.

set -uo pipefail
# A failed cd would validate the wrong tree and could report a false pass.
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

SKILL_DIR="skills/android-app-development"
FAIL=0

ok()   { printf '\033[32mok\033[0m    %s\n' "$*"; }
bad()  { printf '\033[31mFAIL\033[0m  %s\n' "$*"; FAIL=1; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || { bad "$1 is required but not installed"; return 1; }; }

# ---- shell scripts -----------------------------------------------------------
head_ "Shell scripts"
for f in "$SKILL_DIR"/scripts/*.sh tools/*.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" && ok "syntax: $f" || bad "syntax: $f"
  [ -x "$f" ] || bad "not executable: $f (chmod +x, and git update-index --chmod=+x)"
done
if command -v shellcheck >/dev/null 2>&1; then
  for f in "$SKILL_DIR"/scripts/*.sh tools/*.sh; do
    [ -e "$f" ] || continue
    shellcheck -S warning "$f" && ok "shellcheck: $f" || bad "shellcheck: $f"
  done
else
  printf '      shellcheck not installed — skipping lint\n'
fi

# ---- hook --------------------------------------------------------------------
head_ "Hook"
if need node; then
  node --check hooks/android-guardrails.js && ok "syntax: hooks/android-guardrails.js" \
    || bad "syntax: hooks/android-guardrails.js"

  # The hook must fire on a real pattern, stay silent on the correct form, and
  # never be the reason a session breaks.
  fires="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"adb install -r a.apk"}}' \
    | node hooks/android-guardrails.js)"
  [ -n "$fires" ] && ok "fires on an unasserted adb install" \
    || bad "did not fire on an unasserted adb install"

  quiet="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"adb install -r a.apk | grep Success"}}' \
    | node hooks/android-guardrails.js)"
  [ -z "$quiet" ] && ok "silent when the install is asserted" \
    || bad "false positive on a correctly asserted install"

  printf 'not json' | node hooks/android-guardrails.js >/dev/null 2>&1 \
    && ok "exits 0 on malformed input" || bad "non-zero exit on malformed input"

  # Anything it emits must be parseable, or the harness sees garbage.
  printf '%s' "$fires" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{JSON.parse(s)})' \
    && ok "emits valid JSON" || bad "emitted output is not valid JSON"
fi

# ---- JSON --------------------------------------------------------------------
head_ "JSON"
if need python3; then
  for f in .claude-plugin/*.json hooks/hooks.json; do
    [ -e "$f" ] || continue
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" && ok "valid: $f" || bad "invalid: $f"
  done
fi

# ---- skill metadata ----------------------------------------------------------
head_ "Skill metadata"
python3 - "$SKILL_DIR" <<'PY'
import json, pathlib, re, sys
skill = pathlib.Path(sys.argv[1])
fail = []
raw = (skill / "SKILL.md").read_text()
m = re.match(r"\A---\r?\n(.*?)\r?\n---", raw, re.S)
if not m:
    fail.append("SKILL.md has no YAML frontmatter")
else:
    fm = m.group(1)
    name = re.search(r'(?m)^name:\s*"?([^"\r\n]+?)"?\s*$', fm)
    ver = re.search(r'(?m)^version:\s*"?(\d+\.\d+\.\d+)"?\s*$', fm)
    if not name: fail.append("no name: in frontmatter")
    if not ver:  fail.append("no semver version: in frontmatter")

    if name:
        n = name.group(1).strip()
        if len(n) > 64: fail.append(f"name longer than 64 chars: {len(n)}")
        if not re.fullmatch(r"[a-z0-9-]+", n): fail.append(f"name not lowercase/digits/hyphens: {n}")
        if re.search(r"(?i)\b(claude|anthropic)\b", n): fail.append(f"name uses a reserved word: {n}")
        if n != skill.name: fail.append(f"frontmatter name {n!r} != directory {skill.name!r}")

    # Replicates build.ps1's description walker, so CI fails before the build does.
    desc, in_desc = "", False
    for line in fm.split("\n"):
        d = re.match(r"^description:\s*(.*)$", line)
        if d: in_desc = True; desc += d.group(1); continue
        if in_desc:
            if re.match(r"^\s+\S", line): desc += " " + line.strip()
            else: break
    desc = desc.replace(">", "").strip()
    if not desc: fail.append("description is empty")
    if len(desc) > 1024: fail.append(f"description over 1024 chars: {len(desc)}")

    # Version drift between the two places a version is declared.
    pj = pathlib.Path(".claude-plugin/plugin.json")
    if ver and pj.exists():
        pv = json.loads(pj.read_text()).get("version")
        if pv != ver.group(1):
            fail.append(f"version drift: SKILL.md {ver.group(1)} != plugin.json {pv}")

for f in fail: print(f"FAILED {f}")
sys.exit(1 if fail else 0)
PY
[ $? -eq 0 ] && ok "frontmatter, naming and version stamps agree" || bad "skill metadata"

# ---- docs integrity ----------------------------------------------------------
head_ "Docs"
python3 - "$SKILL_DIR" <<'PY'
import pathlib, re, sys
skill = pathlib.Path(sys.argv[1])
docs = list(skill.rglob("*.md")) + [pathlib.Path("README.md")]
fail = []

# Every referenced reference file must exist — a dead pointer is worse than no
# pointer, because the agent follows it and finds nothing.
refs = set()
for f in docs:
    refs |= set(re.findall(r"`?references/([a-z0-9-]+\.md)`?", f.read_text()))
for r in sorted(refs):
    if not (skill / "references" / r).exists():
        fail.append(f"referenced but missing: references/{r}")

# Every "<file>.md §N" must point at a section that exists.
sections = {}
for f in (skill / "references").glob("*.md"):
    # Heading styles differ across files by age: "## 1. Title" in the original
    # references, "## 1 · Title" in newer ones. Both are section 1.
    sections[f.name] = set(re.findall(r"^## (\d+)(?=[.\s·])", f.read_text(), re.M))
for f in docs:
    text = f.read_text()
    for name, have in sections.items():
        for n in re.findall(re.escape(name) + r"`?\s*§(\d+)", text):
            if n not in have:
                fail.append(f"{f}: {name} §{n} does not exist (has {sorted(have, key=int) or 'none'})")

# Unbalanced fences silently swallow the rest of a file when rendered.
for f in docs:
    if f.read_text().count("\n```") % 2 != 0:
        fail.append(f"{f}: unbalanced code fences")

# A bare "scripts/x.sh" resolves against the session's working directory - the
# user's Android project, which very often has its own scripts/ - not against
# the skill. Bundled scripts must be referenced through ${CLAUDE_SKILL_DIR}.
for f in [d for d in docs if d != pathlib.Path("README.md")]:
    for line_no, line in enumerate(f.read_text().split("\n"), 1):
        for m in re.finditer(r"(?<!CLAUDE_SKILL_DIR\}/)scripts/[a-z0-9-]+\.sh", line):
            if "${CLAUDE_SKILL_DIR}/" + m.group(0) in line:
                continue
            fail.append(f"{f}:{line_no}: bare {m.group(0)} - prefix with ${{CLAUDE_SKILL_DIR}}/")

# Every script the docs promise must actually ship.
for f in docs:
    for s in set(re.findall(r"scripts/([a-z0-9-]+\.sh)", f.read_text())):
        if not (skill / "scripts" / s).exists():
            fail.append(f"{f}: promises scripts/{s}, which does not exist")

for x in fail: print(f"FAILED {x}")
print(f"checked {len(docs)} docs, {len(refs)} reference links, "
      f"{sum(len(v) for v in sections.values())} sections")
sys.exit(1 if fail else 0)
PY
[ $? -eq 0 ] && ok "cross-references, fences and script promises all resolve" || bad "docs integrity"

printf '\n'
if [ "$FAIL" -eq 0 ]; then printf '\033[32mPASS\033[0m  repo validation clean.\n'
else printf '\033[31mFAIL\033[0m  repo validation failed.\n'; fi
exit "$FAIL"
