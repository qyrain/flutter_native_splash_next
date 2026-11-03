import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'config.dart';

/// Renders Unicode text (Chinese, English, symbols) into a high-resolution
/// transparent RGBA [img.Image] at `@3x` pixel density.
///
/// Uses the host OS native vector font rasterizer (`AppKit/CoreText` on macOS,
/// `.NET System.Drawing` on Windows, `python3/Pillow` on Linux) with a pure-Dart
/// `package:image` bitmap font fallback.
class SplashTextRenderer {
  const SplashTextRenderer._();

  /// Renders [text] into a tightly-cropped transparent RGBA [img.Image].
  ///
  /// - [fontSizeSp]: Logical font size in `sp`/`pt` (automatically multiplied by `3` for `@3x`).
  /// - [colorHex]: Text color hex (e.g. `#2C3432`).
  /// - [bold]: Whether to use medium/bold font weight.
  /// - [fontFamily]: Optional system font family name (e.g. `"PingFang SC"`, `"SF Pro Display"`).
  /// - [fontFile]: Optional path to a `.ttf` / `.otf` / `.ttc` font file.
  static img.Image renderTextRgba({
    required String text,
    required double fontSizeSp,
    required String colorHex,
    bool bold = false,
    String? fontFamily,
    String? fontFile,
  }) {
    final fontSizePx = (fontSizeSp * 3.0).roundToDouble();
    final rgb = SplashConfig.parseRgb(colorHex);

    // 1. Try macOS native Cocoa/CoreText via built-in /usr/bin/osascript (supports PingFang SC & SF Pro)
    if (Platform.isMacOS) {
      final macImg = _renderWithMacOsCocoa(
        text: text,
        fontSizePx: fontSizePx,
        rgb: rgb,
        bold: bold,
        fontFamily: fontFamily,
        fontFile: fontFile,
      );
      if (macImg != null) return macImg;
    }

    // 2. Try Windows native .NET System.Drawing via PowerShell (supports Microsoft YaHei & Segoe UI)
    if (Platform.isWindows) {
      final winImg = _renderWithWindowsGdi(
        text: text,
        fontSizePx: fontSizePx,
        rgb: rgb,
        bold: bold,
        fontFamily: fontFamily,
        fontFile: fontFile,
      );
      if (winImg != null) return winImg;
    }

    // 3. Try Python3 + Pillow (cross-platform)
    final pyImg = _renderWithPythonPillow(
      text: text,
      fontSizePx: fontSizePx,
      rgb: rgb,
      bold: bold,
      fontFamily: fontFamily,
      fontFile: fontFile,
    );
    if (pyImg != null) return pyImg;

    // 4. Pure-Dart fallback using package:image bitmap font
    return _renderWithPureDartFallback(
      text: text,
      fontSizePx: fontSizePx,
      rgb: rgb,
    );
  }

