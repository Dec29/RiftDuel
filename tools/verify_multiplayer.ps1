param(
    [switch]$Graphics,
    [int]$DelayMs = 0,
    [ValidateSet("battle", "endurance")][string]$Mode = "battle",
    [int]$Ticks = 9000,
    [int]$Port = 24790,
    [string]$Executable = "",
    [string]$Endpoint = ""
)
$ErrorActionPreference = "Stop"
$Godot = "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CaseDirectory = Join-Path $ProjectRoot (".godot\net-qa-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $CaseDirectory | Out-Null
$TracePrefix = (Join-Path $CaseDirectory "peer").Replace("\", "/")
$Processes = @()
$OverallCode = 1
$Runtime = $Godot
if (-not [string]::IsNullOrWhiteSpace($Executable)) {
    $Runtime = [System.IO.Path]::GetFullPath($Executable)
    if (-not (Test-Path -LiteralPath $Runtime)) { throw "Runtime executable not found: $Runtime" }
}
try {
    foreach ($Role in @("host", "client")) {
        $LogPath = $TracePrefix + "_" + $Role + ".log"
        $Arguments = @("--log-file", $LogPath)
        if ([string]::IsNullOrWhiteSpace($Executable)) { $Arguments = @("--path", $ProjectRoot) + $Arguments }
        if ($Graphics) {
            $Arguments += @("--rendering-method", "gl_compatibility")
        } else {
            $Arguments += "--headless"
        }
        if ([string]::IsNullOrWhiteSpace($Executable)) {
            $Arguments += @("--script", "tools/test_net_peer.gd", "--", $Role, $TracePrefix, $Port, ($Port + 1), $DelayMs, $Mode, $Ticks)
        } else {
            $Arguments += @("--", "--qa-peer", $Role, $TracePrefix, $Port, ($Port + 1), $DelayMs, $Mode, $Ticks)
        }
        if (-not [string]::IsNullOrWhiteSpace($Endpoint)) { $Arguments += $Endpoint }
        $Processes += Start-Process -FilePath $Runtime -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    }
    $Deadline = [DateTime]::UtcNow.AddMinutes(16)
    while (@($Processes | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ([DateTime]::UtcNow -gt $Deadline) { throw "Peer test exceeded deadline." }
        if (@($Processes | Where-Object { $_.HasExited -and $_.ExitCode -ne 0 }).Count -gt 0) { throw "One peer failed." }
        foreach ($Role in @("host", "client")) {
            $LogPath = $TracePrefix + "_" + $Role + ".log"
            if ((Test-Path -LiteralPath $LogPath) -and (Select-String -LiteralPath $LogPath -Pattern 'SCRIPT ERROR|Parse Error|Failed to load script|Failed to load resource' -Quiet)) {
                throw "Runtime errors in $Role log."
            }
        }
        foreach ($Process in $Processes) {
            if (-not $Process.HasExited) { [void]$Process.WaitForExit(500) }
        }
    }
    foreach ($Process in $Processes) {
        if ($Process.ExitCode -ne 0) { throw "Peer failed with exit code $($Process.ExitCode)" }
    }
    $HostResult = Get-Content -LiteralPath ($TracePrefix + "_host.json") -Raw | ConvertFrom-Json
    $ClientResult = Get-Content -LiteralPath ($TracePrefix + "_client.json") -Raw | ConvertFrom-Json
    if ($HostResult.build -ne $ClientResult.build -or $HostResult.build.Length -ne 64 -or $HostResult.operators -ne 8 -or $ClientResult.operators -ne 8) {
        throw "Build fingerprint or operator resource validation failed."
    }
    if ($HostResult.tick -ne $ClientResult.tick -or $HostResult.hash -ne $ClientResult.hash -or $HostResult.result -ne $ClientResult.result) {
        throw "Peer final state mismatch."
    }
    $HostTrace = Get-Content -LiteralPath ($TracePrefix + "_host.trace")
    $ClientTrace = Get-Content -LiteralPath ($TracePrefix + "_client.trace")
    if ($HostTrace.Count -ne $ClientTrace.Count) { throw "Tick trace lengths differ." }
    if ($HostTrace.Count -ne $HostResult.tick + 1) { throw "Tick trace is incomplete." }
    for ($Index = 0; $Index -lt $HostTrace.Count; $Index++) {
        if ($HostTrace[$Index] -ne $ClientTrace[$Index]) { throw ("First divergent trace line {0}: {1} / {2}" -f $Index, $HostTrace[$Index], $ClientTrace[$Index]) }
        if (-not $HostTrace[$Index].StartsWith("$Index,")) { throw "Tick trace skipped or duplicated a tick." }
    }
    if ($Mode -eq "battle" -and $HostResult.result -ne 1) { throw "Expected a completed blue win." }
    if ($Mode -eq "endurance" -and $HostResult.tick -lt $Ticks) { throw "Endurance did not reach requested ticks." }
    Write-Host "MULTIPLAYER OK: graphics=$Graphics mode=$Mode delay_ms=$DelayMs tick=$($HostResult.tick) hashes=$($HostTrace.Count) result=$($HostResult.result)" -ForegroundColor Green
    Write-Host "Evidence: $CaseDirectory"
    $OverallCode = 0
} catch {
    Write-Host "MULTIPLAYER FAILED: $_" -ForegroundColor Red
    foreach ($Role in @("host", "client")) {
        $LogPath = $TracePrefix + "_" + $Role + ".log"
        if (Test-Path -LiteralPath $LogPath) { Get-Content -LiteralPath $LogPath | Select-Object -Last 20 }
    }
} finally {
    $Invitation = $TracePrefix + ".invitation"
    foreach ($InvitationFile in @($Invitation, $Invitation + ".tmp")) {
        if (Test-Path -LiteralPath $InvitationFile) { Remove-Item -LiteralPath $InvitationFile }
    }
    foreach ($Process in $Processes) {
        if (-not $Process.HasExited) { Stop-Process -Id $Process.Id }
    }
}
exit $OverallCode
