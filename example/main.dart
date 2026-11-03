import 'package:flutter_native_splash_next/flutter_native_splash_next.dart';

/// Example demonstrating programmatic invocation of `flutter_native_splash_next`.
///
/// In a typical Flutter project, run via CLI:
/// ```bash
/// dart run flutter_native_splash_next:create
/// ```
Future<void> main() async {
  // Parse configuration from a Map or YAML file:
  final config = SplashConfig.fromMap({
    'color': '#EFF7F4',
    'fullscreen_image': 'assets/splash/splash_screen.png',
    'auto_extract_branding': true,
    'branding_bottom_padding': 48,
    'android': true,
    'ios': true,
    'ohos': true,
    'web': true,
  });

  print('Configured splash with base color: ${config.color}');
  print('Android full-screen bleed mode: ${config.androidFullscreenMode}');
  print('Bottom branding padding: ${config.brandingBottomPadding}dp');
}
