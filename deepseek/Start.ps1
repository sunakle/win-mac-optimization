#requires -Version 5.1
[CmdletBinding()]
param([string]$Root=(Join-Path $env:LOCALAPPDATA 'WinMacRestore\DeepSeekBox'),[switch]$NoOpen)
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$compose=Join-Path $Root 'compose.yaml'
if(-not(Test-Path -LiteralPath $compose)){throw 'DeepSeek box is not installed. Run Setup.ps1 -Apply first.'}
$docker=Get-Command docker -ErrorAction Stop
& $docker.Source compose -f $compose up -d --no-build
if($LASTEXITCODE -ne 0){throw 'Docker could not start the DeepSeek containers.'}
$started=& $docker.Source inspect --format '{{.State.StartedAt}}' winmac-dsh-agent
if($LASTEXITCODE -ne 0){throw 'DeepSeek container not found.'}
Write-Host 'Waiting for DeepSeek (cold start can take several minutes)...'
for($attempt=0;$attempt -lt 450;$attempt++){
    $health=& $docker.Source inspect --format '{{.State.Health.Status}}' winmac-dsh-agent 2>$null
    if($health -eq 'healthy'){
        $log=(& $docker.Source logs --since $started winmac-dsh-agent 2>&1 | Out-String)
        $matches=[regex]::Matches($log,'http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9._~%\-]+')
        if($matches.Count -gt 0){
            if(-not $NoOpen){Start-Process -FilePath $matches[$matches.Count-1].Value}
            Write-Host 'DeepSeek is ready at 127.0.0.1:3080. Login link was not printed.'
            return
        }
    }
    if($attempt -gt 0 -and $attempt % 15 -eq 0){Write-Host ("Still starting: {0} min; health={1}" -f [math]::Round($attempt*2/60,1),$health)}
    Start-Sleep -Seconds 2
}
throw 'DeepSeek was not ready after 15 minutes. Inspect the local container logs; do not share login tokens.'

