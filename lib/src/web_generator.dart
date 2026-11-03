import 'dart:io';
import 'dart:math' as math;

import 'config.dart';
import 'image_processor.dart';

/// Generates full-screen (`object-fit: cover`) native splash CSS/HTML in `web/index.html`,
/// with independent responsive layers for the top Logo + `appName` (`top: 28%`) and
/// optional bottom branding (`bottom: 48px`) so neither is ever cropped on 16:9 desktop monitors!
class WebSplashGenerator {
  const WebSplashGenerator._();

  static void generate({
    required SplashConfig config,
    required ProcessedSplashAssets? lightAssets,
    required ProcessedSplashAssets? darkAssets,
  }) {
    if (!Directory('web').existsSync()) {
      print('[Web] web/ directory not found, skipping.');
      return;
    }

    final indexFile = File('web/index.html');
    if (!indexFile.existsSync()) {
      print('[Web] web/index.html not found, skipping.');
      return;
    }

    print('[Web] Generating native splash screen in web/...');

    final hasSeparateLogo = lightAssets?.topLogoBlockRgba != null &&
        config.fullscreenImage == null;
    final hasSeparateBranding = lightAssets?.brandingRgba != null;

    if (lightAssets != null) {
      SplashImageProcessor.writePng(
        'web/splash/img/light.png',
        hasSeparateLogo
            ? lightAssets.webBackgroundRgb
            : lightAssets.iosBackgroundWithLogoRgb,
      );
      if (hasSeparateLogo) {
        SplashImageProcessor.writePng(
          'web/splash/img/logo.png',
          lightAssets.topLogoBlockRgba!,
        );
      } else {
        _deleteIfExists('web/splash/img/logo.png');
      }

      if (hasSeparateBranding) {
        SplashImageProcessor.writePng(
          'web/splash/img/branding.png',
          lightAssets.brandingRgba!,
        );
      } else {
        _deleteIfExists('web/splash/img/branding.png');
      }
    } else {
      _deleteIfExists('web/splash/img/light.png');
      _deleteIfExists('web/splash/img/logo.png');
      _deleteIfExists('web/splash/img/branding.png');
    }

    if (darkAssets != null) {
      SplashImageProcessor.writePng(
        'web/splash/img/dark.png',
        hasSeparateLogo
            ? darkAssets.webBackgroundRgb
            : darkAssets.iosBackgroundWithLogoRgb,
      );
      if (hasSeparateLogo && darkAssets.topLogoBlockRgba != null) {
        SplashImageProcessor.writePng(
          'web/splash/img/logo-dark.png',
          darkAssets.topLogoBlockRgba!,
        );
      } else {
        _deleteIfExists('web/splash/img/logo-dark.png');
      }

      if (hasSeparateBranding && darkAssets.brandingRgba != null) {
        SplashImageProcessor.writePng(
          'web/splash/img/branding-dark.png',
          darkAssets.brandingRgba!,
        );
      } else {
        _deleteIfExists('web/splash/img/branding-dark.png');
      }
    } else {
      _deleteIfExists('web/splash/img/dark.png');
      _deleteIfExists('web/splash/img/logo-dark.png');
      _deleteIfExists('web/splash/img/branding-dark.png');
    }

    var html = indexFile.readAsStringSync();
    // Clean any previously injected splash blocks
    html = html.replaceAll(
      RegExp(r'\s*<style id="splash-screen-style">[\s\S]*?</style>'),
      '',
    );
    html = html.replaceAll(
      RegExp(r'\s*<picture id="splash-logo-picture">[\s\S]*?</picture>'),
      '',
    );
    html = html.replaceAll(
      RegExp(r'\s*<picture id="splash-branding-picture">[\s\S]*?</picture>'),
      '',
    );
    html = html.replaceAll(
      RegExp(r'\s*<picture id="splash">[\s\S]*?</picture>'),
      '',
    );

    final darkBg = config.darkColor ?? config.color;
    final topPercent = (config.logoTopRatio * 100.0).toStringAsFixed(1);
    final logoCssW = hasSeparateLogo
        ? math.max(1, (lightAssets!.topLogoBlockRgba!.width / 3.0).round())
        : 120;
    final brandCssW = hasSeparateBranding
        ? math.max(1, (lightAssets!.brandingRgba!.width / 3.0).round())
        : 100;

    final logoCssRule = hasSeparateLogo
        ? '''
    #splash-logo {
      position: fixed;
      top: $topPercent%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: ${logoCssW}px;
      height: auto;
      z-index: 9999;
      pointer-events: none;
    }'''
        : '';

    final brandCssRule = hasSeparateBranding
        ? '''
    #splash-branding {
      position: fixed;
      bottom: ${config.brandingBottomPadding}px;
      left: 50%;
      transform: translateX(-50%);
      width: ${brandCssW}px;
      height: auto;
      z-index: 9999;
      pointer-events: none;
    }'''
        : '';

    final styleBlock = '''
  <style id="splash-screen-style">
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: ${config.color};
      overflow: hidden;
    }
    @media (prefers-color-scheme: dark) {
      html, body {
        background-color: $darkBg;
      }
    }
    #splash {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
      z-index: 9998;
      pointer-events: none;
    }
    #splash img.splash-bg {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }$logoCssRule$brandCssRule
  </style>
</head>''';

    html = html.replaceFirst('</head>', styleBlock);

    if (lightAssets != null) {
      final darkSource = darkAssets != null
          ? '<source srcset="splash/img/dark.png" media="(prefers-color-scheme: dark)">'
          : '';
      final logoPicture = hasSeparateLogo
          ? '''
  <picture id="splash-logo-picture">
    ${darkAssets?.topLogoBlockRgba != null ? '<source srcset="splash/img/logo-dark.png" media="(prefers-color-scheme: dark)">' : ''}
    <img id="splash-logo" src="splash/img/logo.png" alt="" aria-hidden="true">
  </picture>'''
          : '';
      final brandPicture = hasSeparateBranding
          ? '''
  <picture id="splash-branding-picture">
    ${darkAssets?.brandingRgba != null ? '<source srcset="splash/img/branding-dark.png" media="(prefers-color-scheme: dark)">' : ''}
    <img id="splash-branding" src="splash/img/branding.png" alt="" aria-hidden="true">
  </picture>'''
          : '';

      final pictureBlock = '''<body>
  <picture id="splash">
    $darkSource
    <img class="splash-bg" src="splash/img/light.png" alt="" aria-hidden="true">
  </picture>$logoPicture$brandPicture''';
      html = html.replaceFirst('<body>', pictureBlock);
    }

    indexFile.writeAsStringSync(html);
    print('[Web] Splash screen configured successfully.');
  }

  /// Removes generated Web splash assets and injected HTML/CSS tags from `web/index.html`.
  static void remove() {
    if (!Directory('web').existsSync()) return;

    print('[Web] Removing splash screen from web/...');
    final splashDir = Directory('web/splash');
    if (splashDir.existsSync()) {
      splashDir.deleteSync(recursive: true);
    }

    final indexFile = File('web/index.html');
    if (indexFile.existsSync()) {
      var html = indexFile.readAsStringSync();
      html = html.replaceAll(
        RegExp(r'\s*<style id="splash-screen-style">[\s\S]*?</style>'),
        '',
      );
      html = html.replaceAll(
        RegExp(r'\s*<picture id="splash-logo-picture">[\s\S]*?</picture>'),
        '',
      );
      html = html.replaceAll(
        RegExp(r'\s*<picture id="splash-branding-picture">[\s\S]*?</picture>'),
        '',
      );
      html = html.replaceAll(
        RegExp(r'\s*<picture id="splash">[\s\S]*?</picture>'),
        '',
      );
      indexFile.writeAsStringSync(html);
    }

    print('[Web] Default splash screen restored.');
  }

  static void _deleteIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
