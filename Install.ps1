#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Apply,
    [switch]$InstallApps,
    [string]$WallpaperFile,
    [string]$TaskbarXZip
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This installer requires Windows.' }
$root = $PSScriptRoot
$assets = Join-Path $root 'local-assets'
if (-not $WallpaperFile) { $WallpaperFile = Join-Path $assets 'wallpaper.png' }
if (-not $TaskbarXZip) { $TaskbarXZip = Join-Path $assets 'TaskbarX.zip' }
$target = Join-Path $env:LOCALAPPDATA 'WinMacRestore'
$icon = Join-Path $target 'Assets\BlueFolder.ico'
$isWin10 = [Environment]::OSVersion.Version.Build -lt 22000

$settings = @(
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='AppsUseLightTheme'; Value=0; Kind='DWord'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='SystemUsesLightTheme'; Value=0; Kind='DWord'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Value=0; Kind='DWord'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowInfoTip'; Value=0; Kind='DWord'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton'; Value=0; Kind='DWord'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'; Name='3'; Value=($icon+',0'); Kind='String'},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'; Name='4'; Value=($icon+',0'); Kind='String'}
)
if ($isWin10) {
    $settings += @(
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarSmallIcons'; Value=1; Kind='DWord'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'; Name='ShellFeedsTaskbarViewMode'; Value=2; Kind='DWord'}
    )
}
$remove = @(@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'; Name='29'})
$existingIcon = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons' -Name '3' -ErrorAction SilentlyContinue).'3'
$preserveIcon = $false
if ($existingIcon) {
    $existingFile = $existingIcon -replace ',\d+$',''
    $preserveIcon = (Test-Path -LiteralPath $existingFile -PathType Leaf) -and ($existingFile -ne $icon)
}
if ($preserveIcon) { $settings = @($settings | Where-Object { $_.Path -notlike '*\Shell Icons' -or $_.Name -notin @('3','4') }) }
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (Test-Path -LiteralPath $TaskbarXZip) {
    $settings += @{Path=$runKey; Name='MacStyleTaskbarCenter'; Value=$null; Kind='String'}
}

function Get-SavedValue($path, $name) {
    $key = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    if ($null -eq $key -or $key.GetValueNames() -notcontains $name) {
        return @{Path=$path; Name=$name; Exists=$false; Value=$null; Kind=$null}
    }
    return @{Path=$path; Name=$name; Exists=$true; Value=$key.GetValue($name); Kind=$key.GetValueKind($name).ToString()}
}

Write-Host 'Plan:'
Write-Host ('  Windows: dark theme, '+$(if($preserveIcon){'keep existing folder icon'}else{'blue folder icon'})+', Explorer settings' + $(if($isWin10){', small taskbar, no weather'}else{''}))
Write-Host ('  Wallpaper: ' + $(if(Test-Path -LiteralPath $WallpaperFile){$WallpaperFile}else{'skip (no local-assets/wallpaper.png)'}))
Write-Host ('  TaskbarX: ' + $(if(Test-Path -LiteralPath $TaskbarXZip){$TaskbarXZip}else{'skip (no local-assets/TaskbarX.zip)'}))
Write-Host ('  Apps: ' + $(if($InstallApps){'WinGet packages selected'}else{'skip'}))
if (-not $Apply) { Write-Host 'Preview only. Run .\Install.ps1 -Apply to apply.'; return }
if (-not $PSCmdlet.ShouldProcess('Current user Windows settings','Back up and apply appearance')) { return }

$backupDir = Join-Path $root ('backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$before = @($settings + $remove | ForEach-Object { Get-SavedValue $_.Path $_.Name })
$wallpaperBefore = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallPaper -ErrorAction SilentlyContinue).WallPaper
$snapshot = [ordered]@{Version=1; SavedAt=(Get-Date).ToString('o'); Registry=$before; Wallpaper=$wallpaperBefore}
$snapshot | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $backupDir 'state.json') -Encoding UTF8
if ($wallpaperBefore -and (Test-Path -LiteralPath $wallpaperBefore)) {
    Copy-Item -LiteralPath $wallpaperBefore -Destination (Join-Path $backupDir ('wallpaper-before'+[IO.Path]::GetExtension($wallpaperBefore)))
}

if (-not $preserveIcon) {
    New-Item -ItemType Directory -Path (Split-Path $icon -Parent) -Force | Out-Null
    & (Join-Path $root 'New-FolderIcon.ps1') -Path $icon
}
foreach ($item in $settings) {
    if ($item.Name -eq 'MacStyleTaskbarCenter') { continue }
    if (-not (Test-Path -LiteralPath $item.Path)) { New-Item -Path $item.Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Value -PropertyType $item.Kind -Force | Out-Null
}
foreach ($item in $remove) {
    if (Test-Path -LiteralPath $item.Path) { Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue }
}

if (Test-Path -LiteralPath $WallpaperFile -PathType Leaf) {
    $ext = [IO.Path]::GetExtension($WallpaperFile).ToLowerInvariant()
    if ($ext -notin @('.png','.jpg','.jpeg','.bmp')) { throw 'Wallpaper must be PNG, JPG or BMP.' }
    $wallpaperTarget = Join-Path $target ('Assets\Wallpaper'+$ext)
    Copy-Item -LiteralPath $WallpaperFile -Destination $wallpaperTarget -Force
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WallpaperApi {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
}
'@
    if (-not [WallpaperApi]::SystemParametersInfo(20,0,$wallpaperTarget,3)) { Write-Warning 'Wallpaper API failed; other settings were applied.' }
}

if (Test-Path -LiteralPath $TaskbarXZip -PathType Leaf) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $TaskbarXZip).Path)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('/','\')
            if ([IO.Path]::IsPathRooted($name) -or $name -match '(^|\\)\.\.(\\|$)') { throw 'TaskbarX archive contains unsafe paths.' }
        }
    } finally { $archive.Dispose() }
    $folder = Join-Path $target 'TaskbarX'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    Expand-Archive -LiteralPath $TaskbarXZip -DestinationPath $folder -Force
    $exe = Get-ChildItem -LiteralPath $folder -Filter TaskbarX.exe -Recurse -File | Select-Object -First 1
    if (-not $exe) { throw 'TaskbarX.exe was not found in the ZIP.' }
    $arguments = '-tbs=0 -as=none -obas=none -lr=1000 -oblr=1000 -ftotc=0 -cib=0 -cfsa=1 -rzbt=1 -tbr=0 -tbsg=0 -sti=0'
    New-ItemProperty -LiteralPath $runKey -Name MacStyleTaskbarCenter -Value ('"'+$exe.FullName+'" '+$arguments) -PropertyType String -Force | Out-Null
    if (-not (Get-Process -Name TaskbarX -ErrorAction SilentlyContinue)) { Start-Process -FilePath $exe.FullName -ArgumentList $arguments -WindowStyle Hidden }
}

if ($InstallApps) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) { Write-Warning 'WinGet is unavailable. Install App Installer from Microsoft Store.' }
    else {
        foreach ($id in @('Git.Git','Docker.DockerDesktop','Ollama.Ollama','ShareX.ShareX','Obsidian.Obsidian')) {
            Write-Host "WinGet: $id"
            & $winget.Source install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { Write-Warning "Installation skipped or failed: $id" }
        }
    }
}
Write-Host "Applied. Backup: $(Join-Path $backupDir 'state.json')"
Write-Host 'Sign out and back in if folder icons or the taskbar have not refreshed.'
