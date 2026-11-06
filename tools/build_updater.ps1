param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$ProjectRoot=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Go=$env:RIFTDUEL_GO_BIN
if ([string]::IsNullOrWhiteSpace($Go)) { $Go=(Get-Command go -ErrorAction Stop).Source }
$env:GOTOOLCHAIN='local'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
& $Go -C (Join-Path $ProjectRoot 'tools/updater') build -trimpath -ldflags '-H windowsgui -s -w' -o (Join-Path $OutputDirectory 'RiftDuelUpdater.exe') .
if ($LASTEXITCODE -ne 0) { throw "Updater build failed: $LASTEXITCODE" }
Copy-Item -LiteralPath (Join-Path $ProjectRoot 'tools/updater/client_version.json') -Destination (Join-Path $OutputDirectory 'client_version.json') -Force
$Notices=Join-Path $OutputDirectory 'licenses/updater'
New-Item -ItemType Directory -Path $Notices -Force | Out-Null
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $Go)) 'LICENSE') -Destination (Join-Path $Notices 'GO-LICENSE.txt') -Force
