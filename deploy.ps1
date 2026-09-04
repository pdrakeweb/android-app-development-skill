<#
.SYNOPSIS
    Build and deploy this skill into Claude Desktop's local skills-plugin directory.

.DESCRIPTION
    1. Runs build.ps1.
    2. Extracts the zip to a temp dir.
    3. Locates Claude Desktop's skills dir — it uses a nested
       <outer-guid>\<inner-guid>\skills\<skill-name>\ layout under
       %APPDATA%\Claude\local-agent-mode-sessions\skills-plugin.
    4. Backs up any existing deployment (keeps the last 5).
    5. Mirrors the new files in with robocopy /MIR.
    6. Registers the skill in manifest.json — Claude Desktop only loads skills
       listed there, so a bare file copy is invisible.

.PARAMETER DryRun
    Show what would happen without writing anything.
.PARAMETER RestartClaude
    Kill and relaunch Claude Desktop after a successful deploy.
.PARAMETER SkipBackup
    Skip the pre-deploy backup.
#>
[CmdletBinding()]
param([switch]$DryRun, [switch]$RestartClaude, [switch]$SkipBackup)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$temps = New-Object System.Collections.Generic.List[string]

function Step { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Info { param($m) Write-Host "    $m" -ForegroundColor Gray }
function Ok   { param($m) Write-Host "    $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "    $m" -ForegroundColor Yellow }

function Get-Frontmatter {
    param([string]$SkillMd)
    $raw = Get-Content $SkillMd -Raw
    if ($raw -notmatch '(?s)\A---\r?\n(.*?)\r?\n---') { throw "SKILL.md has no frontmatter." }
    $fm = $Matches[1]
    $name = if ($fm -match '(?m)^name:\s*"?([^"\r\n]+?)"?\s*$') { $Matches[1].Trim() } else { throw "No name:" }
    $desc = ""; $inDesc = $false
    foreach ($line in ($fm -split "\r?\n")) {
        if ($line -match '^description:\s*(.*)$') { $inDesc = $true; $desc += $Matches[1]; continue }
        if ($inDesc) { if ($line -match '^\s+\S') { $desc += " " + $line.Trim() } else { break } }
    }
    return [pscustomobject]@{ Name = $name; Description = $desc.Replace('>', '').Trim() }
}

function Resolve-Target {
    param([string]$SkillName)
    $base = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions\skills-plugin'
    $existing = $null; $anySkillsDir = $null
    if (Test-Path -LiteralPath $base -PathType Container) {
        foreach ($outer in @(Get-ChildItem -LiteralPath $base -Directory -EA SilentlyContinue |
                             Where-Object { $_.Name -ne '.backups' })) {
            foreach ($inner in @(Get-ChildItem -LiteralPath $outer.FullName -Directory -EA SilentlyContinue)) {
                $skillsDir = Join-Path $inner.FullName 'skills'
                if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) { continue }
                if (-not $anySkillsDir) { $anySkillsDir = $skillsDir }
                $cand = Join-Path $skillsDir $SkillName
                if (Test-Path -LiteralPath $cand -PathType Container) { $existing = $cand; break }
            }
            if ($existing) { break }
        }
    }
    if ($existing)    { Info "Existing deployment: $existing"; return $existing }
    if ($anySkillsDir) { $t = Join-Path $anySkillsDir $SkillName; Info "New skill dir: $t"; return $t }
    Warn "No nested skills layout found; falling back to $base\$SkillName"
    return (Join-Path $base $SkillName)
}

function Sync-Manifest {
    param([string]$TargetDir, [string]$SkillName, [string]$Description)
    $skillsDir = Split-Path -Parent $TargetDir
    $manifestPath = Join-Path (Split-Path -Parent $skillsDir) 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Warn "No manifest.json beside the skills dir — Claude Desktop will NOT see this skill."
        Warn "Install it once via Settings > Capabilities > Skills (upload the zip), then redeploy."
        return 'no-manifest'
    }
    if ($DryRun) { Info "[dry-run] would sync manifest.json entry for '$SkillName'"; return 'dry-run' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $entry = @($manifest.skills) | Where-Object { $_.name -eq $SkillName } | Select-Object -First 1
    $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.ffffffZ')
    if ($entry) {
        if ($Description -and $entry.description -ne $Description) {
            Copy-Item -LiteralPath $manifestPath "$manifestPath.bak" -Force
            $entry.description = $Description; $entry.updatedAt = $now
            $manifest.lastUpdated = [int64]([datetimeoffset](Get-Date)).ToUnixTimeMilliseconds()
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
            return 'description-updated'
        }
        return 'unchanged'
    }
    Copy-Item -LiteralPath $manifestPath "$manifestPath.bak" -Force
    $manifest.skills = @($manifest.skills) + @([pscustomobject]@{
        skillId = "skill_local_$SkillName"; name = $SkillName; description = $Description
        creatorType = 'user'; updatedAt = $now; enabled = $true })
    $manifest.lastUpdated = [int64]([datetimeoffset](Get-Date)).ToUnixTimeMilliseconds()
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Ok "Registered '$SkillName' in manifest.json (was missing — a bare file copy is invisible)."
    return 'registered'
}

try {
    Write-Host ""; Write-Host "=== Skill Deploy ===" -ForegroundColor Magenta
    if ($DryRun) { Warn "(DRY RUN — nothing will be written)" }

    $meta = Get-Frontmatter (Join-Path $root 'SKILL.md')
    Info "Skill: $($meta.Name)"

    Step "Building"
    # A PowerShell script that returns normally leaves $LASTEXITCODE untouched, which
    # under StrictMode throws if nothing has set it yet. Seed it, then read it back.
    $global:LASTEXITCODE = 0
    & (Join-Path $root 'build.ps1')
    $rc = $global:LASTEXITCODE
    if ($rc -and $rc -ne 0) { throw "build.ps1 failed ($rc)" }

    $zip = Join-Path $root "$($meta.Name).zip"
    if (-not (Test-Path $zip)) { throw "$zip not found after build." }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("skill-deploy-" + [Guid]::NewGuid().ToString('N'))
    $temps.Add($tmp)
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    $source = Join-Path $tmp $meta.Name
    if (-not (Test-Path (Join-Path $source 'SKILL.md'))) { throw "SKILL.md missing inside the zip." }

    $target = Resolve-Target -SkillName $meta.Name

    if (-not $SkipBackup -and (Test-Path -LiteralPath $target -PathType Container)) {
        $backupRoot = Join-Path $env:APPDATA 'Claude\local-agent-mode-sessions\skills-plugin\.backups'
        $backupDir = Join-Path $backupRoot ("{0}_{1}" -f $meta.Name, (Get-Date -Format 'yyyyMMdd-HHmmss'))
        if ($DryRun) { Info "[dry-run] would back up to $backupDir" }
        else {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            & robocopy @($target, $backupDir, '/E', '/COPY:DAT', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/NJH', '/NJS') | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "Backup failed ($LASTEXITCODE)" }
            $global:LASTEXITCODE = 0
            Ok "Backup: $backupDir"
            @(Get-ChildItem -LiteralPath $backupRoot -Directory -Filter "$($meta.Name)_*" -EA SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -Skip 5) |
              ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA SilentlyContinue }
        }
    }

    $rcArgs = @($source, $target, '/MIR', '/COPY:DAT', '/R:2', '/W:2', '/NFL', '/NDL', '/NP')
    if ($DryRun) { $rcArgs += '/L' }
    Step "robocopy -> $target"
    & robocopy @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
    $global:LASTEXITCODE = 0

    $manifestAction = Sync-Manifest -TargetDir $target -SkillName $meta.Name -Description $meta.Description

    if ($RestartClaude -and -not $DryRun) {
        Step "Restarting Claude Desktop"
        @(Get-Process -Name 'Claude' -EA SilentlyContinue) | Stop-Process -Force -EA SilentlyContinue
        Start-Sleep -Milliseconds 750
        $exe = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\Claude.exe'
        if (-not (Test-Path $exe)) { $exe = Join-Path $env:LOCALAPPDATA 'Programs\Claude\Claude.exe' }
        if (Test-Path $exe) { Start-Process $exe | Out-Null; Ok "Relaunched." } else { Warn "Claude.exe not found." }
    }

    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Magenta
    Write-Host ("  Target   : {0}" -f $target)
    Write-Host ("  Manifest : {0}" -f $manifestAction)
    Write-Host ""
    if ($DryRun) { Warn "Dry run complete." }
    else { Ok "Deployed. Restart Claude Desktop to pick up changes." }
}
catch {
    Write-Host "DEPLOY FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    foreach ($d in $temps) { if ($d -and (Test-Path $d)) { Remove-Item $d -Recurse -Force -EA SilentlyContinue } }
}
