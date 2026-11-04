import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'config.dart';
import 'image_processor.dart';

/// Generates HarmonyOS NEXT (OpenHarmony API 12+) Two-Stage Zero-Flicker splash screen:
/// 1. Stage 1 (0ms OS window): `start_window.json` (`startWindowBackgroundImage: "$media:splash_screen"`, `Cover`,
///    optional `startWindowBrandingImage: "$media:splash_brand"`) wired via `module.json5`.
/// 2. Stage 2 (ArkUI handover): `Index.ets` `splashBuilder()` with 2688x2688 square bleed background
///    (`objectFit: Cover`) + independent bottom-anchored `splash_brand` (`margin({ bottom: 48 })`)
///    for pixel-perfect adaptation on both vertical phones and foldable unfolded screens without stretching!
class HarmonySplashGenerator {
  const HarmonySplashGenerator._();

  static void generate({
    required SplashConfig config,
    required ProcessedSplashAssets? lightAssets,
    required ProcessedSplashAssets? darkAssets,
  }) {
    if (!Directory('ohos').existsSync()) {
      print('[HarmonyOS] ohos/ directory not found, skipping.');
      return;
    }

    print('[HarmonyOS] Generating Two-Stage Zero-Flicker splash in ohos/...');

    const resBaseDir = 'ohos/entry/src/main/resources/base';
    const resDarkDir = 'ohos/entry/src/main/resources/dark';

    // 1. Write splash_screen.png (using the 2688x2688 square bleed canvas so foldable & phone never stretch)
    if (lightAssets != null) {
      SplashImageProcessor.writePng(
        '$resBaseDir/media/splash_screen.png',
        lightAssets.androidSquareBleedRgb,
      );
    }

    if (darkAssets != null) {
      SplashImageProcessor.writePng(
        '$resDarkDir/media/splash_screen.png',
        darkAssets.androidSquareBleedRgb,
      );
    }

    // 2. Write splash_brand.png if bottom branding exists, or delete stale file
    final hasBrandLayer = lightAssets?.brandingRgba != null;
    int brandVpH = 26;
    if (hasBrandLayer) {
      final brand3x = lightAssets!.brandingRgba!;
      brandVpH = math.max(1, (brand3x.height / 3.0).round());
      SplashImageProcessor.writePng(
        '$resBaseDir/media/splash_brand.png',
        brand3x,
      );
      if (darkAssets?.brandingRgba != null) {
        SplashImageProcessor.writePng(
          '$resDarkDir/media/splash_brand.png',
          darkAssets!.brandingRgba!,
        );
      }
    } else {
      _deleteIfExists('$resBaseDir/media/splash_brand.png');
      _deleteIfExists('$resDarkDir/media/splash_brand.png');
    }

    // 3. Write start_window.json
    final startWindowJson = hasBrandLayer
        ? '''{
  "startWindowBackgroundColor": "\$color:start_window_background",
  "startWindowBackgroundImage": "\$media:splash_screen",
  "startWindowBackgroundImageFit": "Cover",
  "startWindowBrandingImage": "\$media:splash_brand"
}
'''
        : '''{
  "startWindowBackgroundColor": "\$color:start_window_background",
  "startWindowBackgroundImage": "\$media:splash_screen",
  "startWindowBackgroundImageFit": "Cover"
}
''';
    _writeTextFile('$resBaseDir/profile/start_window.json', startWindowJson);

    // 4. Update start_window_background in color.json
    _updateColorJson(
      '$resBaseDir/element/color.json',
      'start_window_background',
      config.color,
    );
    if (config.darkColor != null) {
      _updateColorJson(
        '$resDarkDir/element/color.json',
        'start_window_background',
        config.darkColor!,
      );
    }

    // 5. Ensure module.json5 has "startWindow": "$profile:start_window"
    _updateModuleJson5(config.ohosModuleJsonPath);

    // 6. Ensure Index.ets has zero-flicker splashBuilder() with .syncLoad(true)
    _updateIndexEts(
      indexEtsPath: config.ohosIndexEtsPath,
      hasBranding: hasBrandLayer,
      brandVpH: brandVpH,
      brandBottomPadding: config.brandingBottomPadding,
    );

    print('[HarmonyOS] Splash screen configured successfully.');
  }

