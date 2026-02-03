import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../snapshot/combined_snapshot.dart';
import 'service_extensions.dart';

export 'package:flutter/widgets.dart' show TextEditingController;

/// Flutter Mate SDK — Automate Flutter apps
///
/// Use this class for:
/// - **AI agents** that navigate and interact with your UI
/// - **Automated testing** without widget keys
/// - **Accessibility automation** using the semantics tree
///
/// ## Quick Start
///
/// ```dart
/// // 1. Initialize at app startup
/// await FlutterMate.initialize();
///
/// // 2. Get UI snapshot with element refs
/// final snapshot = await FlutterMate.snapshot();
/// print(snapshot);
///
/// // 3. Interact with elements
/// await FlutterMate.tap('w18');  // auto: semantic or gesture
/// await FlutterMate.setText('w9', 'hello@example.com');  // semantic action
/// await FlutterMate.typeText('w10', 'hello@example.com');  // keyboard sim
/// ```
///
/// ## Smart Action System
///
/// Actions like `tap`, `longPress`, and `scroll` are **smart**:
/// - Try semantic action first (if the node has the action)
/// - Fall back to gesture-based action automatically
///
/// ### Semantic Actions (on Semantics widgets)
/// - `setText(ref, text)` — uses `SemanticsAction.setText`
/// - `focus(ref)` — uses `SemanticsAction.focus`
///
/// ### Keyboard Simulation (on actual widgets)
/// - `typeText(ref, text)` — platform messages (like real typing)
/// - `pressKey(key)` — simulates keyboard events
///
/// ## Snapshot Structure
///
/// The snapshot shows the inspector tree (like DevTools) with semantics
/// only attached to explicit `Semantics` widgets:
///
/// ```
/// • w9: Semantics "Email" [tap, focus, setText] (TextField)
///   • w10: TextField (bounds)
/// ```
///
/// - Use `w9` (Semantics) for semantic actions like `setText`
/// - Use `w10` (TextField) for keyboard actions like `typeText`
/// - Use either for `tap` (it auto-detects the best approach)
///
/// ## External Control via VM Service
///
/// When `initialize()` is called, service extensions are registered
/// (`ext.flutter_mate.*`) allowing external control via the CLI:
///
/// ```bash
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws setText w9 "text"
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws typeText w10 "text"
/// ```
class FlutterMate {
  static SemanticsHandle? _semanticsHandle;
  static bool _initialized = false;

  // Cached snapshot for ref -> semantics ID translation
  // ignore: unnecessary_getters_setters
  static CombinedSnapshot? _lastSnapshotValue;

  // Cached Elements from inspector tree for ref -> Element lookup
  static final Map<String, Element> cachedElements = {};

  // Registry for text controllers (for in-app agent usage)
  static final Map<String, TextEditingController> _textControllers = {};

  /// Get the last snapshot (for internal use by other SDK modules)
  // ignore: unnecessary_getters_setters
  static CombinedSnapshot? get lastSnapshot => _lastSnapshotValue;

  /// Set the last snapshot (for internal use by other SDK modules)
  // ignore: unnecessary_getters_setters
  static set lastSnapshot(CombinedSnapshot? value) =>
      _lastSnapshotValue = value;

  /// Register a TextEditingController for use with fillByName
  ///
  /// ```dart
  /// FlutterMate.registerTextField('email', _emailController);
  /// ```
  static void registerTextField(String name, TextEditingController controller) {
    _textControllers[name.toLowerCase()] = controller;
  }

  /// Unregister a TextEditingController
  static void unregisterTextField(String name) {
    _textControllers.remove(name.toLowerCase());
  }

  /// Fill a text field by its registered name
  ///
  /// ```dart
  /// await FlutterMate.fillByName('email', 'hello@example.com');
  /// ```
  static Future<bool> fillByName(String name, String text) async {
    final controller = _textControllers[name.toLowerCase()];
    if (controller == null) {
      debugPrint('FlutterMate: No controller registered for "$name"');
      debugPrint('  Registered: ${_textControllers.keys.join(', ')}');
      return false;
    }
    controller.text = text;
    return true;
  }

  /// Initialize Flutter Mate
  ///
  /// Call this once at app startup (typically in main()).
  /// This enables semantics which is required for UI inspection.
  ///
  /// Can be called before or after runApp() - it will wait appropriately.
  static Future<void> initialize() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Enable semantics - must keep handle alive
    _semanticsHandle = RendererBinding.instance.ensureSemantics();

    // Register service extensions for VM Service access (CLI)
    FlutterMateServiceExtensions.register();

