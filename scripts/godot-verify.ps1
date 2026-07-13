$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$GodotProject = Join-Path $RepoRoot "godot"

function Find-GodotConsole {
    foreach ($commandName in @("godot_console", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    $wingetPackages = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetPackages) {
        $candidate = Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter "GodotEngine.GodotEngine_*" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue
            } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($null -ne $candidate) {
            return $candidate.FullName
        }
    }

    throw "Godot 4 console executable was not found. Install Godot 4.7+ or add godot_console to PATH."
}

function Invoke-GodotCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,
        [Parameter(Mandatory = $true)]
        [string[]] $GodotArguments
    )

    Write-Host "`n[$Label]"
    $output = & $script:GodotExe @GodotArguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $rendered = $output -join "`n"
    if ($exitCode -ne 0 -or $rendered -match "(?m)^(SCRIPT ERROR|ERROR:)") {
        throw "$Label failed (exit $exitCode)."
    }
}

$script:GodotExe = Find-GodotConsole
Write-Host "Using Godot: $script:GodotExe"

Invoke-GodotCheck -Label "Parse project" -GodotArguments @(
    "--headless", "--path", $GodotProject, "--editor", "--quit"
)
Invoke-GodotCheck -Label "Rules smoke" -GodotArguments @(
    "--headless", "--path", $GodotProject, "--script", "res://scripts/game/rules_smoke_test.gd"
)
Invoke-GodotCheck -Label "Integration smoke" -GodotArguments @(
    "--headless", "--path", $GodotProject, "--script", "res://tests/integration_smoke_test.gd"
)
Invoke-GodotCheck -Label "Main flow smoke" -GodotArguments @(
    "--headless", "--path", $GodotProject, "--script", "res://tests/main_flow_smoke_test.gd"
)

$engineSmoke = Join-Path $GodotProject "scripts\engine\engine_smoke_test.gd"
if (Test-Path -LiteralPath $engineSmoke) {
    Invoke-GodotCheck -Label "Engine smoke" -GodotArguments @(
        "--headless", "--path", $GodotProject, "--script", "res://scripts/engine/engine_smoke_test.gd"
    )
}

Invoke-GodotCheck -Label "Main scene smoke" -GodotArguments @(
    "--headless", "--path", $GodotProject, "--quit-after", "3"
)

Write-Host "`nGODOT_VERIFY_OK"
