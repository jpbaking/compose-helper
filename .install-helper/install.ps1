# Github: https://github.com/jpbaking/compose-helper
# Installs compose-helper.ps1 into the current directory.
# Run from inside your project directory (alongside docker-compose.yaml):
#   irm https://raw.githubusercontent.com/jpbaking/compose-helper/main/.install-helper/install.ps1 | iex

$ErrorActionPreference = "Stop"

$Base           = "https://raw.githubusercontent.com/jpbaking/compose-helper/main"
$Script         = "compose-helper.ps1"
$EnvFile        = "compose-helper.env"
$EnvExampleUrl  = "$Base/compose-helper.env.example"

Write-Host "==> Downloading $Script..."
Invoke-WebRequest "$Base/$Script" -OutFile $Script
Write-Host "    OK"

Write-Host "==> Checking $EnvFile..."
$TempExample = [System.IO.Path]::GetTempFileName()
try {
    Invoke-WebRequest $EnvExampleUrl -OutFile $TempExample

    if (-not (Test-Path $EnvFile)) {
        Copy-Item $TempExample $EnvFile
        Write-Host "    Created $EnvFile"
    } else {
        # Extract key names from the example, handling both active and commented-out keys.
        $exampleKeys = Get-Content $TempExample | ForEach-Object {
            if ($_ -match '^\s*#?\s*([A-Za-z_][A-Za-z0-9_]*)\s*=') { $Matches[1] }
        }

        $existingContent = Get-Content $EnvFile -Raw
        $newKeys = $exampleKeys | Where-Object {
            $_ -and ($existingContent -notmatch "(?m)^\s*#?\s*$([regex]::Escape($_))\s*=")
        }

        if ($newKeys) {
            Write-Host "    $EnvFile already exists -- not overwritten."
            Write-Host "    New keys in the latest example missing from your ${EnvFile}:"
            $newKeys | ForEach-Object { Write-Host "      $_" }
            Write-Host "    See $EnvExampleUrl to add them manually."
        } else {
            Write-Host "    $EnvFile is up to date -- not overwritten."
        }
    }
} finally {
    Remove-Item $TempExample -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Run: .\$Script --help"
