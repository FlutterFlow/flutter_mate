/// FlutterMate MCP Support - Model Context Protocol integration
///
/// Mix this into an MCPServer to add Flutter automation tools.
///
/// ## Available Tools
///
/// - `connect` - Connect to a running Flutter app via VM Service
/// - `snapshot` - Capture UI tree with element refs (collapsed view)
/// - `find` - Get detailed info about a specific element
/// - `screenshot` - Capture screenshot (full screen or specific element)
/// - `tap` - Tap element (tries semantic action, falls back to gesture)
/// - `doubleTap` - Double tap an element
/// - `longPress` - Long press an element
/// - `hover` - Hover over an element (trigger onHover/onEnter)
/// - `drag` - Drag from one element to another
/// - `setText` - Set text via semantic action (for Semantics widgets)
/// - `typeText` - Type text via keyboard simulation (for TextField widgets)
/// - `scroll` - Scroll element in a direction
/// - `focus` - Focus an element (for text input)
/// - `pressKey` - Press a keyboard key (enter, tab, escape, etc.)
/// - `keyDown` - Press a key down (hold without releasing)
/// - `keyUp` - Release a key
/// - `clear` - Clear text from a text field
/// - `waitFor` - Wait for element with matching label/text to appear
///
/// ## Snapshot Format
///
/// The snapshot displays a collapsed tree where:
/// - Widgets with same bounds are chained with → (parent → child)
/// - Layout wrappers (Padding, Center, SizedBox, etc.) are hidden
/// - Indentation shows hierarchy (• bullet = child level)
///
/// ### Line Format
///
/// ```
/// [ref] WidgetType (text content) value = "..." {state} [actions] (flags)
/// ```
///
/// Sections (all optional except ref and widget):
/// - `[w123]` - Ref ID for interacting with the element
/// - `WidgetType` - Widget class name (may include debug key like `[GlobalKey#...]`)
/// - `(Label, Hint, Error)` - Text content: semantic label, hint, validation errors
/// - `value = "..."` - Semantic value (e.g., typed text in a field)
/// - `{valid}` or `{invalid}` - Validation state for form fields
/// - `{type: email}` - Keyboard type hints
/// - `[tap, focus, scrollUp]` - Available semantic actions
/// - `(TextField, Button, Focusable, Enabled, Obscured)` - Semantic flags
///
/// ### Example Snapshot
///
/// ```
/// • [w1] MyApp → [w2] MaterialApp → [w3] LoginScreen
///   • [w5] Column
///     • [w9] TextFormField (Email, Enter email) {valid} [tap, focus] (TextField, Focusable)
///     • [w15] TextFormField (Password) value = "****" [tap, focus] (Obscured)
///     • [w20] ElevatedButton (Submit) [tap] (Button, Enabled)
/// ```
///
/// ## Usage with Cursor
///
/// Add to ~/.cursor/mcp.json:
/// ```json
/// {
///   "mcpServers": {
///     "flutter_mate": {
///       "command": "dart",
///       "args": ["run", "/path/to/flutter_mate_cli/bin/mcp_server.dart"],
///       "env": {
///         "FLUTTER_MATE_URI": "ws://127.0.0.1:12345/abc=/ws"
///       }
///     }
///   }
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';

import 'snapshot_formatter.dart';
import 'vm_service_client.dart';

