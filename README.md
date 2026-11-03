# flutter_native_splash_next

[![pub package](https://img.shields.io/badge/pub-v1.0.0-blue)](https://pub.dev/packages/flutter_native_splash_next)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D2.19.0%20%3C4.0.0-00B4AB)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20HarmonyOS%20NEXT%20%7C%20Web-success)](#)

专为 **Flutter 多端工程** 打造的下一代零闪烁、全屏不变形原生启动屏（Native Splash Screen）一键生成工具。
全量支持 **Android（API 21–35 / Android 12–15+）**、**iOS**、**HarmonyOS NEXT（纯血鸿蒙 OpenHarmony API 12+）** 与 **Web** 四大平台。

---

## 目录

- [一、核心特性与架构优势](#一核心特性与架构优势)
- [二、环境要求与多端版本兼容性说明](#二环境要求与多端版本兼容性说明)
- [三、快速开始](#三快速开始)
  - [模式 A：声明式组件配置（推荐）](#模式-a声明式组件配置最推荐)
  - [模式 B：单张全屏成品设计稿](#模式-b单张全屏成品设计稿推荐-1242--2688-3x-切图)
- [四、命令行（CLI）使用指南](#四命令行cli使用指南)
- [五、四端底层实现原理与生成产物说明](#五四端底层实现原理与生成产物说明)
- [六、完整配置参数参考表](#六完整配置参数参考表)
- [七、常见问题排查（FAQ）](#七常见问题排查faq)

---

## 一、核心特性与架构优势

`flutter_native_splash_next` 提供了一套面向多端生产环境的原生启动屏自动化生成方案，具备以下五大核心能力：

| 核心能力 | 功能亮点与技术实现 |
| :--- | :--- |
| **1. 声明式组件化配置（免切全屏大图）** | 只需传入一张普通 App 桌面图标（`app_icon.png`）与可选背景图，即可在 YAML 中自由配置 **Logo 宽高、圆角半径、黄金分割比例、产品名称文字（支持中英文/字号/颜色/粗细/间距）**；底部区域既可配置 **文字**，也可配置 **透明图片（支持指定高度等比缩放）**，或者直接省略底部区域。 |
| **2. Android 全屏正方形出血等比居中引擎** | 自动按 Android `360dp` 安全区缩放，并向四周平滑延展边缘像素生成 `2688×2688` 正方形出血画布（`drawable-xxhdpi/bg_splash.png`），配合 `android:gravity="center"` 与自动清理 `values-v31` / `values-v33` 中心圆圈图标覆盖，在 Android 5.0 ~ 15+ 上实现 **0ms 全屏 `centerCrop` 等比铺满、绝不拉伸变形**。 |
| **3. 四端全链路底部独立安全区锚定** | 支持将底部品牌文字或图片分离为独立顶层图层，在不同屏幕长宽比下永远保持固定底边距：<br>• **Android**：`<layer-list>` 顶层 `<item android:bottom="48dp">` 锚定 `@drawable/splash_brand`<br>• **iOS**：`LaunchScreen.storyboard` 独立 `BrandingImage` 视图绑定底部 `48pt` 约束<br>• **Web**：独立 `#splash-branding` 节点固定 `bottom: 48px`<br>• **HarmonyOS NEXT**：自动按 `1242×2688` 黄金比例合成 `48vp` 底部安全边距 |
| **4. RGB 预合成防重影与无损出血图像处理** | 在图像缩放与出血延展前，自动将半透明 Alpha 像素与基础背景色预合成为纯净的 3 通道 `RGB` 图像，彻底消除半透明 PNG 缩放后常见的边缘残影与白边，确保文字与 Logo 边缘 100% 锐利干净。 |
| **5. 鸿蒙 NEXT 双阶段零白屏无缝接力** | 原生支持 OpenHarmony API 12+ 双阶段启动接力：<br>① **第一阶段（系统 0ms 窗口）**：自动生成 `start_window.json`（`Cover` 全屏背景图）并挂载至 `module.json5`；<br>② **第二阶段（ArkUI 承接）**：自动为 `Index.ets` 注入带 `.objectFit(ImageFit.Cover).syncLoad(true).expandSafeArea(...)` 的 `splashBuilder`，彻底消除异步解码带来的 1~2 帧白屏闪烁。 |

---

## 二、环境要求与多端版本兼容性说明

### 1. Flutter & Dart SDK 版本限制

为了同时兼顾 **主流 Flutter 3.x 工程** 与 **OpenHarmony（鸿蒙 NEXT）分支**，本工具采用了宽泛且向后兼容的 SDK 约束：

| 环境依赖 | 最低支持版本 | 已验证最高版本 | 兼容性说明 |
| :--- | :--- | :--- | :--- |
| **Dart SDK** | `>=2.19.0 <4.0.0` | `3.11.5` | 同时兼容 Dart 2.19（Flutter 3.7）至 Dart 3.11.5 |
| **Flutter SDK（官方 Android/iOS/Web）** | `>=3.7.0` | `3.41.x` | 兼容 Flutter `3.7` ~ `3.41+` |
| **Flutter SDK（鸿蒙 OpenHarmony 版）** | `>=3.7.12-ohos` | **`3.41.9+ohos-1.0.2`** | **鸿蒙端目前已实测支持至 `Flutter 3.41.9+ohos-1.0.2`（配套 `compatibleSdkVersion: 5.1.0(18)` / `targetSdkVersion: 26.0.0`）；后续更高版本暂未测试，升级后请自行验证测试** |
| **开发宿主机 OS** | macOS / Windows / Linux | macOS / Windows / Linux | 文字渲染自动调用宿主机矢量字体引擎（macOS `CoreText/PingFang SC`、Windows `.NET DirectWrite/微软雅黑`、Linux `Pillow/NotoSansCJK`），并支持加载项目内自定义 `.ttf`/`.otf` 字体 |

> **零原生依赖说明**：`flutter_native_splash_next` 是纯 Dart 实现的编译前 CLI 资源与配置生成工具，同时提供基于 Flutter 原生 `WidgetsBinding` 的 `FlutterNativeSplashNext.preserve()` / `remove()` 首帧留存辅助方法，**不会**向 App 注入任何第三方原生 MethodChannel 插件代码。

### 2. 四端系统版本兼容性矩阵

| 目标平台 | 支持系统版本范围 | 屏幕形态适配说明 |
| :--- | :--- | :--- |
| **Android** | **Android 5.0 ~ Android 15+**<br>（API Level 21 ~ 35+） | • **Android 5 ~ 11**：直接通过 `values/styles.xml` 的 `android:windowBackground` 渲染双层 `<layer-list>`。<br>• **Android 12 ~ 15+（API 31 ~ 35）**：自动清理 `values-v31` 与 `values-v33` 中的 `windowSplashScreenAnimatedIcon`，触发系统 `StartingWindow` 全屏背景模式，0ms 秒开全屏且兼容直板机（`16:9` ~ `21:9`）、刘海/挖孔屏（`shortEdges`）与折叠屏。 |
| **iOS** | **iOS 12.0 ~ iOS 18+** | 基于 Xcode 标准 `LaunchScreen.storyboard` + Universal `@1x / @2x / @3x` `Assets.xcassets` 图集，自动同步 `Info.plist` 状态栏显隐（`UIStatusBarHidden`），全量兼容 iPhone SE、iPhone 14/15/16 Pro Max 及 iPad 横竖屏。 |
| **HarmonyOS NEXT** | **HarmonyOS NEXT 5.0 ~ 5.1.0(18)**<br>（OpenHarmony API 12 ~ 18 / Target 26.0.0） | 采用标准 `startWindow` 配置文件（`$profile:start_window`）+ ArkUI `FlutterPage({ splashScreenView })` 同步加载接力，兼容直板机与折叠屏。<br>⚠️ **注：鸿蒙端暂定支持至当前已测版本（`Flutter 3.41.9+ohos-1.0.2` / HarmonyOS SDK `5.1.0(18)`），后续新版本未测试，需开发者自行测试验证。** |
| **Web** | 现代主流浏览器（Chrome / Safari / Edge / Firefox） | 采用三层响应式固定定位（背景 `cover` + 顶部 Logo 百分比定位 + 底部品牌词像素定位），兼容移动端竖屏 H5 与 PC 端 `16:9` / `21:9` 宽屏浏览器。 |

---

## 三、快速开始

### 1. 添加开发依赖

在项目的 `pubspec.yaml` 中添加 `dev_dependencies`：

```yaml
dev_dependencies:
  flutter_native_splash_next: ^1.0.0
```

然后执行 `flutter pub get`。

### 2. 编写启动屏配置

你可以在 `pubspec.yaml` 中直接添加 `flutter_native_splash_next:` 节点，或者在项目根目录下新建独立的 `flutter_native_splash_next.yaml` 文件。支持以下两种配置模式：

#### 模式 A：声明式组件配置（最推荐）

无需设计师切全屏大图，只需准备一张普通的 App 图标（如 `assets/app_icon.png`）和可选的背景图，即可在 YAML 中自由微调 Logo 大小、圆角、产品名称文字以及底部文字/图片：

```yaml
flutter_native_splash_next:
  # 1. 背景配置：纯色底 或 背景底图
  color: "#EFF7F4"
  color_dark: "#121816"                        # 可选：深色模式背景底色
  background_image: "assets/bg_watercolor.png" # 可选：不传则使用纯色背景

  # 2. 顶部 Logo 与产品名称配置
  logo:
    image: "assets/app_icon.png"   # App 图标路径
    size: 80                       # Logo 显示宽高（单位 dp/pt，不传则按原图 @3x 尺寸展示）
    border_radius: 20              # 自动切圆角半径（单位 dp/pt，0 表示不额外切圆角）
    top_ratio: 0.28                # 距离屏幕顶部的垂直位置比例（默认 0.28 黄金分割位）
    title: "Rainier"               # Logo 下方的产品名称文字（支持任意中英文）
    title_size: 18                 # 产品名称字号（单位 sp/pt，默认 18）
    title_color: "#2C3432"         # 产品名称颜色（浅色模式）
    title_color_dark: "#F3F4F6"    # 产品名称颜色（深色模式，可选）
    title_spacing: 14              # Logo 底边与产品名称顶边之间的间距（单位 dp/pt，默认 14）
    title_bold: true               # 产品名称是否加粗（默认 true）
    # font_family: "PingFang SC"   # 可选：指定系统字体名称
    # font_file: "assets/fonts/BrandFont-Bold.ttf" # 可选：指定项目内自定义 .ttf/.otf 字体文件

  # 3. 底部品牌区配置（可选：如果启动屏底部不需要文字或图片，直接省略整个 branding 块即可）
  branding:
    # 方式一：直接配置底部文字（支持中英文，自动生成高清抗锯齿透明图层）
    text: "Hi, Rainier"
    text_size: 13                  # 底部文字字号（单位 sp/pt，默认 13）
    text_color: "#343736"          # 底部文字颜色（浅色模式）
    text_color_dark: "#9CA3AF"     # 底部文字颜色（深色模式，可选）
    text_bold: false               # 底部文字是否加粗（默认 false）
    # font_family: "PingFang SC"   # 可选：指定系统字体名称
    # font_file: "assets/fonts/BrandFont-Regular.ttf" # 可选：指定自定义 .ttf/.otf 字体文件

    # 方式二：或者使用底部品牌透明图片（与 text 二选一）
    # image: "assets/brand_bottom.png"
    # image_dark: "assets/brand_bottom_dark.png"
    # height: 25                   # 底部图片显示高度（单位 dp/pt，宽度自动等比缩放）

    bottom_padding: 48             # 距离屏幕物理底边的固定安全间距（单位 dp/pt/vp，默认 48）

  fullscreen: true
  android: true
  ios: true
  ohos: true
  web: true
```

#### 模式 B：单张全屏成品设计稿（推荐 `1242 × 2688` `@3x` 切图）

如果 UI 设计师已经提供了一张合成好的 `1242 × 2688` 全屏启动图，工具可以自动将其转换为 Android 正方形等比出血画布：
- **底部有品牌文字的设计稿**：开启 `auto_extract_branding: true`，自动从原图底部把品牌文字抠出为独立图层并无痕抹平背景；
- **底部无文字的设计稿**：无需配置 `auto_extract_branding`（即使配置了 `auto_extract_branding: true`，算法也会自动识别到底部无前景像素并跳过抠图与抹除），直接生成纯净单层全屏启动图。

```yaml
flutter_native_splash_next:
  color: "#EFF7F4"
  fullscreen_image: "assets/splash/splash_screen.png"

  # 可选：若原图底部包含品牌文字，开启后自动提取为独立图层并在背景中无痕抹除；若原图底部无文字则可省略
  auto_extract_branding: true
  branding_bottom_padding: 48
  # 原图（1242x2688 坐标系）中底部文字所在的矩形区域 [x0, y0, x1, y1]
  branding_source_box: [450, 2465, 795, 2560]

  fullscreen: true
  android: true
  ios: true
  ohos: true
  web: true
```

---

## 四、命令行（CLI）使用指南

### 1. 生成四端启动屏

```bash
dart run flutter_native_splash_next:create
```

### 2. 指定自定义配置文件或多渠道（Flavor）

```bash
# 指定自定义 YAML 配置文件路径
dart run flutter_native_splash_next:create -p flutter_native_splash_next.yaml

# 指定多渠道 Flavor（读取 YAML 中的 flutter_native_splash_next-staging 节点，并写入 android/app/src/staging/res）
dart run flutter_native_splash_next:create --flavor staging
```

### 3. 一键还原四端默认纯色启动屏

```bash
dart run flutter_native_splash_next:remove
```

### 4. （可选）在 Dart `main()` 中手动控制启动屏留存与释放

如果需要在首屏展示前完成轻量级必要配置加载（如读取本地登录态 Token），可使用 `FlutterNativeSplashNext.preserve()` 与 `FlutterNativeSplashNext.remove()`：

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash_next/flutter_native_splash_next.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 保持原生启动图显示，推迟首帧上屏
  FlutterNativeSplashNext.preserve(widgetsBinding: widgetsBinding);

  // 执行必要的本地快速初始化
  await initLocalAuthState();

  // 释放首帧，从原生启动图无缝切换至 Flutter 业务首帧
  FlutterNativeSplashNext.remove();
  runApp(const MyApp());
}
```

---

## 五、四端底层实现原理与生成产物说明

执行 `dart run flutter_native_splash_next:create` 后，工具会自动完成以下原生工程文件生成与改写：

### 1. Android (`android/app/src/main/res/`)
- `drawable-xxhdpi/bg_splash.png`（及深色模式 `drawable-night-xxhdpi/bg_splash.png`）：
  先将 `1242 × 2688`（`414dp` 宽基准）核心画幅等比缩放到 Android `xxhdpi`（`480dpi`）标准宽度 `1080 × 2337 px`（`360dp` 宽），再向四周平滑延展边缘像素生成 **`2688 × 2688 px` 正方形出血图**。
- `drawable-xxhdpi/splash_brand.png`：底部透明品牌文字/图片层。
- `drawable/launch_background.xml` & `drawable-v21/launch_background.xml`：
  采用双层 `<layer-list>`，底层 `bg_splash` 设置 `android:gravity="center"`（由系统按屏幕 DPI 严格 `1:1` 等比缩放并居中裁切四周出血区，彻底杜绝拉伸），顶层 `splash_brand` 设置 `<item android:bottom="48dp">` 永远固定在距离屏幕物理底边 `48dp` 处。
- `values*/styles.xml`（含 `values`、`values-night`、`values-v31`、`values-night-v31`、`values-v33`、`values-night-v33`）：
  自动清理会导致中心圆圈裁切的 `windowSplashScreenAnimatedIcon` 属性，并开启 `windowLayoutInDisplayCutoutMode = shortEdges` 刘海屏全屏延伸。

### 2. iOS (`ios/Runner/`)
- `Assets.xcassets/LaunchImage.imageset/`：生成 `@1x / @2x / @3x`（及深色模式 `Dark`）背景 + 顶部圆角 Logo 与产品名称图集。
- `Assets.xcassets/BrandingImage.imageset/`：生成 `@1x / @2x / @3x` 独立底部品牌图集。
- `Base.lproj/LaunchScreen.storyboard`：底层 `LaunchImage` 采用 `scaleAspectFill` 四边贴合父容器；顶层 `BrandingImage` 采用独立 `UIImageView`（`scaleAspectFit`）绑定距离底部 `48pt` 约束，确保在 `16:9` 的 iPhone SE、`19.5:9` 的 iPhone 16 Pro Max 及 iPad 上底部文字永远不会被裁切。

### 3. HarmonyOS NEXT (`ohos/entry/src/main/`)
- `resources/base/media/splash_screen.png`（及 `resources/dark/media/splash_screen.png`）：`1242 × 2688` 高清合成启动图。
- `resources/base/profile/start_window.json`：配置系统级 0ms 第一阶段窗口 `"startWindowBackgroundImage": "$media:splash_screen"` 与 `"startWindowBackgroundImageFit": "Cover"`。
- `module.json5` & `resources/base/element/color.json`：自动挂载 `"startWindow": "$profile:start_window"` 并同步 `start_window_background` 底色。
- `ets/pages/Index.ets`：自动配置第二阶段 ArkUI `splashBuilder()`，包含 `.objectFit(ImageFit.Cover)`、**`.syncLoad(true)`（消除异步解码导致的 1~2 帧白屏闪烁）** 与 `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`。

### 4. Web (`web/`)
- `web/splash/img/`：生成 `light.png`（背景层）、`logo.png`（顶部 Logo + 产品名称层）、`branding.png`（底部品牌层）及对应深色模式图片。
- `web/index.html`：注入三层响应式 CSS，背景层 `object-fit: cover` 铺满视口，顶部 `#splash-logo` 独立定位于 `top: 28%`，底部 `#splash-branding` 独立定位于 `bottom: 48px`。

---

## 六、完整配置参数参考表

| 参数路径（支持嵌套或扁平写法） | 类型 | 默认值 | 详细说明 |
| :--- | :--- | :--- | :--- |
| `color` | `String` | `"#EFF7F4"` | 启动屏基础背景色（支持 `#RRGGBB` 或 `0xFFRRGGBB`） |
| `color_dark` | `String?` | `null` | 深色模式启动屏背景色 |
| `background_image` | `String?` | `null` | 背景底图路径（可选，不传则使用 `color` 纯色底） |
| `background_image_dark` | `String?` | `null` | 深色模式背景底图路径 |
| `logo.image` / `logo_image` / `image` | `String?` | `null` | 顶部 Logo / App 图标图片路径 |
| `logo.image_dark` / `logo_image_dark` | `String?` | `null` | 深色模式顶部 Logo 图片路径 |
| `logo.size` / `logo_size` | `double?` | `null` | Logo 显示宽高（单位 `dp`/`pt`，不传则按原图 `@3x` 尺寸展示） |
| `logo.border_radius` / `logo_border_radius` | `double` | `0` | Logo 圆角半径（单位 `dp`/`pt`，`0` 为不额外切圆角） |
| `logo.top_ratio` / `logo_top_ratio` | `double` | `0.28` | Logo + 产品名称整体中心距离屏幕顶部的高度比例（`0.28` 黄金分割位） |
| `logo.title` / `app_name` | `String?` | `null` | Logo 下方的产品名称文字（支持任意中英文） |
| `logo.title_size` / `app_name_size` | `double` | `18` | 产品名称字号（单位 `sp`/`pt`） |
| `logo.title_color` / `app_name_color` | `String` | `"#2C3432"` | 产品名称文字颜色（浅色模式） |
| `logo.title_color_dark` / `app_name_color_dark` | `String?` | `null` | 产品名称文字颜色（深色模式） |
| `logo.title_spacing` / `app_name_spacing` | `double` | `14` | Logo 底边与产品名称顶边之间的间距（单位 `dp`/`pt`） |
| `logo.title_bold` / `app_name_bold` | `bool` | `true` | 产品名称是否使用加粗字重 |
| `logo.font_family` / `app_name_font_family` | `String?` | `null` | 产品名称文字使用的系统字体名称 |
| `logo.font_file` / `app_name_font_file` | `String?` | `null` | 产品名称文字使用的自定义 `.ttf`/`.otf` 字体文件路径 |
| `branding.text` / `branding_text` | `String?` | `null` | 底部品牌区文字（支持任意中英文，与 `branding.image` 二选一） |
| `branding.text_size` / `branding_text_size` | `double` | `13` | 底部品牌文字字号（单位 `sp`/`pt`） |
| `branding.text_color` / `branding_text_color` | `String` | `"#343736"` | 底部品牌文字颜色（浅色模式） |
| `branding.text_color_dark` / `branding_text_color_dark` | `String?` | `null` | 底部品牌文字颜色（深色模式） |
| `branding.text_bold` / `branding_text_bold` | `bool` | `false` | 底部品牌文字是否加粗 |
| `branding.font_family` / `branding_font_family` | `String?` | `null` | 底部品牌文字使用的系统字体名称 |
| `branding.font_file` / `branding_font_file` | `String?` | `null` | 底部品牌文字使用的自定义 `.ttf`/`.otf` 字体文件路径 |
| `branding.image` / `branding_image` | `String?` | `null` | 底部品牌透明图片路径（与 `branding.text` 二选一） |
| `branding.image_dark` / `branding_dark_image` | `String?` | `null` | 深色模式底部品牌透明图片路径 |
| `branding.height` / `branding_image_height` | `double?` | `null` | 底部品牌图片显示高度（单位 `dp`/`pt`，宽度自动等比缩放） |
| `branding.bottom_padding` / `branding_bottom_padding` | `int` | `48` | 底部品牌文字/图片距离屏幕底边的固定间距（单位 `dp`/`pt`/`vp`） |
| `fullscreen_image` | `String?` | `null` | 单张全屏设计稿路径（模式 B 使用） |
| `fullscreen_image_dark` | `String?` | `null` | 深色模式单张全屏设计稿路径 |
| `auto_extract_branding` | `bool` | `false` | 模式 B 下是否从 `fullscreen_image` 底部自动抠出品牌文字并无痕抹平背景 |
| `branding_source_box` | `List<int>` | `[450, 2465, 795, 2560]` | `auto_extract_branding: true` 时在 `1242×2688` 原图上的抠图区域 `[x0, y0, x1, y1]` |
| `android_bleed_canvas_size` | `int` | `2688` | Android `drawable-xxhdpi/bg_splash.png` 正方形出血画布边长（px） |
| `android_safe_width` | `int` | `1080` | Android `xxhdpi`（`360dp`）核心安全区目标宽度（px） |
| `android_fullscreen_mode` | `bool` | `true` | 是否开启 Android 12–15+ 全屏 `windowBackground` 模式 |
| `fullscreen` | `bool` | `true` | 启动阶段是否隐藏系统状态栏 |
| `android` / `ios` / `ohos` / `web` | `bool` | `true` | 是否生成对应平台的启动屏配置 |

---

## 七、常见问题排查（FAQ）

1. **为什么更新启动图后，iOS 真机上还是显示旧的启动图？**
   - iOS 的 `SpringBoard` 会强缓存 `LaunchScreen.storyboard` 渲染快照。请先从手机上**卸载旧 App**、重启手机（或清理 Xcode `DerivedData`）后重新安装即可立即生效。
2. **为什么我的 `main()` 里有很多耗时异步初始化，启动图结束后还是会闪一下白屏？**
   - 原生启动图只负责从**点击桌面图标 0ms 到 Flutter 首帧（First Frame）渲染完成**的阶段。不要在 `runApp()` 之前串行 `await` 大量非首屏必需的网络请求，建议将非关键初始化后置到首帧渲染之后执行。
3. **Android 原生代码 `MainActivity.kt` 需要手动拦截 `onPreDrawListener` 吗？**
   - **千万不要**！`FlutterActivityAndFragmentDelegate` 内部已经自动注册了首帧 `onPreDraw` 守卫，自行在 `MainActivity` 中添加永不放行的 `OnPreDrawListener` 会导致 `BLASTBufferQueue` 帧缓冲死锁。保持默认纯净的 `MainActivity : FlutterActivity()` 即可。

---

## 八、开源协议

本项目基于 [MIT License](LICENSE) 开源。
