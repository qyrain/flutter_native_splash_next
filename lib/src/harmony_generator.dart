import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'image_processor.dart';

/// Generates HarmonyOS NEXT (OpenHarmony API 12+) Two-Stage Zero-Flicker splash screen:
/// 1. Stage 1 (0ms OS window): `start_window.json` (`startWindowBackgroundImage: "$media:splash_screen"`, `Cover`)
///    wired via `module.json5` (`startWindow: "$profile:start_window"`).
/// 2. Stage 2 (ArkUI handover): `Index.ets` `splashBuilder()` with `.objectFit(ImageFit.Cover).syncLoad(true)`
///    and full-screen `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`.
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

    // 1. Write splash_screen.png
    if (lightAssets != null) {
      SplashImageProcessor.writePng(
        '$resBaseDir/media/splash_screen.png',
        lightAssets.masterFullscreenRgb,
      );
    }

    if (darkAssets != null) {
      SplashImageProcessor.writePng(
        '$resDarkDir/media/splash_screen.png',
        darkAssets.masterFullscreenRgb,
      );
    }

    // 2. Write start_window.json
    const startWindowJson = '''{
  "startWindowBackgroundColor": "\$color:start_window_background",
  "startWindowBackgroundImage": "\$media:splash_screen",
  "startWindowBackgroundImageFit": "Cover"
}
''';
    _writeTextFile('$resBaseDir/profile/start_window.json', startWindowJson);

    // 3. Update start_window_background in color.json
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

    // 4. Ensure module.json5 has "startWindow": "$profile:start_window"
    _updateModuleJson5(config.ohosModuleJsonPath);

    // 5. Ensure Index.ets has zero-flicker splashBuilder() with .syncLoad(true)
    _updateIndexEts(config.ohosIndexEtsPath);

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

  static void _updateIndexEts(String indexEtsPath) {
    final file = File(indexEtsPath);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    if (content.contains('splashBuilder()') && content.contains('.syncLoad(true)')) {
      return;
    }

    const optimizedIndexEts = '''import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";

  @Builder
  splashBuilder() {
    Image(\$r('app.media.splash_screen'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .syncLoad(true)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      FlutterPage({
        viewId: this.viewId,
        splashScreenView: () => {
          this.splashBuilder()
        }
      })
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
    file.writeAsStringSync(optimizedIndexEts);
  }

  static void _writeTextFile(String path, String content) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
}
