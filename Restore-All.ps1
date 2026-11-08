#requires -Version 5.1
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference='Stop'
$assets=Join-Path $PSScriptRoot 'private-assets'
if(-not(Test-Path -LiteralPath $assets -PathType Container)) {
    throw 'Private assets are missing. Download and extract the complete ZIP from the private GitHub release.'
}
& (Join-Path $PSScriptRoot 'Restore-PrivateStyle.ps1') -AssetsRoot $assets -Apply:$Apply
if($Apply){& (Join-Path $PSScriptRoot 'Check.ps1')}

