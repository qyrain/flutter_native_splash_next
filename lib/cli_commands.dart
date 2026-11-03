import 'src/android_generator.dart';
import 'src/config.dart';
import 'src/harmony_generator.dart';
import 'src/image_processor.dart';
import 'src/ios_generator.dart';
import 'src/web_generator.dart';

/// Generates native splash screens for Android, iOS, HarmonyOS NEXT (OpenHarmony), and Web.
Future<void> createSplash({
  String? path,
  String? flavor,
}) async {
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║           flutter_native_splash_next — Generating...           ║');
  print('╚════════════════════════════════════════════════════════════════╝');

  final config = SplashConfig.load(configPath: path, flavor: flavor);

  print('[ImageEngine] Processing splash artwork & square bleed canvas...');
  final lightAssets = SplashImageProcessor.buildAssets(
    config: config,
    dark: false,
  );
  final hasDarkInput = config.darkFullscreenImage != null ||
      config.darkBackgroundImage != null ||
      config.darkImage != null ||
      config.darkColor != null;
  final darkAssets = hasDarkInput
      ? SplashImageProcessor.buildAssets(config: config, dark: true)
      : null;

  if (config.android) {
    AndroidSplashGenerator.generate(
      config: config,
      lightAssets: lightAssets,
      darkAssets: darkAssets,
      flavor: flavor,
    );
  }

  if (config.ios) {
    IosSplashGenerator.generate(
      config: config,
      lightAssets: lightAssets,
      darkAssets: darkAssets,
    );
  }

  if (config.ohos) {
    HarmonySplashGenerator.generate(
      config: config,
      lightAssets: lightAssets,
      darkAssets: darkAssets,
    );
  }

  if (config.web) {
    WebSplashGenerator.generate(
      config: config,
      lightAssets: lightAssets,
      darkAssets: darkAssets,
    );
  }

  print('✅ flutter_native_splash_next completed successfully!');
}

/// Restores default solid-color native splash screens across Android, iOS, HarmonyOS NEXT, and Web.
Future<void> removeSplash({
  String? path,
  String? flavor,
}) async {
  print('Restoring default solid splash screen...');
  const cleanConfig = SplashConfig(
    color: '#FFFFFF',
    darkColor: '#000000',
    androidFullscreenMode: true,
    fullscreen: false,
  );

  AndroidSplashGenerator.generate(
    config: cleanConfig,
    lightAssets: null,
    darkAssets: null,
    flavor: flavor,
  );
  IosSplashGenerator.generate(
    config: cleanConfig,
    lightAssets: null,
    darkAssets: null,
  );
  HarmonySplashGenerator.remove();
  WebSplashGenerator.remove();

  print('✅ Default splash screen restored across all platforms.');
}
