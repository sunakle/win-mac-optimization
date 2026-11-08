#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param([Parameter(Mandatory=$true)][string]$BackupPath)
$ErrorActionPreference = 'Stop'
$file = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).Path
$state = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
if ($state.Version -ne 1 -or -not $state.Registry) { throw 'Unsupported backup format.' }
Write-Host "Restoring settings saved at $($state.SavedAt)"
if (-not $PSCmdlet.ShouldProcess('Current user Windows settings','Restore backup')) { return }
foreach ($entry in $state.Registry) {
    if ($entry.Exists) {
        if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType $entry.Kind -Force | Out-Null
    } elseif (Test-Path -LiteralPath $entry.Path) {
        Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
    }
}
$wallpaper = [string]$state.Wallpaper
if ($wallpaper -and -not (Test-Path -LiteralPath $wallpaper)) {
    $saved = Get-ChildItem -LiteralPath (Split-Path -Parent $file) -Filter 'wallpaper-before.*' -File | Select-Object -First 1
    if ($saved) { $wallpaper = $saved.FullName }
}
if ($wallpaper -and (Test-Path -LiteralPath $wallpaper)) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WallpaperUndoApi {
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool SystemParametersInfo(uint action, uint param, string value, uint flags);
}
'@
    [void][WallpaperUndoApi]::SystemParametersInfo(20,0,$wallpaper,3)
}
$managed = Join-Path $env:LOCALAPPDATA 'WinMacRestore\TaskbarX'
Get-Process -Name TaskbarX -ErrorAction SilentlyContinue | ForEach-Object {
    try { if ($_.Path.StartsWith($managed,[StringComparison]::OrdinalIgnoreCase)) { $_ | Stop-Process } } catch { }
}
Write-Host 'Settings restored. Sign out and back in if icons have not refreshed.'

