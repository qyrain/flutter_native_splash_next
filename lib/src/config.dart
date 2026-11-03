import 'dart:io';

import 'package:yaml/yaml.dart';

/// Parsed configuration for `flutter_native_splash_next`.
class SplashConfig {
  /// Base background color hex (always normalized with leading `#`, e.g. `#EFF7F4`).
  final String color;

  /// Optional dark mode background color hex (e.g. `#121212`).
  final String? darkColor;

  /// Full-screen splash design image path (e.g. `1242x2688` iOS/HarmonyOS 3x art).
  final String? fullscreenImage;

  /// Optional dark-mode full-screen splash image path.
  final String? darkFullscreenImage;

  /// Optional background image path when compositing background + logo + app_name + branding.
  final String? backgroundImage;

  /// Optional dark-mode background image path.
  final String? darkBackgroundImage;

  /// Optional logo / app icon image path (`logo_image` or `image`).
  final String? image;

  /// Optional dark-mode logo image path (`logo_image_dark` or `image_dark`).
  final String? darkImage;

  /// Optional target logo width/height in `dp`/`pt` (e.g. `80` -> `240px` at `@3x`).
  /// When null, uses the source image's natural `@3x` pixel dimensions.
  final double? logoSize;

  /// Optional corner radius in `dp`/`pt` applied to [image] (e.g. `20` -> `60px` at `@3x`).
  /// Defaults to `0` (no additional rounding).
  final double logoBorderRadius;

  /// Vertical center ratio of the logo + product name block from the top of the screen.
  /// Defaults to `0.28` (28% golden ratio from the top).
  final double logoTopRatio;

  /// Optional product name text displayed below the logo (e.g. `"Rainier"`).
  final String? appName;

  /// Font size of [appName] in `sp`/`pt` (default `18`, which is `54px` at `@3x`).
  final double appNameSize;

  /// Text color hex of [appName] in light mode (default `#2C3432`).
  final String appNameColor;

  /// Optional text color hex of [appName] in dark mode.
  final String? appNameDarkColor;

  /// Vertical spacing in `dp`/`pt` between the bottom of the logo and [appName] (default `14`).
  final double appNameSpacing;

  /// Whether [appName] uses medium/bold weight (default `true`).
  final bool appNameBold;

  /// Optional system font family name for [appName] (e.g. `"PingFang SC"`, `"SF Pro Display"`).
  final String? appNameFontFamily;

  /// Optional path to a custom `.ttf` / `.otf` / `.ttc` font file for [appName].
  final String? appNameFontFile;

  /// Optional bottom branding text (e.g. `"Hi, Rainier"`).
  /// Can be used instead of [brandingImage] to render crisp text at the bottom!
  final String? brandingText;

  /// Font size of [brandingText] in `sp`/`pt` (default `13`, which is `39px` at `@3x`).
  final double brandingTextSize;

  /// Text color hex of [brandingText] in light mode (default `#343736`).
  final String brandingTextColor;

  /// Optional text color hex of [brandingText] in dark mode.
  final String? brandingTextDarkColor;

  /// Whether [brandingText] uses bold weight (default `false`).
  final bool brandingTextBold;

  /// Optional system font family name for [brandingText].
  final String? brandingFontFamily;

  /// Optional path to a custom `.ttf` / `.otf` / `.ttc` font file for [brandingText].
  final String? brandingFontFile;

  /// Optional bottom branding image path (e.g. transparent PNG).
  final String? brandingImage;

  /// Optional dark-mode bottom branding image path.
  final String? darkBrandingImage;

  /// Optional display height in `dp`/`pt` for [brandingImage] (scales width proportionally).
  final double? brandingImageHeight;

  /// Whether to automatically extract the bottom branding text from [fullscreenImage]
  /// into a separate branding layer and cleanly erase it from the background.
  final bool autoExtractBranding;

  /// Bounding box `[x0, y0, x1, y1]` in the source [fullscreenImage] (normalized to
  /// `1242x2688` coordinates) used when [autoExtractBranding] is true.
  final List<int> brandingSourceBox;

  /// Distance in `dp`/`pt`/`vp` from the bottom of the screen for the bottom branding.
  /// Defaults to `48`.
  final int brandingBottomPadding;

  /// Square bleed canvas size in pixels for `drawable-xxhdpi/bg_splash.png`.
  /// Defaults to `2688`.
  final int androidBleedCanvasSize;

