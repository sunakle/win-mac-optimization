#requires -Version 5.1
[CmdletBinding()]
param([string]$Root=(Join-Path $env:LOCALAPPDATA 'WinMacRestore\DeepSeekBox'))
$ErrorActionPreference='Stop'
$compose=Join-Path ([IO.Path]::GetFullPath($Root)) 'compose.yaml'
if(-not(Test-Path -LiteralPath $compose)){throw 'DeepSeek box is not installed.'}
$docker=Get-Command docker -ErrorAction Stop
& $docker.Source compose -f $compose stop
if($LASTEXITCODE -ne 0){throw 'Docker could not stop the DeepSeek containers.'}
Write-Host 'Stopped. Chats and settings remain in the Docker volume.'
