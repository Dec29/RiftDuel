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
    $OutputDirectory = Join-Path $ProjectRoot "build\Demo\RiftDuel"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$Executable = Join-Path $OutputDirectory "RiftDuel.exe"
$Package = Join-Path $OutputDirectory "RiftDuel.pck"
$Log = Join-Path $OutputDirectory "smoke.log"
$Archive = Join-Path (Split-Path -Parent $OutputDirectory) "RiftDuel-windows-x86_64.zip"
$ExportTimeoutMilliseconds = 180000
$SmokeTimeoutMilliseconds = 30000
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Set-Content -LiteralPath (Join-Path $OutputDirectory ".gdignore") -Value "exported game folder; not project content" -Encoding ASCII
foreach ($GeneratedFile in @($Executable, $Package, $Log, $Archive)) {
    if (Test-Path -LiteralPath $GeneratedFile) { Remove-Item -LiteralPath $GeneratedFile -Force }
}
# The game folder sits inside the project tree, so a left-over copy would be
# rediscovered by the exporter's own scan (it finds the nested .gdextension and
# then fails to copy the library). Clear the staged addon tree first, so each
# build starts from the freshly exported content.
$StagedAddon = Join-Path $OutputDirectory "addons"
if (Test-Path -LiteralPath $StagedAddon) { Remove-Item -LiteralPath $StagedAddon -Recurse -Force }
$StagedLicenses = Join-Path $OutputDirectory "licenses"
if (Test-Path -LiteralPath $StagedLicenses) { Remove-Item -LiteralPath $StagedLicenses -Recurse -Force }
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
# The export only stages runtime DLLs. The extension manifest and provider list
# must ship with the game folder too, otherwise the unpacked game cannot load
# SpineBridge at all (.gdextension missing => every bone-rendered operator loses
# its classes). providers.json also goes into the PCK via the export preset's
# include_filter; this stages the on-disk copy as well.
$AddonSource = Join-Path $ProjectRoot "addons\spine_bridge"
$AddonTarget = Join-Path $OutputDirectory "addons\spine_bridge"
foreach ($AddonFile in @("spine_bridge.gdextension", "providers.json")) {
    $SourceFile = Join-Path $AddonSource $AddonFile
    if (-not (Test-Path -LiteralPath $SourceFile) -or (Get-Item -LiteralPath $SourceFile).Length -eq 0) {
        throw "Windows export is missing a required SpineBridge addon file: $SourceFile"
    }
    Copy-Item -LiteralPath $SourceFile -Destination (Join-Path $AddonTarget $AddonFile) -Force
}
foreach ($AddonFile in @("spine_bridge.gdextension", "providers.json")) {
    $DeliveredFile = Join-Path $AddonTarget $AddonFile
    if (-not (Test-Path -LiteralPath $DeliveredFile) -or (Get-Item -LiteralPath $DeliveredFile).Length -eq 0) {
        throw "Windows export did not stage the SpineBridge addon file: $DeliveredFile"
    }
}
# The game folder lives inside the project tree, so the editor's filesystem scan
# would descend into the exported copy and try to load its nested addons as project
# extensions, which aborts the import scan. .gdignore is Godot's supported marker
# for "this directory is not project content"; it is not shipped in the ZIP.
$IgnoreMarker = Join-Path $OutputDirectory ".gdignore"
Set-Content -LiteralPath $IgnoreMarker -Value "exported game folder; not project content" -Encoding ASCII
if (-not (Test-Path -LiteralPath $IgnoreMarker)) {
    throw "Windows export could not mark the game folder as non-project content."
}
$SmokeStartInfo = New-Object System.Diagnostics.ProcessStartInfo
& (Join-Path $ProjectRoot "tools/build_updater.ps1") -OutputDirectory $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw "Updater staging failed" }
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
if ($LogText -match "SCRIPT ERROR|(^|\s)ERROR:|Parse Error|Failed to load script|Failed to load resource|Failed loading resource") {
    Write-Host "WINDOWS BUILD FAILED: exported game logged a script or resource failure." -ForegroundColor Red
    Get-Content -LiteralPath $Log | Select-Object -Last 30
    exit 1
}
$BridgeLibrary = Join-Path $OutputDirectory "libspine_bridge.windows.template_release.x86_64.dll"
$ProviderDirectory = Join-Path $OutputDirectory "addons\spine_bridge\windows"
$ProviderLibrary = Join-Path $ProviderDirectory "spine_provider_38.windows.template_release.x86_64.dll"
foreach ($RuntimeFile in @($BridgeLibrary, $ProviderLibrary)) {
    if (-not (Test-Path -LiteralPath $RuntimeFile) -or (Get-Item -LiteralPath $RuntimeFile).Length -eq 0) {
        throw "Windows export is missing the Spine runtime: $RuntimeFile"
    }
}
$LicenseDirectory = Join-Path $OutputDirectory "licenses\spine_bridge"
New-Item -ItemType Directory -Path $LicenseDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $ProjectRoot "addons\spine_bridge\SPINE-RUNTIMES-LICENSE.txt"), (Join-Path $ProjectRoot "addons\spine_bridge\GODOT-CPP-LICENSE.md") -Destination $LicenseDirectory -Force
Compress-Archive -LiteralPath $Executable, $Package, $BridgeLibrary, (Join-Path $OutputDirectory "RiftDuelUpdater.exe"), (Join-Path $OutputDirectory "client_version.json"), (Join-Path $OutputDirectory "addons"), (Join-Path $OutputDirectory "licenses") -DestinationPath $Archive -Force
$ExecutableHash = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
$PackageHash = (Get-FileHash -LiteralPath $Package -Algorithm SHA256).Hash
$ArchiveHash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash
$ArchiveHash | Set-Content -LiteralPath ([System.IO.Path]::ChangeExtension($Archive, ".sha256")) -Encoding ASCII
Write-Host "WINDOWS BUILD OK: $Archive" -ForegroundColor Green
Write-Host "Executable SHA256: $ExecutableHash"
Write-Host "Package SHA256:    $PackageHash"
exit 0
