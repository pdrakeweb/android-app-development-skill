<#
.SYNOPSIS
    Package this skill into android-app-development.zip (claude.ai upload format).

.DESCRIPTION
    This repo is a Claude Code PLUGIN: the skill payload lives under
    skills/<skill-name>/ so that plugin.json needs no custom "skills" path (which
    is also what avoids the "Path escapes plugin directory" failure seen on
    Claude Code for Windows when a plugin declares skills: "./").

    The claude.ai upload zip, however, must contain a single top-level directory
    named for the skill, so the build stages the payload into a temp dir of that
    name before zipping. Both distribution paths are therefore supported from one
    source tree.

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

$skillRoot = Join-Path $PSScriptRoot "skills\android-app-development"
$skillMd = Join-Path $skillRoot "SKILL.md"
if (-not (Test-Path $skillMd)) { Write-Error "SKILL.md not found at $skillMd."; exit 1 }

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
if (-not (Test-Path (Join-Path $skillRoot "references"))) {
    Write-Error "references/ directory not found under $skillRoot."; exit 1
}

# The plugin manifest version must not drift from the skill frontmatter version.
$pluginJson = Join-Path $PSScriptRoot ".claude-plugin\plugin.json"
if (Test-Path $pluginJson) {
    $pv = (Get-Content $pluginJson -Raw | ConvertFrom-Json).version
    if ($pv -ne $version) {
        Write-Error "Version drift: SKILL.md says $version, .claude-plugin/plugin.json says $pv."
        exit 1
    }
}

# --- stage --------------------------------------------------------------------
$outName = Join-Path $OutDir "$skillName.zip"
if (Test-Path $outName) { Remove-Item $outName -Force }

$tmp = Join-Path $env:TEMP "skill_build_$(Get-Random)"
$stage = Join-Path $tmp $skillName
New-Item $stage -ItemType Directory -Force | Out-Null

Copy-Item $skillMd $stage
Copy-Item (Join-Path $skillRoot "references") $stage -Recurse
$scripts = Join-Path $skillRoot "scripts"
if (Test-Path $scripts) { Copy-Item $scripts $stage -Recurse }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $outName)
Remove-Item $tmp -Recurse -Force

$size = (Get-Item $outName).Length
$files = @(Get-ChildItem $stage -File -Recurse).Count
Write-Host "Built: $outName" -ForegroundColor Green
Write-Host "  skill   : $skillName v$version"
Write-Host "  files   : $files"
Write-Host "  size    : $size bytes"
