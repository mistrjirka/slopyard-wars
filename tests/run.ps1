param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$IncludeLan
)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $projectPath 'artifacts'
New-Item -ItemType Directory -Force -Path $artifactPath | Out-Null

# Headless Godot may return zero even after a script error. Inspect the log as well.
$regressionLog = Join-Path $artifactPath 'tests.log'
& $Godot --headless --path $projectPath --script res://tests/run_tests.gd --log-file $regressionLog
if ($LASTEXITCODE -ne 0 -or (Select-String -Path $regressionLog -Pattern 'SCRIPT ERROR:|ERROR:|WARNING:.*leaked')) {
    throw 'Godot regression tests failed. See artifacts/tests.log.'
}

if ($IncludeLan) {
    $hostLog = Join-Path $artifactPath 'lan_host.log'
    $clientLog = Join-Path $artifactPath 'lan_client.log'
    $common = @('--headless', '--path', ('"' + $projectPath + '"'), '--script', 'res://tests/lan_smoke.gd')
    $hostProcess = Start-Process -FilePath $Godot -ArgumentList ($common + @('--log-file', ('"' + $hostLog + '"'), '--', 'host')) -WindowStyle Hidden -PassThru
    $clientProcess = Start-Process -FilePath $Godot -ArgumentList ($common + @('--log-file', ('"' + $clientLog + '"'), '--', 'client')) -WindowStyle Hidden -PassThru
    try {
        Wait-Process -Id $hostProcess.Id, $clientProcess.Id -Timeout 25
        $hostProcess.Refresh()
        $clientProcess.Refresh()
        if ($hostProcess.ExitCode -ne 0 -or $clientProcess.ExitCode -ne 0) {
            throw 'LAN smoke processes failed.'
        }
        if (-not (Select-String -Path $hostLog -SimpleMatch 'LAN HOST PASS') -or
            -not (Select-String -Path $clientLog -SimpleMatch 'LAN CLIENT PASS') -or
            (Select-String -Path $hostLog, $clientLog -Pattern 'SCRIPT ERROR:|ERROR:')) {
            throw 'LAN smoke logs failed validation.'
        }
        Write-Output 'LAN smoke: both processes passed.'
    }
    finally {
        foreach ($testProcess in @($hostProcess, $clientProcess)) {
            $testProcess.Refresh()
            if (-not $testProcess.HasExited) {
                Stop-Process -Id $testProcess.Id
            }
        }
    }
}
