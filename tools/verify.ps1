# verify.ps1 - Run RiftDuel headless verification.
# Usage: powershell -ExecutionPolicy Bypass -File tools/verify.ps1
# Exit code: 0 = all passed, 1 = at least one failed.
# Override the Godot binary with the GODOT_BIN environment variable.

param([ValidateRange(1, 900)][int]$CaseTimeoutSeconds = 300)

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
$EvidenceDirectory = Join-Path $ProjectRoot (".godot\verify-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null

function Invoke-GodotVerification {
    param([string[]]$GodotArguments, [string]$CaseName)
    $OutputLog = Join-Path $EvidenceDirectory ($CaseName + ".stdout.log")
    $ErrorLog = Join-Path $EvidenceDirectory ($CaseName + ".stderr.log")
    $EngineLog = Join-Path $EvidenceDirectory ($CaseName + ".engine.log")
    $CaseProcess = Start-Process -FilePath $Godot -ArgumentList ($GodotArguments + @("--log-file", $EngineLog)) `
        -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $OutputLog -RedirectStandardError $ErrorLog
    [void]$CaseProcess.Handle
    $TimedOut = -not $CaseProcess.WaitForExit($CaseTimeoutSeconds * 1000)
    if ($TimedOut) {
        $CaseProcess.Kill()
    }
    $CaseProcess.WaitForExit()
    Get-Content -LiteralPath $OutputLog | ForEach-Object { Write-Host $_ }
    Get-Content -LiteralPath $ErrorLog | ForEach-Object { Write-Host $_ }
    if ($TimedOut) {
        Write-Host "[FAIL] ${CaseName}: exceeded ${CaseTimeoutSeconds}s; owned process stopped." -ForegroundColor Red
        return 124
    }
    if ($CaseProcess.ExitCode -eq 0 -and (Select-String -LiteralPath @($OutputLog, $ErrorLog) -Pattern "SCRIPT ERROR|(^|\s)ERROR:|Parse Error|Failed to load script|Failed to load resource" -Quiet)) {
        Write-Host "[FAIL] ${CaseName}: Godot exited 0 with error logs." -ForegroundColor Red
        return 1
    }
    return $CaseProcess.ExitCode
}

Write-Host "Godot:   $Godot"
Write-Host "Project: $ProjectRoot"
Write-Host "Evidence: $EvidenceDirectory"
Write-Host ""

Write-Host "[SCAN] project resources and global classes" -ForegroundColor Cyan
$ImportCode = Invoke-GodotVerification -GodotArguments @("--headless", "--path", $ProjectRoot, "--import") -CaseName "scan"
if ($ImportCode -ne 0) {
    Write-Host "[FAIL] project import scan (exit code $ImportCode)" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] project import scan" -ForegroundColor Green
Write-Host ""

Write-Host "[RUN ] main scene smoke test" -ForegroundColor Cyan
$SceneCode = Invoke-GodotVerification -GodotArguments @("--headless", "--path", $ProjectRoot, "--quit-after", "3") -CaseName "smoke"
if ($SceneCode -ne 0) {
    Write-Host "[FAIL] main scene smoke test (exit code $SceneCode)" -ForegroundColor Red
    exit 1
}
Write-Host "[PASS] main scene smoke test" -ForegroundColor Green
Write-Host ""

$Suites = @("tools/test_swire_skills.gd", "tools/test_swire_skill_view.gd", "tools/test_swire_skill_network.gd", "tools/test_saileach_skills.gd", "tools/test_saileach_skill_view.gd", "tools/test_saileach_skill_network.gd", "tools/test_ceobe_skill_view.gd", "tools/test_ceobe_skill_network.gd", "tools/test_silence.gd", "tools/test_ceobe_priority.gd", "tools/test_silence_view.gd", "tools/test_phantom_skills.gd", "tools/test_phantom_skill_view.gd", "tools/test_phantom_skill_network.gd", "tools/test_angelina_skills.gd", "tools/test_angelina_skill_view.gd", "tools/test_angelina_skill_network.gd", "tools/test_horn_skills.gd", "tools/test_horn_skill_view.gd", "tools/test_horn_skill_network.gd", "tools/test_displacement.gd", "tools/test_displacement_view.gd", "tools/test_displacement_network.gd", "tools/test_nightingale_skills.gd", "tools/test_nightingale_skill_view.gd", "tools/test_nightingale_skill_network.gd", "tools/test_eyjafjalla_skills.gd", "tools/test_eyjafjalla_skill_view.gd", "tools/test_eyjafjalla_skill_network.gd", "tools/test_hoshiguma_skills.gd", "tools/test_hoshiguma_skill_view.gd", "tools/test_hoshiguma_skill_network.gd", "tools/test_arena.gd", "tools/test_ranges.gd", "tools/test_facing.gd", "tools/test_damage.gd", "tools/test_skills.gd", "tools/test_passive_heal.gd", "tools/test_passive_heal_view.gd", "tools/test_skill_view.gd", "tools/test_deploy_view.gd", "tools/test_mirror_view.gd", "tools/test_enemy_view.gd", "tools/test_info_view.gd", "tools/test_settings.gd", "tools/test_start_menu.gd", "tools/test_pause_menu.gd", "tools/test_match_end.gd", "tools/test_result_view.gd", "tools/test_net_session.gd", "tools/test_net_lockstep.gd", "tools/test_room_view.gd", "tools/sim_match.gd")
$Suites += @("tools/test_talents.gd", "tools/test_phantom_view.gd", "tools/test_balance.gd")
$Suites += @("tools/test_squad.gd", "tools/test_exusiai_skills.gd", "tools/test_exusiai_skill_view.gd", "tools/test_skill_loadout_network.gd")
$Suites += @("tools/test_squad_menu.gd")
$Suites += @("tools/test_shining.gd")
$Suites += @("tools/test_shining_network.gd")
$Suites += @("tools/test_silverash.gd", "tools/test_silverash_network.gd")
$Suites += @("tools/test_eyjafjalla.gd", "tools/test_eyjafjalla_network.gd")
$Suites += @("tools/test_suzuran.gd", "tools/test_suzuran_network.gd")
$Suites += @("tools/test_saileach.gd", "tools/test_saileach_view.gd", "tools/test_saileach_network.gd")
$Suites += @("tools/test_horn.gd", "tools/test_horn_view.gd", "tools/test_horn_network.gd")
$Suites += @("tools/test_schwarz.gd", "tools/test_schwarz_network.gd", "tools/test_schwarz_skills.gd", "tools/test_schwarz_skill_view.gd", "tools/test_schwarz_skill_network.gd")
$Suites += @("tools/test_phantom.gd", "tools/test_phantom_network.gd", "tools/test_phantom_clone_view.gd")
$Suites += @("tools/test_suzuran_skills.gd", "tools/test_shining_skills.gd", "tools/test_blaze_skills.gd")
$Suites += @("tools/test_three_skill_view.gd")
$Suites += @("tools/test_three_skill_network.gd")
$Suites += @("tools/test_silverash_skills.gd", "tools/test_silverash_skill_view.gd", "tools/test_silverash_skill_network.gd")
$Suites += @("tools/test_bagpipe_skills.gd", "tools/test_bagpipe_skill_view.gd", "tools/test_bagpipe_skill_network.gd")
$Suites += @("tools/test_tactical_boxes.gd", "tools/test_tactical_boxes_view.gd")
$Suites += @("tools/test_tactical_items.gd", "tools/test_tactical_items_network.gd")
$Suites += @("tools/test_tactical_items_input.gd", "tools/test_arena_projection.gd")
$Suites += @("tools/test_bagpipe_visual.gd", "tools/test_exusiai_visual.gd", "tools/test_operator_spine_visual.gd", "tools/test_operator_animation_selection.gd", "tools/test_operator_cards.gd", "tools/test_battle_layout.gd", "tools/test_battle_ui.gd", "tools/test_pace.gd", "tools/test_visual_cues.gd", "tools/test_battle_depth.gd")
$Suites += @("tools/test_battle_info.gd")
$Suites += @("tools/test_resource_validation.gd")
$Suites += @("tools/test_skadi.gd", "tools/test_skadi_view.gd", "tools/test_skadi_network.gd")
$Failed = @()
$Suites += @("tools/test_audio_menu.gd")
$Suites += @("tools/test_battle_audio.gd")
$Suites += @("tools/test_room_return.gd")

foreach ($Suite in $Suites) {
    if (-not (Test-Path -LiteralPath $Suite)) {
        Write-Host "[FAIL] $Suite (required suite missing)" -ForegroundColor Red
        $Failed += $Suite
        continue
    }

    Write-Host "[RUN ] $Suite" -ForegroundColor Cyan
    $Code = Invoke-GodotVerification -GodotArguments @("--headless", "--path", $ProjectRoot, "--script", $Suite) -CaseName (Split-Path -Leaf $Suite)

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
