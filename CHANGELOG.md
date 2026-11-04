## 1.0.0

* Initial release of `flutter_native_splash_next`.
* **Android (API 21–35 / Android 12–15+)**:
  * Supports full-screen distortion-free `centerCrop` mode via automatic `2688x2688` square bleed generation (`drawable-xxhdpi/bg_splash.png` + `android:gravity="center"`).
  * Automatically flattens semi-transparent alpha channels onto the base background color to eliminate text/logo ghosting.
  * Supports two-layer bottom branding separation (`<item android:bottom="48dp">`) so bottom branding text never collides with system gesture bars or gets cropped across `16:9`, `20:9`, `21:9`, and foldable screens.
  * Automatically cleans `values-v31` and `values-v33` `windowSplashScreenAnimatedIcon` overrides in full-screen mode so Android 12–15 renders the full-screen `windowBackground` at 0ms.
* **HarmonyOS NEXT (OpenHarmony API 12+)**:
  * Implements the Two-Stage Zero-Flicker Handover (`start_window.json` with `Cover` fit + `Index.ets` `splashBuilder` with `.syncLoad(true)` and `.expandSafeArea`).
  * Full foldable screen and tablet support: uses `2688x2688` square bleed canvas for `splash_screen.png` and separates bottom branding into an independent `$media:splash_brand` layer anchored at `bottom: 48vp` in `Index.ets`, preventing bottom text truncation and logo distortion when unfolded.
* **iOS**:
  * Automatically configures `LaunchScreen.storyboard` with `scaleAspectFill` and 4-edge superview constraints plus `@1x / @2x / @3x` `LaunchImage.imageset` assets.
* **Web**:
  * Generates full-screen `object-fit: cover` or centered splash HTML/CSS in `web/index.html`.
