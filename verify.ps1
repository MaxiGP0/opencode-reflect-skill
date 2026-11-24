#Requires -Version 5.1
<#
.SYNOPSIS
    Check that the claude-reflect OpenCode port is installed correctly.

.PARAMETER ConfigDir
    OpenCode config root. Defaults to $env:OPENCODE_CONFIG_DIR, or
    ~/.config/opencode.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify.ps1

.EXAMPLE
    .\verify.ps1 -ConfigDir "C:\temp\opencode-config"
#>
[CmdletBinding()]
param(
    [string]$ConfigDir
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host "FAIL  $Message" -ForegroundColor Red
    exit 1
}

function Get-HomeDir {
    if ($HOME) { return $HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    Fail "Could not find your home directory. Pass -ConfigDir explicitly."
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
$SkillTarget = Join-Path $ConfigDir "skills\claude-reflect"
$CommandsTarget = Join-Path $ConfigDir "commands"
$QueuePath = Join-Path $ConfigDir "reflect-queue.json"

$CommandNames = @(
    "reflect.md",
    "reflect-skills.md",
    "skip-reflect.md",
    "view-queue.md"
)

$Required = @(
    (Join-Path $SkillTarget "SKILL.md")
)
foreach ($Name in $CommandNames) {
    $Required += (Join-Path $CommandsTarget $Name)
}

$Missing = @()
foreach ($Path in $Required) {
    if (-not (Test-Path -LiteralPath $Path)) {
        $Missing += $Path
    }
}

if ($Missing.Count -gt 0) {
    Write-Host "FAIL  The installation is incomplete. Missing:" -ForegroundColor Red
    foreach ($Path in $Missing) {
        Write-Host "      - $Path"
    }
    Write-Host "      Run install.ps1 first, or install.ps1 -Force to repair." -ForegroundColor Yellow
    exit 1
}

$SkillPath = Join-Path $SkillTarget "SKILL.md"
$SkillText = [System.IO.File]::ReadAllText($SkillPath)

if ($SkillText -notmatch "(?m)^name:\s*claude-reflect\s*$") {
    Fail "SKILL.md does not declare 'name: claude-reflect'."
}
if ($SkillText -notmatch "(?m)^description:\s*\S") {
    Fail "SKILL.md has no description, so OpenCode will not advertise the skill."
}
foreach ($Path in $Required) {
    if ($Path -eq $SkillPath) { continue }
    $Text = [System.IO.File]::ReadAllText($Path)
    if ($Text -notmatch "(?m)^description:\s*\S") {
        Fail "$(Split-Path -Leaf $Path) has no 'description' frontmatter."
    }
}

$CheckFiles = @($SkillPath)
$OptionalSkillFiles = @(
    (Join-Path $SkillTarget "LICENSE"),
    (Join-Path $SkillTarget "NOTICE"),
    (Join-Path $SkillTarget "scripts\recent-sessions.mjs")
)
foreach ($Path in $OptionalSkillFiles) {
    if (Test-Path -LiteralPath $Path) {
        $CheckFiles += $Path
    }
}
foreach ($Name in $CommandNames) {
    $CheckFiles += (Join-Path $CommandsTarget $Name)
}

$Forbidden = @("~/.claude", "CLAUDE.md", "hooks.json")
foreach ($Path in $CheckFiles) {
    $Text = [System.IO.File]::ReadAllText($Path)
    foreach ($Needle in $Forbidden) {
        if ($Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Fail "Forbidden reference '$Needle' found in $Path"
        }
    }
}

if ($SkillText.IndexOf("reflect-queue.json", [System.StringComparison]::Ordinal) -lt 0) {
    Fail "SKILL.md does not document the queue path (reflect-queue.json)."
}
$ReflectText = [System.IO.File]::ReadAllText((Join-Path $CommandsTarget "reflect.md"))
if ($ReflectText.IndexOf("reflect-queue.json", [System.StringComparison]::Ordinal) -lt 0) {
    Fail "commands/reflect.md does not document the queue path (reflect-queue.json)."
}

foreach ($Marker in @("claude-reflect:start", "claude-reflect:end")) {
    if ($SkillText.IndexOf($Marker, [System.StringComparison]::Ordinal) -lt 0) {
        Fail "SKILL.md does not document the AGENTS.md marker '$Marker'."
    }
    if ($ReflectText.IndexOf($Marker, [System.StringComparison]::Ordinal) -lt 0) {
        Fail "commands/reflect.md does not document the AGENTS.md marker '$Marker'."
    }
}

if (Test-Path -LiteralPath $QueuePath) {
    try {
        $QueueText = [System.IO.File]::ReadAllText($QueuePath)
        $Queue = $QueueText | ConvertFrom-Json
    }
    catch {
        Fail "The queue file is not valid JSON: $QueuePath"
    }
    if ($null -eq $Queue.version -or $null -eq $Queue.items) {
        Fail "The queue file does not match schema version 1: $QueuePath"
    }
}
else {
    Write-Host "Note: no queue file yet at $QueuePath. Installer normally creates it." -ForegroundColor Yellow
}

$FileCount = (Get-ChildItem -LiteralPath $SkillTarget -Recurse -File).Count
Write-Host "OK  claude-reflect is installed at $SkillTarget ($FileCount skill files, 4 commands)." -ForegroundColor Green
Write-Host "    Queue: $QueuePath"
Write-Host "    AGENTS.md markers: <!-- claude-reflect:start --> / <!-- claude-reflect:end -->"
