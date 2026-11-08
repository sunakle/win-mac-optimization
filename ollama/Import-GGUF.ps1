#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string]$ModelPath,
    [ValidatePattern('^[a-z0-9][a-z0-9._-]*$')][string]$Name='gpt4chan-chat',
    [string]$OllamaExe,
    [switch]$Apply
)
$ErrorActionPreference='Stop'
$file=(Resolve-Path -LiteralPath $ModelPath -ErrorAction Stop).Path
if([IO.Path]::GetExtension($file).ToLowerInvariant() -ne '.gguf'){throw 'Select a .gguf model file.'}
$ollama=if($OllamaExe){
    if(-not(Test-Path -LiteralPath $OllamaExe -PathType Leaf)){throw 'OllamaExe was not found.'}
    [pscustomobject]@{Source=(Resolve-Path -LiteralPath $OllamaExe).Path}
}else{Get-Command ollama -ErrorAction SilentlyContinue}
if(-not $ollama){
    $candidate=Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if(Test-Path -LiteralPath $candidate){$ollama=[pscustomobject]@{Source=$candidate}}
}
if(-not $ollama){throw 'Ollama is not installed. Install the official Windows app first.'}
Write-Host "Import $file as Ollama model $Name"
if(-not $Apply){Write-Host 'Preview only. Add -Apply to import the model.';return}
if(-not $PSCmdlet.ShouldProcess($Name,'Create local Ollama model')){return}
$folder=Join-Path $env:TEMP ('ollama-import-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$modelfile=Join-Path $folder 'Modelfile'
try {
    $forward=$file.Replace('\','/')
    if($forward.Contains('"')){throw 'The GGUF path contains a quotation mark.'}
    "FROM `"$forward`"`nPARAMETER num_ctx 4096`n" | Set-Content -LiteralPath $modelfile -Encoding UTF8
    & $ollama.Source create $Name -f $modelfile
    if($LASTEXITCODE -ne 0){throw 'Ollama could not import the GGUF file.'}
    Write-Host "Created $Name. Open Ollama and select this model for text chat. Use 'ollama stop $Name' to release RAM."
} finally {
    Remove-Item -LiteralPath $modelfile -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $folder -ErrorAction SilentlyContinue
}

