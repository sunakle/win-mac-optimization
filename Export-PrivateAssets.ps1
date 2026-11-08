#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
$destinationFull=[IO.Path]::GetFullPath($Destination)
if([IO.Path]::GetExtension($destinationFull).ToLowerInvariant() -ne '.zip'){throw 'Destination must end in .zip.'}
if(Test-Path -LiteralPath $destinationFull){throw 'Destination already exists. Choose a new file name.'}
$style=Join-Path $env:LOCALAPPDATA 'MacStyleCompleted'
if(-not(Test-Path -LiteralPath $style -PathType Container)){throw 'MacStyleCompleted was not found on this PC.'}
$folders=@('Icons','Wallpapers','Cursors','Sounds','TaskbarCenter') | ForEach-Object {Join-Path $style $_} | Where-Object {Test-Path -LiteralPath $_ -PathType Container}
if(-not $folders){throw 'No personal style assets were found.'}
$themes=Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes') -Filter '*macOS*.theme' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
$systemTheme=Join-Path $env:WINDIR 'Resources\Themes\Big Sur'
if(Test-Path -LiteralPath $systemTheme -PathType Container){$folders+= $systemTheme}
$parent=Split-Path -Parent $destinationFull
if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
Add-Type -AssemblyName System.IO.Compression
$written=0
$skipped=New-Object System.Collections.Generic.List[string]
$zipFile=[IO.File]::Open($destinationFull,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $zip=New-Object System.IO.Compression.ZipArchive($zipFile,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {
        $items=New-Object System.Collections.Generic.List[object]
        foreach($folder in $folders) {
            $prefix=(Split-Path -Leaf $folder)+'/'
            foreach($file in Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue) {
                if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
                $relative=$file.FullName.Substring($folder.Length).TrimStart('\','/') -replace '\\','/'
                $items.Add(@{Source=$file.FullName;Entry=$prefix+$relative})
            }
        }
        foreach($theme in @($themes)) {
            if($theme -and (Test-Path -LiteralPath $theme -PathType Leaf)) {
                $items.Add(@{Source=$theme;Entry='Themes/'+(Split-Path -Leaf $theme)})
            }
        }
        foreach($item in $items) {
            try {
                $source=[IO.File]::Open($item.Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
                try {
                    $entry=$zip.CreateEntry($item.Entry,[IO.Compression.CompressionLevel]::Optimal)
                    $output=$entry.Open()
                    try {$source.CopyTo($output)} finally {$output.Dispose()}
                    $written++
                } finally {$source.Dispose()}
            } catch [IO.IOException] {
                $skipped.Add($item.Source)
            } catch [UnauthorizedAccessException] {
                $skipped.Add($item.Source)
            }
        }
    } finally {$zip.Dispose()}
} finally {$zipFile.Dispose()}
if($written -eq 0){Remove-Item -LiteralPath $destinationFull -Force; throw 'No files could be archived.'}
Write-Host "Private style archive: $destinationFull"
Write-Host "Files archived: $written; locked or inaccessible: $($skipped.Count)"
if($skipped.Count){$skipped | ForEach-Object {Write-Warning "Skipped: $_"}}
Write-Host 'Store it on an external drive or private cloud account. It is intentionally excluded from GitHub.'