/// Mixin that adds Flutter automation tools to an MCP server.
base mixin FlutterMateSupport on ToolsSupport {
  /// VM Service client for communicating with the Flutter app.
  VmServiceClient? _client;

  /// WebSocket URI for the Flutter app's VM Service.
  String? _wsUri;

  /// Set the VM Service URI.
  void setVmServiceUri(String uri) {
    _wsUri = uri;
  }

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    // Register all Flutter Mate tools BEFORE super.initialize()
    // so they're included in the capabilities response
    registerTool(_connectTool, _handleConnect);
    registerTool(_snapshotTool, _handleSnapshot);
    registerTool(_findTool, _handleFind);
    registerTool(_tapTool, _handleTap);
    registerTool(_setTextTool, _handleSetText);
    registerTool(_scrollTool, _handleScroll);
    registerTool(_focusTool, _handleFocus);
    registerTool(_pressKeyTool, _handlePressKey);
    registerTool(_keyDownTool, _handleKeyDown);
    registerTool(_keyUpTool, _handleKeyUp);
    registerTool(_typeTextTool, _handleTypeText);
    registerTool(_clearTool, _handleClear);
    registerTool(_doubleTapTool, _handleDoubleTap);
    registerTool(_longPressTool, _handleLongPress);
    registerTool(_hoverTool, _handleHover);
    registerTool(_dragTool, _handleDrag);
    registerTool(_waitForTool, _handleWaitFor);
    registerTool(_screenshotTool, _handleScreenshot);

    return super.initialize(request);
  }

  @override
  Future<void> shutdown() async {
    await _client?.disconnect();
    _client = null;
    await super.shutdown();
  }

  /// Ensure we're connected to the Flutter app.
  Future<bool> _ensureConnected() async {
    if (_client != null) return true;

    if (_wsUri == null) {
      return false;
    }

    try {
      _client = VmServiceClient(_wsUri!);
      await _client!.connect();
      return true;
    } catch (e) {
      _client = null;
      return false;
    }
  }

  /// Call a Flutter Mate service extension.
  Future<Map<String, dynamic>> _callExtension(
    String extension, {
    Map<String, String>? args,
  }) async {
    if (!await _ensureConnected()) {
      return {
        'success': false,
        'error': 'Not connected. Set FLUTTER_MATE_URI or use connect tool.',
      };
    }

    return _client!.callExtension(extension, args: args);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Tool Definitions
  // ══════════════════════════════════════════════════════════════════════════

  static final _connectTool = Tool(
    name: 'connect',
    description: '''Connect to a running Flutter app via VM Service.

Get the URI from the Flutter app's console output when running `flutter run`:
  "A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/"

The URI will be automatically normalized (http→ws, adds /ws suffix if needed).''',
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description:
              'VM Service URI from Flutter console (http:// or ws://).',
        ),
      },
      required: ['uri'],
    ),
  );

  static final _snapshotTool = Tool(
    name: 'snapshot',
    description: '''Capture the current UI state of the Flutter app.

Returns a collapsed tree of widgets with refs (w0, w1, w2...) for interaction.

## Output Format

Each line: `[ref] Widget (text) value="..." {state} [actions] (flags)`

- `[w123]` - Ref ID to use with other tools
- `Widget` - Widget type (may include debug key like `[GlobalKey#...]`)
- `(Label, Hint)` - Text content from semantics
- `value = "..."` - Typed text in fields
- `{valid}` / `{invalid}` - Form validation state
- `[tap, focus]` - Available semantic actions
- `(TextField, Button, Enabled)` - Semantic flags

## Tree Structure

- Widgets with same bounds chained with → (e.g., `Container → Text`)
- Layout wrappers hidden (Padding, Center, etc.)
- Indentation shows parent-child hierarchy

## Compact Mode

Set compact=true to only show widgets with meaningful info.
Hides purely structural widgets like `[w123] Row` or `[w456] Column`.''',
    annotations: ToolAnnotations(title: 'UI Snapshot', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'compact': Schema.bool(
          description:
              'Only show widgets with info (text, actions, flags). Hides structural-only widgets.',
        ),
      },
    ),
  );

  static final _tapTool = Tool(
    name: 'tap',
    description: 'Tap on an element by ref. '
        'Automatically tries semantic action first, falls back to gesture.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Element ref from snapshot (e.g., "w5").',
        ),
      },
      required: ['ref'],
    ),
  );

  static final _setTextTool = Tool(
    name: 'setText',
    description: '''Set text on a field using semantic action.

Use this for widgets with (TextField) flag in snapshot. This directly sets
the value without simulating keystrokes. Preferred for form fields.

For keyboard simulation (typing character by character), use typeText instead.''',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Element ref from snapshot (e.g., "w9").',
        ),
        'text': Schema.string(description: 'Text to set in the field.'),
      },
      required: ['ref', 'text'],
    ),
  );

  static final _scrollTool = Tool(
    name: 'scroll',
    description: '''Scroll a scrollable element in a direction.

Scrollable elements show [scrollUp], [scrollDown], etc. in their actions.
Tries semantic scroll action first, falls back to gesture simulation.''',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Scrollable element ref from snapshot.',
        ),
        'direction': Schema.string(
          description: 'Direction: up, down, left, right.',
        ),
      },
      required: ['ref', 'direction'],
    ),
  );

  static final _focusTool = Tool(
    name: 'focus',
    description: 'Focus on an element (for text input, etc.).',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _pressKeyTool = Tool(
    name: 'pressKey',
    description: '''Press a keyboard key.

Common keys: enter, tab, escape, backspace, delete,
arrowUp, arrowDown, arrowLeft, arrowRight''',
    inputSchema: Schema.object(
      properties: {
        'key': Schema.string(description: 'Key name to press.'),
      },
      required: ['key'],
    ),
  );

  static final _typeTextTool = Tool(
    name: 'typeText',
    description: '''Type text into a field using keyboard simulation.

Taps to focus the element first, then types each character via platform messages.
Use this when you need to simulate actual typing behavior.

For direct value setting (faster, no keystroke simulation), use setText instead.''',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Element ref from snapshot (e.g., "w10").',
        ),
        'text': Schema.string(description: 'Text to type.'),
      },
      required: ['ref', 'text'],
    ),
  );

  static final _clearTool = Tool(
    name: 'clear',
    description: 'Clear all text from a text field.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Text field ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _doubleTapTool = Tool(
    name: 'doubleTap',
    description: 'Double tap on an element.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _longPressTool = Tool(
    name: 'longPress',
    description: 'Long press on an element. '
        'Tries semantic action first, falls back to gesture.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _waitForTool = Tool(
    name: 'waitFor',
    description: '''Wait for an element with matching text to appear.

Polls the UI until an element matching the pattern is found, or timeout is reached.
Useful for waiting after navigation or async operations.

Searches (in order): textContent, semantics.label, semantics.value, semantics.hint

Returns the ref of the found element and what text matched.''',
    inputSchema: Schema.object(
      properties: {
        'labelPattern': Schema.string(
          description:
              'Regex pattern to match against element text/label/value/hint.',
        ),
        'timeout': Schema.int(
          description: 'Timeout in milliseconds (default: 5000).',
        ),
      },
      required: ['labelPattern'],
    ),
  );

  static final _hoverTool = Tool(
    name: 'hover',
    description: '''Hover over an element (trigger onHover/onEnter callbacks).

Useful for showing tooltips, dropdown menus, or any hover-based UI.''',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref from snapshot.'),
      },
      required: ['ref'],
    ),
  );

  static final _dragTool = Tool(
    name: 'drag',
    description: '''Drag from one element to another.

Simulates a drag gesture from the center of one element to the center of another.
Useful for drag-and-drop, sliders, or reordering items.''',
    inputSchema: Schema.object(
      properties: {
        'fromRef': Schema.string(
          description: 'Element ref to drag from.',
        ),
        'toRef': Schema.string(
          description: 'Element ref to drag to.',
        ),
      },
      required: ['fromRef', 'toRef'],
    ),
  );

  static final _keyDownTool = Tool(
    name: 'keyDown',
    description: '''Press a key down (hold without releasing).

Use with keyUp for fine-grained keyboard control.
Useful for modifier keys (shift, control, alt, command) when typing.

Common keys: enter, tab, escape, backspace, delete, space,
arrowUp, arrowDown, arrowLeft, arrowRight''',
    inputSchema: Schema.object(
      properties: {
        'key': Schema.string(description: 'Key name to press down.'),
        'control': Schema.bool(description: 'Hold control modifier.'),
        'shift': Schema.bool(description: 'Hold shift modifier.'),
        'alt': Schema.bool(description: 'Hold alt/option modifier.'),
        'command': Schema.bool(description: 'Hold command/meta modifier.'),
      },
      required: ['key'],
    ),
  );

  static final _keyUpTool = Tool(
    name: 'keyUp',
    description: '''Release a key (after keyDown).

Use with keyDown for fine-grained keyboard control.''',
    inputSchema: Schema.object(
      properties: {
        'key': Schema.string(description: 'Key name to release.'),
        'control': Schema.bool(description: 'Control modifier state.'),
        'shift': Schema.bool(description: 'Shift modifier state.'),
        'alt': Schema.bool(description: 'Alt/option modifier state.'),
        'command': Schema.bool(description: 'Command/meta modifier state.'),
      },
      required: ['key'],
    ),
  );

  static final _findTool = Tool(
    name: 'find',
    description: '''Get detailed information about a specific element.

Returns the full element data including bounds, semantics, text content,
and children. Useful for inspecting a specific element after taking a snapshot.''',
    annotations: ToolAnnotations(title: 'Find Element', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Element ref from snapshot (e.g., "w5").',
        ),
      },
      required: ['ref'],
    ),
  );

  static final _screenshotTool = Tool(
    name: 'screenshot',
    description: '''Capture a screenshot of the Flutter app.

Returns a base64-encoded PNG image. Can capture:
- Full screen (no ref provided)
- Specific element (provide ref)

The image is returned as base64 data that can be displayed or analyzed.''',
    annotations: ToolAnnotations(title: 'Screenshot', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description:
              'Optional element ref to capture. If omitted, captures full screen.',
        ),
      },
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Tool Handlers
  // ══════════════════════════════════════════════════════════════════════════

  Future<CallToolResult> _handleConnect(CallToolRequest request) async {
    final uri = request.arguments?['uri'] as String?;
    if (uri == null) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required argument: uri')],
        isError: true,
      );
    }

    // Normalize URI
    var wsUri = uri;
    if (wsUri.startsWith('http://')) {
      wsUri = wsUri.replaceFirst('http://', 'ws://');
    }
    if (!wsUri.endsWith('/ws')) {
      wsUri = wsUri.endsWith('/') ? '${wsUri}ws' : '$wsUri/ws';
    }

    try {
      await _client?.disconnect();
      _client = VmServiceClient(wsUri);
      await _client!.connect();
      _wsUri = wsUri;

      return CallToolResult(
        content: [TextContent(text: 'Connected to Flutter app at $wsUri')],
      );
    } catch (e) {
      _client = null;
      return CallToolResult(
        content: [TextContent(text: 'Failed to connect: $e')],
        isError: true,
      );
    }
  }

  Future<CallToolResult> _handleSnapshot(CallToolRequest request) async {
    final compact = request.arguments?['compact'] as bool? ?? false;

    // Pass compact to SDK for server-side filtering (much faster for large UIs)
    final result = await _callExtension(
      'ext.flutter_mate.snapshot',
      args: compact ? {'compact': 'true'} : null,
    );

    if (result['success'] != true) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Snapshot failed: ${result['error'] ?? 'Unknown error'}',
          ),
        ],
        isError: true,
      );
    }

    final data = _parseResult(result['result']);
    if (data == null) {
      return CallToolResult(
        content: [TextContent(text: 'Failed to parse snapshot result')],
        isError: true,
      );
    }

    final nodes = data['nodes'] as List<dynamic>? ?? [];
    final lines = formatSnapshot(nodes, compact: compact);

    final output = StringBuffer();
    if (compact) {
      output.writeln(
          '${lines.length} meaningful elements (from ${nodes.length} nodes)');
    } else {
      output.writeln('${lines.length} elements (from ${nodes.length} nodes)');
    }
    output.writeln('');
    for (final line in lines) {
      output.writeln(line);
    }

    return CallToolResult(
      content: [TextContent(text: output.toString())],
    );
  }

  Future<CallToolResult> _handleTap(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) {
      return _missingArg('ref');
    }

    final result = await _callExtension(
      'ext.flutter_mate.tap',
      args: {'ref': ref},
    );

    return _simpleResult(result, 'tap');
  }

  Future<CallToolResult> _handleSetText(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    final text = request.arguments?['text'] as String?;
    if (ref == null) return _missingArg('ref');
    if (text == null) return _missingArg('text');

    final result = await _callExtension(
      'ext.flutter_mate.setText',
      args: {'ref': ref, 'text': text},
    );

    return _simpleResult(result, 'setText');
  }

  Future<CallToolResult> _handleScroll(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    final direction = request.arguments?['direction'] as String?;
    if (ref == null) return _missingArg('ref');
    if (direction == null) return _missingArg('direction');

    final result = await _callExtension(
      'ext.flutter_mate.scroll',
      args: {'ref': ref, 'direction': direction},
    );

    return _simpleResult(result, 'scroll');
  }

  Future<CallToolResult> _handleFocus(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    final result = await _callExtension(
      'ext.flutter_mate.focus',
      args: {'ref': ref},
    );

    return _simpleResult(result, 'focus');
  }

  Future<CallToolResult> _handlePressKey(CallToolRequest request) async {
    final key = request.arguments?['key'] as String?;
    if (key == null) return _missingArg('key');

    final result = await _callExtension(
      'ext.flutter_mate.pressKey',
      args: {'key': key},
    );

    return _simpleResult(result, 'pressKey');
  }

  Future<CallToolResult> _handleTypeText(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    final text = request.arguments?['text'] as String?;
    if (ref == null) return _missingArg('ref');
    if (text == null) return _missingArg('text');

    final result = await _callExtension(
      'ext.flutter_mate.typeText',
      args: {'ref': ref, 'text': text},
    );

    return _simpleResult(result, 'typeText');
  }

  Future<CallToolResult> _handleClear(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    // Focus first, then clear
    await _callExtension('ext.flutter_mate.focus', args: {'ref': ref});
    final result = await _callExtension('ext.flutter_mate.clearText');

    return _simpleResult(result, 'clear');
  }

  Future<CallToolResult> _handleDoubleTap(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    final result =
        await _callExtension('ext.flutter_mate.doubleTap', args: {'ref': ref});

    return _simpleResult(result, 'doubleTap');
  }

  Future<CallToolResult> _handleLongPress(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    final result = await _callExtension(
      'ext.flutter_mate.longPress',
      args: {'ref': ref},
    );

    return _simpleResult(result, 'longPress');
  }

  Future<CallToolResult> _handleWaitFor(CallToolRequest request) async {
    final labelPattern = request.arguments?['labelPattern'] as String?;
    if (labelPattern == null) return _missingArg('labelPattern');

    final timeoutMs = (request.arguments?['timeout'] as int?) ?? 5000;

    if (!await _ensureConnected()) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Not connected. Set FLUTTER_MATE_URI or use connect tool.',
          ),
        ],
        isError: true,
      );
    }

    final result = await _client!.waitFor(
      labelPattern,
      timeout: Duration(milliseconds: timeoutMs),
    );

    if (result['success'] == true) {
      final ref = result['ref'];
      final matchedText = result['matchedText'];
      return CallToolResult(
        content: [
          TextContent(text: 'Found element: $ref (matched: "$matchedText")'),
        ],
      );
    }

    return CallToolResult(
      content: [TextContent(text: result['error'] ?? 'Element not found')],
      isError: true,
    );
  }

  Future<CallToolResult> _handleHover(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    final result = await _callExtension(
      'ext.flutter_mate.hover',
      args: {'ref': ref},
    );

    return _simpleResult(result, 'hover');
  }

  Future<CallToolResult> _handleDrag(CallToolRequest request) async {
    final fromRef = request.arguments?['fromRef'] as String?;
    final toRef = request.arguments?['toRef'] as String?;
    if (fromRef == null) return _missingArg('fromRef');
    if (toRef == null) return _missingArg('toRef');

    final result = await _callExtension(
      'ext.flutter_mate.drag',
      args: {'fromRef': fromRef, 'toRef': toRef},
    );

    return _simpleResult(result, 'drag');
  }

  Future<CallToolResult> _handleKeyDown(CallToolRequest request) async {
    final key = request.arguments?['key'] as String?;
    if (key == null) return _missingArg('key');

    final control = request.arguments?['control'] as bool? ?? false;
    final shift = request.arguments?['shift'] as bool? ?? false;
    final alt = request.arguments?['alt'] as bool? ?? false;
    final command = request.arguments?['command'] as bool? ?? false;

    final result = await _callExtension(
      'ext.flutter_mate.keyDown',
      args: {
        'key': key,
        if (control) 'control': 'true',
        if (shift) 'shift': 'true',
        if (alt) 'alt': 'true',
        if (command) 'command': 'true',
      },
    );

    return _simpleResult(result, 'keyDown');
  }

  Future<CallToolResult> _handleKeyUp(CallToolRequest request) async {
    final key = request.arguments?['key'] as String?;
    if (key == null) return _missingArg('key');

    final control = request.arguments?['control'] as bool? ?? false;
    final shift = request.arguments?['shift'] as bool? ?? false;
    final alt = request.arguments?['alt'] as bool? ?? false;
    final command = request.arguments?['command'] as bool? ?? false;

    final result = await _callExtension(
      'ext.flutter_mate.keyUp',
      args: {
        'key': key,
        if (control) 'control': 'true',
        if (shift) 'shift': 'true',
        if (alt) 'alt': 'true',
        if (command) 'command': 'true',
      },
    );

    return _simpleResult(result, 'keyUp');
  }

  Future<CallToolResult> _handleFind(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    final result = await _callExtension(
      'ext.flutter_mate.find',
      args: {'ref': ref},
    );

    if (result['success'] != true) {
      return CallToolResult(
        content: [
          TextContent(text: '❌ find failed: ${result['error'] ?? 'Unknown'}'),
        ],
        isError: true,
      );
    }

    final data = _parseResult(result['result']);
    final element = data?['element'] as Map<String, dynamic>?;
    if (element == null) {
      return CallToolResult(
        content: [TextContent(text: '❌ Element not found: $ref')],
        isError: true,
      );
    }

    // Use shared formatter for consistent output
    final lines = formatElementDetails(element);
    return CallToolResult(
      content: [TextContent(text: lines.join('\n'))],
    );
  }

  Future<CallToolResult> _handleScreenshot(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;

    final args = <String, String>{};
    if (ref != null && ref.isNotEmpty) {
      args['ref'] = ref;
    }

    final result = await _callExtension(
      'ext.flutter_mate.screenshot',
      args: args.isNotEmpty ? args : null,
    );

    if (result['success'] != true) {
      return CallToolResult(
        content: [
          TextContent(
            text: '❌ Screenshot failed: ${result['error'] ?? 'Unknown error'}',
          ),
        ],
        isError: true,
      );
    }

    final data = _parseResult(result['result']);
    final base64Image = data?['image'] as String?;

    if (base64Image == null) {
      return CallToolResult(
        content: [TextContent(text: '❌ Screenshot failed: no image data')],
        isError: true,
      );
    }

    // Return as base64 image content
    return CallToolResult(
      content: [
        ImageContent(
          data: base64Image,
          mimeType: 'image/png',
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════════════════

  CallToolResult _missingArg(String name) {
    return CallToolResult(
      content: [TextContent(text: 'Missing required argument: $name')],
      isError: true,
    );
  }

  CallToolResult _simpleResult(Map<String, dynamic> result, String action) {
    if (result['success'] == true) {
      return CallToolResult(
        content: [TextContent(text: '✅ $action succeeded')],
      );
    }
    return CallToolResult(
      content: [TextContent(text: '❌ $action failed: ${result['error']}')],
      isError: true,
    );
  }

  Map<String, dynamic>? _parseResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is String) {
      try {
        return jsonDecode(result) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
