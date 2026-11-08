#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string]$AssetsRoot,
    [switch]$Apply
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath $AssetsRoot -ErrorAction Stop).Path
$sourceTheme=Join-Path $root 'Themes\macOS Graphite Night.theme'
$sourceIcons=Join-Path $root 'Icons\Yosemite'
$sourceWallpaper=Join-Path $root 'Wallpapers\Anime-Graphite.png'
foreach($path in @($sourceTheme,(Join-Path $sourceIcons '3.ico'),(Join-Path $sourceIcons '4.ico'),$sourceWallpaper)) {
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Private backup is incomplete: $path"}
}
$style=Join-Path $env:LOCALAPPDATA 'MacStyleCompleted'
$themeDir=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes'
$targetTheme=Join-Path $themeDir 'macOS Graphite Night - restored.theme'
$taskbarSource=Join-Path $root 'TaskbarCenter'
Write-Host 'Plan: restore personal folders, wallpaper, sounds and cursors from the private archive.'
Write-Host ('Taskbar centering: '+$(if(Test-Path (Join-Path $taskbarSource 'TaskbarX.exe')){'restore saved TaskbarX'}else{'skip; TaskbarX.exe missing'}))
Write-Host 'Big Sur visual style and window buttons: stage the theme file only; system patching is not automatic.'
if(-not $Apply){Write-Host 'Preview only. Add -Apply to restore.'; return}
if(-not $PSCmdlet.ShouldProcess($style,'Copy private assets and apply current-user appearance')){return}

$backupDir=Join-Path $PSScriptRoot ('backups\private-style-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
foreach($name in @('Control Panel\Cursors','AppEvents\Schemes\Apps')) {
    $file=Join-Path $backupDir (($name -replace '\','-')+'.reg')
    & reg.exe export ('HKCU\'+$name) $file /y | Out-Null
    if($LASTEXITCODE -ne 0){throw "Could not back up $name"}
}
foreach($folder in @('Icons','Wallpapers','Cursors','Sounds','TaskbarCenter')) {
    $source=Join-Path $root $folder
    if(Test-Path -LiteralPath $source -PathType Container) {
        $destination=Join-Path $style $folder
        if([IO.Path]::GetFullPath($source).TrimEnd('\') -ne [IO.Path]::GetFullPath($destination).TrimEnd('\')) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
        }
    }
}
$oldPrefix='[A-Za-z]:\\Users\\[^\\]+\\AppData\\Local\\MacStyleCompleted'
$themeText=Get-Content -LiteralPath $sourceTheme -Raw
$themeText=[regex]::Replace($themeText,$oldPrefix,[System.Text.RegularExpressions.MatchEvaluator]{param($m) $style})
New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
Set-Content -LiteralPath $targetTheme -Value $themeText -Encoding Unicode

$section=''
$changedCursors=0
$changedSounds=0
foreach($line in $themeText -split '\r?\n') {
    if($line -match '^\s*\[(.+)\]\s*$'){$section=$Matches[1]; continue}
    if($line -notmatch '^\s*([^=]+?)\s*=\s*(.*?)\s*$'){continue}
    $name=$Matches[1].Trim(); $value=$Matches[2].Trim()
    if($section -eq 'Control Panel\Cursors' -and $name -ne 'DefaultValue') {
        if($value -and -not(Test-Path -LiteralPath $value -PathType Leaf)){continue}
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Control Panel\Cursors')
        try {$key.SetValue($name,$value,[Microsoft.Win32.RegistryValueKind]::String);$changedCursors++} finally {$key.Dispose()}
    } elseif($section -like 'AppEvents\Schemes\Apps\*' -and $name -eq 'DefaultValue') {
        if($value -and -not(Test-Path -LiteralPath $value -PathType Leaf)){continue}
        $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($section)
        try {$key.SetValue('',$value,[Microsoft.Win32.RegistryValueKind]::String);$changedSounds++} finally {$key.Dispose()}
    }
}
if($changedCursors) {
    Add-Type @'
using System; using System.Runtime.InteropServices;
public static class CursorRefresh { [DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(uint action,uint param,IntPtr data,uint flags); }
'@
    [void][CursorRefresh]::SystemParametersInfo(0x57,0,[IntPtr]::Zero,3)
}
$taskbarZip=$null
if(Test-Path -LiteralPath (Join-Path $taskbarSource 'TaskbarX.exe') -PathType Leaf) {
    $taskbarZip=Join-Path $backupDir 'TaskbarX-restored.zip'
    Compress-Archive -Path (Join-Path $taskbarSource '*') -DestinationPath $taskbarZip -CompressionLevel Fastest
}
$installArgs=@{Apply=$true;IconDirectory=(Join-Path $style 'Icons\Yosemite');WallpaperFile=(Join-Path $style 'Wallpapers\Anime-Graphite.png')}
if($taskbarZip){$installArgs.TaskbarXZip=$taskbarZip}
& (Join-Path $PSScriptRoot 'Install.ps1') @installArgs
Write-Host "Restored $changedCursors cursors and $changedSounds sound events."
Write-Host "Theme staged at: $targetTheme"
Write-Host "Registry backup: $backupDir"
Write-Host 'Sign out and in to refresh Explorer icons. Big Sur window controls still require a compatible theme patcher and manual installation.'

