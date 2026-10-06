param([string]$RelayExecutable = "", [switch]$Graphics)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Godot = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($Godot)) { $Godot = "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" }
if ([string]::IsNullOrWhiteSpace($RelayExecutable)) { $RelayExecutable = Join-Path $ProjectRoot ".godot\riftduel-relay-test.exe" }
$Log = Join-Path $ProjectRoot ".godot\relay-client.log"
if (Test-Path -LiteralPath $Log) { Remove-Item -LiteralPath $Log }
$Server = $null
$Client = $null
$Code = 1
try {
    $Server = Start-Process -FilePath $RelayExecutable -ArgumentList @("-listen", "127.0.0.1:24860") -WindowStyle Hidden -PassThru
    $Deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if ($Server.HasExited -or [DateTime]::UtcNow -gt $Deadline) { throw "Relay failed to start." }
        try { $Health = Invoke-WebRequest -Uri "http://127.0.0.1:24860/healthz" -UseBasicParsing -TimeoutSec 1 } catch { $Health = $null }
    } while ($null -eq $Health)
    $Client = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", $ProjectRoot, "--script", "tools/test_relay_session.gd", "--log-file", $Log) -WindowStyle Hidden -PassThru
    $Deadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not $Client.HasExited) {
        if ($Server.HasExited -or [DateTime]::UtcNow -gt $Deadline) { throw "Relay test exceeded deadline or server exited." }
        if ((Test-Path -LiteralPath $Log) -and (Select-String -LiteralPath $Log -Pattern "SCRIPT ERROR|Parse Error|Failed to load script" -Quiet)) { throw "Relay script failed." }
        [void]$Client.WaitForExit(500)
    }
    if ($Client.ExitCode -ne 0) { throw "Relay test exited with $($Client.ExitCode)." }
    if ((Get-Content -LiteralPath $Log -Raw) -notmatch "Relay OK:") { throw "Relay test did not report success." }
    if ($Graphics) {
        $Verifier = Join-Path $ProjectRoot "tools\verify_multiplayer.ps1"
        foreach ($Case in @(@("-Mode", "battle", "-Port", "24870"), @("-Mode", "battle", "-DelayMs", "200", "-Port", "24880"), @("-Mode", "endurance", "-Ticks", "9000", "-Port", "24890"))) {
            $Arguments = @("-ExecutionPolicy", "Bypass", "-File", $Verifier, "-Graphics", "-Endpoint", "ws://127.0.0.1:24860/ws") + $Case
            $Peers = Start-Process -FilePath "powershell" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
            if ($Peers.ExitCode -ne 0) { throw "Relay graphical case failed." }
        }
    }
    $Code = 0
} catch {
    Write-Host "RELAY FAILED: $_" -ForegroundColor Red
} finally {
    if (Test-Path -LiteralPath $Log) { Get-Content -LiteralPath $Log }
    if ($Client -and -not $Client.HasExited) { Stop-Process -Id $Client.Id }
    if ($Server -and -not $Server.HasExited) { Stop-Process -Id $Server.Id }
}
exit $Code
