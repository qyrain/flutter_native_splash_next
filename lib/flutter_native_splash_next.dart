/// Zero-flicker, full-screen native splash screen generator for
/// Android (12-15+ centerCrop bleed), iOS, HarmonyOS NEXT (OpenHarmony), and Web.
library flutter_native_splash_next;

export 'cli_commands.dart';
export 'src/config.dart';
export 'src/image_processor.dart';
export 'src/text_renderer.dart';

/// Optional runtime helper to preserve and release the native splash screen
/// during asynchronous initialization in `main()` via Flutter's native
/// `WidgetsBinding.deferFirstFrame()` / `allowFirstFrame()` mechanism.
///
/// Usage:
/// ```dart
/// void main() async {
///   final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
///   FlutterNativeSplashNext.preserve(widgetsBinding: widgetsBinding);
///   await initEssentialServices();
///   FlutterNativeSplashNext.remove();
///   runApp(const MyApp());
/// }
/// ```
class FlutterNativeSplashNext {
  const FlutterNativeSplashNext._();

  static dynamic _widgetsBinding;
  static bool _isDeferred = false;

  /// Keeps the native splash screen visible by deferring Flutter's first frame
  /// until [remove] is called.
  static void preserve({required dynamic widgetsBinding}) {
    _widgetsBinding = widgetsBinding;
    if (!_isDeferred && _widgetsBinding != null) {
      _widgetsBinding.deferFirstFrame();
      _isDeferred = true;
    }
  }

  /// Releases the deferred first frame so the native splash screen seamlessly
  /// hands over to Flutter's rendered first frame.
  static void remove() {
    if (_isDeferred && _widgetsBinding != null) {
      _widgetsBinding.allowFirstFrame();
      _isDeferred = false;
      _widgetsBinding = null;
    }
  }
}
