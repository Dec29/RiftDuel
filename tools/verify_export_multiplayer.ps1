param([switch]$Graphics)
$ErrorActionPreference = "Stop"
$Godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$QaDirectory = Join-Path $ProjectRoot ".godot\export-qa"
$QaExecutable = Join-Path $QaDirectory "RiftDuel-QA.exe"
New-Item -ItemType Directory -Path $QaDirectory -Force | Out-Null
$Export = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", $ProjectRoot, "--export-debug", "WindowsQA", $QaExecutable) -NoNewWindow -Wait -PassThru
if ($Export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $QaExecutable)) {
    Write-Host "EXPORTED MULTIPLAYER FAILED: QA export failed." -ForegroundColor Red
    exit 1
}
$Verifier = Join-Path $ProjectRoot "tools\verify_multiplayer.ps1"
$Cases = @(
    @{ Arguments = @("-Mode", "battle", "-Port", "24820") },
    @{ Arguments = @("-Mode", "battle", "-DelayMs", "200", "-Port", "24830") },
    @{ Arguments = @("-Mode", "endurance", "-Ticks", "9000", "-Port", "24840") }
)
foreach ($Case in $Cases) {
    $Arguments = @("-ExecutionPolicy", "Bypass", "-File", $Verifier, "-Executable", $QaExecutable) + $Case.Arguments
    if ($Graphics) { $Arguments += "-Graphics" }
    $Process = Start-Process -FilePath "powershell" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    if ($Process.ExitCode -ne 0) {
        Write-Host "EXPORTED MULTIPLAYER FAILED: one acceptance case failed." -ForegroundColor Red
        exit 1
    }
}
Write-Host "EXPORTED MULTIPLAYER OK: complete battle, 200ms delay and 9000-tick endurance." -ForegroundColor Green
exit 0
