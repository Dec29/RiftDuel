param(
    [string]$OutputDirectory = ""
)
$ErrorActionPreference = "Stop"
$Godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot "build\RiftDuel"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$Executable = Join-Path $OutputDirectory "RiftDuel.exe"
$Package = Join-Path $OutputDirectory "RiftDuel.pck"
$Log = Join-Path $OutputDirectory "smoke.log"
$Archive = Join-Path (Split-Path -Parent $OutputDirectory) "RiftDuel-windows-x86_64.zip"
$ExportTimeoutMilliseconds = 180000
$SmokeTimeoutMilliseconds = 30000
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($GeneratedFile in @($Executable, $Package, $Log, $Archive)) {
    if (Test-Path -LiteralPath $GeneratedFile) { Remove-Item -LiteralPath $GeneratedFile -Force }
}
foreach ($TemporaryExecutable in Get-ChildItem -LiteralPath $OutputDirectory -File -Filter "RiftDuel.exe~*.TMP") {
    Remove-Item -LiteralPath $TemporaryExecutable.FullName -Force
}
$ExportStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$ExportStartInfo.FileName = $Godot
$ExportStartInfo.Arguments = '--headless --path "{0}" --export-release "WindowsDesktop" "{1}"' -f $ProjectRoot, $Executable
$ExportStartInfo.UseShellExecute = $false
$ExportStartInfo.CreateNoWindow = $true
$Export = New-Object System.Diagnostics.Process
$Export.StartInfo = $ExportStartInfo
[void]$Export.Start()
if (-not $Export.WaitForExit($ExportTimeoutMilliseconds)) {
    Write-Host "WINDOWS BUILD FAILED: export exceeded 180 seconds." -ForegroundColor Red
    $Export.Kill()
    [void]$Export.WaitForExit(5000)
    exit 1
}
$Export.WaitForExit()
$ExportExitCode = $Export.ExitCode
if ($ExportExitCode -ne 0) {
    Write-Host "WINDOWS BUILD FAILED: export exited with $ExportExitCode." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $Executable) -or -not (Test-Path -LiteralPath $Package)) {
    Write-Host "WINDOWS BUILD FAILED: export did not produce the executable and PCK." -ForegroundColor Red
    exit 1
}
if ((Get-Item -LiteralPath $Executable).Length -eq 0 -or (Get-Item -LiteralPath $Package).Length -eq 0) {
    Write-Host "WINDOWS BUILD FAILED: exported executable or PCK is empty." -ForegroundColor Red
    exit 1
}
$SmokeStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$SmokeStartInfo.FileName = $Executable
$SmokeStartInfo.Arguments = '--headless --quit-after 3 --log-file "{0}"' -f $Log
$SmokeStartInfo.WorkingDirectory = $OutputDirectory
$SmokeStartInfo.UseShellExecute = $false
$SmokeStartInfo.CreateNoWindow = $true
$Smoke = New-Object System.Diagnostics.Process
$Smoke.StartInfo = $SmokeStartInfo
[void]$Smoke.Start()
if (-not $Smoke.WaitForExit($SmokeTimeoutMilliseconds)) {
    Write-Host "WINDOWS BUILD FAILED: exported game cold start exceeded 30 seconds." -ForegroundColor Red
    $Smoke.Kill()
    [void]$Smoke.WaitForExit(5000)
    exit 1
}
$Smoke.WaitForExit()
$SmokeExitCode = $Smoke.ExitCode
if ($SmokeExitCode -ne 0) {
    Write-Host "WINDOWS BUILD FAILED: exported game exited with $SmokeExitCode." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $Log) -or (Get-Item -LiteralPath $Log).Length -eq 0) {
    Write-Host "WINDOWS BUILD FAILED: exported game did not write a smoke-test log." -ForegroundColor Red
    exit 1
}
$LogText = Get-Content -LiteralPath $Log -Raw
if ($LogText -match "SCRIPT ERROR|Parse Error|Failed to load script|Failed to load resource") {
    Write-Host "WINDOWS BUILD FAILED: exported game logged a script or resource failure." -ForegroundColor Red
    Get-Content -LiteralPath $Log | Select-Object -Last 30
    exit 1
}
Compress-Archive -LiteralPath $Executable, $Package -DestinationPath $Archive -Force
$ExecutableHash = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
$PackageHash = (Get-FileHash -LiteralPath $Package -Algorithm SHA256).Hash
Write-Host "WINDOWS BUILD OK: $Archive" -ForegroundColor Green
Write-Host "Executable SHA256: $ExecutableHash"
Write-Host "Package SHA256:    $PackageHash"
exit 0
