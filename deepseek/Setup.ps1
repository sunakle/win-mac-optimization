#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$Apply, [string]$Root=(Join-Path $env:LOCALAPPDATA 'WinMacRestore\DeepSeekBox'))
$ErrorActionPreference='Stop'
$source=$PSScriptRoot
$Root=[IO.Path]::GetFullPath($Root)
Write-Host "DeepSeek destination: $Root"
Write-Host 'Will copy public templates, build two images, and start three local containers.'
if(-not $Apply){Write-Host 'Preview only. Add -Apply to continue.';return}
if(-not $PSCmdlet.ShouldProcess($Root,'Install DeepSeek Docker box')){return}
$docker=Get-Command docker -ErrorAction SilentlyContinue
if(-not $docker){throw 'Docker Desktop CLI was not found. Install and start Docker Desktop first.'}
& $docker.Source info --format '{{.ServerVersion}}' *> $null
if($LASTEXITCODE -ne 0){throw 'Docker engine is not ready. Open Docker Desktop and finish its WSL setup.'}
$port = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
if ($port) { throw 'Port 3080 is already used. Stop the existing DeepSeek box before installing another one.' }
New-Item -ItemType Directory -Path $Root,(Join-Path $Root 'workspace') -Force | Out-Null
foreach($name in @('compose.yaml','Dockerfile','Dockerfile.proxy','start.sh','container.patch.yml','squid.conf','allowed-domains.txt','.dockerignore')){
    $dest=Join-Path $Root $name
    if(-not (Test-Path -LiteralPath $dest)){Copy-Item -LiteralPath (Join-Path $source $name) -Destination $dest}
}
& $docker.Source compose -f (Join-Path $Root 'compose.yaml') build
if($LASTEXITCODE -ne 0){throw 'Docker image build failed. Check Docker Desktop and network access.'}
& (Join-Path $source 'Start.ps1') -Root $Root

