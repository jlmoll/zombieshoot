param([string]$Godot)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) {
        $Godot = $installed.Source
    } else {
        $Godot = Join-Path $projectRoot '.godot/test-engine/Godot_v4.7.2-stable_win64_console.exe'
    }
}
if (-not (Test-Path -LiteralPath $Godot)) {
    throw 'Provide the Godot 4.7 executable with -Godot <absolute path>.'
}
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$qaRoot = Join-Path $projectRoot '.godot/qa'
New-Item -ItemType Directory -Force -Path $qaRoot | Out-Null

function Invoke-GodotCheck([string]$Name, [string[]]$Options, [bool]$NeedsPass = $true) {
    $logPath = Join-Path $qaRoot ($Name + '.log')
    $engineArgs = @('--headless', '--path', $projectRoot, '--log-file', $logPath) + $Options
    $output = & $Godot @engineArgs 2>&1
    $engineExit = $LASTEXITCODE
    $output | Out-Host
    $text = $output -join "`n"
    if ($engineExit -ne 0 -or $text -cmatch '(?m)^(SCRIPT ERROR|ERROR:)|^[A-Z][A-Z ]* FAILED\b|instances were leaked') {
        throw "${Name} failed; see $logPath"
    }
    if ($NeedsPass -and $text -notmatch 'PASSED') {
        throw "${Name} ended without a success marker; see $logPath"
    }
}

$previousAppData = $env:APPDATA
try {
    # Isolate engine caches and persistence from the user's actual game profile.
    $env:APPDATA = Join-Path $qaRoot 'user'
    $profileDir = Join-Path $env:APPDATA 'Godot/app_userdata/Dead Shift — Contención'
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    $fixtureSave = Join-Path $profileDir 'dead_shift.cfg'
    if (-not (Test-Path -LiteralPath $fixtureSave)) {
        Set-Content -LiteralPath $fixtureSave -Encoding utf8NoBOM -Value "[run]`nbest=12345`n`n[settings]`nmuted=true`n"
    }
    Invoke-GodotCheck 'import' @('--editor', '--quit') $false
    $suites = @(
        'actors/health_component', 'actors/health', 'actors/cursor_projection',
        'perks/perks', 'combat/projectiles', 'rewards/run_rewards', 'waves/run_wave_tests',
        'weapons/weapons', 'weapons/chainsaw', 'input/input_profiles', 'enemies/enemies',
        'enemies/enemy_animation', 'enemies/enemy_model_fidelity',
        'player/player_presentation', 'player/player_model_fidelity', 'integration'
    )
    foreach ($suite in $suites) {
        Invoke-GodotCheck ($suite.Replace('/', '-')) @('--fixed-fps', '60', '--script', "tests/$suite.gd")
    }
    Invoke-GodotCheck 'smoke' @('--fixed-fps', '60', '--', '--smoke-test')
    Write-Host "ALL TESTS PASSED: $($suites.Count + 1) suites plus editor import. Logs: $qaRoot"
} finally {
    $env:APPDATA = $previousAppData
}

