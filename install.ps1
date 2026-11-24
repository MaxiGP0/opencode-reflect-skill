#Requires -Version 5.1
<#
.SYNOPSIS
    Install the claude-reflect skill and commands for OpenCode.

.DESCRIPTION
    Copies the authored OpenCode port from this repository into an OpenCode
    config root. It installs the skill, four commands, and an empty queue file
    when no queue exists. It never downloads the upstream Claude Code plugin and
    never edits AGENTS.md.

.PARAMETER ConfigDir
    OpenCode config root. Defaults to $env:OPENCODE_CONFIG_DIR, or
    ~/.config/opencode.

.PARAMETER Force
    Replace an existing claude-reflect installation and overwrite the four
    command files owned by this project. Other commands and files are left
    alone.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -ConfigDir "C:\temp\opencode-config" -Force
#>
[CmdletBinding()]
param(
    [string]$ConfigDir,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "!!  $Message" -ForegroundColor Yellow
}

function Get-HomeDir {
    if ($HOME) { return $HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    throw "Could not find your home directory. Pass -ConfigDir explicitly."
}

if (-not $ConfigDir) {
    if ($env:OPENCODE_CONFIG_DIR) {
        $ConfigDir = $env:OPENCODE_CONFIG_DIR
    }
    else {
        $ConfigDir = Join-Path (Get-HomeDir) ".config\opencode"
    }
}
elseif ($ConfigDir -eq "~" -or $ConfigDir -like "~/*" -or $ConfigDir -like "~\*") {
    $HomeDir = Get-HomeDir
    if ($ConfigDir -eq "~") {
        $ConfigDir = $HomeDir
    }
    else {
        $ConfigDir = Join-Path $HomeDir $ConfigDir.Substring(2)
    }
}

$ConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)

$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) {
    throw "Could not determine the repository root. Clone the repository and run the script from that folder."
}

$SkillSource = Join-Path $RepoRoot "skill\claude-reflect"
$CommandsSource = Join-Path $RepoRoot "commands"
$CommandNames = @(
    "reflect.md",
    "reflect-skills.md",
    "skip-reflect.md",
    "view-queue.md"
)

$RequiredSource = @(
    (Join-Path $SkillSource "SKILL.md"),
    (Join-Path $SkillSource "scripts\recent-sessions.mjs"),
    (Join-Path $RepoRoot "LICENSE"),
    (Join-Path $RepoRoot "NOTICE")
)
foreach ($Name in $CommandNames) {
    $RequiredSource += (Join-Path $CommandsSource $Name)
}

foreach ($Path in $RequiredSource) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Repository content is incomplete: missing $Path"
    }
}

$SkillText = [System.IO.File]::ReadAllText((Join-Path $SkillSource "SKILL.md"))
if ($SkillText -notmatch "(?m)^name:\s*claude-reflect\s*$") {
    throw "skill/claude-reflect/SKILL.md does not declare 'name: claude-reflect'."
}
if ($SkillText -notmatch "(?m)^description:\s*\S") {
    throw "skill/claude-reflect/SKILL.md has no description, so OpenCode will not advertise it."
}

$SkillsDir = Join-Path $ConfigDir "skills"
$SkillTarget = Join-Path $SkillsDir "claude-reflect"
$CommandsTarget = Join-Path $ConfigDir "commands"
$QueuePath = Join-Path $ConfigDir "reflect-queue.json"

$Conflicts = @()
if (Test-Path -LiteralPath $SkillTarget) {
    $Conflicts += $SkillTarget
}
foreach ($Name in $CommandNames) {
    $Candidate = Join-Path $CommandsTarget $Name
    if (Test-Path -LiteralPath $Candidate) {
        $Conflicts += $Candidate
    }
}

if ($Conflicts.Count -gt 0 -and -not $Force) {
    Write-Warn "claude-reflect is already installed, or a target file already exists:"
    foreach ($Conflict in $Conflicts) {
        Write-Host "    $Conflict"
    }
    Write-Host "    Re-run with -Force to replace the claude-reflect skill and its four commands."
    Write-Host "    Files outside skills/claude-reflect and the four named commands are never touched."
    exit 1
}

if ($Force -and (Test-Path -LiteralPath $SkillTarget)) {
    Write-Step "Removing the existing skill at $SkillTarget"
    Remove-Item -LiteralPath $SkillTarget -Recurse -Force
}

Write-Step "Installing the skill to $SkillTarget"
New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $SkillSource "SKILL.md") -Destination (Join-Path $SkillTarget "SKILL.md") -Force
Copy-Item -LiteralPath (Join-Path $SkillSource "scripts") -Destination $SkillTarget -Recurse -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "LICENSE") -Destination (Join-Path $SkillTarget "LICENSE") -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "NOTICE") -Destination (Join-Path $SkillTarget "NOTICE") -Force

Write-Step "Installing commands to $CommandsTarget"
New-Item -ItemType Directory -Path $CommandsTarget -Force | Out-Null
foreach ($Name in $CommandNames) {
    Copy-Item -LiteralPath (Join-Path $CommandsSource $Name) -Destination (Join-Path $CommandsTarget $Name) -Force
}

if (Test-Path -LiteralPath $QueuePath) {
    Write-Host "    Keeping the existing queue: $QueuePath"
}
else {
    Write-Step "Creating an empty queue at $QueuePath"
    $QueueJson = "{`n  `"version`": 1,`n  `"items`": []`n}`n"
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($QueuePath, $QueueJson, $Utf8NoBom)
}

$RequiredInstalled = @(
    (Join-Path $SkillTarget "SKILL.md"),
    (Join-Path $SkillTarget "scripts\recent-sessions.mjs"),
    (Join-Path $SkillTarget "LICENSE"),
    (Join-Path $SkillTarget "NOTICE")
)
foreach ($Name in $CommandNames) {
    $RequiredInstalled += (Join-Path $CommandsTarget $Name)
}
foreach ($Path in $RequiredInstalled) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Installation is incomplete: missing $Path"
    }
}

$FileCount = (Get-ChildItem -LiteralPath $SkillTarget -Recurse -File).Count
Write-Ok "Installed the claude-reflect skill ($FileCount files) and 4 commands."
Write-Host ""
Write-Host "Start a new OpenCode session, then:" -ForegroundColor Green
Write-Host '  - say "remember: use pnpm, not npm" or correct the agent during work'
Write-Host "  - run /view-queue to inspect the queue"
Write-Host "  - run /reflect --dry-run to preview, then /reflect to apply"
Write-Host ""
Write-Host "Learnings are written to a marked section of AGENTS.md."
Write-Host "Queue: $QueuePath"
Write-Host "Upstream inspiration and license: https://github.com/BayramAnnakov/claude-reflect"
