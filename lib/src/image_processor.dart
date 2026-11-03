import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'config.dart';
import 'text_renderer.dart';

/// Result of processing the splash artwork for Android, iOS, HarmonyOS, and Web.
class ProcessedSplashAssets {
  /// Full-screen master image (`1242x2688` `@3x` RGB, including bottom branding)
  /// used for HarmonyOS NEXT `start_window.json` + `Index.ets` two-stage handover.
  final img.Image masterFullscreenRgb;

  /// Full-screen `1242x2688` `@3x` RGB image containing the background + top Logo/AppName
  /// WITHOUT the bottom branding (so iOS `LaunchScreen.storyboard` can pin the
  /// bottom branding as a separate `UIImageView` at `brandingBottomPadding` pt!).
  final img.Image iosBackgroundWithLogoRgb;

  /// Pure background `1242x2688` `@3x` RGB image (for Web responsive background).
  final img.Image webBackgroundRgb;

  /// Optional combined top Logo + `appName` RGBA image (`@3x`, for Web responsive positioning).
  final img.Image? topLogoBlockRgba;

  /// Square bleed canvas (`2688x2688` RGB) for Android `drawable-xxhdpi/bg_splash.png`.
  final img.Image androidSquareBleedRgb;

  /// Optional bottom branding image (`@3x` transparent RGBA) used by:
  /// - Android (`drawable-xxhdpi/splash_brand.png` pinned at `brandingBottomPadding` dp)
  /// - iOS (`BrandingImage.imageset` pinned at `brandingBottomPadding` pt in `LaunchScreen.storyboard`)
  /// - Web (`web/splash/img/branding.png` pinned at `brandingBottomPadding` px in `index.html`)
  final img.Image? brandingRgba;

  const ProcessedSplashAssets({
    required this.masterFullscreenRgb,
    required this.iosBackgroundWithLogoRgb,
    required this.webBackgroundRgb,
    this.topLogoBlockRgba,
    required this.androidSquareBleedRgb,
    this.brandingRgba,
  });
}

/// Pure-Dart image processing engine for `flutter_native_splash_next`.
class SplashImageProcessor {
  const SplashImageProcessor._();

