import 'dart:io';

import 'package:flutter_native_splash_next/flutter_native_splash_next.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('1. SplashConfig Parsing, Normalization & Error Handling', () {
    test('normalizes 6-digit and 8-digit hex colors and parses flat + nested logo/branding blocks', () {
      final config = SplashConfig.fromMap({
        'color': 'eff7f4',
        'color_dark': '0xFF121212',
        'background_image': 'assets/bg.png',
        'logo': {
          'image': 'assets/icon.png',
          'size': 84,
          'border_radius': 20,
          'top_ratio': 0.28,
          'title': 'Rainier',
          'title_size': 19,
          'title_color': '#2C3432',
          'title_color_dark': '#E5E7EB',
          'title_spacing': 16,
          'title_bold': true,
        },
        'branding': {
          'text': 'Hi, Rainier',
          'text_size': 14,
          'text_color': '#343736',
          'text_color_dark': '#9CA3AF',
          'bottom_padding': 52,
        },
      });

      expect(config.color, '#EFF7F4');
      expect(config.darkColor, '#121212');
      expect(config.rgbComponents, [239, 247, 244]);
      expect(config.image, 'assets/icon.png');
      expect(config.logoSize, 84.0);
      expect(config.logoBorderRadius, 20.0);
      expect(config.logoTopRatio, 0.28);
      expect(config.appName, 'Rainier');
      expect(config.appNameSize, 19.0);
      expect(config.appNameColor, '#2C3432');
      expect(config.appNameDarkColor, '#E5E7EB');
      expect(config.appNameSpacing, 16.0);
      expect(config.appNameBold, isTrue);
      expect(config.brandingText, 'Hi, Rainier');
      expect(config.brandingTextSize, 14.0);
      expect(config.brandingTextColor, '#343736');
      expect(config.brandingTextDarkColor, '#9CA3AF');
      expect(config.brandingBottomPadding, 52);
      expect(config.androidFullscreenMode, isTrue);
    });

    test('parses flat keys for logo_size, app_name, branding_image, and branding_image_height', () {
      final config = SplashConfig.fromMap({
        'color': '#FFFFFF',
        'logo_image': 'assets/logo.png',
        'logo_size': 96,
        'logo_border_radius': 18,
        'app_name': 'Rainier Pro',
        'branding_image': 'assets/brand.png',
        'branding_image_height': 24,
        'branding_bottom_padding': 44,
      });

      expect(config.image, 'assets/logo.png');
      expect(config.logoSize, 96.0);
      expect(config.logoBorderRadius, 18.0);
      expect(config.appName, 'Rainier Pro');
      expect(config.brandingImage, 'assets/brand.png');
      expect(config.brandingImageHeight, 24.0);
      expect(config.brandingBottomPadding, 44);
    });

    test('throws FormatException on invalid hex color', () {
      expect(
        () => SplashConfig.normalizeHexColor('#12345'),
        throwsFormatException,
      );
    });

    test('supports loading flavor-specific configuration from YAML file', () {
      final tempDir = Directory.systemTemp.createTempSync('splash_cfg_test_');
      try {
        final yamlFile = File(p.join(tempDir.path, 'custom_splash.yaml'));
        yamlFile.writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  fullscreen_image: "assets/prod.png"

flutter_native_splash_next-staging:
  color: "#E0F2FE"
  fullscreen_image: "assets/staging.png"
  branding_bottom_padding: 60
''');

        final prodCfg = SplashConfig.load(configPath: yamlFile.path);
        expect(prodCfg.color, '#EFF7F4');
        expect(prodCfg.fullscreenImage, 'assets/prod.png');

        final stagingCfg = SplashConfig.load(
          configPath: yamlFile.path,
          flavor: 'staging',
        );
        expect(stagingCfg.color, '#E0F2FE');
        expect(stagingCfg.fullscreenImage, 'assets/staging.png');
        expect(stagingCfg.brandingBottomPadding, 60);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('2. SplashImageProcessor & SplashTextRenderer Engine', () {
    test('flattens semi-transparent RGBA onto solid RGB without ghosting', () {
      final src = img.Image(width: 64, height: 64, numChannels: 4);
      img.fill(src, color: img.ColorRgba8(239, 247, 244, 191));
      final flat = SplashImageProcessor.flattenOntoRgb(src, [239, 247, 244]);

      expect(flat.numChannels, 3);
      final px = flat.getPixel(32, 32);
      expect(px.r.toInt(), 239);
      expect(px.g.toInt(), 247);
      expect(px.b.toInt(), 244);
    });

    test('applies rounded corner mask cleanly to square app icon', () {
      final square = img.Image(width: 120, height: 120, numChannels: 4);
      img.fill(square, color: img.ColorRgba8(45, 160, 180, 255));
      final rounded = SplashImageProcessor.applyRoundedCorners(square, 30.0);

      expect(rounded.getPixel(0, 0).a.toInt(), 0);
      expect(rounded.getPixel(60, 60).a.toInt(), 255);
    });

    test('renders Unicode text (English & Chinese) into transparent RGBA', () {
      final textImg = SplashTextRenderer.renderTextRgba(
        text: 'Rainier · 云端',
        fontSizeSp: 18,
        colorHex: '#2C3432',
        bold: true,
      );

      expect(textImg.width, greaterThan(40));
      expect(textImg.height, greaterThan(15));
      expect(textImg.numChannels, 4);
    });

    test('scales bottom branding image proportionally when branding.height is configured', () {
      final tempDir = Directory.systemTemp.createTempSync('splash_brand_scale_');
      try {
        final rawBrand = img.Image(width: 400, height: 100, numChannels: 4);
        img.fill(rawBrand, color: img.ColorRgba8(52, 55, 54, 255));
        final brandPath = p.join(tempDir.path, 'brand.png');
        File(brandPath).writeAsBytesSync(img.encodePng(rawBrand));

        final cfg = SplashConfig.fromMap({
          'color': '#EFF7F4',
          'branding': {
            'image': brandPath,
            'height': 20, // 20dp -> 60px @3x, width should scale from 400 to 240px!
          },
        });

        final brandBlock = SplashImageProcessor.buildBottomBrandingBlock(
          config: cfg,
          dark: false,
        );
        expect(brandBlock, isNotNull);
        expect(brandBlock!.height, 60);
        expect(brandBlock.width, 240);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('extracts transparent bottom branding and cleanly erases background', () {
      final canvas = img.Image(width: 300, height: 120, numChannels: 3);
      img.fill(canvas, color: img.ColorRgb8(239, 247, 244));
      img.fillRect(
        canvas,
        x1: 120,
        y1: 45,
        x2: 180,
        y2: 75,
        color: img.ColorRgb8(52, 55, 54),
      );

      final extracted = SplashImageProcessor.extractTransparentBranding(
        canvas,
        x0: 80,
        y0: 30,
        x1: 220,
        y1: 90,
      );

      expect(extracted, isNotNull);
      expect(extracted!.width, 140);
      expect(extracted.height, 60);
      expect(extracted.getPixel(5, 5).a.toInt(), 0);
      expect(extracted.getPixel(70, 30).a.toInt(), greaterThan(240));

      SplashImageProcessor.eraseRegionWithHorizontalInterpolation(
        canvas,
        x0: 75,
        y0: 25,
        x1: 225,
        y1: 95,
      );
      final centerAfterErase = canvas.getPixel(150, 60);
      expect(centerAfterErase.r.toInt(), closeTo(239, 2));
      expect(centerAfterErase.g.toInt(), closeTo(247, 2));
      expect(centerAfterErase.b.toInt(), closeTo(244, 2));
    });

    test('returns null from extractTransparentBranding when bottom region has no text', () {
      final canvas = img.Image(width: 300, height: 120, numChannels: 3);
      img.fill(canvas, color: img.ColorRgb8(239, 247, 244));

      final extracted = SplashImageProcessor.extractTransparentBranding(
        canvas,
        x0: 80,
        y0: 30,
        x1: 220,
        y1: 90,
      );

      expect(extracted, isNull);
    });
  });

  group('3. End-to-End Multi-Platform Splash Generation (Android/iOS/OHOS/Web)', () {
    late Directory tempWorkspace;
    late Directory originalCwd;

    setUp(() {
      originalCwd = Directory.current;
      tempWorkspace = Directory.systemTemp.createTempSync('splash_e2e_test_');
      Directory.current = tempWorkspace;

      Directory('android/app/src/main/res/values').createSync(recursive: true);
      Directory('android/app/src/main/res/values-v31')
          .createSync(recursive: true);
      Directory('android/app/src/main/res/values-v33')
          .createSync(recursive: true);
      Directory('ios/Runner/Base.lproj').createSync(recursive: true);
      Directory('ohos/entry/src/main/ets/pages').createSync(recursive: true);
      Directory('web').createSync(recursive: true);

      const legacyV31Styles = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#FFFFFF</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>
        <item name="android:windowSplashScreenBrandingImage">@drawable/old_brand</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
''';
      File('android/app/src/main/res/values-v31/styles.xml')
          .writeAsStringSync(legacyV31Styles);
      File('android/app/src/main/res/values-v33/styles.xml')
          .writeAsStringSync(legacyV31Styles);

      File('ios/Runner/Info.plist').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Runner</string>
</dict>
</plist>
''');

      File('ohos/entry/src/main/module.json5').writeAsStringSync('''{
  "module": {
    "name": "entry",
    "abilities": [
      {
        "name": "EntryAbility",
        "startWindowIcon": "\$media:startIcon",
        "startWindowBackground": "\$color:start_window_background"
      }
    ]
  }
}
''');
      File('ohos/entry/src/main/ets/pages/Index.ets').writeAsStringSync('''
import { FlutterPage } from '@ohos/flutter_ohos'
@Entry
@Component
struct Index {
  build() {
    FlutterPage({ viewId: "1" })
  }
}
''');

      File('web/index.html').writeAsStringSync('''<!DOCTYPE html>
<html>
<head>
  <title>Test App</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''');
    });

    tearDown(() {
      Directory.current = originalCwd;
      if (tempWorkspace.existsSync()) {
        tempWorkspace.deleteSync(recursive: true);
      }
    });

    test('Component Mode (Light + Dark): Configurable logo size/radius + app_name + branding_text across all 4 platforms', () async {
      Directory('assets').createSync(recursive: true);

      final bgImg = img.Image(width: 600, height: 1200, numChannels: 3);
      img.fill(bgImg, color: img.ColorRgb8(239, 247, 244));
      File('assets/bg.png').writeAsBytesSync(img.encodePng(bgImg));

      final iconImg = img.Image(width: 512, height: 512, numChannels: 4);
      img.fill(iconImg, color: img.ColorRgba8(52, 168, 178, 255));
      File('assets/app_icon.png').writeAsBytesSync(img.encodePng(iconImg));

      File('flutter_native_splash_next.yaml').writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  color_dark: "#121816"
  background_image: "assets/bg.png"
  logo:
    image: "assets/app_icon.png"
    size: 80
    border_radius: 20
    top_ratio: 0.28
    title: "Rainier"
    title_size: 18
    title_color: "#2C3432"
    title_color_dark: "#F3F4F6"
    title_spacing: 14
    title_bold: true
  branding:
    text: "Hi, Rainier"
    text_size: 13
    text_color: "#343736"
    text_color_dark: "#9CA3AF"
    bottom_padding: 48
  android: true
  ios: true
  ohos: true
  web: true
''');

      await createSplash();

      // 1. Verify Android light & dark two-layer output
      expect(
        File('android/app/src/main/res/drawable-xxhdpi/bg_splash.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/drawable-xxhdpi/splash_brand.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/drawable-night-xxhdpi/bg_splash.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/drawable-night-xxhdpi/splash_brand.png')
            .existsSync(),
        isTrue,
      );
      final launchBgXml =
          File('android/app/src/main/res/drawable/launch_background.xml')
              .readAsStringSync();
      expect(launchBgXml, contains('<item android:bottom="48dp">'));
      expect(launchBgXml, contains('android:src="@drawable/splash_brand"'));

      // 2. Verify iOS light & dark two-layer output (LaunchImage + BrandingImage pinned at bottom=48pt)
      expect(
        File('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark@3x.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('ios/Runner/Assets.xcassets/BrandingImage.imageset/BrandingImage@3x.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('ios/Runner/Assets.xcassets/BrandingImage.imageset/BrandingImageDark@3x.png')
            .existsSync(),
        isTrue,
      );
      final storyboard =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
              .readAsStringSync();
      expect(storyboard, contains('contentMode="scaleAspectFill"'));
      expect(storyboard, contains('image="BrandingImage"'));
      expect(storyboard, contains('constant="48"'));

      // 3. Verify HarmonyOS NEXT light & dark output (2688x2688 square bleed + independent splash_brand)
      final ohosSplash =
          File('ohos/entry/src/main/resources/base/media/splash_screen.png');
      final ohosDarkSplash =
          File('ohos/entry/src/main/resources/dark/media/splash_screen.png');
      expect(ohosSplash.existsSync(), isTrue);
      expect(ohosDarkSplash.existsSync(), isTrue);
      final decodedOhos = img.decodeImage(ohosSplash.readAsBytesSync())!;
      expect(decodedOhos.width, 2688);
      expect(decodedOhos.height, 2688);
      expect(
        File('ohos/entry/src/main/resources/base/media/splash_brand.png')
            .existsSync(),
        isTrue,
      );
      final ohosStartWindow =
          File('ohos/entry/src/main/resources/base/profile/start_window.json')
              .readAsStringSync();
      expect(ohosStartWindow, contains('startWindowBrandingImage'));
      final indexEts =
          File('ohos/entry/src/main/ets/pages/Index.ets').readAsStringSync();
      expect(indexEts, contains('.syncLoad(true)'));
      expect(indexEts, contains('splash_brand'));
      expect(indexEts, contains('.margin({ bottom: 48 })'));

      // 4. Verify Web multi-layer responsive output (light + dark)
      expect(File('web/splash/img/light.png').existsSync(), isTrue);
      expect(File('web/splash/img/dark.png').existsSync(), isTrue);
      expect(File('web/splash/img/logo.png').existsSync(), isTrue);
      expect(File('web/splash/img/logo-dark.png').existsSync(), isTrue);
      expect(File('web/splash/img/branding.png').existsSync(), isTrue);
      expect(File('web/splash/img/branding-dark.png').existsSync(), isTrue);
      final webHtml = File('web/index.html').readAsStringSync();
      expect(webHtml, contains('#splash-logo'));
      expect(webHtml, contains('top: 28.0%;'));
      expect(webHtml, contains('#splash-branding'));
      expect(webHtml, contains('bottom: 48px;'));
    });

    test('Single Fullscreen Mode: fullscreen_image + auto_extract_branding works and removeSplash restores', () async {
      Directory('assets').createSync(recursive: true);
      final fullArt = img.Image(width: 1242, height: 2688, numChannels: 4);
      img.fill(fullArt, color: img.ColorRgba8(239, 247, 244, 255));
      img.fillRect(
        fullArt,
        x1: 500,
        y1: 2480,
        x2: 740,
        y2: 2540,
        color: img.ColorRgba8(52, 55, 54, 255),
      );
      File('assets/splash_full.png')
          .writeAsBytesSync(img.encodePng(fullArt));

      File('flutter_native_splash_next.yaml').writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  fullscreen_image: "assets/splash_full.png"
  auto_extract_branding: true
  branding_bottom_padding: 48
  branding_source_box: [450, 2465, 795, 2560]
''');

      await createSplash();

      final bgSplashFile =
          File('android/app/src/main/res/drawable-xxhdpi/bg_splash.png');
      final brandSplashFile =
          File('android/app/src/main/res/drawable-xxhdpi/splash_brand.png');
      expect(bgSplashFile.existsSync(), isTrue);
      expect(brandSplashFile.existsSync(), isTrue);
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('<key>UIStatusBarHidden</key>\n\t<true/>'),
      );

      await removeSplash();
      expect(bgSplashFile.existsSync(), isFalse);
      expect(brandSplashFile.existsSync(), isFalse);
      expect(
        Directory('ios/Runner/Assets.xcassets/LaunchImage.imageset')
            .existsSync(),
        isFalse,
      );
      expect(
        File('ohos/entry/src/main/resources/base/media/splash_screen.png')
            .existsSync(),
        isFalse,
      );
      expect(
        File('ohos/entry/src/main/resources/base/media/splash_brand.png')
            .existsSync(),
        isFalse,
      );
      expect(
        File('ohos/entry/src/main/resources/base/profile/start_window.json')
            .existsSync(),
        isFalse,
      );
      expect(Directory('web/splash').existsSync(), isFalse);
      expect(
        File('web/index.html').readAsStringSync(),
        isNot(contains('splash-screen-style')),
      );
    });

    test('No Bottom Text / No Branding Compatibility: Mode A (without branding) & Mode B (fullscreen_image without bottom text)', () async {
      Directory('assets').createSync(recursive: true);

      final iconImg = img.Image(width: 512, height: 512, numChannels: 4);
      img.fill(iconImg, color: img.ColorRgba8(52, 168, 178, 255));
      File('assets/app_icon.png').writeAsBytesSync(img.encodePng(iconImg));

      // First generate WITH branding to ensure stale branding assets exist
      File('flutter_native_splash_next.yaml').writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  logo:
    image: "assets/app_icon.png"
    size: 80
    title: "Rainier"
  branding:
    text: "Hi, Rainier"
''');
      await createSplash();
      expect(
        File('android/app/src/main/res/drawable-xxhdpi/splash_brand.png')
            .existsSync(),
        isTrue,
      );
      expect(
        Directory('ios/Runner/Assets.xcassets/BrandingImage.imageset')
            .existsSync(),
        isTrue,
      );
      expect(File('web/splash/img/branding.png').existsSync(), isTrue);

      // Case 1: Mode A WITHOUT bottom branding/text -> must cleanly omit and delete stale branding across all 4 platforms
      File('flutter_native_splash_next.yaml').writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  color_dark: "#121816"
  logo:
    image: "assets/app_icon.png"
    size: 80
    border_radius: 20
    title: "Rainier"
  android: true
  ios: true
  ohos: true
  web: true
''');
      await createSplash();

      expect(
        File('android/app/src/main/res/drawable-xxhdpi/bg_splash.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/drawable-xxhdpi/splash_brand.png')
            .existsSync(),
        isFalse,
      );
      final modeAXml =
          File('android/app/src/main/res/drawable/launch_background.xml')
              .readAsStringSync();
      expect(modeAXml, isNot(contains('splash_brand')));

      expect(
        Directory('ios/Runner/Assets.xcassets/BrandingImage.imageset')
            .existsSync(),
        isFalse,
      );
      final modeAStoryboard =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
              .readAsStringSync();
      expect(modeAStoryboard, isNot(contains('BrandingImage')));

      expect(
        File('ohos/entry/src/main/resources/base/media/splash_screen.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('ohos/entry/src/main/resources/base/media/splash_brand.png')
            .existsSync(),
        isFalse,
      );
      final ohosNoBrandEts =
          File('ohos/entry/src/main/ets/pages/Index.ets').readAsStringSync();
      expect(ohosNoBrandEts, isNot(contains('splash_brand')));

      expect(File('web/splash/img/logo.png').existsSync(), isTrue);
      expect(File('web/splash/img/branding.png').existsSync(), isFalse);
      final modeAHtml = File('web/index.html').readAsStringSync();
      expect(modeAHtml, contains('#splash-logo'));
      expect(modeAHtml, isNot(contains('#splash-branding')));
      expect(modeAHtml, isNot(contains('splash-branding-picture')));

      // Case 2: Mode B with fullscreen_image that has NO bottom text (even if auto_extract_branding: true is set)
      final fullArtNoBottom =
          img.Image(width: 1242, height: 2688, numChannels: 4);
      img.fill(fullArtNoBottom, color: img.ColorRgba8(239, 247, 244, 255));
      // Draw only top logo at y=650..850, bottom is pure background with no text
      img.fillRect(
        fullArtNoBottom,
        x1: 520,
        y1: 650,
        x2: 720,
        y2: 850,
        color: img.ColorRgba8(52, 168, 178, 255),
      );
      File('assets/splash_no_bottom.png')
          .writeAsBytesSync(img.encodePng(fullArtNoBottom));

      File('flutter_native_splash_next.yaml').writeAsStringSync('''
flutter_native_splash_next:
  color: "#EFF7F4"
  fullscreen_image: "assets/splash_no_bottom.png"
  auto_extract_branding: true
''');
      await createSplash();

      expect(
        File('android/app/src/main/res/drawable-xxhdpi/bg_splash.png')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/drawable-xxhdpi/splash_brand.png')
            .existsSync(),
        isFalse,
      );
      expect(
        File('android/app/src/main/res/drawable/launch_background.xml')
            .readAsStringSync(),
        isNot(contains('splash_brand')),
      );
      expect(
        Directory('ios/Runner/Assets.xcassets/BrandingImage.imageset')
            .existsSync(),
        isFalse,
      );
      expect(File('web/splash/img/branding.png').existsSync(), isFalse);
    });

    test('FlutterNativeSplashNext.preserve() and remove() defer and allow first frame cleanly', () {
      final mockBinding = _MockWidgetsBinding();
      expect(mockBinding.deferredCount, 0);
      expect(mockBinding.allowedCount, 0);

      FlutterNativeSplashNext.preserve(widgetsBinding: mockBinding);
      // Calling preserve twice should only defer once
      FlutterNativeSplashNext.preserve(widgetsBinding: mockBinding);
      expect(mockBinding.deferredCount, 1);

      FlutterNativeSplashNext.remove();
      // Calling remove twice should only allow once
      FlutterNativeSplashNext.remove();
      expect(mockBinding.allowedCount, 1);
    });
  });
}

class _MockWidgetsBinding {
  int deferredCount = 0;
  int allowedCount = 0;

  void deferFirstFrame() {
    deferredCount++;
  }

  void allowFirstFrame() {
    allowedCount++;
  }
}
