Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

function New-IconBitmap([int]$size) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F8F3ED'))

  $scale = $size / 1024.0
  $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#75677F'), 22 * $scale)
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $cover = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#CFC4D9'))
  $page = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#FFFDF8'))
  $bookmark = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#D9AD76'))
  $linePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#B9ADBF'), 15 * $scale)
  $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

  [RoundedRectangles]::FillRoundedRectangle($graphics, $cover, [System.Drawing.RectangleF]::new(197*$scale, 154*$scale, 630*$scale, 716*$scale), 94*$scale)
  [RoundedRectangles]::DrawRoundedRectangle($graphics, $pen, [System.Drawing.RectangleF]::new(197*$scale, 154*$scale, 630*$scale, 716*$scale), 94*$scale)
  [RoundedRectangles]::FillRoundedRectangle($graphics, $page, [System.Drawing.RectangleF]::new(281*$scale, 227*$scale, 449*$scale, 528*$scale), 38*$scale)
  [RoundedRectangles]::DrawRoundedRectangle($graphics, $pen, [System.Drawing.RectangleF]::new(281*$scale, 227*$scale, 449*$scale, 528*$scale), 38*$scale)
  $graphics.FillPolygon($bookmark, [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(631*$scale, 227*$scale),
    [System.Drawing.PointF]::new(697*$scale, 227*$scale),
    [System.Drawing.PointF]::new(697*$scale, 414*$scale),
    [System.Drawing.PointF]::new(664*$scale, 382*$scale),
    [System.Drawing.PointF]::new(631*$scale, 414*$scale)
  ))
  $graphics.DrawLine($linePen, 358*$scale, 397*$scale, 652*$scale, 397*$scale)
  $graphics.DrawLine($linePen, 358*$scale, 484*$scale, 625*$scale, 484*$scale)
  $graphics.DrawLine($linePen, 358*$scale, 571*$scale, 574*$scale, 571*$scale)

  $graphics.Dispose()
  $pen.Dispose(); $cover.Dispose(); $page.Dispose(); $bookmark.Dispose(); $linePen.Dispose()
  return $bitmap
}

Add-Type -ReferencedAssemblies ([System.Drawing.Graphics].Assembly.Location) @'
using System.Drawing;
using System.Drawing.Drawing2D;
public static class RoundedRectangles {
  public static void FillRoundedRectangle(this Graphics g, Brush brush, RectangleF r, float radius) {
    using (GraphicsPath path = Path(r, radius)) { g.FillPath(brush, path); }
  }
  public static void DrawRoundedRectangle(this Graphics g, Pen pen, RectangleF r, float radius) {
    using (GraphicsPath path = Path(r, radius)) { g.DrawPath(pen, path); }
  }
  private static GraphicsPath Path(RectangleF r, float radius) {
    float d = radius * 2;
    GraphicsPath path = new GraphicsPath();
    path.AddArc(r.X, r.Y, d, d, 180, 90);
    path.AddArc(r.Right-d, r.Y, d, d, 270, 90);
    path.AddArc(r.Right-d, r.Bottom-d, d, d, 0, 90);
    path.AddArc(r.X, r.Bottom-d, d, d, 90, 90);
    path.CloseFigure();
    return path;
  }
}
'@

function Save-Png([int]$size, [string]$path) {
  $bitmap = New-IconBitmap $size
  $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

$android = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($density in $android.Keys) { Save-Png $android[$density] (Join-Path $root "android/app/src/main/res/mipmap-$density/ic_launcher.png") }

$ios = @{
  'Icon-App-1024x1024@1x.png' = 1024; 'Icon-App-20x20@1x.png' = 20; 'Icon-App-20x20@2x.png' = 40; 'Icon-App-20x20@3x.png' = 60;
  'Icon-App-29x29@1x.png' = 29; 'Icon-App-29x29@2x.png' = 58; 'Icon-App-29x29@3x.png' = 87; 'Icon-App-40x40@1x.png' = 40;
  'Icon-App-40x40@2x.png' = 80; 'Icon-App-40x40@3x.png' = 120; 'Icon-App-60x60@2x.png' = 120; 'Icon-App-60x60@3x.png' = 180;
  'Icon-App-76x76@1x.png' = 76; 'Icon-App-76x76@2x.png' = 152; 'Icon-App-83.5x83.5@2x.png' = 167
}
foreach ($name in $ios.Keys) { Save-Png $ios[$name] (Join-Path $root "ios/Runner/Assets.xcassets/AppIcon.appiconset/$name") }

$macos = @(16, 32, 64, 128, 256, 512, 1024)
foreach ($size in $macos) { Save-Png $size (Join-Path $root "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png") }

Save-Png 512 (Join-Path $root 'web/favicon.png')
Save-Png 192 (Join-Path $root 'web/icons/Icon-192.png')
Save-Png 512 (Join-Path $root 'web/icons/Icon-512.png')
Save-Png 192 (Join-Path $root 'web/icons/Icon-maskable-192.png')
Save-Png 512 (Join-Path $root 'web/icons/Icon-maskable-512.png')

$windowsBitmap = New-IconBitmap 256
$icon = [System.Drawing.Icon]::FromHandle($windowsBitmap.GetHicon())
$stream = [System.IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
$icon.Save($stream)
$stream.Dispose(); $icon.Dispose(); $windowsBitmap.Dispose()
