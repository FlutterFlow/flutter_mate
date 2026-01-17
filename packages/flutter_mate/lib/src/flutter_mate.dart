import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

export 'package:flutter/widgets.dart' show TextEditingController;

import 'snapshot.dart';

/// Flutter Mate SDK — Automate Flutter apps
///
/// Use this class for:
/// - **In-app AI agents** that navigate and interact with your UI
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
/// final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
/// print(snapshot);
///
/// // 3. Interact with elements
/// await FlutterMate.fill('w5', 'hello@example.com');
/// await FlutterMate.tap('w10');
/// ```
///
/// ## Three Ways to Interact
///
/// 1. **Semantics Actions** — `tap()`, `fill()`, `scroll()`, `focus()`
///    Uses Flutter's accessibility system. Most reliable.
///
/// 2. **Gesture Simulation** — `tapAt()`, `tapGesture()`, `drag()`
///    Injects raw pointer events. For complex gestures.
///
/// 3. **Keyboard Simulation** — `typeText()`, `pressKey()`, `pressEnter()`
///    Sends platform channel messages like a real keyboard.
///
/// ## External Control via VM Service
///
/// When `initialize()` is called, service extensions are registered
/// (`ext.flutter_mate.*`) allowing external control via the CLI:
///
/// ```bash
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
/// ```
class FlutterMate {
  static SemanticsHandle? _semanticsHandle;
  static bool _initialized = false;

  // Registry for text controllers (for in-app agent usage)
  static final Map<String, TextEditingController> _textControllers = {};

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
    _registerServiceExtensions();

