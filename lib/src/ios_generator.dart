import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'config.dart';
import 'image_processor.dart';

/// Generates iOS `LaunchImage.imageset` (`@1x`, `@2x`, `@3x` + `Contents.json`),
/// optional `BrandingImage.imageset` (`@1x`, `@2x`, `@3x` + `Contents.json`),
/// and full-screen `LaunchScreen.storyboard` (`scaleAspectFill` background +
/// bottom-anchored `BrandingImage` at `brandingBottomPadding` pt).
class IosSplashGenerator {
  const IosSplashGenerator._();

  static void generate({
    required SplashConfig config,
    required ProcessedSplashAssets? lightAssets,
    required ProcessedSplashAssets? darkAssets,
  }) {
    if (!Directory('ios').existsSync()) {
      print('[iOS] ios/ directory not found, skipping.');
      return;
    }

    print('[iOS] Generating native splash screen in ios/Runner/...');

    const launchImagesetDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    const brandImagesetDir =
        'ios/Runner/Assets.xcassets/BrandingImage.imageset';

    if (lightAssets != null) {
      Directory(launchImagesetDir).createSync(recursive: true);
      _writeMultiScaleImageset(
        dirPath: launchImagesetDir,
        baseName: 'LaunchImage',
        master3x: lightAssets.iosBackgroundWithLogoRgb,
        dark3x: darkAssets?.iosBackgroundWithLogoRgb,
      );
    } else if (Directory(launchImagesetDir).existsSync()) {
      Directory(launchImagesetDir).deleteSync(recursive: true);
    }

    final hasBrandLayer = lightAssets?.brandingRgba != null;
    int brandPtW = 100;
    int brandPtH = 26;

    if (hasBrandLayer) {
      Directory(brandImagesetDir).createSync(recursive: true);
      final brand3x = lightAssets!.brandingRgba!;
      brandPtW = math.max(1, (brand3x.width / 3.0).round());
      brandPtH = math.max(1, (brand3x.height / 3.0).round());

      _writeMultiScaleImageset(
        dirPath: brandImagesetDir,
        baseName: 'BrandingImage',
        master3x: brand3x,
        dark3x: darkAssets?.brandingRgba,
      );
    } else if (Directory(brandImagesetDir).existsSync()) {
      Directory(brandImagesetDir).deleteSync(recursive: true);
    }

    final rgb = config.rgbComponents;
    final rNorm = (rgb[0] / 255.0).toStringAsFixed(6);
    final gNorm = (rgb[1] / 255.0).toStringAsFixed(6);
    final bNorm = (rgb[2] / 255.0).toStringAsFixed(6);

    final storyboard = _buildStoryboardXml(
      rNorm: rNorm,
      gNorm: gNorm,
      bNorm: bNorm,
      hasLaunchImage: lightAssets != null,
      hasBranding: hasBrandLayer,
      brandPtW: brandPtW,
      brandPtH: brandPtH,
      brandBottomPaddingPt: config.brandingBottomPadding,
    );
    final storyboardFile = File('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    storyboardFile.parent.createSync(recursive: true);
    storyboardFile.writeAsStringSync(storyboard);

    _updateInfoPlist(fullscreen: config.fullscreen);

    print('[iOS] Splash screen configured successfully.');
  }

  /// Synchronizes `UIStatusBarHidden` and `UILaunchStoryboardName` in `ios/Runner/Info.plist`.
  static void _updateInfoPlist({required bool fullscreen}) {
    final plistFile = File('ios/Runner/Info.plist');
    if (!plistFile.existsSync()) return;

    var content = plistFile.readAsStringSync();
    final statusTag = fullscreen ? '<true/>' : '<false/>';

    if (content.contains('<key>UIStatusBarHidden</key>')) {
      content = content.replaceFirstMapped(
        RegExp(r'(<key>UIStatusBarHidden</key>\s*)<(true|false)/>'),
        (m) => '${m.group(1)}$statusTag',
      );
    } else if (content.contains('</dict>')) {
      content = content.replaceFirst(
        '</dict>',
        '\t<key>UIStatusBarHidden</key>\n\t$statusTag\n</dict>',
      );
    }

    if (!content.contains('<key>UILaunchStoryboardName</key>') &&
        content.contains('</dict>')) {
      content = content.replaceFirst(
        '</dict>',
        '\t<key>UILaunchStoryboardName</key>\n\t<string>LaunchScreen</string>\n</dict>',
      );
    }

    plistFile.writeAsStringSync(content);
  }

  static void _writeMultiScaleImageset({
    required String dirPath,
    required String baseName,
    required img.Image master3x,
    img.Image? dark3x,
  }) {
    final master2x = img.copyResize(
      master3x,
      width: math.max(1, (master3x.width * 2) ~/ 3),
      height: math.max(1, (master3x.height * 2) ~/ 3),
      interpolation: img.Interpolation.cubic,
    );
    final master1x = img.copyResize(
      master3x,
      width: math.max(1, master3x.width ~/ 3),
      height: math.max(1, master3x.height ~/ 3),
      interpolation: img.Interpolation.cubic,
    );

    SplashImageProcessor.writePng('$dirPath/$baseName.png', master1x);
    SplashImageProcessor.writePng('$dirPath/$baseName@2x.png', master2x);
    SplashImageProcessor.writePng('$dirPath/$baseName@3x.png', master3x);

    if (dark3x != null) {
      final dark2x = img.copyResize(
        dark3x,
        width: math.max(1, (dark3x.width * 2) ~/ 3),
        height: math.max(1, (dark3x.height * 2) ~/ 3),
        interpolation: img.Interpolation.cubic,
      );
      final dark1x = img.copyResize(
        dark3x,
        width: math.max(1, dark3x.width ~/ 3),
        height: math.max(1, dark3x.height ~/ 3),
        interpolation: img.Interpolation.cubic,
      );

      SplashImageProcessor.writePng('$dirPath/${baseName}Dark.png', dark1x);
      SplashImageProcessor.writePng('$dirPath/${baseName}Dark@2x.png', dark2x);
      SplashImageProcessor.writePng('$dirPath/${baseName}Dark@3x.png', dark3x);
    }

    final contentsJson = dark3x != null
        ? _contentsJsonDark(baseName)
        : _contentsJsonLight(baseName);
    File('$dirPath/Contents.json').writeAsStringSync(contentsJson);
  }

  static String _buildStoryboardXml({
    required String rNorm,
    required String gNorm,
    required String bNorm,
    required bool hasLaunchImage,
    required bool hasBranding,
    required int brandPtW,
    required int brandPtH,
    required int brandBottomPaddingPt,
  }) {
    final launchImageSubview = hasLaunchImage
        ? '\n                            <imageView opaque="NO" clipsSubviews="YES" multipleTouchEnabled="YES" contentMode="scaleAspectFill" image="LaunchImage" translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4"/>'
        : '';

    final brandingSubview = hasBranding
        ? '''
                            <imageView opaque="NO" clipsSubviews="YES" multipleTouchEnabled="YES" contentMode="scaleAspectFit" image="BrandingImage" translatesAutoresizingMaskIntoConstraints="NO" id="Uyq-Kz-ftE">
                                <constraints>
                                    <constraint firstAttribute="width" constant="$brandPtW" id="bw1-01-abc"/>
                                    <constraint firstAttribute="height" constant="$brandPtH" id="bh1-02-def"/>
                                </constraints>
                            </imageView>'''
        : '';

    final launchImageConstraints = hasLaunchImage
        ? '''
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="top" secondItem="Ze5-6b-2t3" secondAttribute="top" id="1a2-6s-vTC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="bottom" secondItem="Ze5-6b-2t3" secondAttribute="bottom" id="4X2-HB-R7a"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="leading" secondItem="Ze5-6b-2t3" secondAttribute="leading" id="8bC-Xf-vdC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="trailing" secondItem="Ze5-6b-2t3" secondAttribute="trailing" id="9dD-Yg-weD"/>'''
        : '';

    final brandingConstraints = hasBranding
        ? '''
                            <constraint firstItem="Uyq-Kz-ftE" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="3kg-TC-cPP"/>
                            <constraint firstAttribute="bottom" secondItem="Uyq-Kz-ftE" secondAttribute="bottom" constant="$brandBottomPaddingPt" id="8Yb-q4-8bl"/>'''
        : '';

    final launchResource = hasLaunchImage
        ? '\n        <image name="LaunchImage" width="414" height="896"/>'
        : '';
    final brandingResource = hasBranding
        ? '\n        <image name="BrandingImage" width="$brandPtW" height="$brandPtH"/>'
        : '';

    return '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21507" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21505"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="Ydg-fD-yQy"/>
                        <viewControllerLayoutGuide type="bottom" id="xbc-2k-c8Z"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>$launchImageSubview$brandingSubview
                        </subviews>
                        <color key="backgroundColor" red="$rNorm" green="$gNorm" blue="$bNorm" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>$launchImageConstraints$brandingConstraints
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>$launchResource$brandingResource
    </resources>
</document>
''';
  }

  static String _contentsJsonLight(String baseName) => '''{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "$baseName.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "$baseName@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "$baseName@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
''';

  static String _contentsJsonDark(String baseName) => '''{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "$baseName.png",
      "scale" : "1x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "filename" : "${baseName}Dark.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "$baseName@2x.png",
      "scale" : "2x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "filename" : "${baseName}Dark@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "$baseName@3x.png",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "filename" : "${baseName}Dark@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
''';
}