  /// Target Android `xxhdpi` (`480dpi`) safe-area width in pixels when scaling
  /// a `1242px` (`414dp`) design. Defaults to `1080` (`360dp`).
  final int androidSafeWidth;

  /// Whether to enable Android 12–15+ full-screen `windowBackground` mode.
  final bool androidFullscreenMode;

  /// Whether to hide the status bar during splash launch. Defaults to `true`.
  final bool fullscreen;

  /// Enabled target platforms.
  final bool android;
  final bool ios;
  final bool ohos;
  final bool web;

  /// Optional custom HarmonyOS `module.json5` and `Index.ets` paths.
  final String ohosModuleJsonPath;
  final String ohosIndexEtsPath;

  const SplashConfig({
    required this.color,
    this.darkColor,
    this.fullscreenImage,
    this.darkFullscreenImage,
    this.backgroundImage,
    this.darkBackgroundImage,
    this.image,
    this.darkImage,
    this.logoSize,
    this.logoBorderRadius = 0,
    this.logoTopRatio = 0.28,
    this.appName,
    this.appNameSize = 18,
    this.appNameColor = '#2C3432',
    this.appNameDarkColor,
    this.appNameSpacing = 14,
    this.appNameBold = true,
    this.appNameFontFamily,
    this.appNameFontFile,
    this.brandingText,
    this.brandingTextSize = 13,
    this.brandingTextColor = '#343736',
    this.brandingTextDarkColor,
    this.brandingTextBold = false,
    this.brandingFontFamily,
    this.brandingFontFile,
    this.brandingImage,
    this.darkBrandingImage,
    this.brandingImageHeight,
    this.autoExtractBranding = false,
    this.brandingSourceBox = const [450, 2465, 795, 2560],
    this.brandingBottomPadding = 48,
    this.androidBleedCanvasSize = 2688,
    this.androidSafeWidth = 1080,
    required this.androidFullscreenMode,
    this.fullscreen = true,
    this.android = true,
    this.ios = true,
    this.ohos = true,
    this.web = true,
    this.ohosModuleJsonPath = 'ohos/entry/src/main/module.json5',
    this.ohosIndexEtsPath = 'ohos/entry/src/main/ets/pages/Index.ets',
  });

  /// Loads [SplashConfig] from `flutter_native_splash_next.yaml`,
  /// `flutter_native_splash.yaml`, or `pubspec.yaml`.
  factory SplashConfig.load({String? configPath, String? flavor}) {
    String resolvedPath;
    if (configPath != null && configPath.isNotEmpty) {
      resolvedPath = configPath;
    } else if (File('flutter_native_splash_next.yaml').existsSync()) {
      resolvedPath = 'flutter_native_splash_next.yaml';
    } else if (File('flutter_native_splash.yaml').existsSync()) {
      resolvedPath = 'flutter_native_splash.yaml';
    } else {
      resolvedPath = 'pubspec.yaml';
    }

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw FileSystemException('Configuration file not found', resolvedPath);
    }

    final yamlDoc = loadYaml(file.readAsStringSync());
    if (yamlDoc is! YamlMap) {
      throw const FormatException('Invalid YAML configuration file.');
    }

    final String baseKey = yamlDoc.containsKey('flutter_native_splash_next')
        ? 'flutter_native_splash_next'
        : 'flutter_native_splash';

    final String targetKey =
        flavor != null && flavor.isNotEmpty ? '$baseKey-$flavor' : baseKey;

    final dynamic section = yamlDoc[targetKey] ?? yamlDoc[baseKey];
    if (section is! YamlMap) {
      throw FormatException(
        'Could not find `$targetKey` section in $resolvedPath.',
      );
    }