    _initialized = true;
    debugPrint('FlutterMate: Initialized (semantics enabled)');
  }

  /// Initialize for widget tests (use with tester.ensureSemantics())
  ///
  /// In tests, use tester.ensureSemantics() for semantics handling,
  /// then call this to enable FlutterMate without creating a second handle.
  ///
  /// This also enables test mode which skips real delays (incompatible with FakeAsync).
  ///
  /// If [tester] is provided (a `WidgetTester` from flutter_test), FlutterMate
  /// will automatically call `pumpAndSettle()` after each action, eliminating
  /// the need for manual pump calls.
  ///
  /// ```dart
  /// testWidgets('my test', (tester) async {
  ///   tester.ensureSemantics();
  ///   FlutterMate.initializeForTest(tester: tester);
  ///   await tester.pumpWidget(const MyApp());
  ///
  ///   // No manual pump calls needed!
  ///   await FlutterMate.fillByLabel('Email', 'test@example.com');
  ///   await FlutterMate.tapByLabel('Login');
  /// });
  /// ```
  static void initializeForTest({dynamic tester}) {
    _initialized = true;
    _testMode = true;
    _tester = tester;
  }

  static bool _testMode = false;

  // WidgetTester instance for auto-pumping (stored as dynamic to avoid
  // flutter_test dependency in production code)
  static dynamic _tester;

  /// Pump the widget tree if in test mode with a tester provided.
  ///
  /// This is called automatically after each action when a tester is provided
  /// to [initializeForTest]. You typically don't need to call this manually.
  ///
  /// [settle] - If true (default), calls `pumpAndSettle()`. If false, calls `pump()`.
  static Future<void> pumpIfTesting({bool settle = true}) async {
    if (_tester != null) {
      if (settle) {
        await (_tester as dynamic).pumpAndSettle();
      } else {
        await (_tester as dynamic).pump();
      }
    }
  }

  /// Pump a widget for testing.
  ///
  /// This combines `tester.pumpWidget()` and `tester.pumpAndSettle()` into a
  /// single call. Requires a tester to be provided to [initializeForTest].
  ///
  /// ```dart
  /// testWidgets('my test', (tester) async {
  ///   tester.ensureSemantics();
  ///   FlutterMate.initializeForTest(tester: tester);
  ///   await FlutterMate.pumpApp(const MyApp());
  ///
  ///   // App is ready, no manual pump calls needed!
  ///   await FlutterMate.tapByLabel('Login');
  /// });
  /// ```
  ///
  /// [settle] - If true (default), calls `pumpAndSettle()` after pumping.
  /// If false, calls `pump()` once.
  static Future<void> pumpApp(Widget app, {bool settle = true}) async {
    if (_tester == null) {
      throw StateError(
        'FlutterMate.pumpApp() requires a tester. '
        'Call FlutterMate.initializeForTest(tester: tester) first.',
      );
    }
    await (_tester as dynamic).pumpWidget(app);
    if (settle) {
      await (_tester as dynamic).pumpAndSettle();
    } else {
      await (_tester as dynamic).pump();
    }
  }

  /// Whether running in test mode (skips real delays)
  static bool get isTestMode => _testMode;

  /// Delay that respects test mode (skips in FakeAsync environment)
  static Future<void> delay(Duration duration) async {
    if (!_testMode) {
      await Future.delayed(duration);
    }
  }

  /// Dispatch a pointer event through the appropriate binding
  ///
  /// In test mode, uses WidgetsBinding which properly integrates with FakeAsync.
  /// At runtime, uses GestureBinding directly.
  static void dispatchPointerEvent(PointerEvent event) {
    // Use WidgetsBinding if available (works in both test and runtime)
    // This properly integrates with the test binding's event queue
    WidgetsBinding.instance.handlePointerEvent(event);
  }

  // Note: In debug builds, Flutter allows client ID -1 as a magic value
  // that bypasses client ID verification. This lets us send text input
  // without needing to intercept the channel to capture the real ID.
  // See: TextInput._handleTextInputInvocation in Flutter SDK

  /// Dispatch text input via platform message simulation
  ///
  /// Uses the same mechanism as Flutter's TestTextInput - injects a
  /// platform message to simulate keyboard input.
  ///
  /// Uses client ID -1 which is a magic value in debug builds that
  /// bypasses client ID verification.
  static Future<void> dispatchTextInput(String text) async {
    const codec = JSONMethodCodec();

    // Use client ID -1 (magic value in debug builds that bypasses verification)
    // See: TextInput._handleTextInputInvocation in Flutter SDK
    const int magicClientId = -1;

    // Use channelBuffers.push which is the modern approach
    ServicesBinding.instance.channelBuffers.push(
      'flutter/textinput',
      codec.encodeMethodCall(MethodCall(
        'TextInputClient.updateEditingState',
        <dynamic>[
          magicClientId,
          <String, dynamic>{
            'text': text,
            'selectionBase': text.length,
            'selectionExtent': text.length,
            'composingBase': -1,
            'composingExtent': -1,
          },
        ],
      )),
      (ByteData? response) {
        // Response handling (usually empty)
      },
    );

    await delay(const Duration(milliseconds: 50));
  }

  /// Wait for the UI to be ready (call after runApp if needed)
  static Future<void> waitForFirstFrame() async {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    // Schedule a frame in case one isn't pending
    SchedulerBinding.instance.scheduleFrame();
    await completer.future;
    // Give semantics tree time to build
    await delay(const Duration(milliseconds: 100));
  }

  /// Dispose Flutter Mate resources
  static void dispose() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    _initialized = false;
    _testMode = false;
    _tester = null;
  }

  /// Ensure FlutterMate is initialized
  static void ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'FlutterMate not initialized. Call FlutterMate.initialize() first.',
      );
    }
  }
}
