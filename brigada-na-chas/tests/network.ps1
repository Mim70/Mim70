param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path $GodotPath).Path
$testLogs = Join-Path $projectPath 'build/test-logs'
New-Item -ItemType Directory -Force $testLogs | Out-Null
$processes = @()
try {
    $processes += Start-Process -FilePath $enginePath -ArgumentList @('--headless','--path',('"'+$projectPath+'"'),'--','--test-host') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$testLogs/host.log" -RedirectStandardError "$testLogs/host.err"
    Start-Sleep -Milliseconds 700
    foreach ($i in 1..3) {
        $processes += Start-Process -FilePath $enginePath -ArgumentList @('--headless','--path',('"'+$projectPath+'"'),'--','--test-client') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$testLogs/client-$i.log" -RedirectStandardError "$testLogs/client-$i.err"
    }
    $processes | Wait-Process -Timeout 35
    foreach ($label in @('host','client-1','client-2','client-3')) {
        $outputText = Get-Content -Raw "$testLogs/$label.log"
        $errorText = Get-Content -Raw "$testLogs/$label.err"
        if ($errorText) { throw "$label errors: $errorText" }
        if ($outputText -notmatch 'ragdoll=true' -or $outputText -notmatch 'peak=4' -or $outputText -notmatch 'pipe=0.5' -or $outputText -notmatch 'voice=[1-9]' -or $outputText -notmatch 'valve=true') { throw "$label failed: $outputText" }
        Write-Output "$label PASS: four peers, replicated job state, solved network minigame, voice packets, replicated ragdoll"
    }
} finally {
    foreach ($proc in $processes) { if (-not $proc.HasExited) { Stop-Process -Id $proc.Id } }
}
