#requires -Version 5.1
$ErrorActionPreference = 'Stop'
function Read-Value($path,$name) {
    try { return (Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction Stop).$name }
    catch { return $null }
}
$p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$i = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
$f = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds'
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
[pscustomobject]@{
    WindowsBuild = [Environment]::OSVersion.Version.Build
    DarkApps = (Read-Value $p 'AppsUseLightTheme') -eq 0
    DarkSystem = (Read-Value $p 'SystemUsesLightTheme') -eq 0
    SmallTaskbar = Read-Value $a 'TaskbarSmallIcons'
    WeatherHidden = ((Read-Value $f 'ShellFeedsTaskbarViewMode') -eq 2) -or ((Read-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds') -eq 0)
    FolderIcon = Read-Value $i '3'
    ShortcutOverlayOverride = Read-Value $i '29'
    TaskbarXAutostart = [bool](Read-Value $run 'MacStyleTaskbarCenter')
    Wallpaper = Read-Value 'HKCU:\Control Panel\Desktop' 'WallPaper'
    DockerAvailable = [bool](Get-Command docker -ErrorAction SilentlyContinue)
    OllamaAvailable = [bool](Get-Command ollama -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe')) -or [bool](Get-Process -Name ollama -ErrorAction SilentlyContinue)
} | Format-List