    _initialized = true;
    debugPrint('FlutterMate: Initialized (semantics enabled)');
  }

  /// Register VM Service extensions for external control via CLI
  static void _registerServiceExtensions() {
    // Only register in debug/profile mode
    assert(() {
      // ext.flutter_mate.snapshot - Get UI snapshot
      registerExtension('ext.flutter_mate.snapshot', (method, params) async {
        final interactiveOnly = params['interactiveOnly'] == 'true';
        final snap = await snapshot(interactiveOnly: interactiveOnly);
        return ServiceExtensionResponse.result(jsonEncode(snap.toJson()));
      });

      // ext.flutter_mate.tap - Tap element by ref
      registerExtension('ext.flutter_mate.tap', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await tap(ref);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.fill - Fill text field
      registerExtension('ext.flutter_mate.fill', (method, params) async {
        final ref = params['ref'];
        final text = params['text'];
        if (ref == null || text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref or text parameter',
          );
        }
        final success = await fill(ref, text);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.scroll - Scroll element
      registerExtension('ext.flutter_mate.scroll', (method, params) async {
        final ref = params['ref'];
        final dirStr = params['direction'] ?? 'down';
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final direction = switch (dirStr) {
          'up' => ScrollDirection.up,
          'left' => ScrollDirection.left,
          'right' => ScrollDirection.right,
          _ => ScrollDirection.down,
        };
        final success = await scroll(ref, direction);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.focus - Focus element
      registerExtension('ext.flutter_mate.focus', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await focus(ref);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      debugPrint('FlutterMate: Service extensions registered');
      return true;
    }());
  }

  /// Wait for the UI to be ready (call after runApp if needed)
  static Future<void> _waitForFirstFrame() async {
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
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Dispose Flutter Mate resources
  static void dispose() {
    _semanticsHandle?.dispose();
    _semanticsHandle = null;
    _initialized = false;
  }

  /// Get a snapshot of the current UI
  ///
  /// Returns a [Snapshot] containing all semantics nodes.
  /// Use [interactiveOnly] to filter to only interactive elements.
  static Future<Snapshot> snapshot({bool interactiveOnly = false}) async {
    _ensureInitialized();

    // Find the semantics owner from render views
    SemanticsNode? rootNode = _findRootSemanticsNode();

    // If not found, wait for first frame and try again
    if (rootNode == null) {
      await _waitForFirstFrame();
      rootNode = _findRootSemanticsNode();
    }

    if (rootNode == null) {
      return Snapshot(
        success: false,
        error: 'No root semantics node found. Is the UI rendered?',
        timestamp: DateTime.now(),
        nodes: [],
        refs: {},
      );
    }

    final nodes = <SnapshotNode>[];
    final refs = <String, SnapshotNode>{};

    _extractNode(rootNode, nodes, refs, interactiveOnly: interactiveOnly);

    return Snapshot(
      success: true,
      timestamp: DateTime.now(),
      nodes: nodes,
      refs: refs,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEMANTICS-BASED ACTIONS
  // These use Flutter's accessibility system to interact with elements.
  // Most reliable way to interact with standard Flutter widgets.
  // ══════════════════════════════════════════════════════════════════════════

  /// Tap on an element by ref
  ///
  /// ```dart
  /// await FlutterMate.tap('w5');
  /// ```
  static Future<bool> tap(String ref) async {
    return _performAction(ref, SemanticsAction.tap);
  }

  /// Long press on an element by ref
  static Future<bool> longPress(String ref) async {
    return _performAction(ref, SemanticsAction.longPress);
  }

  /// Fill a text field by ref
  ///
  /// ```dart
  /// await FlutterMate.fill('w3', 'hello@example.com');
  /// ```
  static Future<bool> fill(String ref, String text) async {
    _ensureInitialized();

    final node = _findNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final data = node.getSemanticsData();

    // Try to focus first
    if (data.hasAction(SemanticsAction.focus)) {
      node.owner?.performAction(node.id, SemanticsAction.focus);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Try setText even if not advertised - it often works anyway!
    // TextField may handle it internally even without advertising
    node.owner?.performAction(node.id, SemanticsAction.setText, text);
    await Future.delayed(const Duration(milliseconds: 100));

    return true;
  }

  /// Scroll an element
  ///
  /// ```dart
  /// await FlutterMate.scroll('w10', ScrollDirection.down);
  /// ```
  static Future<bool> scroll(String ref, ScrollDirection direction) async {
    final action = switch (direction) {
      ScrollDirection.up => SemanticsAction.scrollUp,
      ScrollDirection.down => SemanticsAction.scrollDown,
      ScrollDirection.left => SemanticsAction.scrollLeft,
      ScrollDirection.right => SemanticsAction.scrollRight,
    };
    return _performAction(ref, action);
  }

  /// Focus on an element by ref
  static Future<bool> focus(String ref) async {
    return _performAction(ref, SemanticsAction.focus);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GESTURE SIMULATION
  // These inject raw pointer events to simulate touches and drags.
  // Use when you need precise control over gesture timing and position.
  // ══════════════════════════════════════════════════════════════════════════
  // ============================================================

  static int _pointerIdCounter = 0;

  /// Simulate a tap at screen coordinates
  ///
  /// This sends real pointer events, mimicking actual user touch.
  /// ```dart
  /// await FlutterMate.tapAt(Offset(100, 200));
  /// ```
  static Future<void> tapAt(Offset position) async {
    _ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Pointer down
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
    ));

    await Future.delayed(const Duration(milliseconds: 50));

    // Pointer up
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + const Duration(milliseconds: 50),
    ));

    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Simulate a tap on an element using its bounding box
  ///
  /// This uses real pointer events at the element's center.
  static Future<bool> tapGesture(String ref) async {
    _ensureInitialized();

    final snap = await snapshot();
    final node = snap[ref];
    if (node == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    // Calculate center of element
    final center = Offset(
      node.rect.x + node.rect.width / 2,
      node.rect.y + node.rect.height / 2,
    );

    await tapAt(center);
    return true;
  }

  /// Simulate a drag/swipe gesture
  ///
  /// ```dart
  /// await FlutterMate.drag(
  ///   from: Offset(200, 500),
  ///   to: Offset(200, 200),
  ///   duration: Duration(milliseconds: 300),
  /// );
  /// ```
  static Future<void> drag({
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 300),
    int steps = 20,
  }) async {
    _ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final startTime =
        Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
    final stepDuration = duration ~/ steps;
    final delta = (to - from) / steps.toDouble();

    // Pointer down at start
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: from,
      timeStamp: startTime,
    ));

    // Move through intermediate points
    var currentPosition = from;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      currentPosition = from + delta * i.toDouble();

      GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: delta,
        timeStamp: startTime + stepDuration * i,
      ));
    }

    // Pointer up at end
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: to,
      timeStamp: startTime + duration,
    ));

    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Simulate a scroll gesture on an element
  ///
  /// ```dart
  /// await FlutterMate.scrollGesture('w15', Offset(0, -200));
  /// ```
  static Future<bool> scrollGesture(String ref, Offset delta) async {
    _ensureInitialized();

    final snap = await snapshot();
    final node = snap[ref];
    if (node == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final center = Offset(
      node.rect.x + node.rect.width / 2,
      node.rect.y + node.rect.height / 2,
    );

    await drag(
      from: center,
      to: center + delta,
      duration: const Duration(milliseconds: 200),
    );

    return true;
  }

  /// Simulate a long press at screen coordinates
  static Future<void> longPressAt(
    Offset position, {
    Duration pressDuration = const Duration(milliseconds: 500),
  }) async {
    _ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Pointer down
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
    ));

    // Hold for long press duration
    await Future.delayed(pressDuration);

    // Pointer up
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + pressDuration,
    ));

    await Future.delayed(const Duration(milliseconds: 50));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KEYBOARD / TEXT INPUT SIMULATION
  // Sends platform channel messages exactly like a real keyboard would.
  //
  // How it works:
  // 1. When a TextField is focused, Flutter assigns a connection ID
  // 2. Platform sends 'TextInputClient.updateEditingState' with that ID
  // 3. We simulate this by calling channelBuffers.push() with the message
  //
  // Usage:
  //   FlutterMate.tapAt(fieldCenter);   // Focus the field
  //   FlutterMate.nextConnection();      // Track the new connection
  //   await FlutterMate.typeText('...');  // Type like a real keyboard
  // ══════════════════════════════════════════════════════════════════════════

  static int? _activeTextInputConnectionId;
  static String _currentText = '';
  static int _connectionIdCounter = 0;

  /// Type text into the currently focused text field
  ///
  /// Sends platform channel messages exactly like a real keyboard.
  /// Call [nextConnection] after focusing a new field.
  ///
  /// ```dart
  /// FlutterMate.tapAt(fieldCenter);
  /// await Future.delayed(Duration(milliseconds: 300));
  /// FlutterMate.nextConnection();
  /// await FlutterMate.typeText('hello@example.com');
  /// ```
  static Future<bool> typeText(String text) async {
    _ensureInitialized();

    // Use tracked ID or try incrementing counter
    // Connection IDs in Flutter start at 1 and increment with each focus
    int connectionId =
        _activeTextInputConnectionId ?? (_connectionIdCounter + 1);

    debugPrint('FlutterMate: Typing "$text" to connection ID: $connectionId');

    try {
      final binding = ServicesBinding.instance;

      // Type character by character to simulate real typing
      for (int i = 0; i < text.length; i++) {
        _currentText += text[i];

        // Create the message exactly as the platform would send it
        final message = const JSONMethodCodec().encodeMethodCall(
          MethodCall('TextInputClient.updateEditingState', <dynamic>[
            connectionId,
            <String, dynamic>{
              'text': _currentText,
              'selectionBase': _currentText.length,
              'selectionExtent': _currentText.length,
              'composingBase': -1,
              'composingExtent': -1,
            },
          ]),
        );

        // KEY FIX: Use handlePlatformMessage to dispatch AS IF from the platform
        // messenger.send() sends TO platform, handlePlatformMessage receives FROM platform
        final completer = Completer<void>();
        binding.channelBuffers.push(
          'flutter/textinput',
          message,
          (ByteData? response) {
            completer.complete();
          },
        );
        await completer.future;
        await Future.delayed(const Duration(milliseconds: 25));
      }

      debugPrint('FlutterMate: Typed "$text" successfully');
      return true;
    } catch (e, stack) {
      debugPrint('FlutterMate: typeText error: $e\n$stack');
      return false;
    }
  }

  /// Manually set the text input connection ID
  /// Call this if automatic detection isn't working
  static void setConnectionId(int id) {
    _activeTextInputConnectionId = id;
    _connectionIdCounter = id;
    debugPrint('FlutterMate: Set connection ID to $id');
  }

  /// Increment connection ID (call when focusing a new field)
  static void nextConnection() {
    _connectionIdCounter++;
    _activeTextInputConnectionId = _connectionIdCounter;
    _currentText = '';
    debugPrint('FlutterMate: Connection ID now $_connectionIdCounter');
  }

  /// Clear the current text field
  static Future<bool> clearText() async {
    _ensureInitialized();

    if (_activeTextInputConnectionId == null) {
      debugPrint('FlutterMate: No active text input');
      return false;
    }

    try {
      final messenger = WidgetsBinding.instance.defaultBinaryMessenger;
      _currentText = '';

      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('TextInputClient.updateEditingState', <dynamic>[
          _activeTextInputConnectionId,
          <String, dynamic>{
            'text': '',
            'selectionBase': 0,
            'selectionExtent': 0,
            'composingBase': -1,
            'composingExtent': -1,
          },
        ]),
      );

      await messenger.send('flutter/textinput', message);
      return true;
    } catch (e) {
      debugPrint('FlutterMate: clearText error: $e');
      return false;
    }
  }

  /// Get current active text input connection ID (for debugging)
  static int? get activeTextInputConnectionId => _activeTextInputConnectionId;

  /// Get current text in the active input (for debugging)
  static String get currentInputText => _currentText;

  /// Simulate pressing a specific key
  ///
  /// ```dart
  /// await FlutterMate.pressKey(LogicalKeyboardKey.enter);
  /// await FlutterMate.pressKey(LogicalKeyboardKey.tab);
  /// ```
  static Future<bool> pressKey(LogicalKeyboardKey key) async {
    _ensureInitialized();

    try {
      final messenger = WidgetsBinding.instance.defaultBinaryMessenger;
      final keyId = key.keyId;

      await _sendKeyEventWithLogicalKey(messenger, 'keydown', keyId, 0);
      await Future.delayed(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, 0);
      await Future.delayed(const Duration(milliseconds: 30));

      return true;
    } catch (e) {
      debugPrint('FlutterMate: pressKey error: $e');
      return false;
    }
  }

  static Future<void> _sendKeyEventWithLogicalKey(
    BinaryMessenger messenger,
    String type,
    int logicalKeyId,
    int modifiers,
  ) async {
    final message = const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'type': type,
      'keymap': 'macos',
      'keyCode': logicalKeyId & 0xFFFF,
      'modifiers': modifiers,
    });

    if (message != null) {
      await messenger.send('flutter/keyevent', message);
    }
  }

  /// Simulate pressing Enter key
  static Future<bool> pressEnter() => pressKey(LogicalKeyboardKey.enter);

  /// Simulate pressing Tab key
  static Future<bool> pressTab() => pressKey(LogicalKeyboardKey.tab);

  /// Simulate pressing Escape key
  static Future<bool> pressEscape() => pressKey(LogicalKeyboardKey.escape);

  /// Simulate pressing Backspace key
  static Future<bool> pressBackspace() =>
      pressKey(LogicalKeyboardKey.backspace);

  /// Simulate pressing arrow keys
  static Future<bool> pressArrowUp() => pressKey(LogicalKeyboardKey.arrowUp);
  static Future<bool> pressArrowDown() =>
      pressKey(LogicalKeyboardKey.arrowDown);
  static Future<bool> pressArrowLeft() =>
      pressKey(LogicalKeyboardKey.arrowLeft);
  static Future<bool> pressArrowRight() =>
      pressKey(LogicalKeyboardKey.arrowRight);

  /// Simulate keyboard shortcut (e.g., Cmd+A, Ctrl+C)
  ///
  /// ```dart
  /// await FlutterMate.pressShortcut(LogicalKeyboardKey.keyA, command: true);  // Cmd+A
  /// await FlutterMate.pressShortcut(LogicalKeyboardKey.keyC, control: true);  // Ctrl+C
  /// ```
  static Future<bool> pressShortcut(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
    bool command = false,
  }) async {
    _ensureInitialized();

    try {
      final messenger = WidgetsBinding.instance.defaultBinaryMessenger;

      // macOS modifier flags
      int modifiers = 0;
      if (shift) modifiers |= 0x20000;
      if (control) modifiers |= 0x40000;
      if (alt) modifiers |= 0x80000;
      if (command) modifiers |= 0x100000;

      final keyId = key.keyId;

      await _sendKeyEventWithLogicalKey(messenger, 'keydown', keyId, modifiers);
      await Future.delayed(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, modifiers);
      await Future.delayed(const Duration(milliseconds: 30));

      return true;
    } catch (e) {
      debugPrint('FlutterMate: pressShortcut error: $e');
      return false;
    }
  }

  /// Wait for an element to appear
  ///
  /// Returns the ref if found, null if timeout.
  static Future<String?> waitFor(
    String labelPattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    _ensureInitialized();

    final pattern = RegExp(labelPattern, caseSensitive: false);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final snap = await snapshot();
      for (final node in snap.nodes) {
        if (node.label != null && pattern.hasMatch(node.label!)) {
          return node.ref;
        }
        if (node.value != null && pattern.hasMatch(node.value!)) {
          return node.ref;
        }
      }
      await Future.delayed(pollInterval);
    }

    return null;
  }

  // === Private Methods ===

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'FlutterMate not initialized. Call FlutterMate.initialize() first.',
      );
    }
  }

  static SemanticsNode? _findRootSemanticsNode() {
    final renderViews = RendererBinding.instance.renderViews;
    for (final view in renderViews) {
      final owner = view.owner;
      if (owner?.semanticsOwner?.rootSemanticsNode != null) {
        return owner!.semanticsOwner!.rootSemanticsNode;
      }
    }
    return null;
  }

  static Future<bool> _performAction(String ref, SemanticsAction action) async {
    _ensureInitialized();

    final node = _findNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final data = node.getSemanticsData();
    if (!data.hasAction(action)) {
      debugPrint('FlutterMate: Node $ref does not support $action');
      return false;
    }

    node.owner?.performAction(node.id, action);
    await Future.delayed(const Duration(milliseconds: 100));

    return true;
  }

  static SemanticsNode? _findNode(String ref) {
    // Clean ref: '@w5' -> 'w5' -> 5
    final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;
    if (!cleanRef.startsWith('w')) return null;
    final nodeId = int.tryParse(cleanRef.substring(1));
    if (nodeId == null) return null;

    // Find root
    SemanticsNode? rootNode;
    for (final view in RendererBinding.instance.renderViews) {
      if (view.owner?.semanticsOwner?.rootSemanticsNode != null) {
        rootNode = view.owner!.semanticsOwner!.rootSemanticsNode;
        break;
      }
    }
    if (rootNode == null) return null;

    return _searchNode(rootNode, nodeId);
  }

  static SemanticsNode? _searchNode(SemanticsNode node, int targetId) {
    if (node.id == targetId) return node;

    SemanticsNode? found;
    node.visitChildren((child) {
      final result = _searchNode(child, targetId);
      if (result != null) {
        found = result;
        return false;
      }
      return true;
    });
    return found;
  }

  static void _extractNode(
    SemanticsNode node,
    List<SnapshotNode> nodes,
    Map<String, SnapshotNode> refs, {
    bool interactiveOnly = false,
    int depth = 0,
  }) {
    final data = node.getSemanticsData();
    final actions = _getActions(data);
    final flags = _getFlags(data);

    final isInteractive = actions.isNotEmpty ||
        flags.contains('isButton') ||
        flags.contains('isTextField') ||
        flags.contains('isLink') ||
        flags.contains('isFocusable');

    // Skip non-interactive nodes if filter is on
    if (interactiveOnly && !isInteractive && depth > 0) {
      node.visitChildren((child) {
        _extractNode(child, nodes, refs,
            interactiveOnly: interactiveOnly, depth: depth + 1);
        return true;
      });
      return;
    }

    final ref = 'w${node.id}';
    final rect = node.rect;
    final transform = node.transform;

    // Calculate global position
    Offset globalTopLeft = rect.topLeft;
    if (transform != null) {
      globalTopLeft = MatrixUtils.transformPoint(transform, rect.topLeft);
    }

    final snapshotNode = SnapshotNode(
      ref: ref,
      id: node.id,
      depth: depth,
      label: data.label.isNotEmpty ? data.label : null,
      value: data.value.isNotEmpty ? data.value : null,
      hint: data.hint.isNotEmpty ? data.hint : null,
      actions: actions,
      flags: flags,
      rect: Rect(
        x: globalTopLeft.dx.round(),
        y: globalTopLeft.dy.round(),
        width: rect.width.round(),
        height: rect.height.round(),
      ),
      isInteractive: isInteractive,
    );

    nodes.add(snapshotNode);
    refs[ref] = snapshotNode;

    node.visitChildren((child) {
      _extractNode(child, nodes, refs,
          interactiveOnly: interactiveOnly, depth: depth + 1);
      return true;
    });
  }

  static List<String> _getActions(SemanticsData data) {
    final actions = <String>[];
    if (data.hasAction(SemanticsAction.tap)) actions.add('tap');
    if (data.hasAction(SemanticsAction.longPress)) actions.add('longPress');
    if (data.hasAction(SemanticsAction.scrollLeft)) actions.add('scrollLeft');
    if (data.hasAction(SemanticsAction.scrollRight)) actions.add('scrollRight');
    if (data.hasAction(SemanticsAction.scrollUp)) actions.add('scrollUp');
    if (data.hasAction(SemanticsAction.scrollDown)) actions.add('scrollDown');
    if (data.hasAction(SemanticsAction.focus)) actions.add('focus');
    if (data.hasAction(SemanticsAction.setText)) actions.add('setText');
    return actions;
  }

  static List<String> _getFlags(SemanticsData data) {
    final flags = <String>[];

    void checkFlag(SemanticsFlag flag, String name) {
      // ignore: deprecated_member_use
      if (data.hasFlag(flag)) flags.add(name);
    }

    checkFlag(SemanticsFlag.isButton, 'isButton');
    checkFlag(SemanticsFlag.isTextField, 'isTextField');
    checkFlag(SemanticsFlag.isLink, 'isLink');
    checkFlag(SemanticsFlag.isFocusable, 'isFocusable');
    checkFlag(SemanticsFlag.isFocused, 'isFocused');
    checkFlag(SemanticsFlag.isEnabled, 'isEnabled');
    checkFlag(SemanticsFlag.isChecked, 'isChecked');
    checkFlag(SemanticsFlag.isSelected, 'isSelected');
    checkFlag(SemanticsFlag.isToggled, 'isToggled');
    checkFlag(SemanticsFlag.isHeader, 'isHeader');
    checkFlag(SemanticsFlag.isSlider, 'isSlider');
    checkFlag(SemanticsFlag.isImage, 'isImage');
    checkFlag(SemanticsFlag.isObscured, 'isObscured');

    return flags;
  }
}

/// Scroll direction for [FlutterMate.scroll]
enum ScrollDirection { up, down, left, right }