  static img.Image? _renderWithMacOsCocoa({
    required String text,
    required double fontSizePx,
    required List<int> rgb,
    required bool bold,
    String? fontFamily,
    String? fontFile,
  }) {
    final tempDir = Directory.systemTemp.createTempSync('splash_txt_');
    final outPath = p.join(tempDir.path, 'text.png');
    try {
      final escapedText = text
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', ' ');
      final weightExpr =
          bold ? r'$.NSFontWeightMedium' : r'$.NSFontWeightRegular';
      final rNorm = (rgb[0] / 255.0).toStringAsFixed(6);
      final gNorm = (rgb[1] / 255.0).toStringAsFixed(6);
      final bNorm = (rgb[2] / 255.0).toStringAsFixed(6);
      final absFontFile = (fontFile != null && File(fontFile).existsSync())
          ? File(fontFile).absolute.path
          : null;

      final script = '''
ObjC.import("Cocoa");
ObjC.import("CoreText");
const text = \$("$escapedText");
let font = \$.NSFont.systemFontOfSizeWeight($fontSizePx, $weightExpr);
${absFontFile != null ? '''
const fontUrl = \$.NSURL.fileURLWithPath(\$(${_jsQuote(absFontFile)}));
\$.CTFontManagerRegisterFontsForURL(fontUrl, 1, null);
const descArr = \$.CTFontManagerCreateFontDescriptorsFromURL(fontUrl);
if (descArr && descArr.count > 0) {
  const f = \$.NSFont.fontWithDescriptorSize(descArr.objectAtIndex(0), $fontSizePx);
  if (f && !f.isNil()) font = f;
}
''' : ''}
${fontFamily != null ? '''
const namedFont = \$.NSFont.fontWithNameSize(\$(${_jsQuote(fontFamily)}), $fontSizePx);
if (namedFont && !namedFont.isNil()) font = namedFont;
''' : ''}
const color = \$.NSColor.colorWithSRGBRedGreenBlueAlpha($rNorm, $gNorm, $bNorm, 1.0);
const attrs = \$.NSMutableDictionary.alloc.init;
attrs.setObjectForKey(font, \$("NSFont"));
attrs.setObjectForKey(color, \$("NSColor"));
const size = text.sizeWithAttributes(attrs);
const padX = 12;
const padY = 8;
const w = Math.max(4, Math.ceil(size.width) + padX * 2);
const h = Math.max(4, Math.ceil(size.height) + padY * 2);
const rep = \$.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
  null, w, h, 8, 4, true, false, \$.NSCalibratedRGBColorSpace, 0, 0
);
const ctx = \$.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
\$.NSGraphicsContext.setCurrentContext(ctx);
text.drawAtPointWithAttributes(\$.NSMakePoint(padX, padY), attrs);
\$.NSGraphicsContext.setCurrentContext(null);
const pngData = rep.representationUsingTypeProperties(\$.NSBitmapImageFileTypePNG, \$.NSDictionary.dictionary);
pngData.writeToFileAtomically(\$(${_jsQuote(outPath)}), true);
''';

      final res = Process.runSync('/usr/bin/osascript', [
        '-l',
        'JavaScript',
        '-e',
        script,
      ]);
      if (res.exitCode == 0 && File(outPath).existsSync()) {
        final decoded = img.decodePng(File(outPath).readAsBytesSync());
        if (decoded != null) {
          return _trimTransparentBounds(decoded, padding: 2);
        }
      }
    } catch (_) {
      // Fall through
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
    return null;
  }

  static img.Image? _renderWithWindowsGdi({
    required String text,
    required double fontSizePx,
    required List<int> rgb,
    required bool bold,
    String? fontFamily,
    String? fontFile,
  }) {
    final tempDir = Directory.systemTemp.createTempSync('splash_txt_win_');
    final outPath = p.join(tempDir.path, 'text.png');
    try {
      final escaped = text.replaceAll("'", "''");
      final style = bold ? 'Bold' : 'Regular';
      final familyName = (fontFamily ?? 'Microsoft YaHei UI').replaceAll("'", "''");
      final absFontFile = (fontFile != null && File(fontFile).existsSync())
          ? File(fontFile).absolute.path.replaceAll("'", "''")
          : null;
      final psScript = '''
Add-Type -AssemblyName System.Drawing
${absFontFile != null ? '''
\$pfc = New-Object System.Drawing.Text.PrivateFontCollection
\$pfc.AddFontFile('$absFontFile')
\$font = New-Object System.Drawing.Font(\$pfc.Families[0], ${fontSizePx.round()}, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
''' : '''
\$font = New-Object System.Drawing.Font('$familyName', ${fontSizePx.round()}, [System.Drawing.FontStyle]::$style, [System.Drawing.GraphicsUnit]::Pixel)
'''}
\$bmpTmp = New-Object System.Drawing.Bitmap(1, 1)
\$gTmp = [System.Drawing.Graphics]::FromImage(\$bmpTmp)
\$size = \$gTmp.MeasureString('$escaped', \$font)
\$w = [Math]::Max(4, [int][Math]::Ceiling(\$size.Width) + 16)
\$h = [Math]::Max(4, [int][Math]::Ceiling(\$size.Height) + 12)
\$bmp = New-Object System.Drawing.Bitmap(\$w, \$h)
\$g = [System.Drawing.Graphics]::FromImage(\$bmp)
\$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
\$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, ${rgb[0]}, ${rgb[1]}, ${rgb[2]}))
\$g.DrawString('$escaped', \$font, \$brush, 8, 6)
\$bmp.Save('${outPath.replaceAll("'", "''")}', [System.Drawing.Imaging.ImageFormat]::Png)
''';
      final res = Process.runSync('powershell', [
        '-NoProfile',
        '-Command',
        psScript,
      ]);
      if (res.exitCode == 0 && File(outPath).existsSync()) {
        final decoded = img.decodePng(File(outPath).readAsBytesSync());
        if (decoded != null) {
          return _trimTransparentBounds(decoded, padding: 2);
        }
      }
    } catch (_) {
      // Fall through
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
    return null;
  }

  static img.Image? _renderWithPythonPillow({
    required String text,
    required double fontSizePx,
    required List<int> rgb,
    required bool bold,
    String? fontFamily,
    String? fontFile,
  }) {
    final tempDir = Directory.systemTemp.createTempSync('splash_txt_py_');
    final outPath = p.join(tempDir.path, 'text.png');
    try {
      final absFontFile = (fontFile != null && File(fontFile).existsSync())
          ? File(fontFile).absolute.path
          : null;
      final pyCode = '''
import sys
from PIL import Image, ImageDraw, ImageFont
text = ${_pyQuote(text)}
size = int(${fontSizePx.round()})
font = None
candidates = [
    ${absFontFile != null ? '${_pyQuote(absFontFile)},' : ''}
    ${fontFamily != null ? '${_pyQuote(fontFamily)},' : ''}
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]
for fp in candidates:
    try:
        font = ImageFont.truetype(fp, size)
        break
    except Exception:
        pass
if font is None:
    font = ImageFont.load_default()
dummy = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
d = ImageDraw.Draw(dummy)
bb = d.textbbox((0, 0), text, font=font)
w = max(4, bb[2] - bb[0] + 20)
h = max(4, bb[3] - bb[1] + 16)
im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
d2 = ImageDraw.Draw(im)
d2.text((10 - bb[0], 8 - bb[1]), text, font=font, fill=(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, 255))
im.save(${_pyQuote(outPath)})
''';
      final res = Process.runSync('python3', ['-c', pyCode]);
      if (res.exitCode == 0 && File(outPath).existsSync()) {
        final decoded = img.decodePng(File(outPath).readAsBytesSync());
        if (decoded != null) {
          return _trimTransparentBounds(decoded, padding: 2);
        }
      }
    } catch (_) {
      // Fall through
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
    return null;
  }

  static img.Image _renderWithPureDartFallback({
    required String text,
    required double fontSizePx,
    required List<int> rgb,
  }) {
    final baseW = math.max(64, text.length * 32 + 32);
    const baseH = 72;
    final canvas = img.Image(width: baseW, height: baseH, numChannels: 4);
    img.drawString(
      canvas,
      text,
      font: img.arial48,
      x: 8,
      y: 12,
      color: img.ColorRgba8(rgb[0], rgb[1], rgb[2], 255),
    );
    final trimmed = _trimTransparentBounds(canvas, padding: 4);
    final scale = fontSizePx / 48.0;
    if ((scale - 1.0).abs() < 0.08) return trimmed;
    return img.copyResize(
      trimmed,
      width: math.max(4, (trimmed.width * scale).round()),
      height: math.max(4, (trimmed.height * scale).round()),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// Trims excess transparent margin around [source] while leaving [padding] px on each side.
  static img.Image _trimTransparentBounds(img.Image source, {int padding = 2}) {
    int minX = source.width;
    int minY = source.height;
    int maxX = -1;
    int maxY = -1;

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (source.getPixel(x, y).a > 4) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return source;
    }

    final x0 = math.max(0, minX - padding);
    final y0 = math.max(0, minY - padding);
    final x1 = math.min(source.width - 1, maxX + padding);
    final y1 = math.min(source.height - 1, maxY + padding);

    return img.copyCrop(
      source,
      x: x0,
      y: y0,
      width: x1 - x0 + 1,
      height: y1 - y0 + 1,
    );
  }

  static String _jsQuote(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  static String _pyQuote(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}
