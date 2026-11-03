import 'dart:io';

import 'package:xml/xml.dart';

import 'config.dart';
import 'image_processor.dart';

/// Generates Android native splash resources (`drawable-xxhdpi/bg_splash.png`,
/// `drawable-xxhdpi/splash_brand.png`, `launch_background.xml`, and `values*/styles.xml`).
class AndroidSplashGenerator {
  const AndroidSplashGenerator._();

  static void generate({
    required SplashConfig config,
    required ProcessedSplashAssets? lightAssets,
    required ProcessedSplashAssets? darkAssets,
    String? flavor,
  }) {
    final resDir = flavor != null && flavor.isNotEmpty
        ? 'android/app/src/$flavor/res'
        : 'android/app/src/main/res';

    if (!Directory('android').existsSync()) {
      print('[Android] android/ directory not found, skipping.');
      return;
    }

    print('[Android] Generating native splash screen in $resDir...');

    final hasLightSplash = lightAssets != null;
    final hasLightBrand = lightAssets?.brandingRgba != null;

    if (lightAssets != null) {
      SplashImageProcessor.writePng(
        '$resDir/drawable-xxhdpi/bg_splash.png',
        lightAssets.androidSquareBleedRgb,
      );
      if (lightAssets.brandingRgba != null) {
        SplashImageProcessor.writePng(
          '$resDir/drawable-xxhdpi/splash_brand.png',
          lightAssets.brandingRgba!,
        );
      } else {
        _deleteIfExists('$resDir/drawable-xxhdpi/splash_brand.png');
      }
    } else {
      _deleteIfExists('$resDir/drawable-xxhdpi/bg_splash.png');
      _deleteIfExists('$resDir/drawable-xxhdpi/splash_brand.png');
    }

    final hasDarkConfig = config.darkColor != null || darkAssets != null;
    if (darkAssets != null) {
      SplashImageProcessor.writePng(
        '$resDir/drawable-night-xxhdpi/bg_splash.png',
        darkAssets.androidSquareBleedRgb,
      );
      if (darkAssets.brandingRgba != null) {
        SplashImageProcessor.writePng(
          '$resDir/drawable-night-xxhdpi/splash_brand.png',
          darkAssets.brandingRgba!,
        );
      } else {
        _deleteIfExists('$resDir/drawable-night-xxhdpi/splash_brand.png');
      }
    } else {
      _deleteIfExists('$resDir/drawable-night-xxhdpi/bg_splash.png');
      _deleteIfExists('$resDir/drawable-night-xxhdpi/splash_brand.png');
    }

    final lightXml = _buildLaunchBackgroundXml(
      colorHex: config.color,
      hasBgSplash: hasLightSplash,
      hasBrandSplash: hasLightBrand,
      brandBottomPaddingDp: config.brandingBottomPadding,
    );
    _writeTextFile('$resDir/drawable/launch_background.xml', lightXml);
    _writeTextFile('$resDir/drawable-v21/launch_background.xml', lightXml);

    if (hasDarkConfig) {
      final darkXml = _buildLaunchBackgroundXml(
        colorHex: config.darkColor ?? config.color,
        hasBgSplash: (darkAssets ?? lightAssets) != null,
        hasBrandSplash:
            (darkAssets?.brandingRgba ?? lightAssets?.brandingRgba) != null,
        brandBottomPaddingDp: config.brandingBottomPadding,
      );
      _writeTextFile('$resDir/drawable-night/launch_background.xml', darkXml);
      _writeTextFile(
        '$resDir/drawable-night-v21/launch_background.xml',
        darkXml,
      );
    }

    final styleTargets = <MapEntry<String, bool>>[
      const MapEntry('values/styles.xml', false),
      const MapEntry('values-night/styles.xml', true),
      const MapEntry('values-v31/styles.xml', false),
      const MapEntry('values-night-v31/styles.xml', true),
      if (File('$resDir/values-v33/styles.xml').existsSync())
        const MapEntry('values-v33/styles.xml', false),
      if (File('$resDir/values-night-v33/styles.xml').existsSync())
        const MapEntry('values-night-v33/styles.xml', true),
    ];

    for (final entry in styleTargets) {
      _updateStylesXml(
        filePath: '$resDir/${entry.key}',
        isDark: entry.value,
        fullscreen: config.fullscreen,
        androidFullscreenMode: config.androidFullscreenMode,
      );
    }

    print('[Android] Splash screen configured successfully.');
  }