  /// Loads an image from disk and throws if unreadable.
  static img.Image loadImageFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Splash image asset not found', path);
    }
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      throw FormatException('Unable to decode image file: $path');
    }
    return decoded;
  }

  /// Flattens any semi-transparent pixels in [source] onto a solid [baseRgb] (`[R, G, B]`)
  /// canvas, returning an opaque 3-channel RGB image to prevent alpha ghosting.
  static img.Image flattenOntoRgb(img.Image source, List<int> baseRgb) {
    final out = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    final br = baseRgb[0];
    final bg = baseRgb[1];
    final bb = baseRgb[2];

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final p = source.getPixel(x, y);
        final a = source.numChannels >= 4 ? (p.a / 255.0) : 1.0;
        final r = (p.r * a + br * (1.0 - a)).round().clamp(0, 255);
        final g = (p.g * a + bg * (1.0 - a)).round().clamp(0, 255);
        final b = (p.b * a + bb * (1.0 - a)).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  /// Applies a rounded corner mask (`[radiusPx]`) to [source], returning an RGBA image.
  static img.Image applyRoundedCorners(img.Image source, double radiusPx) {
    if (radiusPx <= 0.5) return source;
    final w = source.width;
    final h = source.height;
    final r = math.min(radiusPx, math.min(w, h) / 2.0);
    final out = img.Image(width: w, height: h, numChannels: 4);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        final srcAlpha = source.numChannels >= 4 ? p.a.toDouble() : 255.0;
        double cornerAlpha = 1.0;

        // Check distance to the 4 corner circles with 1px anti-aliased feathering
        double? dx;
        double? dy;
        if (x < r && y < r) {
          dx = r - (x + 0.5);
          dy = r - (y + 0.5);
        } else if (x >= w - r && y < r) {
          dx = (x + 0.5) - (w - r);
          dy = r - (y + 0.5);
        } else if (x < r && y >= h - r) {
          dx = r - (x + 0.5);
          dy = (y + 0.5) - (h - r);
        } else if (x >= w - r && y >= h - r) {
          dx = (x + 0.5) - (w - r);
          dy = (y + 0.5) - (h - r);
        }

        if (dx != null && dy != null && dx > 0 && dy > 0) {
          final dist = math.sqrt(dx * dx + dy * dy);
          cornerAlpha = (r + 0.5 - dist).clamp(0.0, 1.0);
        }

        final finalA = (srcAlpha * cornerAlpha).round().clamp(0, 255);
        out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), finalA);
      }
    }
    return out;
  }

  /// Builds the combined top Logo + optional `appName` block at `@3x` resolution.
  static img.Image? buildTopLogoBlock({
    required SplashConfig config,
    required bool dark,
  }) {
    final logoPath = dark ? (config.darkImage ?? config.image) : config.image;
    final appName = config.appName;

    img.Image? logoRgba;
    if (logoPath != null) {
      var rawLogo = loadImageFile(logoPath);
      if (config.logoSize != null && config.logoSize! > 0) {
        final targetPx = (config.logoSize! * 3.0).round();
        rawLogo = img.copyResize(
          rawLogo,
          width: targetPx,
          height: targetPx,
          interpolation: img.Interpolation.cubic,
        );
      }
      if (config.logoBorderRadius > 0) {
        rawLogo = applyRoundedCorners(rawLogo, config.logoBorderRadius * 3.0);
      }
      logoRgba = rawLogo;
    }

    img.Image? titleRgba;
    if (appName != null && appName.isNotEmpty) {
      final titleColor = dark
          ? (config.appNameDarkColor ?? config.appNameColor)
          : config.appNameColor;
      titleRgba = SplashTextRenderer.renderTextRgba(
        text: appName,
        fontSizeSp: config.appNameSize,
        colorHex: titleColor,
        bold: config.appNameBold,
        fontFamily: config.appNameFontFamily,
        fontFile: config.appNameFontFile,
      );
    }

    if (logoRgba == null && titleRgba == null) return null;
    if (logoRgba != null && titleRgba == null) return logoRgba;
    if (logoRgba == null && titleRgba != null) return titleRgba;

    final spacingPx = (config.appNameSpacing * 3.0).round();
    final blockW = math.max(logoRgba!.width, titleRgba!.width);
    final blockH = logoRgba.height + spacingPx + titleRgba.height;
    final combined = img.Image(width: blockW, height: blockH, numChannels: 4);

    img.compositeImage(
      combined,
      logoRgba,
      dstX: (blockW - logoRgba.width) ~/ 2,
      dstY: 0,
    );
    img.compositeImage(
      combined,
      titleRgba,
      dstX: (blockW - titleRgba.width) ~/ 2,
      dstY: logoRgba.height + spacingPx,
    );
    return combined;
  }

  /// Builds the bottom branding RGBA image (`@3x`) from either `brandingText` or `brandingImage`.
  static img.Image? buildBottomBrandingBlock({
    required SplashConfig config,
    required bool dark,
  }) {
    final brandText = config.brandingText;
    if (brandText != null && brandText.isNotEmpty) {
      final textColor = dark
          ? (config.brandingTextDarkColor ?? config.brandingTextColor)
          : config.brandingTextColor;
      return SplashTextRenderer.renderTextRgba(
        text: brandText,
        fontSizeSp: config.brandingTextSize,
        colorHex: textColor,
        bold: config.brandingTextBold,
        fontFamily: config.brandingFontFamily,
        fontFile: config.brandingFontFile,
      );
    }

    final brandPath = dark
        ? (config.darkBrandingImage ?? config.brandingImage)
        : config.brandingImage;
    if (brandPath != null) {
      var rawBrand = loadImageFile(brandPath);
      if (config.brandingImageHeight != null &&
          config.brandingImageHeight! > 0) {
        final targetH = (config.brandingImageHeight! * 3.0).round();
        final targetW =
            math.max(1, (rawBrand.width * (targetH / rawBrand.height)).round());
        rawBrand = img.copyResize(
          rawBrand,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.cubic,
        );
      }
      return rawBrand;
    }

    return null;
  }

  /// Builds all platform splash images from [config] (either for light or dark mode).
  static ProcessedSplashAssets? buildAssets({
    required SplashConfig config,
    bool dark = false,
  }) {
    final hexColor = dark ? (config.darkColor ?? config.color) : config.color;
    final baseRgb = SplashConfig.parseRgb(hexColor);

    final fullPath = dark
        ? (config.darkFullscreenImage ?? config.fullscreenImage)
        : config.fullscreenImage;
    final bgPath = dark
        ? (config.darkBackgroundImage ?? config.backgroundImage)
        : config.backgroundImage;

    final topLogoBlock = buildTopLogoBlock(config: config, dark: dark);
    var bottomBrandingRgba = buildBottomBrandingBlock(
      config: config,
      dark: dark,
    );

    if (fullPath == null &&
        bgPath == null &&
        topLogoBlock == null &&
        bottomBrandingRgba == null) {
      return null;
    }

    const masterW = 1242;
    const masterH = 2688;

    late img.Image webBgRgb;
    late img.Image bgWithLogoRgb;

    if (fullPath != null) {
      final rawFull = loadImageFile(fullPath);
      bgWithLogoRgb = flattenOntoRgb(rawFull, baseRgb);
      webBgRgb = bgWithLogoRgb.clone();
    } else {
      if (bgPath != null) {
        final rawBg = loadImageFile(bgPath);
        final flatBg = flattenOntoRgb(rawBg, baseRgb);
        webBgRgb = img.copyResize(
          flatBg,
          width: masterW,
          height: masterH,
          interpolation: img.Interpolation.cubic,
        );
      } else {
        webBgRgb = img.Image(width: masterW, height: masterH, numChannels: 3);
        img.fill(
          webBgRgb,
          color: img.ColorRgb8(baseRgb[0], baseRgb[1], baseRgb[2]),
        );
      }

      bgWithLogoRgb = webBgRgb.clone();
      if (topLogoBlock != null) {
        final dstX = (bgWithLogoRgb.width - topLogoBlock.width) ~/ 2;
        final dstY =
            (bgWithLogoRgb.height * config.logoTopRatio - topLogoBlock.height / 2)
                .round();
        img.compositeImage(
          bgWithLogoRgb,
          topLogoBlock,
          dstX: dstX,
          dstY: dstY,
        );
      }
    }

    // Scale bgWithLogoRgb to Android xxhdpi safe width (1080px = 360dp)
    final safeW = config.androidSafeWidth;
    final safeH =
        (bgWithLogoRgb.height * (safeW / bgWithLogoRgb.width)).round();
    final scaledAndroidRgb = img.copyResize(
      bgWithLogoRgb,
      width: safeW,
      height: safeH,
      interpolation: img.Interpolation.cubic,
    );

    // If single fullscreen_image + autoExtractBranding is enabled, extract branding & erase from both
    // scaledAndroidRgb and bgWithLogoRgb (so iOS and Web also get a clean background + separate branding layer!)
    if (config.autoExtractBranding && fullPath != null) {
      final box = config.brandingSourceBox;
      final mx0 = box[0].clamp(20, bgWithLogoRgb.width - 21);
      final my0 = box[1].clamp(20, bgWithLogoRgb.height - 21);
      final mx1 = box[2].clamp(mx0 + 10, bgWithLogoRgb.width - 20);
      final my1 = box[3].clamp(my0 + 10, bgWithLogoRgb.height - 20);

      final scaleX = safeW / bgWithLogoRgb.width;
      final scaleY = safeH / bgWithLogoRgb.height;
      final ax0 = (mx0 * scaleX).round().clamp(20, safeW - 21);
      final ay0 = (my0 * scaleY).round().clamp(20, safeH - 21);
      final ax1 = (mx1 * scaleX).round().clamp(ax0 + 10, safeW - 20);
      final ay1 = (my1 * scaleY).round().clamp(ay0 + 10, safeH - 20);

      bottomBrandingRgba ??= extractTransparentBranding(
        scaledAndroidRgb,
        x0: ax0,
        y0: ay0,
        x1: ax1,
        y1: ay1,
      );

      // Only erase the bottom region if visible branding text was actually detected
      if (bottomBrandingRgba != null) {
        eraseRegionWithHorizontalInterpolation(
          scaledAndroidRgb,
          x0: math.max(20, ax0 - 10),
          y0: math.max(20, ay0 - 6),
          x1: math.min(safeW - 20, ax1 + 10),
          y1: math.min(safeH - 20, ay1 + 6),
        );

        eraseRegionWithHorizontalInterpolation(
          bgWithLogoRgb,
          x0: math.max(20, mx0 - 12),
          y0: math.max(20, my0 - 8),
          x1: math.min(bgWithLogoRgb.width - 20, mx1 + 12),
          y1: math.min(bgWithLogoRgb.height - 20, my1 + 8),
        );
        webBgRgb = bgWithLogoRgb.clone();
      }
    } else if (topLogoBlock != null && fullPath != null) {
      // Allow overlaying custom logo/app_name even when fullscreen_image is used as background
      final dstX = (bgWithLogoRgb.width - topLogoBlock.width) ~/ 2;
      final dstY =
          (bgWithLogoRgb.height * config.logoTopRatio - topLogoBlock.height / 2)
              .round();
      img.compositeImage(
        bgWithLogoRgb,
        topLogoBlock,
        dstX: dstX,
        dstY: dstY,
      );
    }

    // Build masterFullscreenRgb (1242x2688 with bottom branding composited for HarmonyOS NEXT)
    final masterFullRgb = bgWithLogoRgb.clone();
    if (bottomBrandingRgba != null) {
      final brandBottomPx = config.brandingBottomPadding * 3;
      final dstX = (masterFullRgb.width - bottomBrandingRgba.width) ~/ 2;
      final dstY =
          masterFullRgb.height - brandBottomPx - bottomBrandingRgba.height;
      img.compositeImage(
        masterFullRgb,
        bottomBrandingRgba,
        dstX: dstX,
        dstY: dstY,
      );
    }

    // Expand scaledAndroidRgb onto the 2688x2688 square bleed canvas
    final bleedCanvas = buildSquareBleedCanvas(
      scaledAndroidRgb,
      canvasSize: config.androidBleedCanvasSize,
    );

    return ProcessedSplashAssets(
      masterFullscreenRgb: masterFullRgb,
      iosBackgroundWithLogoRgb: bgWithLogoRgb,
      webBackgroundRgb: webBgRgb,
      topLogoBlockRgba: topLogoBlock,
      androidSquareBleedRgb: bleedCanvas,
      brandingRgba: bottomBrandingRgba,
    );
  }

  /// Extracts dark branding text from a light pastel background region `[x0, y0, x1, y1]`
  /// into a clean transparent RGBA image.
  ///
  /// Returns `null` if the region contains no visible foreground text/graphics
  /// (so images without bottom text are automatically handled cleanly).
  static img.Image? extractTransparentBranding(
    img.Image sourceRgb, {
    required int x0,
    required int y0,
    required int x1,
    required int y1,
  }) {
    final cw = x1 - x0;
    final ch = y1 - y0;
    final out = img.Image(width: cw, height: ch, numChannels: 4);
    int visiblePixelCount = 0;

    for (var y = 0; y < ch; y++) {
      final sy = y0 + y;
      double leftLuma = 0;
      double rightLuma = 0;
      for (var i = 0; i < 15; i++) {
        final pl = sourceRgb.getPixel(x0 + i, sy);
        final pr = sourceRgb.getPixel(x1 - 1 - i, sy);
        leftLuma += (pl.r + pl.g + pl.b) / 3.0;
        rightLuma += (pr.r + pr.g + pr.b) / 3.0;
      }
      leftLuma /= 15.0;
      rightLuma /= 15.0;

      for (var x = 0; x < cw; x++) {
        final sx = x0 + x;
        final t = cw > 1 ? x / (cw - 1) : 0.0;
        final bgLuma = (1.0 - t) * leftLuma + t * rightLuma;
        final p = sourceRgb.getPixel(sx, sy);
        final pxLuma = (p.r + p.g + p.b) / 3.0;
        const textLuma = 53.7;
        final denom = math.max(1.0, bgLuma - textLuma);
        var alpha = ((bgLuma - pxLuma) / denom).clamp(0.0, 1.0);
        if (alpha < 0.04) {
          alpha = 0.0;
        } else if (alpha > 0.20) {
          visiblePixelCount++;
        }
        out.setPixelRgba(x, y, 52, 55, 54, (alpha * 255.0).round());
      }
    }

    if (visiblePixelCount < 10) {
      return null;
    }
    return out;
  }

  /// Smoothly erases a rectangular region `[x0, y0, x1, y1]` in a 3-channel RGB image
  /// by linearly interpolating between the clean left and right margin strips.
  static void eraseRegionWithHorizontalInterpolation(
    img.Image targetRgb, {
    required int x0,
    required int y0,
    required int x1,
    required int y1,
  }) {
    final ew = x1 - x0;
    for (var y = y0; y < y1; y++) {
      double lr = 0, lg = 0, lb = 0;
      double rr = 0, rg = 0, rb = 0;
      const strip = 20;
      for (var i = 0; i < strip; i++) {
        final pl = targetRgb.getPixel(x0 - strip + i, y);
        final pr = targetRgb.getPixel(x1 + i, y);
        lr += pl.r;
        lg += pl.g;
        lb += pl.b;
        rr += pr.r;
        rg += pr.g;
        rb += pr.b;
      }
      lr /= strip;
      lg /= strip;
      lb /= strip;
      rr /= strip;
      rg /= strip;
      rb /= strip;

      for (var x = 0; x < ew; x++) {
        final t = ew > 1 ? x / (ew - 1) : 0.0;
        final r = ((1.0 - t) * lr + t * rr).round().clamp(0, 255);
        final g = ((1.0 - t) * lg + t * rg).round().clamp(0, 255);
        final b = ((1.0 - t) * lb + t * rb).round().clamp(0, 255);
        targetRgb.setPixelRgb(x0 + x, y, r, g, b);
      }
    }
  }

  /// Places [coreRgb] (`1080x2337`) in the center of a `[canvasSize]x[canvasSize]`
  /// (`2688x2688`) square canvas and smoothly extends the 4 edges to form a
  /// seamless bleed area for Android `gravity="center"`.
  static img.Image buildSquareBleedCanvas(
    img.Image coreRgb, {
    int canvasSize = 2688,
  }) {
    final side = math.max(canvasSize, math.max(coreRgb.width, coreRgb.height));
    final canvas = img.Image(width: side, height: side, numChannels: 3);

    final x0 = (side - coreRgb.width) ~/ 2;
    final y0 = (side - coreRgb.height) ~/ 2;
    final x1 = x0 + coreRgb.width;
    final y1 = y0 + coreRgb.height;

    for (var y = 0; y < coreRgb.height; y++) {
      for (var x = 0; x < coreRgb.width; x++) {
        final p = coreRgb.getPixel(x, y);
        canvas.setPixelRgb(
          x0 + x,
          y0 + y,
          p.r.toInt(),
          p.g.toInt(),
          p.b.toInt(),
        );
      }
    }

    final edgeSample = math.min(24, coreRgb.width);
    for (var y = 0; y < coreRgb.height; y++) {
      double lr = 0, lg = 0, lb = 0;
      double rr = 0, rg = 0, rb = 0;
      for (var i = 0; i < edgeSample; i++) {
        final pl = coreRgb.getPixel(i, y);
        final pr = coreRgb.getPixel(coreRgb.width - 1 - i, y);
        lr += pl.r;
        lg += pl.g;
        lb += pl.b;
        rr += pr.r;
        rg += pr.g;
        rb += pr.b;
      }
      final lR = (lr / edgeSample).round().clamp(0, 255);
      final lG = (lg / edgeSample).round().clamp(0, 255);
      final lB = (lb / edgeSample).round().clamp(0, 255);
      final rR = (rr / edgeSample).round().clamp(0, 255);
      final rG = (rg / edgeSample).round().clamp(0, 255);
      final rB = (rb / edgeSample).round().clamp(0, 255);

      final cy = y0 + y;
      for (var x = 0; x < x0; x++) {
        canvas.setPixelRgb(x, cy, lR, lG, lB);
      }
      for (var x = x1; x < side; x++) {
        canvas.setPixelRgb(x, cy, rR, rG, rB);
      }
    }

    final vSample = math.min(24, coreRgb.height);
    for (var x = 0; x < side; x++) {
      double tr = 0, tg = 0, tb = 0;
      double br = 0, bg = 0, bb = 0;
      for (var i = 0; i < vSample; i++) {
        final pt = canvas.getPixel(x, y0 + i);
        final pb = canvas.getPixel(x, y1 - 1 - i);
        tr += pt.r;
        tg += pt.g;
        tb += pt.b;
        br += pb.r;
        bg += pb.g;
        bb += pb.b;
      }
      final tR = (tr / vSample).round().clamp(0, 255);
      final tG = (tg / vSample).round().clamp(0, 255);
      final tB = (tb / vSample).round().clamp(0, 255);
      final bR = (br / vSample).round().clamp(0, 255);
      final bG = (bg / vSample).round().clamp(0, 255);
      final bB = (bb / vSample).round().clamp(0, 255);

      for (var y = 0; y < y0; y++) {
        canvas.setPixelRgb(x, y, tR, tG, tB);
      }
      for (var y = y1; y < side; y++) {
        canvas.setPixelRgb(x, y, bR, bG, bB);
      }
    }

    return canvas;
  }

  /// Writes an [img.Image] as PNG to [filePath], creating parent directories if needed.
  static void writePng(String filePath, img.Image image) {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
  }
}
