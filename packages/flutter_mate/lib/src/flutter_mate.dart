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
  static CombinedSnapshot? _lastSnapshot;

  // Cached Elements from inspector tree for ref -> Element lookup
  static final Map<String, Element> _cachedElements = {};

  // Text input client ID for platform message simulation
  static int? _lastTextInputClientId;

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

    // Set up text input channel interceptor to capture client IDs
    _setupTextInputInterceptor();

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

  /// Dispatch a pointer event through the appropriate binding
  ///
  /// In test mode, uses WidgetsBinding which properly integrates with FakeAsync.
  /// At runtime, uses GestureBinding directly.
  static void _dispatchPointerEvent(PointerEvent event) {
    // Use WidgetsBinding if available (works in both test and runtime)
    // This properly integrates with the test binding's event queue
    WidgetsBinding.instance.handlePointerEvent(event);
  }

  static bool _textInputInterceptorSetup = false;

  /// Set up interceptor to capture text input client IDs
  ///
  /// When a TextField is focused, Flutter sends TextInput.setClient with a client ID.
  /// We intercept this to capture the ID for use with _dispatchTextInput.
  static void _setupTextInputInterceptor() {
    if (_textInputInterceptorSetup) return;

    // Listen to platform messages on the text input channel
    ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
      'flutter/textinput',
      (ByteData? message) async {
        if (message != null) {
          try {
            final methodCall =
                const JSONMethodCodec().decodeMethodCall(message);
            if (methodCall.method == 'TextInput.setClient') {
              final args = methodCall.arguments as List<dynamic>;
              _lastTextInputClientId = args[0] as int;
              debugPrint(
                  'FlutterMate: Captured text input client ID: $_lastTextInputClientId');
            }
          } catch (_) {
            // Ignore decode errors
          }
        }
        // Return null to let the default handler process the message
        return null;
      },
    );

    _textInputInterceptorSetup = true;
    debugPrint('FlutterMate: Text input interceptor set up');
  }

  /// Dispatch text input via platform message simulation
  ///
  /// Uses the same mechanism as Flutter's TestTextInput - injects a
  /// platform message to simulate keyboard input.
  static Future<void> _dispatchTextInput(int clientId, String text) async {
    final codec = const JSONMethodCodec();

    // Use channelBuffers.push which is the modern approach
    ServicesBinding.instance.channelBuffers.push(
      'flutter/textinput',
      codec.encodeMethodCall(MethodCall(
        'TextInputClient.updateEditingState',
        <dynamic>[
          clientId,
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

    await _delay(const Duration(milliseconds: 50));
  }

  static bool _extensionsRegistered = false;

  /// Register VM Service extensions for external control via CLI
  static void _registerServiceExtensions() {
    // Only register once (extensions persist across test runs in same VM)
    if (_extensionsRegistered) return;

    // Only register in debug/profile mode
    assert(() {
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
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'tap failed: element may not support tap action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.setText - Set text on element (semantic action)
      registerExtension('ext.flutter_mate.setText', (method, params) async {
        final ref = params['ref'];
        final text = params['text'];
        if (ref == null || text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref or text parameter',
          );
        }
        final success = await setText(ref, text);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'setText failed: element may not support setText action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
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
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'scroll failed: element may not support scroll action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
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
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'focus failed: element may not support focus action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.snapshot - Get UI snapshot (widget tree + semantics)
      registerExtension('ext.flutter_mate.snapshot', (method, params) async {
        final snap = await snapshot();
        return ServiceExtensionResponse.result(jsonEncode(snap.toJson()));
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
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'longPress failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
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
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'doubleTap failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.typeText - Type text into a text field by ref
      registerExtension('ext.flutter_mate.typeText', (method, params) async {
        final ref = params['ref'];
        final text = params['text'];
        if (ref == null || text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref or text parameter',
          );
        }
        final success = await typeText(ref, text);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'typeText failed: element not found or not a text field',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
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

      // ext.flutter_mate.debugTrees - Get both trees for debugging
      registerExtension('ext.flutter_mate.debugTrees', (method, params) async {
        final result = await _getDebugTrees();
        return ServiceExtensionResponse.result(jsonEncode(result));
      });

      _extensionsRegistered = true;
      debugPrint('FlutterMate: Service extensions registered');
      return true;
    }());
  }

  /// Get both inspector tree and semantics tree for debugging/matching
  static Future<Map<String, dynamic>> _getDebugTrees() async {
    _ensureInitialized();

    // Get inspector summary tree
    final service = WidgetInspectorService.instance;
    final inspectorJson =
        service.getRootWidgetSummaryTree('flutter_mate_debug');
    final inspectorTree = jsonDecode(inspectorJson) as Map<String, dynamic>?;

    // Get semantics tree
    final semanticsNodes = <Map<String, dynamic>>[];
    SemanticsNode? rootNode;
    for (final view in RendererBinding.instance.renderViews) {
      if (view.owner?.semanticsOwner?.rootSemanticsNode != null) {
        rootNode = view.owner!.semanticsOwner!.rootSemanticsNode;
        break;
      }
    }

    if (rootNode != null) {
      void walkSemantics(SemanticsNode node, int depth) {
        final data = node.getSemanticsData();
        final rect = node.rect;
        final transform = node.transform;

        Offset? globalTopLeft;
        if (transform != null) {
          globalTopLeft = MatrixUtils.transformPoint(transform, rect.topLeft);
        }

        semanticsNodes.add({
          'id': node.id,
          'depth': depth,
          'label': data.label.isNotEmpty ? data.label : null,
          'value': data.value.isNotEmpty ? data.value : null,
          'hint': data.hint.isNotEmpty ? data.hint : null,
          'rect': {
            'x': globalTopLeft?.dx ?? rect.left,
            'y': globalTopLeft?.dy ?? rect.top,
            'width': rect.width,
            'height': rect.height,
          },
          'actions': _getActions(data),
          'flags': _getFlags(data),
        });

        node.visitChildren((child) {
          walkSemantics(child, depth + 1);
          return true;
        });
      }

      walkSemantics(rootNode, 0);
    }

    return {
      'inspectorTree': inspectorTree,
      'semanticsNodes': semanticsNodes,
    };
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

  // ══════════════════════════════════════════════════════════════════════════
  // SNAPSHOT
  // Uses Flutter's WidgetInspectorService for the summary tree (same as DevTools)
  // then attaches semantics info for AI/automation interactions.
  // ══════════════════════════════════════════════════════════════════════════

  /// Get a snapshot of the current UI
  ///
  /// Returns a [CombinedSnapshot] containing the widget tree with semantics.
  /// Each node has a ref (w0, w1, w2...) that can be used for interactions.
  ///
  /// Uses Flutter's WidgetInspectorService to get the same tree that DevTools
  /// shows - only user-created widgets, not framework internals.
  ///
  /// ```dart
  /// final snapshot = await FlutterMate.snapshot();
  /// print(snapshot);
  /// ```
  static Future<CombinedSnapshot> snapshot() async {
    _ensureInitialized();

    // Wait for first frame if needed
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      await _waitForFirstFrame();
    }

    if (WidgetsBinding.instance.rootElement == null) {
      return CombinedSnapshot(
        success: false,
        error: 'No root element found. Is the UI rendered?',
        timestamp: DateTime.now(),
        nodes: [],
      );
    }

    try {
      // Use Flutter's WidgetInspectorService to get the summary tree
      // This is the same tree that DevTools shows - only user widgets
      final service = WidgetInspectorService.instance;
      const groupName = 'flutter_mate_snapshot';

      final jsonStr = service.getRootWidgetSummaryTree(groupName);

      final treeJson = jsonDecode(jsonStr) as Map<String, dynamic>?;
      if (treeJson == null) {
        return CombinedSnapshot(
          success: false,
          error: 'Failed to get widget tree from inspector',
          timestamp: DateTime.now(),
          nodes: [],
        );
      }

      // Clear cached elements for fresh snapshot
      _cachedElements.clear();

      // Parse the inspector tree and attach semantics using toObject
      final nodes = <CombinedNode>[];
      int refCounter = 0;

      void walkInspectorNode(Map<String, dynamic> node, int depth) {
        final description = node['description'] as String? ?? '';
        final widgetType = _extractWidgetType(description);
        final valueId = node['valueId'] as String?;
        final childrenJson = node['children'] as List<dynamic>? ?? [];

        final ref = 'w${refCounter++}';

        CombinedRect? bounds;
        SemanticsInfo? semantics;
        String? textContent;

        // Use toObject to get the actual Element from valueId
        if (valueId != null) {
          try {
            // ignore: invalid_use_of_protected_member
            final obj = service.toObject(valueId, groupName);
            if (obj is Element) {
              // Cache the Element for ref lookup (used by typeText, etc.)
              _cachedElements[ref] = obj;

              // Extract text content from widget
              textContent = _extractWidgetContent(obj.widget);
              // Find the RenderObject
              RenderObject? ro;
              if (obj is RenderObjectElement) {
                ro = obj.renderObject;
              } else {
                // Walk down to find first RenderObjectElement
                void findRenderObject(Element el) {
                  if (ro != null) return;
                  if (el is RenderObjectElement) {
                    ro = el.renderObject;
                    return;
                  }
                  el.visitChildren(findRenderObject);
                }

                findRenderObject(obj);
              }

              if (ro != null) {
                // Get bounds if it's a RenderBox
                if (ro is RenderBox) {
                  final box = ro as RenderBox;
                  if (box.hasSize) {
                    try {
                      final topLeft = box.localToGlobal(Offset.zero);
                      bounds = CombinedRect(
                        x: topLeft.dx,
                        y: topLeft.dy,
                        width: box.size.width,
                        height: box.size.height,
                      );
                    } catch (_) {
                      // localToGlobal can fail if not attached
                    }
                  }
                }

                // Only attach semantics to Semantics widgets
                // Other widgets just get bounds - actions figure out semantics at runtime
                if (widgetType == 'Semantics') {
                  SemanticsNode? sn = ro!.debugSemantics;
                  if (sn != null) {
                    // For Semantics widget, find the child semantics with actions
                    // The Semantics widget annotates its child, so walk down to find actionable node
                    SemanticsNode nodeWithActions = sn;

                    void findActionableNode(SemanticsNode node) {
                      final data = node.getSemanticsData();
                      if (data.actions != 0) {
                        nodeWithActions = node;
                        return;
                      }
                      node.visitChildren((child) {
                        findActionableNode(child);
                        return true;
                      });
                    }

                    if (sn.getSemanticsData().actions == 0) {
                      findActionableNode(sn);
                    }

                    semantics = _extractSemanticsInfo(nodeWithActions);
                  }
                }
              }
            }
          } catch (e) {
            // toObject can fail for some elements, continue without semantics
            debugPrint('FlutterMate: toObject failed for $valueId: $e');
          }
        }

        // Collect children refs
        final childRefs = <String>[];
        final childStartRef = refCounter;

        for (final childJson in childrenJson) {
          if (childJson is Map<String, dynamic>) {
            final beforeCount = refCounter;
            walkInspectorNode(childJson, depth + 1);
            if (refCounter > beforeCount) {
              childRefs.add('w$beforeCount');
            }
          }
        }

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
            textContent: textContent,
          ),
        );
      }

      walkInspectorNode(treeJson, 0);

      // Reorder nodes to be in depth-first order (parents before children)
      nodes.sort((a, b) {
        final refA = int.parse(a.ref.substring(1));
        final refB = int.parse(b.ref.substring(1));
        return refA.compareTo(refB);
      });

      final snapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: nodes,
      );

      // Cache for ref -> semantics ID translation in actions
      _lastSnapshot = snapshot;

      return snapshot;
    } catch (e, stack) {
      debugPrint('FlutterMate: snapshot error: $e\n$stack');
      return CombinedSnapshot(
        success: false,
        error: 'Failed to get snapshot: $e',
        timestamp: DateTime.now(),
        nodes: [],
      );
    }
  }

  /// Extract widget type from inspector description
  static String _extractWidgetType(String description) {
    // Description can be like "Text" or "Padding(padding: EdgeInsets...)"
    final parenIndex = description.indexOf('(');
    if (parenIndex > 0) {
      return description.substring(0, parenIndex);
    }
    return description;
  }

  /// Extract content from widget using its diagnostic description
  /// This is a general solution that works for any widget type.
  static String? _extractWidgetContent(Widget widget) {
    try {
      // Use toStringShort() which includes key properties for most widgets
      // e.g., Text("Hello") returns 'Text("Hello")'
      // e.g., Icon(IconData(U+E88A)) returns 'Icon'
      final shortString = widget.toStringShort();

      // Extract content between quotes if present
      final quoteMatch = RegExp(r'"([^"]*)"').firstMatch(shortString);
      if (quoteMatch != null) {
        return quoteMatch.group(1);
      }

      // For widgets without quoted content, try toDiagnosticsNode
      final diagNode = widget.toDiagnosticsNode();
      final props = diagNode.getProperties();
      for (final prop in props) {
        // Look for 'data', 'label', 'text', 'title' properties
        final name = prop.name?.toLowerCase();
        if (name == 'data' ||
            name == 'label' ||
            name == 'text' ||
            name == 'title') {
          final value = prop.value;
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {
      // Diagnostics can fail for some widgets
    }
    return null;
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
      // Scroll properties
      scrollChildCount: data.scrollChildCount,
      scrollIndex: data.scrollIndex,
      scrollPosition: data.scrollPosition,
      scrollExtentMax: data.scrollExtentMax,
      scrollExtentMin: data.scrollExtentMin,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEMANTICS-BASED ACTIONS
  // These use Flutter's accessibility system to interact with elements.
  // Most reliable way to interact with standard Flutter widgets.
  // ══════════════════════════════════════════════════════════════════════════

  /// Tap on an element by ref
  ///
  /// Tries semantic tap action first (for Semantics widgets).
  /// Falls back to gesture-based tap if semantic action not available.
  ///
  /// ```dart
  /// await FlutterMate.tap('w5');
  /// ```
  static Future<bool> tap(String ref) async {
    _ensureInitialized();

    // Check if this ref has semantic tap action
    if (_lastSnapshot != null) {
      final node = _lastSnapshot![ref];
      if (node?.semantics?.hasAction('tap') == true) {
        debugPrint('FlutterMate: tap via semantic action on $ref');
        return _performAction(ref, SemanticsAction.tap);
      }
    }

    // Fallback to gesture-based tap
    debugPrint('FlutterMate: tap via gesture on $ref');
    return _tapGesture(ref);
  }

  /// Internal gesture-based tap
  static Future<bool> _tapGesture(String ref) async {
    final element = _cachedElements[ref];
    if (element == null) {
      debugPrint('FlutterMate: _tapGesture - Element not found: $ref');
      return false;
    }

    RenderObject? ro = element.renderObject;
    while (ro != null && ro is! RenderBox) {
      if (ro is RenderObjectElement) {
        ro = (ro as RenderObjectElement).renderObject;
      } else {
        break;
      }
    }

    if (ro == null || ro is! RenderBox || !ro.hasSize) {
      debugPrint('FlutterMate: _tapGesture - No RenderBox for: $ref');
      return false;
    }

    final box = ro;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    await tapAt(center);
    return true;
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

    final center = nodeInfo.center;
    if (center == null) {
      debugPrint('FlutterMate: Node has no bounds: $ref');
      return false;
    }

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
  /// Tries semantic longPress action first (for Semantics widgets).
  /// Falls back to gesture-based long press if semantic action not available.
  ///
  /// ```dart
  /// await FlutterMate.longPress('w5');
  /// ```
  static Future<bool> longPress(String ref) async {
    _ensureInitialized();

    // Check if this ref has semantic longPress action
    if (_lastSnapshot != null) {
      final node = _lastSnapshot![ref];
      if (node?.semantics?.hasAction('longPress') == true) {
        debugPrint('FlutterMate: longPress via semantic action on $ref');
        return _performAction(ref, SemanticsAction.longPress);
      }
    }

    // Fallback to gesture-based long press
    debugPrint('FlutterMate: longPress via gesture on $ref');
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
    final center = nodeInfo.center;
    if (center == null) {
      debugPrint('FlutterMate: Node has no bounds: $ref');
      return false;
    }

    await longPressAt(center);
    return true;
  }

  /// Set text on an element using semantic setText action
  ///
  /// This is the semantic way to set text fields. For keyboard simulation,
  /// use [typeText] instead.
  ///
  /// ```dart
  /// await FlutterMate.setText('w9', 'hello@example.com');
  /// ```
  static Future<bool> setText(String ref, String text) async {
    _ensureInitialized();

    final node = _findNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: setText - Node not found: $ref');
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

  /// Alias for [setText] for backwards compatibility
  @Deprecated('Use setText instead')
  static Future<bool> fill(String ref, String text) => setText(ref, text);

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
    _dispatchPointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
    ));

    await _delay(const Duration(milliseconds: 50));

    // Pointer up
    _dispatchPointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + const Duration(milliseconds: 50),
    ));

    await _delay(const Duration(milliseconds: 50));
  }

  /// Simulate a tap on an element using its bounding box
  ///
  /// @deprecated Use [tap] instead, which automatically falls back to gesture.
  @Deprecated('Use tap() instead - it now auto-falls back to gesture')
  static Future<bool> tapGesture(String ref) => _tapGesture(ref);

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
    _dispatchPointerEvent(PointerDownEvent(
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

      _dispatchPointerEvent(PointerMoveEvent(
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
      _dispatchPointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: stepDelta * 0.5,
        timeStamp: startTime + duration + Duration(milliseconds: i * 8),
        kind: PointerDeviceKind.touch,
      ));
      await _delay(const Duration(milliseconds: 8));
    }

    // Pointer up at end
    _dispatchPointerEvent(PointerUpEvent(
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

    final center = node.center;
    if (center == null) {
      debugPrint('FlutterMate: scrollGesture - Node has no bounds: $ref');
      return false;
    }

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
    _dispatchPointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.touch,
    ));

    // Hold for long press duration (must be >500ms for recognition)
    await _delay(pressDuration);

    // Pointer up
    _dispatchPointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + pressDuration,
    ));

    await _delay(const Duration(milliseconds: 50));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KEYBOARD / TEXT INPUT SIMULATION
  // Uses platform messages to simulate keyboard input, just like a real keyboard.
  //
  // How it works:
  // 1. typeText(ref, text) finds the widget from the inspector tree
  // 2. Taps to focus the TextField
  // 3. Captures the text input client ID via channel interceptor
  // 4. Sends platform messages to simulate typing character by character
  //
  // Usage:
  //   await FlutterMate.snapshot();  // Cache elements
  //   await FlutterMate.typeText('w10', 'hello@example.com');
  // ══════════════════════════════════════════════════════════════════════════

  /// Type text into a text field by ref
  ///
  /// This uses platform message simulation - the same mechanism as real keyboard input.
  /// It finds the TextField element from the inspector tree, focuses it via gesture,
  /// then sends platform messages to simulate typing.
  ///
  /// ```dart
  /// await FlutterMate.typeText('w10', 'hello@example.com');
  /// ```
  static Future<bool> typeText(String ref, String text) async {
    _ensureInitialized();

    debugPrint('FlutterMate: typeText "$text" into $ref');

    try {
      // Find the Element from cached inspector tree
      final element = _cachedElements[ref];
      if (element == null) {
        debugPrint(
            'FlutterMate: Element not found for $ref. Did you call snapshot() first?');
        return false;
      }

      // Find the center of the element for tapping
      RenderObject? ro;
      if (element is RenderObjectElement) {
        ro = element.renderObject;
      } else {
        // Walk down to find RenderObject
        void findRenderObject(Element el) {
          if (ro != null) return;
          if (el is RenderObjectElement) {
            ro = el.renderObject;
            return;
          }
          el.visitChildren(findRenderObject);
        }

        findRenderObject(element);
      }

      if (ro == null || ro is! RenderBox) {
        debugPrint('FlutterMate: No RenderBox found for $ref');
        return false;
      }

      final box = ro as RenderBox;
      if (!box.hasSize) {
        debugPrint('FlutterMate: RenderBox has no size for $ref');
        return false;
      }

      // Calculate center and tap to focus
      final center = box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
      debugPrint('FlutterMate: Tapping to focus at $center');
      await tapAt(center);

      // Wait for focus and text input connection to be established
      await _delay(const Duration(milliseconds: 150));

      // Check if we captured a client ID
      if (_lastTextInputClientId == null) {
        debugPrint(
            'FlutterMate: No text input client ID captured. Falling back to EditableTextState.');
        return _typeTextViaEditableState(text);
      }

      // Get current text from the focused field
      final focusNode = FocusManager.instance.primaryFocus;
      String currentText = '';
      if (focusNode != null) {
        final editableState = _findEditableTextState(focusNode.context);
        if (editableState != null) {
          currentText = editableState.currentTextEditingValue.text;
        }
      }

      // Type character by character using platform messages
      for (int i = 0; i < text.length; i++) {
        currentText += text[i];
        await _dispatchTextInput(_lastTextInputClientId!, currentText);
      }

      debugPrint(
          'FlutterMate: Typed "$text" via platform messages (client ID: $_lastTextInputClientId)');
      return true;
    } catch (e, stack) {
      debugPrint('FlutterMate: typeText error: $e\n$stack');
      return false;
    }
  }

  /// Type text into the currently focused field (fallback method)
  static Future<bool> _typeTextViaEditableState(String text) async {
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

    String currentText = editableState.currentTextEditingValue.text;

    for (int i = 0; i < text.length; i++) {
      currentText += text[i];
      editableState.updateEditingValue(TextEditingValue(
        text: currentText,
        selection: TextSelection.collapsed(offset: currentText.length),
      ));
      if (!_testMode) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    debugPrint('FlutterMate: Typed "$text" via EditableTextState (fallback)');
    return true;
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
        final label = node.semantics?.label;
        final value = node.semantics?.value;
        if (label != null && pattern.hasMatch(label)) {
          return node.ref;
        }
        if (value != null && pattern.hasMatch(value)) {
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
  ///   await FlutterMate.setText(ref, 'test@example.com');
  /// }
  /// ```
  static Future<String?> findByLabel(String label) async {
    _ensureInitialized();

    final snap = await snapshot();
    final lowerLabel = label.toLowerCase();

    for (final node in snap.nodes) {
      final label = node.semantics?.label;
      final value = node.semantics?.value;
      // Check label
      if (label != null && label.toLowerCase().contains(lowerLabel)) {
        return node.ref;
      }
      // Check value
      if (value != null && value.toLowerCase().contains(lowerLabel)) {
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
      final label = node.semantics?.label;
      final value = node.semantics?.value;
      if (label != null && pattern.hasMatch(label)) {
        refs.add(node.ref);
      } else if (value != null && pattern.hasMatch(value)) {
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
    return setText(ref, text);
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
    // Clean ref: '@w5' -> 'w5'
    final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;
    if (!cleanRef.startsWith('w')) return null;

    // Look up semantics ID from cached snapshot
    if (_lastSnapshot != null) {
      final node = _lastSnapshot![cleanRef];
      if (node?.semantics != null) {
        final semanticsId = node!.semantics!.id;
        return _searchNodeById(semanticsId);
      }
    }

    // Fallback: try parsing ref as semantics ID directly (backwards compat)
    final nodeId = int.tryParse(cleanRef.substring(1));
    if (nodeId == null) return null;
    return _searchNodeById(nodeId);
  }

  static SemanticsNode? _searchNodeById(int nodeId) {
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
