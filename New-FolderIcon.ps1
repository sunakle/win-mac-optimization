#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$images = [Collections.Generic.List[byte[]]]::new()
foreach ($size in @(16,24,32,48,64,128,256)) {
    $bitmap = [Drawing.Bitmap]::new($size,$size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([Drawing.Color]::Transparent)
        $scale = $size / 256.0
        $graphics.ScaleTransform([float]$scale,[float]$scale)
        $back = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,81,169,208))
        $front = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,106,193,229))
        $shine = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(155,191,232,247))
        $edge = [Drawing.Pen]::new([Drawing.Color]::FromArgb(255,42,114,157),3)
        try {
            $tab = [Drawing.PointF[]]@(
                [Drawing.PointF]::new(20,52),[Drawing.PointF]::new(93,52),
                [Drawing.PointF]::new(112,71),[Drawing.PointF]::new(226,71),
                [Drawing.PointF]::new(232,83),[Drawing.PointF]::new(232,198),
                [Drawing.PointF]::new(20,198)
            )
            $graphics.FillPolygon($back,$tab)
            $graphics.FillRectangle($front,16,88,224,125)
            $graphics.DrawRectangle($edge,17,89,221,123)
            $graphics.FillRectangle($shine,23,96,210,16)
        } finally { $back.Dispose(); $front.Dispose(); $shine.Dispose(); $edge.Dispose() }
        $buffer = [IO.MemoryStream]::new()
        try { $bitmap.Save($buffer,[Drawing.Imaging.ImageFormat]::Png); $images.Add($buffer.ToArray()) }
        finally { $buffer.Dispose() }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
$parent = Split-Path -Parent $Path
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$stream = [IO.File]::Create($Path)
$writer = [IO.BinaryWriter]::new($stream)
try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$images.Count)
    $offset = 6 + 16*$images.Count
    for ($i=0; $i -lt $images.Count; $i++) {
        $size = @(16,24,32,48,64,128,256)[$i]
        $writer.Write([byte]$(if($size -eq 256){0}else{$size}))
        $writer.Write([byte]$(if($size -eq 256){0}else{$size}))
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$images[$i].Length)
        $writer.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($bytes in $images) { $writer.Write($bytes) }
} finally { $writer.Dispose() }
Write-Host "Created original blue folder icon: $Path"