  /// Removes generated HarmonyOS splash assets and restores default `module.json5` and `Index.ets`.
  static void remove({
    String moduleJsonPath = 'ohos/entry/src/main/module.json5',
    String indexEtsPath = 'ohos/entry/src/main/ets/pages/Index.ets',
  }) {
    if (!Directory('ohos').existsSync()) return;

    print('[HarmonyOS] Removing splash screen from ohos/...');
    const resBaseDir = 'ohos/entry/src/main/resources/base';
    const resDarkDir = 'ohos/entry/src/main/resources/dark';

    for (final p in [
      '$resBaseDir/media/splash_screen.png',
      '$resDarkDir/media/splash_screen.png',
      '$resBaseDir/media/splash_brand.png',
      '$resDarkDir/media/splash_brand.png',
      '$resBaseDir/profile/start_window.json',
    ]) {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    }

    _updateColorJson(
      '$resBaseDir/element/color.json',
      'start_window_background',
      '#FFFFFF',
    );

    final moduleFile = File(moduleJsonPath);
    if (moduleFile.existsSync()) {
      var content = moduleFile.readAsStringSync();
      content = content.replaceAll(
        RegExp(r'\s*"startWindow"\s*:\s*"\$profile:start_window"\s*,?'),
        '',
      );
      moduleFile.writeAsStringSync(content);
    }

    final indexFile = File(indexEtsPath);
    if (indexFile.existsSync()) {
      const defaultIndexEts = '''import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  build() {
    Column() {
      FlutterPage({ viewId: this.viewId })
    }
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
''';
      indexFile.writeAsStringSync(defaultIndexEts);
    }

    print('[HarmonyOS] Default splash screen restored.');
  }

  static void _updateColorJson(
    String filePath,
    String colorName,
    String colorHex,
  ) {
    final file = File(filePath);
    if (!file.existsSync()) {
      final jsonStr = '''{
  "color": [
    {
      "name": "$colorName",
      "value": "$colorHex"
    }
  ]
}
''';
      _writeTextFile(filePath, jsonStr);
      return;
    }

    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic> && decoded['color'] is List) {
        final list = decoded['color'] as List<dynamic>;
        var found = false;
        for (final item in list) {
          if (item is Map<String, dynamic> && item['name'] == colorName) {
            item['value'] = colorHex;
            found = true;
            break;
          }
        }
        if (!found) {
          list.add({'name': colorName, 'value': colorHex});
        }
        const encoder = JsonEncoder.withIndent('  ');
        file.writeAsStringSync('${encoder.convert(decoded)}\n');
      }
    } catch (_) {
      // Preserve file if custom format
    }
  }

  static void _updateModuleJson5(String moduleJsonPath) {
    final file = File(moduleJsonPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    if (!content.contains('"startWindow"')) {
      content = content.replaceFirstMapped(
        RegExp(r'("startWindowBackground"\s*:\s*"[^"]+"\s*,?)'),
        (m) =>
            '${m.group(1)}\n        "startWindow": "\$profile:start_window",',
      );
      file.writeAsStringSync(content);
    }
  }

  static void _updateIndexEts({
    required String indexEtsPath,
    required bool hasBranding,
    required int brandVpH,
    required int brandBottomPadding,
  }) {
    final file = File(indexEtsPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    final String targetTopLevelBuilder = hasBranding
        ? '''@Builder
function splashBuilder() {
  Stack({ alignContent: Alignment.Bottom }) {
    Image(\$r("app.media.splash_screen"))
      .objectFit(ImageFit.Cover)
      .width('100%')
      .height('100%')
      .syncLoad(true)

    Image(\$r("app.media.splash_brand"))
      .objectFit(ImageFit.Contain)
      .height($brandVpH)
      .margin({ bottom: $brandBottomPadding })
      .syncLoad(true)
  }
  .width('100%')
  .height('100%')
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
}'''
        : '''@Builder
function splashBuilder() {
  Stack() {
    Image(\$r("app.media.splash_screen"))
      .objectFit(ImageFit.Cover)
      .width('100%')
      .height('100%')
      .syncLoad(true)
  }
  .width('100%')
  .height('100%')
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
}''';

    final String targetMemberBuilder = hasBranding
        ? '''  @Builder
  splashBuilder() {
    Stack({ alignContent: Alignment.Bottom }) {
      Image(\$r("app.media.splash_screen"))
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .syncLoad(true)

      Image(\$r("app.media.splash_brand"))
        .objectFit(ImageFit.Contain)
        .height($brandVpH)
        .margin({ bottom: $brandBottomPadding })
        .syncLoad(true)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }'''
        : '''  @Builder
  splashBuilder() {
    Stack() {
      Image(\$r("app.media.splash_screen"))
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
        .syncLoad(true)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }''';

    // 1. If Index.ets already has splashBuilder, replace it cleanly
    final topLevelMatch = RegExp(
      r'@Builder\s+function\s+splashBuilder\s*\([^)]*\)\s*\{[\s\S]*?\n\}',
    );
    final memberMatch = RegExp(
      r'@Builder\s+splashBuilder\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}',
    );

    if (topLevelMatch.hasMatch(content)) {
      content = content.replaceFirst(topLevelMatch, targetTopLevelBuilder);
      file.writeAsStringSync(content);
      return;
    } else if (memberMatch.hasMatch(content)) {
      content = content.replaceFirst(memberMatch, targetMemberBuilder);
      file.writeAsStringSync(content);
      return;
    }

    // 2. If it's a default Index.ets without splashBuilder, write complete zero-flicker template
    final fullTemplate = '''import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

$targetTopLevelBuilder

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  build() {
    Stack() {
      FlutterPage({
        viewId: this.viewId,
        splashScreenView: splashBuilder,
      }).backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(\$r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  onBackPress(): boolean {
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
''';
    file.writeAsStringSync(fullTemplate);
  }

  static void _deleteIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  static void _writeTextFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
