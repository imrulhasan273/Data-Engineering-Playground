# git-sync.ps1 -- Pull, stage all, commit with timestamp, push
# Usage: .\git-sync.ps1
#        .\git-sync.ps1 "optional custom message"

param(
    [string]$Message = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Log setup ----------------------------------------------------------------
$logDir  = Join-Path $PSScriptRoot "log"
$logFile = Join-Path $logDir "git-sync_$(Get-Date -Format 'yyyy-MM-dd').log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

function Log([string]$level, [string]$text) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$level] $text"
    Add-Content -Path $logFile -Value $line
    switch ($level) {
        "INFO"  { Write-Host $line -ForegroundColor Cyan }
        "OK"    { Write-Host $line -ForegroundColor Green }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        "ERROR" { Write-Host $line -ForegroundColor Red }
    }
}

# --- Git identity -------------------------------------------------------------
git config user.email "imrulhasan273@gmail.com"
git config user.name  "imrulhasan273"

# --- Commit message -----------------------------------------------------------
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$commitMsg = if ($Message) { "$Message [$timestamp]" } else { $timestamp }

Log INFO "======================================"
Log INFO "  Git Sync started"
Log INFO "  Log: $logFile"
Log INFO "======================================"

# --- 1. Pull ------------------------------------------------------------------
Log INFO "[1/4] Pulling latest changes..."
$pullOut = git pull 2>&1
Add-Content -Path $logFile -Value ($pullOut | Out-String)
if ($LASTEXITCODE -ne 0) {
    Log ERROR "git pull failed: $pullOut"
    exit 1
}
Log OK "Pull OK"

# --- 2. Stage all -------------------------------------------------------------
Log INFO "[2/4] Staging all changes..."
$addOut = git add . 2>&1
Add-Content -Path $logFile -Value ($addOut | Out-String)
Log OK "Staged"

# --- 3. Commit ----------------------------------------------------------------
Log INFO "[3/4] Committing: '$commitMsg'"
$porcelain = git status --porcelain
if (-not $porcelain) {
    Log WARN "Nothing to commit - working tree clean."
} else {
    $commitOut = git commit -m $commitMsg 2>&1
    Add-Content -Path $logFile -Value ($commitOut | Out-String)
    if ($LASTEXITCODE -ne 0) {
        Log ERROR "git commit failed: $commitOut"
        exit 1
    }
    Log OK "Committed: $commitMsg"
}

# --- 4. Push ------------------------------------------------------------------
Log INFO "[4/4] Pushing..."
$pushOut = git push 2>&1
Add-Content -Path $logFile -Value ($pushOut | Out-String)
if ($LASTEXITCODE -ne 0) {
    Log ERROR "git push failed: $pushOut"
    exit 1
}
Log OK "Pushed"

Log INFO "======================================"
Log OK "  Done: $commitMsg"
Log INFO "======================================"