    return SplashConfig.fromMap(Map<String, dynamic>.from(section));
  }

  /// Parses a [SplashConfig] from a raw configuration map (supports both flat keys
  /// and nested `logo:` / `branding:` maps).
  factory SplashConfig.fromMap(Map<String, dynamic> map) {
    final logoMap = map['logo'] is Map
        ? Map<String, dynamic>.from(map['logo'] as Map)
        : const <String, dynamic>{};
    final brandingMap = map['branding'] is Map
        ? Map<String, dynamic>.from(map['branding'] as Map)
        : const <String, dynamic>{};

    final color = normalizeHexColor(map['color']?.toString() ?? '#EFF7F4');
    final darkColor = map['color_dark'] != null
        ? normalizeHexColor(map['color_dark'].toString())
        : null;

    final fullscreenImage = _nonEmptyString(map['fullscreen_image']);
    final darkFullscreenImage = _nonEmptyString(map['fullscreen_image_dark']);
    final backgroundImage = _nonEmptyString(map['background_image']);
    final darkBackgroundImage = _nonEmptyString(map['background_image_dark']);

    final image = _nonEmptyString(logoMap['image']) ??
        _nonEmptyString(map['logo_image']) ??
        _nonEmptyString(map['image']);
    final darkImage = _nonEmptyString(logoMap['image_dark']) ??
        _nonEmptyString(map['logo_image_dark']) ??
        _nonEmptyString(map['image_dark']);

    final logoSize = _parseDouble(logoMap['size'] ?? map['logo_size']);
    final logoBorderRadius =
        _parseDouble(logoMap['border_radius'] ?? map['logo_border_radius']) ??
            0.0;
    final logoTopRatio =
        _parseDouble(logoMap['top_ratio'] ?? map['logo_top_ratio']) ?? 0.28;

    final appName = _nonEmptyString(logoMap['title']) ??
        _nonEmptyString(logoMap['app_name']) ??
        _nonEmptyString(map['app_name']);
    final appNameSize = _parseDouble(
          logoMap['title_size'] ??
              logoMap['app_name_size'] ??
              map['app_name_size'],
        ) ??
        18.0;
    final appNameColor = normalizeHexColor(
      (logoMap['title_color'] ??
              logoMap['app_name_color'] ??
              map['app_name_color'] ??
              '#2C3432')
          .toString(),
    );
    final rawAppNameDarkColor = _nonEmptyString(
      logoMap['title_color_dark'] ??
          logoMap['app_name_color_dark'] ??
          map['app_name_color_dark'],
    );
    final appNameDarkColor = rawAppNameDarkColor != null
        ? normalizeHexColor(rawAppNameDarkColor)
        : null;
    final appNameSpacing = _parseDouble(
          logoMap['title_spacing'] ??
              logoMap['app_name_spacing'] ??
              map['app_name_spacing'],
        ) ??
        14.0;
    final appNameBold = (logoMap['title_bold'] ??
            logoMap['app_name_bold'] ??
            map['app_name_bold']) as bool? ??
        true;
    final appNameFontFamily = _nonEmptyString(
      logoMap['font_family'] ??
          logoMap['title_font_family'] ??
          map['app_name_font_family'] ??
          map['font_family'],
    );
    final appNameFontFile = _nonEmptyString(
      logoMap['font_file'] ??
          logoMap['title_font_file'] ??
          map['app_name_font_file'] ??
          map['font_file'],
    );

    final brandingText = _nonEmptyString(brandingMap['text']) ??
        _nonEmptyString(map['branding_text']);
    final brandingTextSize = _parseDouble(
          brandingMap['text_size'] ?? map['branding_text_size'],
        ) ??
        13.0;
    final brandingTextColor = normalizeHexColor(
      (brandingMap['text_color'] ?? map['branding_text_color'] ?? '#343736')
          .toString(),
    );
    final rawBrandingTextDarkColor = _nonEmptyString(
      brandingMap['text_color_dark'] ?? map['branding_text_color_dark'],
    );
    final brandingTextDarkColor = rawBrandingTextDarkColor != null
        ? normalizeHexColor(rawBrandingTextDarkColor)
        : null;
    final brandingTextBold =
        (brandingMap['text_bold'] ?? map['branding_text_bold']) as bool? ??
            false;
    final brandingFontFamily = _nonEmptyString(
      brandingMap['font_family'] ??
          map['branding_font_family'] ??
          map['font_family'],
    );
    final brandingFontFile = _nonEmptyString(
      brandingMap['font_file'] ??
          map['branding_font_file'] ??
          map['font_file'],
    );

    final brandingImage = _nonEmptyString(brandingMap['image']) ??
        (map['branding'] is String ? _nonEmptyString(map['branding']) : null) ??
        _nonEmptyString(map['branding_image']);
    final darkBrandingImage = _nonEmptyString(brandingMap['image_dark']) ??
        _nonEmptyString(map['branding_dark']) ??
        _nonEmptyString(map['branding_dark_image']);
    final brandingImageHeight = _parseDouble(
      brandingMap['height'] ??
          brandingMap['image_height'] ??
          map['branding_image_height'],
    );

    final autoExtractBranding = map['auto_extract_branding'] as bool? ?? false;

    List<int> brandingBox = const [450, 2465, 795, 2560];
    if (map['branding_source_box'] is List) {
      final rawList = (map['branding_source_box'] as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .toList();
      if (rawList.length == 4) {
        brandingBox = rawList;
      }
    }

    final brandingBottomPadding = int.tryParse(
          (brandingMap['bottom_padding'] ??
                  map['branding_bottom_padding'] ??
                  48)
              .toString(),
        ) ??
        48;

    final androidBleedCanvasSize = int.tryParse(
          (map['android_bleed_canvas_size'] ?? 2688).toString(),
        ) ??
        2688;

    final androidSafeWidth = int.tryParse(
          (map['android_safe_width'] ?? 1080).toString(),
        ) ??
        1080;

    final bool hasSplashContent = fullscreenImage != null ||
        backgroundImage != null ||
        image != null ||
        appName != null ||
        brandingText != null ||
        brandingImage != null;
    final androidFullscreenMode =
        map['android_fullscreen_mode'] as bool? ?? hasSplashContent;

    return SplashConfig(
      color: color,
      darkColor: darkColor,
      fullscreenImage: fullscreenImage,
      darkFullscreenImage: darkFullscreenImage,
      backgroundImage: backgroundImage,
      darkBackgroundImage: darkBackgroundImage,
      image: image,
      darkImage: darkImage,
      logoSize: logoSize,
      logoBorderRadius: logoBorderRadius,
      logoTopRatio: logoTopRatio,
      appName: appName,
      appNameSize: appNameSize,
      appNameColor: appNameColor,
      appNameDarkColor: appNameDarkColor,
      appNameSpacing: appNameSpacing,
      appNameBold: appNameBold,
      appNameFontFamily: appNameFontFamily,
      appNameFontFile: appNameFontFile,
      brandingText: brandingText,
      brandingTextSize: brandingTextSize,
      brandingTextColor: brandingTextColor,
      brandingTextDarkColor: brandingTextDarkColor,
      brandingTextBold: brandingTextBold,
      brandingFontFamily: brandingFontFamily,
      brandingFontFile: brandingFontFile,
      brandingImage: brandingImage,
      darkBrandingImage: darkBrandingImage,
      brandingImageHeight: brandingImageHeight,
      autoExtractBranding: autoExtractBranding,
      brandingSourceBox: brandingBox,
      brandingBottomPadding: brandingBottomPadding,
      androidBleedCanvasSize: androidBleedCanvasSize,
      androidSafeWidth: androidSafeWidth,
      androidFullscreenMode: androidFullscreenMode,
      fullscreen: map['fullscreen'] as bool? ?? true,
      android: map['android'] as bool? ?? true,
      ios: map['ios'] as bool? ?? true,
      ohos: (map['ohos'] ?? map['harmony']) as bool? ?? true,
      web: map['web'] as bool? ?? true,
      ohosModuleJsonPath: _nonEmptyString(map['ohos_module_json']) ??
          'ohos/entry/src/main/module.json5',
      ohosIndexEtsPath: _nonEmptyString(map['ohos_index_ets']) ??
          'ohos/entry/src/main/ets/pages/Index.ets',
    );
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString().trim());
  }

  /// Normalizes a hex color string to `#RRGGBB`.
  static String normalizeHexColor(String raw) {
    final cleaned = raw.trim().replaceAll('#', '').replaceAll('0x', '');
    if (cleaned.length == 6) {
      return '#${cleaned.toUpperCase()}';
    }
    if (cleaned.length == 8) {
      return '#${cleaned.substring(2).toUpperCase()}';
    }
    throw FormatException('Invalid hex color: $raw');
  }

  /// Parses [color] into `[R, G, B]` integer components (`0..255`).
  List<int> get rgbComponents => parseRgb(color);

  /// Parses a `#RRGGBB` string into `[R, G, B]`.
  static List<int> parseRgb(String hexColor) {
    final cleaned = normalizeHexColor(hexColor).substring(1);
    return [
      int.parse(cleaned.substring(0, 2), radix: 16),
      int.parse(cleaned.substring(2, 4), radix: 16),
      int.parse(cleaned.substring(4, 6), radix: 16),
    ];
  }
}
