import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

export 'package:flutter/widgets.dart' show TextEditingController;

import 'combined_snapshot.dart';
import 'snapshot.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET CONSOLIDATION - Skip these wrapper widgets when they have single child
// Based on Hologram's widget_tree_filter.dart
// ══════════════════════════════════════════════════════════════════════════════

const _skipWidgets = <String>{
  // Layout wrappers
  'Padding',
  'Align',
  'Center',
  'Expanded',
  'Flexible',
  'Positioned',
  'SizedBox',
  'ConstrainedBox',
  'UnconstrainedBox',
  'LimitedBox',
  'FittedBox',
  'FractionallySizedBox',
  'IntrinsicHeight',
  'IntrinsicWidth',
  'AspectRatio',
  // Gesture wrappers
  'GestureDetector',
  'InkWell',
  'MouseRegion',
  'AbsorbPointer',
  'IgnorePointer',
  // Visual wrappers
  'Opacity',
  'Visibility',
  'ClipRect',
  'ClipRRect',
  'ClipOval',
  'ClipPath',
  'Transform',
  'RotatedBox',
  'AnimatedOpacity',
  'AnimatedAlign',
  'AnimatedPadding',
  'AnimatedPositioned',
  'AnimatedSize',
  // Semantics wrappers
  'Semantics',
  'MergeSemantics',
  'ExcludeSemantics',
  // Framework internals
  'Material',
  'SafeArea',
  'Builder',
  'RepaintBoundary',
  'KeyedSubtree',
  'Offstage',
  'WillPopScope',
  'AnimatedBuilder',
  // Private/internal widgets (start with _)
};

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
/// ## Two-Tier Action System
///
/// ### Tier 1: Semantic Actions (High-Level)
/// Uses Flutter's accessibility system via `SemanticsOwner.performAction()`.
/// - `tap()`, `focus()`, `scroll()` — work with semantic nodes
/// - Best for standard widgets with proper semantics
/// - Platform-native behavior
///
/// ### Tier 2: Gesture/Input Simulation (Low-Level)
/// Mimics actual user input at the gesture/keyboard level.
/// - `tapGesture()`, `longPressGesture()`, `doubleTap()` — inject PointerEvents
/// - `typeText()` — uses `EditableTextState.updateEditingValue()` (same as platform)
/// - `pressKey()` — simulates keyboard events
/// - Works with custom widgets that don't have standard semantics
/// - Triggers all GestureDetector callbacks
///
/// Most actions try Tier 1 first, then fall back to Tier 2 if needed.
///
/// ## Legacy API (Still Supported)
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

  /// Initialize for widget tests (use with tester.ensureSemantics())
  ///
  /// In tests, use tester.ensureSemantics() for semantics handling,
  /// then call this to enable FlutterMate without creating a second handle.
  ///
  /// This also enables test mode which skips real delays (incompatible with FakeAsync).
  ///
  /// ```dart
  /// testWidgets('my test', (tester) async {
  ///   final handle = tester.ensureSemantics();
  ///   FlutterMate.initializeForTest();
  ///   // ... test code ...
  ///   handle.dispose();
  /// });
  /// ```
  static void initializeForTest() {
    _initialized = true;
    _testMode = true;
  }

  static bool _testMode = false;

  /// Whether running in test mode (skips real delays)
  static bool get isTestMode => _testMode;

  /// Delay that respects test mode (skips in FakeAsync environment)
  static Future<void> _delay(Duration duration) async {
    if (!_testMode) {
      await Future.delayed(duration);
    }
  }

  static bool _extensionsRegistered = false;

  /// Register VM Service extensions for external control via CLI
  static void _registerServiceExtensions() {
    // Only register once (extensions persist across test runs in same VM)
    if (_extensionsRegistered) return;

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
        final distanceStr = params['distance'];
        final distance =
            distanceStr != null ? double.tryParse(distanceStr) ?? 300.0 : 300.0;
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
        final success = await scroll(ref, direction, distance: distance);
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

      // ext.flutter_mate.snapshotCombined - Get combined widget tree + semantics
      registerExtension('ext.flutter_mate.snapshotCombined',
          (method, params) async {
        final consolidate = params['consolidate'] != 'false';
        final snap = await snapshotCombined(consolidate: consolidate);
        return ServiceExtensionResponse.result(jsonEncode(snap.toJson()));
      });

      // ext.flutter_mate.getSemanticsNodes - Get structured semantics tree
      registerExtension('ext.flutter_mate.getSemanticsNodes',
          (method, params) async {
        final interactiveOnly = params['interactiveOnly'] != 'false';
        final nodes = getSemanticsNodes(interactiveOnly: interactiveOnly);
        return ServiceExtensionResponse.result(jsonEncode(nodes));
      });

      // ext.flutter_mate.longPress - Long press element by ref
      registerExtension('ext.flutter_mate.longPress', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await longPress(ref);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.doubleTap - Double tap element by ref
      registerExtension('ext.flutter_mate.doubleTap', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await doubleTap(ref);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.typeText - Type text into focused field
      registerExtension('ext.flutter_mate.typeText', (method, params) async {
        final text = params['text'];
        if (text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing text parameter',
          );
        }
        final success = await typeText(text);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.clearText - Clear focused text field
      registerExtension('ext.flutter_mate.clearText', (method, params) async {
        final success = await clearText();
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.pressKey - Press a keyboard key
      registerExtension('ext.flutter_mate.pressKey', (method, params) async {
        final key = params['key'];
        if (key == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing key parameter',
          );
        }
        final logicalKey = _parseLogicalKey(key);
        if (logicalKey == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Unknown key: $key',
          );
        }
        final success = await pressKey(logicalKey);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      _extensionsRegistered = true;
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
    await _delay(const Duration(milliseconds: 100));
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
  // COMBINED SNAPSHOT
  // Walks the Element tree (widget tree) and attaches semantics info.
  // Provides both widget structure and interaction capabilities.
  // ══════════════════════════════════════════════════════════════════════════

  /// Get a combined snapshot of the widget tree with semantics
  ///
  /// This provides both structural context (widget types, hierarchy) and
  /// interaction capabilities (actions, labels, values).
  ///
  /// Set [consolidate] to true (default) to skip wrapper widgets like
  /// Padding, Align, GestureDetector when they have a single child.
  ///
  /// ```dart
  /// final snapshot = await FlutterMate.snapshotCombined();
  /// print(snapshot);
  /// ```
  static Future<CombinedSnapshot> snapshotCombined({
    bool consolidate = true,
  }) async {
    _ensureInitialized();

    // Wait for first frame if needed
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      await _waitForFirstFrame();
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return CombinedSnapshot(
        success: false,
        error: 'No root element found. Is the UI rendered?',
        timestamp: DateTime.now(),
        nodes: [],
      );
    }

    final nodes = <CombinedNode>[];
    int refCounter = 0;

    void walkElement(Element element, int depth) {
      final widget = element.widget;
      final widgetType = widget.runtimeType.toString();

      // Consolidation: skip wrapper widgets with single child
      if (consolidate && _shouldSkipWidget(widgetType)) {
        int childCount = 0;
        Element? singleChild;
        element.visitChildren((child) {
          childCount++;
          singleChild = child;
        });
        if (childCount == 1 && singleChild != null) {
          walkElement(singleChild!, depth);
          return;
        }
      }

      // Skip private/internal widgets (start with _)
      if (widgetType.startsWith('_') && consolidate) {
        element.visitChildren((child) {
          walkElement(child, depth);
        });
        return;
      }

      final ref = 'w${refCounter++}';

      // Get bounds and semantics from RenderObject
      CombinedRect? bounds;
      SemanticsInfo? semantics;

      if (element is RenderObjectElement) {
        final ro = element.renderObject;

        // Get bounds
        if (ro is RenderBox && ro.hasSize) {
          try {
            final topLeft = ro.localToGlobal(Offset.zero);
            bounds = CombinedRect(
              x: topLeft.dx,
              y: topLeft.dy,
              width: ro.size.width,
              height: ro.size.height,
            );
          } catch (_) {
            // localToGlobal can fail if not attached
          }
        }

        // Get semantics from RenderObject
        final sn = ro.debugSemantics;
        if (sn != null) {
          semantics = _extractSemanticsInfo(sn);
        }
      }

      // Collect children refs by walking first
      final childRefs = <String>[];
      final childStartRef = refCounter;

      element.visitChildren((child) {
        final beforeCount = refCounter;
        walkElement(child, depth + 1);
        // If refCounter advanced, a child was added
        if (refCounter > beforeCount) {
          childRefs.add('w$beforeCount');
        }
      });

      // Insert this node at the correct position (before its children)
      final nodeIndex = nodes.length - (refCounter - childStartRef);
      nodes.insert(
        nodeIndex < 0 ? 0 : nodeIndex,
        CombinedNode(
          ref: ref,
          widget: widgetType,
          depth: depth,
          bounds: bounds,
          children: childRefs,
          semantics: semantics,
        ),
      );
    }

    walkElement(root, 0);

    // Reorder nodes to be in depth-first order (parents before children)
    nodes.sort((a, b) {
      final refA = int.parse(a.ref.substring(1));
      final refB = int.parse(b.ref.substring(1));
      return refA.compareTo(refB);
    });

    return CombinedSnapshot(
      success: true,
      timestamp: DateTime.now(),
      nodes: nodes,
    );
  }

  /// Check if a widget type should be skipped during consolidation
  static bool _shouldSkipWidget(String widgetType) {
    // Check exact match
    if (_skipWidgets.contains(widgetType)) return true;

    // Check for private widgets that wrap public ones (e.g., _InkWell)
    final withoutUnderscore =
        widgetType.startsWith('_') ? widgetType.substring(1) : null;
    if (withoutUnderscore != null && _skipWidgets.contains(withoutUnderscore)) {
      return true;
    }

    return false;
  }

  /// Extract semantics info from a SemanticsNode
  static SemanticsInfo _extractSemanticsInfo(SemanticsNode node) {
    final data = node.getSemanticsData();

    return SemanticsInfo(
      id: node.id,
      label: data.label.isNotEmpty ? data.label : null,
      value: data.value.isNotEmpty ? data.value : null,
      hint: data.hint.isNotEmpty ? data.hint : null,
      increasedValue:
          data.increasedValue.isNotEmpty ? data.increasedValue : null,
      decreasedValue:
          data.decreasedValue.isNotEmpty ? data.decreasedValue : null,
      flags: _getFlags(data).toSet(),
      actions: _getActions(data).toSet(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEMANTICS TREE EXTRACTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Get semantics nodes as a structured list
  ///
  /// Returns all semantics nodes with their actions, flags, labels, and bounds.
  /// Used by CLI via ext.flutter_mate.getSemanticsNodes service extension.
  ///
  /// ```dart
  /// final nodes = FlutterMate.getSemanticsNodes();
  /// print(nodes); // [{ref: "s0", id: 1, label: "Login", ...}, ...]
  /// ```
  static List<Map<String, dynamic>> getSemanticsNodes({
    bool interactiveOnly = true,
  }) {
    final binding = WidgetsBinding.instance;
    final owner = binding.pipelineOwner.semanticsOwner;
    if (owner == null) return [];
    final root = owner.rootSemanticsNode;
    if (root == null) return [];

    final results = <Map<String, dynamic>>[];
    var idx = 0;

    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final label = data.label;
      final actions = _getActions(data);
      final flags = _getFlags(data);

      // Get rect with transform
      final rect = node.rect;
      final transform = node.transform;
      var left = rect.left;
      var top = rect.top;
      var right = rect.right;
      var bottom = rect.bottom;
      if (transform != null) {
        final tl = MatrixUtils.transformPoint(transform, rect.topLeft);
        final br = MatrixUtils.transformPoint(transform, rect.bottomRight);
        left = tl.dx;
        top = tl.dy;
        right = br.dx;
        bottom = br.dy;
      }

      // Filter to interactive only
      final isInteractive = label.isNotEmpty || actions.isNotEmpty;
      if (!interactiveOnly || isInteractive) {
        results.add({
          'ref': 's$idx',
          'id': node.id,
          'label': label,
          'value': data.value,
          'actions': actions,
          'flags': flags,
          'rect': {
            'left': left,
            'top': top,
            'right': right,
            'bottom': bottom,
          },
        });
        idx++;
      }

      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    return results;
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

  /// Double tap on an element by ref
  ///
  /// Uses gesture simulation to trigger GestureDetector.onDoubleTap callbacks.
  static Future<bool> doubleTap(String ref) async {
    return doubleTapGesture(ref);
  }

  /// Double tap via gesture simulation
  static Future<bool> doubleTapGesture(String ref) async {
    _ensureInitialized();

    final snap = await snapshot();
    final nodeInfo = snap[ref];
    if (nodeInfo == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final center = Offset(
      nodeInfo.rect.x + nodeInfo.rect.width / 2,
      nodeInfo.rect.y + nodeInfo.rect.height / 2,
    );

    await doubleTapAt(center);
    return true;
  }

  /// Simulate a double tap at specific coordinates
  static Future<void> doubleTapAt(Offset position) async {
    _ensureInitialized();

    debugPrint('FlutterMate: doubleTapAt $position');

    // First tap
    await tapAt(position);
    // Short delay between taps (must be <300ms for double tap recognition)
    await _delay(const Duration(milliseconds: 100));
    // Second tap
    await tapAt(position);

    await _delay(const Duration(milliseconds: 50));
  }

  /// Long press on an element by ref
  ///
  /// Uses gesture simulation to trigger GestureDetector.onLongPress callbacks.
  /// Note: Semantic longPress action doesn't trigger widget callbacks reliably.
  static Future<bool> longPress(String ref) async {
    // Always use gesture simulation for longPress
    // Semantic performAction doesn't trigger GestureDetector callbacks
    return longPressGesture(ref);
  }

  /// Long press via gesture simulation
  static Future<bool> longPressGesture(String ref) async {
    _ensureInitialized();

    final snap = await snapshot();
    final nodeInfo = snap[ref];
    if (nodeInfo == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    // Calculate center of element
    final center = Offset(
      nodeInfo.rect.x + nodeInfo.rect.width / 2,
      nodeInfo.rect.y + nodeInfo.rect.height / 2,
    );

    await longPressAt(center);
    return true;
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
      await _delay(const Duration(milliseconds: 50));
    }

    // Try setText even if not advertised - it often works anyway!
    // TextField may handle it internally even without advertising
    node.owner?.performAction(node.id, SemanticsAction.setText, text);
    await _delay(const Duration(milliseconds: 100));

    return true;
  }

  /// Scroll an element
  ///
  /// First tries semantic scroll action on the node or its ancestors.
  /// Falls back to gesture-based scrolling if no semantic scroll is available.
  ///
  /// ```dart
  /// await FlutterMate.scroll('w10', ScrollDirection.down);
  /// ```
  static Future<bool> scroll(String ref, ScrollDirection direction,
      {double distance = 200}) async {
    // NOTE: SemanticsAction scroll directions refer to VIEW movement, not content:
    // - scrollUp = view moves up = content moves down = reveals content BELOW
    // - scrollDown = view moves down = content moves up = reveals content ABOVE
    //
    // When user says "scroll down" they mean "see content below", so we use scrollUp
    final action = switch (direction) {
      ScrollDirection.up => SemanticsAction.scrollDown, // see content above
      ScrollDirection.down => SemanticsAction.scrollUp, // see content below
      ScrollDirection.left => SemanticsAction.scrollRight,
      ScrollDirection.right => SemanticsAction.scrollLeft,
    };

    // Find the node
    final node = _findNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: Scroll - Node not found: $ref');
      return false;
    }

    // Tier 1: Try semantic scrolling first
    // Walk up the tree to find a scrollable ancestor
    SemanticsNode? current = node;
    while (current != null) {
      final data = current.getSemanticsData();
      if (data.hasAction(action)) {
        debugPrint('FlutterMate: Scroll via semantic action on w${current.id}');
        current.owner?.performAction(current.id, action);
        await _delay(const Duration(milliseconds: 300));
        return true;
      }
      current = current.parent;
    }

    // Tier 2: Fall back to gesture-based scrolling
    debugPrint('FlutterMate: No semantic scroll available, using gesture');
    return scrollGestureByDirection(ref, direction, distance);
  }

  /// Scroll using gesture simulation, staying within element bounds
  static Future<bool> scrollGestureByDirection(
      String ref, ScrollDirection direction, double distance) async {
    _ensureInitialized();

    // Find the semantics node directly (not through snapshot which is slow)
    final node = _findNode(ref);
    if (node == null) {
      debugPrint(
          'FlutterMate: scrollGestureByDirection - Node not found: $ref');
      return false;
    }

    // Get the node's rect in global coordinates
    final localRect = node.rect;
    final transform = node.transform;

    Offset topLeft = localRect.topLeft;
    Offset bottomRight = localRect.bottomRight;
    if (transform != null) {
      topLeft = MatrixUtils.transformPoint(transform, localRect.topLeft);
      bottomRight =
          MatrixUtils.transformPoint(transform, localRect.bottomRight);
    }

    final centerX = (topLeft.dx + bottomRight.dx) / 2;
    final topY = topLeft.dy + (bottomRight.dy - topLeft.dy) * 0.25;
    final bottomY = topLeft.dy + (bottomRight.dy - topLeft.dy) * 0.75;

    // User direction refers to content they want to see:
    // - "scroll down" = see content below = drag finger UP (bottom to top)
    // - "scroll up" = see content above = drag finger DOWN (top to bottom)
    Offset from, to;
    switch (direction) {
      case ScrollDirection.down:
        // See content below: swipe up (drag from bottom to top)
        from = Offset(centerX, bottomY);
        to = Offset(centerX, topY);
        break;
      case ScrollDirection.up:
        // See content above: swipe down (drag from top to bottom)
        from = Offset(centerX, topY);
        to = Offset(centerX, bottomY);
        break;
      case ScrollDirection.left:
        // See content on left: swipe right
        final leftX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.25;
        final rightX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.75;
        final centerY = (topLeft.dy + bottomRight.dy) / 2;
        from = Offset(leftX, centerY);
        to = Offset(rightX, centerY);
        break;
      case ScrollDirection.right:
        // See content on right: swipe left
        final leftX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.25;
        final rightX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.75;
        final centerY = (topLeft.dy + bottomRight.dy) / 2;
        from = Offset(rightX, centerY);
        to = Offset(leftX, centerY);
        break;
    }

    debugPrint('FlutterMate: scrollGesture $direction from $from to $to');

    await drag(from: from, to: to);

    return true;
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

    await _delay(const Duration(milliseconds: 50));

    // Pointer up
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + const Duration(milliseconds: 50),
    ));

    await _delay(const Duration(milliseconds: 50));
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
    Duration duration = const Duration(milliseconds: 200),
    int steps = 10,
  }) async {
    _ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final startTime =
        Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
    final stepDuration = duration ~/ steps;
    final totalDelta = to - from;
    final stepDelta = totalDelta / steps.toDouble();

    debugPrint('FlutterMate: drag from $from to $to');

    // Pointer down at start - use touch device kind for scrolling
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: from,
      timeStamp: startTime,
      kind: PointerDeviceKind.touch,
    ));

    await _delay(const Duration(milliseconds: 16));

    // Move through intermediate points with acceleration
    var currentPosition = from;
    for (var i = 1; i <= steps; i++) {
      currentPosition = from + stepDelta * i.toDouble();

      GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: stepDelta,
        timeStamp: startTime + stepDuration * i,
        kind: PointerDeviceKind.touch,
      ));

      await _delay(const Duration(milliseconds: 8));
    }

    // Quick final moves to add velocity
    for (var i = 0; i < 3; i++) {
      currentPosition = currentPosition + stepDelta * 0.5;
      GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: stepDelta * 0.5,
        timeStamp: startTime + duration + Duration(milliseconds: i * 8),
        kind: PointerDeviceKind.touch,
      ));
      await _delay(const Duration(milliseconds: 8));
    }

    // Pointer up at end
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: currentPosition,
      timeStamp: startTime + duration + const Duration(milliseconds: 50),
      kind: PointerDeviceKind.touch,
    ));

    // Wait for scroll physics to settle
    await _delay(const Duration(milliseconds: 300));
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
      debugPrint('FlutterMate: scrollGesture - Node not found: $ref');
      return false;
    }

    final center = Offset(
      node.rect.x + node.rect.width / 2,
      node.rect.y + node.rect.height / 2,
    );

    debugPrint(
        'FlutterMate: scrollGesture from $center delta $delta (to ${center + delta})');

    await drag(
      from: center,
      to: center + delta,
      duration: const Duration(milliseconds: 300),
    );

    // Wait for scroll physics to settle
    await _delay(const Duration(milliseconds: 100));

    return true;
  }

  /// Simulate a long press at screen coordinates
  static Future<void> longPressAt(
    Offset position, {
    Duration pressDuration = const Duration(milliseconds: 600),
  }) async {
    _ensureInitialized();

    debugPrint('FlutterMate: longPressAt $position');

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Pointer down - use touch for gesture recognition
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.touch,
    ));

    // Hold for long press duration (must be >500ms for recognition)
    await _delay(pressDuration);

    // Pointer up
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + pressDuration,
    ));

    await _delay(const Duration(milliseconds: 50));
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

  // Note: Connection ID tracking removed - we now use FocusManager + EditableTextState directly

  /// Type text into the currently focused text field
  ///
  /// Uses `EditableTextState.updateEditingValue()` - the same method called
  /// when the platform sends keyboard input. This ensures:
  /// - Input formatters are applied
  /// - onChanged callbacks fire correctly
  /// - Same code path as real keyboard input
  ///
  /// ```dart
  /// await FlutterMate.focus('w5');
  /// await FlutterMate.typeText('hello@example.com');
  /// ```
  static Future<bool> typeText(String text) async {
    _ensureInitialized();

    debugPrint('FlutterMate: typeText "$text"');

    try {
      // Find the currently focused element
      final focusNode = FocusManager.instance.primaryFocus;
      if (focusNode == null) {
        debugPrint(
            'FlutterMate: No focused element - is a text field focused?');
        return false;
      }

      // Find the EditableTextState (implements TextInputClient)
      final editableState = _findEditableTextState(focusNode.context);
      if (editableState == null) {
        debugPrint('FlutterMate: No EditableTextState found in focus tree');
        return false;
      }

      // Get current text value
      final currentValue = editableState.currentTextEditingValue;
      String currentText = currentValue.text;

      // Type character by character, using updateEditingValue
      // This is the exact method the platform calls for keyboard input
      for (int i = 0; i < text.length; i++) {
        currentText += text[i];

        // Call updateEditingValue - same as platform keyboard input
        editableState.updateEditingValue(TextEditingValue(
          text: currentText,
          selection: TextSelection.collapsed(offset: currentText.length),
        ));

        // Small delay between characters for realism (skip in test mode - FakeAsync incompatible)
        if (!_testMode) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }

      debugPrint('FlutterMate: Typed "$text" via updateEditingValue');
      return true;
    } catch (e, stack) {
      debugPrint('FlutterMate: typeText error: $e\n$stack');
      return false;
    }
  }

  /// Find EditableTextState from a BuildContext
  static EditableTextState? _findEditableTextState(BuildContext? context) {
    if (context == null) return null;

    EditableTextState? found;

    // Search subtree first
    void visitor(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visitor);
    }

    (context as Element).visitChildren(visitor);

    // If not in subtree, check ancestors
    if (found == null) {
      context.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          found = element.state as EditableTextState;
          return false;
        }
        return true;
      });
    }

    return found;
  }

  /// Clear the currently focused text field
  static Future<bool> clearText() async {
    _ensureInitialized();

    debugPrint('FlutterMate: clearText');

    try {
      final focusNode = FocusManager.instance.primaryFocus;
      if (focusNode == null) {
        debugPrint('FlutterMate: No focused element');
        return false;
      }

      final editableState = _findEditableTextState(focusNode.context);
      if (editableState == null) {
        debugPrint('FlutterMate: No EditableTextState found');
        return false;
      }

      // Use updateEditingValue to clear - same as platform input
      editableState.updateEditingValue(const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ));
      debugPrint('FlutterMate: Text cleared');
      return true;
    } catch (e) {
      debugPrint('FlutterMate: clearText error: $e');
      return false;
    }
  }

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
      await _delay(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, 0);
      await _delay(const Duration(milliseconds: 30));

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
      await _delay(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, modifiers);
      await _delay(const Duration(milliseconds: 30));

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
      await _delay(pollInterval);
    }

    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LABEL-BASED FINDING (for readable tests and AI agents)
  // ══════════════════════════════════════════════════════════════════════════

  /// Find element ref by semantic label
  ///
  /// Searches the current snapshot for an element whose label or value
  /// contains the given text (case-insensitive).
  ///
  /// ```dart
  /// final ref = await FlutterMate.findByLabel('Email');
  /// if (ref != null) {
  ///   await FlutterMate.fill(ref, 'test@example.com');
  /// }
  /// ```
  static Future<String?> findByLabel(String label) async {
    _ensureInitialized();

    final snap = await snapshot();
    final lowerLabel = label.toLowerCase();

    for (final node in snap.nodes) {
      // Check label
      if (node.label != null &&
          node.label!.toLowerCase().contains(lowerLabel)) {
        return node.ref;
      }
      // Check value
      if (node.value != null &&
          node.value!.toLowerCase().contains(lowerLabel)) {
        return node.ref;
      }
    }

    return null;
  }

  /// Find all element refs matching a label pattern
  ///
  /// Returns all refs whose label or value matches the pattern.
  ///
  /// ```dart
  /// final refs = await FlutterMate.findAllByLabel('Item');
  /// for (final ref in refs) {
  ///   await FlutterMate.tap(ref);
  /// }
  /// ```
  static Future<List<String>> findAllByLabel(String labelPattern) async {
    _ensureInitialized();

    final snap = await snapshot();
    final pattern = RegExp(labelPattern, caseSensitive: false);
    final refs = <String>[];

    for (final node in snap.nodes) {
      if (node.label != null && pattern.hasMatch(node.label!)) {
        refs.add(node.ref);
      } else if (node.value != null && pattern.hasMatch(node.value!)) {
        refs.add(node.ref);
      }
    }

    return refs;
  }

  /// Tap element by label (convenience method)
  ///
  /// Finds element by label and taps it.
  ///
  /// ```dart
  /// await FlutterMate.tapByLabel('Login');
  /// await FlutterMate.tapByLabel('Submit');
  /// ```
  static Future<bool> tapByLabel(String label) async {
    final ref = await findByLabel(label);
    if (ref == null) {
      debugPrint(
          'FlutterMate: tapByLabel - No element found with label: $label');
      return false;
    }
    return tap(ref);
  }

  /// Fill text field by label (convenience method)
  ///
  /// Finds text field by label, focuses it, and types the text.
  ///
  /// ```dart
  /// await FlutterMate.fillByLabel('Email', 'test@example.com');
  /// await FlutterMate.fillByLabel('Password', 'secret123');
  /// ```
  static Future<bool> fillByLabel(String label, String text) async {
    final ref = await findByLabel(label);
    if (ref == null) {
      debugPrint(
          'FlutterMate: fillByLabel - No element found with label: $label');
      return false;
    }
    return fill(ref, text);
  }

  /// Long press element by label (convenience method)
  static Future<bool> longPressByLabel(String label) async {
    final ref = await findByLabel(label);
    if (ref == null) {
      debugPrint(
          'FlutterMate: longPressByLabel - No element found with label: $label');
      return false;
    }
    return longPress(ref);
  }

  /// Double tap element by label (convenience method)
  static Future<bool> doubleTapByLabel(String label) async {
    final ref = await findByLabel(label);
    if (ref == null) {
      debugPrint(
          'FlutterMate: doubleTapByLabel - No element found with label: $label');
      return false;
    }
    return doubleTap(ref);
  }

  /// Focus element by label (convenience method)
  static Future<bool> focusByLabel(String label) async {
    final ref = await findByLabel(label);
    if (ref == null) {
      debugPrint(
          'FlutterMate: focusByLabel - No element found with label: $label');
      return false;
    }
    return focus(ref);
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
    await _delay(const Duration(milliseconds: 100));

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

  /// Parse a key name string to LogicalKeyboardKey
  static LogicalKeyboardKey? _parseLogicalKey(String key) {
    return switch (key.toLowerCase()) {
      'enter' => LogicalKeyboardKey.enter,
      'tab' => LogicalKeyboardKey.tab,
      'escape' => LogicalKeyboardKey.escape,
      'backspace' => LogicalKeyboardKey.backspace,
      'delete' => LogicalKeyboardKey.delete,
      'space' => LogicalKeyboardKey.space,
      'arrowup' => LogicalKeyboardKey.arrowUp,
      'arrowdown' => LogicalKeyboardKey.arrowDown,
      'arrowleft' => LogicalKeyboardKey.arrowLeft,
      'arrowright' => LogicalKeyboardKey.arrowRight,
      _ => null,
    };
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
