#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$Apply, [ValidateRange(2,365)][int]$OlderThanDays=7)
$ErrorActionPreference = 'Stop'
$rules = @(
    @{Path=$env:TEMP; Days=$OlderThanDays; Pattern='\.(tmp|log|dmp)$'},
    @{Path=(Join-Path $env:LOCALAPPDATA 'CrashDumps'); Days=[Math]::Max(14,$OlderThanDays); Pattern='\.dmp$'}
)
$windowsTemp = Join-Path $env:WINDIR 'Temp'
if (Test-Path -LiteralPath $windowsTemp) { $rules += @{Path=$windowsTemp; Days=[Math]::Max(14,$OlderThanDays); Pattern='\.(tmp|log|dmp)$'} }
$found = [Collections.Generic.List[object]]::new()
foreach ($rule in $rules) {
    if (-not (Test-Path -LiteralPath $rule.Path -PathType Container)) { continue }
    $base = [IO.Path]::GetFullPath($rule.Path).TrimEnd('\') + '\'
    if ((Get-Item -LiteralPath $rule.Path).Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $rule.Path -File -Force -ErrorAction SilentlyContinue) {
        $full = [IO.Path]::GetFullPath($file.FullName)
        if (-not $full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
        if ($file.Name -notmatch $rule.Pattern -or $file.LastWriteTimeUtc -gt [DateTime]::UtcNow.AddDays(-$rule.Days)) { continue }
        $found.Add($file)
    }
}
$bytes = [long]0
foreach ($file in $found) { $bytes += $file.Length }
Write-Host ("Found {0} old temporary files ({1:N1} MB)." -f $found.Count,($bytes/1MB))
if (-not $Apply) { Write-Host 'Preview only. Add -Apply to remove them.'; return }
$deleted=0
foreach ($file in $found) {
    if ($PSCmdlet.ShouldProcess($file.FullName,'Remove stale temporary file')) {
        try { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop; $deleted++ }
        catch { Write-Warning "Skipped: $($file.FullName)" }
    }
}
Write-Host "Removed $deleted files. Downloads, documents, browser profiles and Recycle Bin were not touched."

