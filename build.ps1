<#
.SYNOPSIS
    Package this skill into android-app-development.zip (claude.ai upload format).

.DESCRIPTION
    This repo is FLAT: SKILL.md and references/ live at the root, because this is a
    documentation-only skill with no scripts, cache, or API to sync. The zip, however,
    must contain a single top-level directory named for the skill, so the build stages
    the payload into a temp dir of that name before zipping.

    Validates, before packaging:
      1. frontmatter `name:` obeys Anthropic's rules (<=64 chars, [a-z0-9-] only,
         no reserved words) and matches this repo's expected skill name;
      2. frontmatter `description:` is present and <=1024 chars;
      3. frontmatter `version:` is present and is semver.

.PARAMETER OutDir
    Where to write the zip. Defaults to the repo root.
#>
param([string]$OutDir = $PSScriptRoot)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$skillMd = Join-Path $PSScriptRoot "SKILL.md"
if (-not (Test-Path $skillMd)) { Write-Error "SKILL.md not found at repo root."; exit 1 }

# --- parse frontmatter --------------------------------------------------------
$raw = Get-Content $skillMd -Raw
if ($raw -notmatch '(?s)\A---\r?\n(.*?)\r?\n---') {
    Write-Error "SKILL.md has no YAML frontmatter."; exit 1
}
$fm = $Matches[1]

if ($fm -notmatch '(?m)^name:\s*"?([^"\r\n]+?)"?\s*$') {
    Write-Error "No 'name:' in SKILL.md frontmatter."; exit 1
}
$skillName = $Matches[1].Trim()

if ($fm -notmatch '(?m)^version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)"?\s*$') {
    Write-Error "No semver 'version:' in SKILL.md frontmatter."; exit 1
}
$version = $Matches[1]

# description may be a single line or a folded scalar with indented continuations
$desc = ""
$inDesc = $false
foreach ($line in ($fm -split "\r?\n")) {
    if ($line -match '^description:\s*(.*)$') { $inDesc = $true; $desc += $Matches[1]; continue }
    if ($inDesc) {
        if ($line -match '^\s+\S') { $desc += " " + $line.Trim() } else { break }
    }
}
$desc = $desc.Replace('>', '').Trim()

# --- validate -----------------------------------------------------------------
if ($skillName.Length -gt 64) { Write-Error "Skill name exceeds 64 chars."; exit 1 }
if ($skillName -cnotmatch '^[a-z0-9-]+$') {
    Write-Error "Skill name '$skillName' must be lowercase letters, digits and hyphens only."; exit 1
}
if ($skillName -match '(?i)\b(claude|anthropic)\b') {
    Write-Error "Skill name '$skillName' uses a reserved word (claude/anthropic)."; exit 1
}
if ([string]::IsNullOrWhiteSpace($desc)) { Write-Error "Frontmatter description is empty."; exit 1 }
if ($desc.Length -gt 1024) { Write-Error "Description exceeds 1024 chars ($($desc.Length))."; exit 1 }
if (-not (Test-Path (Join-Path $PSScriptRoot "references"))) {
    Write-Error "references/ directory not found."; exit 1
}

# --- stage --------------------------------------------------------------------
$outName = Join-Path $OutDir "$skillName.zip"
if (Test-Path $outName) { Remove-Item $outName -Force }

$tmp = Join-Path $env:TEMP "skill_build_$(Get-Random)"
$stage = Join-Path $tmp $skillName
New-Item $stage -ItemType Directory -Force | Out-Null

Copy-Item $skillMd $stage
Copy-Item (Join-Path $PSScriptRoot "references") $stage -Recurse

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $outName)
Remove-Item $tmp -Recurse -Force

$size = (Get-Item $outName).Length
$files = @(Get-ChildItem (Join-Path $PSScriptRoot "references") -File).Count + 1
Write-Host "Built: $outName" -ForegroundColor Green
Write-Host "  skill   : $skillName v$version"
Write-Host "  files   : $files"
Write-Host "  size    : $size bytes"
