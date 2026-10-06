# verify.ps1 - Run RiftDuel headless verification.
# Usage: powershell -ExecutionPolicy Bypass -File tools/verify.ps1
# Exit code: 0 = all passed, 1 = at least one failed.
# Override the Godot binary with the GODOT_BIN environment variable.

$ErrorActionPreference = "Stop"

$Godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}

if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host "Godot binary not found: $Godot" -ForegroundColor Red
    Write-Host "Set GODOT_BIN to the full path of the Godot editor executable." -ForegroundColor Yellow
    exit 1
}

# Locate project root relative to this script.
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location -LiteralPath $ProjectRoot

Write-Host "Godot:   $Godot"
Write-Host "Project: $ProjectRoot"
Write-Host ""

Write-Host "[SCAN] project resources and global classes" -ForegroundColor Cyan
$ImportProcess = Start-Process -FilePath $Godot `
    -ArgumentList @("--headless", "--path", $ProjectRoot, "--import") `
    -NoNewWindow -Wait -PassThru
if ($ImportProcess.ExitCode -ne 0) {
    Write-Host "[FAIL] project import scan (exit code $($ImportProcess.ExitCode))" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] project import scan" -ForegroundColor Green
Write-Host ""

Write-Host "[RUN ] main scene smoke test" -ForegroundColor Cyan
$SceneProcess = Start-Process -FilePath $Godot `
    -ArgumentList @("--headless", "--path", $ProjectRoot, "--quit-after", "3") `
    -NoNewWindow -Wait -PassThru
if ($SceneProcess.ExitCode -ne 0) {
    Write-Host "[FAIL] main scene smoke test (exit code $($SceneProcess.ExitCode))" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] main scene smoke test" -ForegroundColor Green
Write-Host ""

$Suites = @("tools/test_arena.gd", "tools/test_ranges.gd", "tools/test_facing.gd", "tools/test_damage.gd", "tools/test_skills.gd", "tools/test_passive_heal.gd", "tools/test_passive_heal_view.gd", "tools/test_skill_view.gd", "tools/test_deploy_view.gd", "tools/test_mirror_view.gd", "tools/test_enemy_view.gd", "tools/test_info_view.gd", "tools/test_settings.gd", "tools/test_start_menu.gd", "tools/test_pause_menu.gd", "tools/test_match_end.gd", "tools/test_result_view.gd", "tools/test_net_session.gd", "tools/test_net_lockstep.gd", "tools/test_room_view.gd", "tools/sim_match.gd")
$Suites += @("tools/test_talents.gd", "tools/test_phantom_view.gd", "tools/test_balance.gd")
$Failed = @()

foreach ($Suite in $Suites) {
    if (-not (Test-Path -LiteralPath $Suite)) {
        Write-Host "[SKIP] $Suite (not present yet)" -ForegroundColor Yellow
        continue
    }

    Write-Host "[RUN ] $Suite" -ForegroundColor Cyan
    $Process = Start-Process -FilePath $Godot `
        -ArgumentList @("--headless", "--path", $ProjectRoot, "--script", $Suite) `
        -NoNewWindow -Wait -PassThru
    $Code = $Process.ExitCode

    if ($Code -eq 0) {
        Write-Host "[PASS] $Suite" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Suite (exit code $Code)" -ForegroundColor Red
        $Failed += $Suite
    }
    Write-Host ""
}

if ($Failed.Count -gt 0) {
    Write-Host "VERIFY FAILED: $($Failed -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "VERIFY OK" -ForegroundColor Green
exit 0