  static String _buildLaunchBackgroundXml({
    required String colorHex,
    required bool hasBgSplash,
    required bool hasBrandSplash,
    required int brandBottomPaddingDp,
  }) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="utf-8"?>')
      ..writeln(
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">',
      )
      ..writeln('    <item>')
      ..writeln('        <color android:color="$colorHex" />')
      ..writeln('    </item>');

    if (hasBgSplash) {
      buffer
        ..writeln('    <item>')
        ..writeln('        <bitmap')
        ..writeln('            android:gravity="center"')
        ..writeln('            android:src="@drawable/bg_splash" />')
        ..writeln('    </item>');
    }

    if (hasBrandSplash) {
      buffer
        ..writeln('    <item android:bottom="${brandBottomPaddingDp}dp">')
        ..writeln('        <bitmap')
        ..writeln('            android:gravity="bottom|center_horizontal"')
        ..writeln('            android:src="@drawable/splash_brand" />')
        ..writeln('    </item>');
    }

    buffer.writeln('</layer-list>');
    return buffer.toString();
  }

  static void _updateStylesXml({
    required String filePath,
    required bool isDark,
    required bool fullscreen,
    required bool androidFullscreenMode,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) {
      final parentTheme = isDark
          ? '@android:style/Theme.Black.NoTitleBar'
          : '@android:style/Theme.Light.NoTitleBar';
      final defaultXml = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="$parentTheme">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:windowFullscreen">$fullscreen</item>
        <item name="android:windowDrawsSystemBarBackgrounds">$fullscreen</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
    <style name="NormalTheme" parent="$parentTheme">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''';
      _writeTextFile(filePath, defaultXml);
      return;
    }

    final doc = XmlDocument.parse(file.readAsStringSync());
    final resources = doc.getElement('resources');
    if (resources == null) return;

    XmlElement? launchTheme;
    for (final style in resources.findElements('style')) {
      if (style.getAttribute('name') == 'LaunchTheme') {
        launchTheme = style;
        break;
      }
    }
    if (launchTheme == null) return;

    if (androidFullscreenMode) {
      _removeStyleItem(launchTheme, 'android:windowSplashScreenBackground');
      _removeStyleItem(launchTheme, 'android:windowSplashScreenAnimatedIcon');
      _removeStyleItem(launchTheme, 'android:windowSplashScreenBrandingImage');
      _removeStyleItem(
        launchTheme,
        'android:windowSplashScreenIconBackgroundColor',
      );
    }

    _setStyleItem(
      launchTheme,
      'android:windowBackground',
      '@drawable/launch_background',
    );
    _setStyleItem(launchTheme, 'android:forceDarkAllowed', 'false');
    _setStyleItem(
      launchTheme,
      'android:windowFullscreen',
      fullscreen.toString(),
    );
    _setStyleItem(
      launchTheme,
      'android:windowDrawsSystemBarBackgrounds',
      fullscreen.toString(),
    );
    _setStyleItem(
      launchTheme,
      'android:windowLayoutInDisplayCutoutMode',
      'shortEdges',
    );

    file.writeAsStringSync(
      '${doc.toXmlString(pretty: true, indent: '    ')}\n',
    );
  }

  static void _setStyleItem(XmlElement style, String name, String value) {
    _removeStyleItem(style, name);
    style.children.add(
      XmlElement(
        XmlName('item'),
        [XmlAttribute(XmlName('name'), name)],
        [XmlText(value)],
      ),
    );
  }

  static void _removeStyleItem(XmlElement style, String name) {
    style.children.removeWhere(
      (node) =>
          node is XmlElement &&
          node.name.local == 'item' &&
          node.getAttribute('name') == name,
    );
  }

  static void _writeTextFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  static void _deleteIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
