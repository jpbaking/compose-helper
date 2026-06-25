# Author: jpbaking (https://github.com/jpbaking)
#
# Thin wrapper around docker compose for PowerShell.
# Must live alongside docker-compose.yaml. Mirrors compose-helper (bash).
#
# WARNING: Intended for local development use only. Do not use in production
# or CI/CD pipelines without careful review -- 'down' removes volumes, env
# files are loaded into the process, and there is no dry-run mode.
#
# USAGE: .\compose-helper.ps1 <command> [args]
# If blocked by execution policy, run once:
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# $PSScriptRoot is the directory containing this script (PowerShell 3+).
# Symlink resolution is not automatic; place the script directly in the
# project directory for reliable behaviour.
$ScriptDir  = $PSScriptRoot
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

Set-Location $ScriptDir

# Prefer v2 plugin ("docker compose") over standalone v1 binary.
$DC = $null
$null = docker compose version 2>&1
if ($LASTEXITCODE -eq 0) {
    $DC = @("docker", "compose")
} elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $DC = @("docker-compose")
} else {
    Write-Error "neither 'docker compose' nor 'docker-compose' found"
    exit 1
}

# Find compose file.
if (Test-Path "docker-compose.yaml") {
    $ComposeFile = "docker-compose.yaml"
} elseif (Test-Path "docker-compose.yml") {
    $ComposeFile = "docker-compose.yml"
} else {
    Write-Error "no docker-compose.yaml or docker-compose.yml found in $ScriptDir"
    exit 1
}

# Load (script_name).env -- configures DCH itself; overrides caller environment.
# Blank lines and lines beginning with # are skipped.
$ConfigFile = "$ScriptName.env"
if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process')
        }
    }
}

$ProjectName = if ($env:DCH_PROJECT_NAME) { $env:DCH_PROJECT_NAME } else { Split-Path -Leaf $ScriptDir }
$StopTimeout = if ($env:DCH_STOP_TIMEOUT) { $env:DCH_STOP_TIMEOUT } else { "30" }
$LogsTail    = if ($env:DCH_LOGS_TAIL)    { $env:DCH_LOGS_TAIL    } else { "10" }

# Base args applied to every docker compose invocation.
$DcOpts = @("-p", $ProjectName, "-f", $ComposeFile)

# .env is passed to docker compose for container variable substitution.
if (Test-Path ".env") {
    $DcOpts += @("--env-file", ".env")
} elseif (Test-Path ".config/.env") {
    $DcOpts += @("--env-file", ".config/.env")
}

function Invoke-DC {
    $extra = $args
    $full  = @()
    if ($DC.Count -gt 1) { $full += $DC[1..($DC.Count - 1)] }
    $full += $DcOpts
    if ($extra) { $full += $extra }
    & $DC[0] @full
}

function Show-Usage {
    Write-Host @"
Usage: $ScriptName <command> [args]

Commands:
  up       Rebuild, start detached, then follow logs
  rebuild  Rebuild, start detached
  build    Rebuild only (no start)
  pull     Pull images
  start    Start detached (no pull/build)
  restart  Stop then start detached (no pull/build)
  stop     Stop with ${StopTimeout}s timeout, remove orphans
  down     Stop with ${StopTimeout}s timeout, remove orphans and volumes
  logs     Follow logs from last ${LogsTail} lines
  <other>  Pass arguments directly to docker compose

Environment (set in ${ConfigFile}):
  DCH_PROJECT_NAME  Override project name (default: directory name)
  DCH_STOP_TIMEOUT  Shutdown timeout in seconds (default: 30)
  DCH_LOGS_TAIL     Log tail line count (default: 10)

Project: $ProjectName  Compose: $ComposeFile
"@
}

# Parse command from $args (no param block so --help is not misread as a flag).
$Command   = if ($args.Count -gt 0) { [string]$args[0] } else { "" }
$Remaining = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($Command.ToLower()) {
    { $_ -in @("", "--help") } {
        Show-Usage
    }
    "up" {
        Invoke-DC --profile build build --pull
        Invoke-DC up -d
        Invoke-DC logs -f "--tail=$LogsTail"
    }
    "start" {
        Invoke-DC up -d
    }
    "pull" {
        Invoke-DC pull
    }
    "build" {
        Invoke-DC --profile build build --pull
    }
    "rebuild" {
        Invoke-DC --profile build build --pull
        Invoke-DC up -d
    }
    "restart" {
        Invoke-DC down -t $StopTimeout --remove-orphans
        Invoke-DC up -d
    }
    "stop" {
        Invoke-DC down -t $StopTimeout --remove-orphans
    }
    "down" {
        Invoke-DC down -t $StopTimeout --remove-orphans -v
    }
    "logs" {
        Invoke-DC logs -f "--tail=$LogsTail"
    }
    default {
        Invoke-DC $Command @Remaining
    }
}
