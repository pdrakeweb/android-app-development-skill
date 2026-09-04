#!/usr/bin/env bash
#
# Package this skill into android-app-development.zip (claude.ai upload format).
#
# POSIX counterpart to build.ps1 — same validations, same payload, so a build on
# macOS/Linux/Git-Bash matches a build on Windows PowerShell. CI runs this one,
# which is why it exists: the PowerShell build only ever ran when someone
# happened to be on Windows, so its validations were unenforced everywhere else.
#
# This repo is a Claude Code PLUGIN, so the skill lives at
# skills/<name>/ rather than at the root. The upload zip, however, must contain
# a single top-level directory named for the skill, so the payload is staged
# into a directory of that name before zipping.
#
# Validates, before packaging:
#   1. frontmatter `name:` obeys Anthropic's rules and matches the directory;
#   2. frontmatter `description:` is present and <= 1024 chars;
#   3. frontmatter `version:` is semver and matches .claude-plugin/plugin.json.
#
# Usage:
#   ./build.sh            # -> android-app-development.zip
#   ./build.sh --out DIR  # write the zip somewhere else

set -euo pipefail
cd "$(dirname "$0")" || { echo "cannot cd to repo root" >&2; exit 1; }

OUT_DIR="$PWD"
while [ $# -gt 0 ]; do
    case "$1" in
        --out) OUT_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

SKILL_DIR="skills/android-app-development"
[ -f "$SKILL_DIR/SKILL.md" ] || die "SKILL.md not found at $SKILL_DIR."
[ -d "$SKILL_DIR/references" ] || die "references/ not found under $SKILL_DIR."

# Same probe as the sibling council-skill repo: on Windows a bare `python3` on
# PATH is often the Microsoft Store alias stub, which resolves under
# `command -v` but exits non-zero. Check it actually runs.
find_python() {
    local c
    for c in python3 python py; do
        if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import zipfile' >/dev/null 2>&1; then
            printf '%s' "$c"; return 0
        fi
    done
    return 1
}
PY=$(find_python) || die "No usable Python found (tried python3, python, py)."

# --- validate frontmatter -----------------------------------------------------
# Done in Python so the description walker matches build.ps1's exactly; a
# divergence here would let CI pass a package the Windows build then rejects.
"$PY" - "$SKILL_DIR" <<'PYEOF' || die "SKILL.md failed validation."
import json, pathlib, re, sys
skill = pathlib.Path(sys.argv[1])
raw = (skill / "SKILL.md").read_text()
m = re.match(r"\A---\r?\n(.*?)\r?\n---", raw, re.S)
if not m:
    print("SKILL.md has no YAML frontmatter.", file=sys.stderr); sys.exit(1)
fm = m.group(1)
errs = []

nm = re.search(r'(?m)^name:\s*"?([^"\r\n]+?)"?\s*$', fm)
if not nm: errs.append("no name: in frontmatter")
else:
    n = nm.group(1).strip()
    if len(n) > 64: errs.append("name exceeds 64 chars")
    if not re.fullmatch(r"[a-z0-9-]+", n): errs.append(f"name not lowercase/digits/hyphens: {n}")
    if re.search(r"(?i)\b(claude|anthropic)\b", n): errs.append(f"name uses a reserved word: {n}")
    if n != skill.name: errs.append(f"name {n!r} does not match directory {skill.name!r}")

vm = re.search(r'(?m)^version:\s*"?(\d+\.\d+\.\d+)"?\s*$', fm)
if not vm: errs.append("no semver version: in frontmatter")

desc, in_desc = "", False
for line in fm.split("\n"):
    d = re.match(r"^description:\s*(.*)$", line)
    if d: in_desc = True; desc += d.group(1); continue
    if in_desc:
        if re.match(r"^\s+\S", line): desc += " " + line.strip()
        else: break
desc = desc.replace(">", "").strip()
if not desc: errs.append("description is empty")
if len(desc) > 1024: errs.append(f"description exceeds 1024 chars ({len(desc)})")

pj = pathlib.Path(".claude-plugin/plugin.json")
if vm and pj.exists():
    pv = json.loads(pj.read_text()).get("version")
    if pv != vm.group(1):
        errs.append(f"version drift: SKILL.md {vm.group(1)} != plugin.json {pv}")

for e in errs: print(f"  {e}", file=sys.stderr)
sys.exit(1 if errs else 0)
PYEOF

SKILL_NAME=$(basename "$SKILL_DIR")
VERSION=$(sed -n 's/^version:[[:space:]]*"\{0,1\}\([0-9]\+\.[0-9]\+\.[0-9]\+\)"\{0,1\}.*$/\1/p' \
    "$SKILL_DIR/SKILL.md" | head -1)

mkdir -p "$OUT_DIR"
OUT_NAME="$OUT_DIR/$SKILL_NAME.zip"
rm -f "$OUT_NAME"

# --- stage --------------------------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stage="$tmp/$SKILL_NAME"
mkdir -p "$stage"

cp "$SKILL_DIR/SKILL.md" "$stage/"
cp -R "$SKILL_DIR/references" "$stage/references"
[ -d "$SKILL_DIR/scripts" ] && cp -R "$SKILL_DIR/scripts" "$stage/scripts"
find "$stage" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

dest=$(cd "$OUT_DIR" && printf '%s/%s.zip' "$PWD" "$SKILL_NAME")
if command -v zip >/dev/null 2>&1; then
    ( cd "$tmp" && zip -q -r "$dest" "$SKILL_NAME" )
else
    ( cd "$tmp" && "$PY" -c '
import os, sys, zipfile
dest, root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
    for base, _, files in os.walk(root):
        for f in sorted(files):
            p = os.path.join(base, f)
            z.write(p, os.path.relpath(p, "."))
' "$dest" "$SKILL_NAME" )
fi

FILES=$(find "$stage" -type f | wc -l | tr -d ' ')
SIZE=$(wc -c < "$dest" | tr -d ' ')
echo "Built: $dest"
echo "  skill   : $SKILL_NAME v$VERSION"
echo "  files   : $FILES"
echo "  size    : $SIZE bytes"
