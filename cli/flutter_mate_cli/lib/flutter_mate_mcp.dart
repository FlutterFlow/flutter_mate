/// FlutterMate MCP Support - Model Context Protocol integration
///
/// Mix this into an MCPServer to add Flutter automation tools.
///
/// ## Available Tools
///
/// - `connect` - Connect to a running Flutter app
/// - `snapshot` - Get UI tree with element refs (collapsed view)
/// - `tap` - Tap element (semantic first, then gesture fallback)
/// - `setText` - Set text via semantic action
/// - `typeText` - Type text via keyboard simulation
/// - `scroll` - Scroll element (semantic first, then gesture fallback)
/// - `focus` - Focus element
/// - `pressKey` - Press keyboard key
/// - `clear` - Clear text field
/// - `doubleTap` - Double tap element
/// - `longPress` - Long press element
/// - `waitFor` - Wait for element with matching label
///
/// ## Snapshot Format
///
/// The snapshot uses a collapsed tree format that:
/// - Chains widgets with same bounds using →
/// - Hides layout wrappers (Padding, Container, etc.)
/// - Shows text content and semantic info inline
///
/// ```
/// • [w1] DemoApp → [w2] MaterialApp → [w3] LoginPage
///   • [w6] Column
///     • [w9] Semantics "Email" [tap, focus, setText] (TextField)
///       • [w10] TextField
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
    registerTool(_tapTool, _handleTap);
    registerTool(_setTextTool, _handleSetText);
    registerTool(_scrollTool, _handleScroll);
    registerTool(_focusTool, _handleFocus);
    registerTool(_pressKeyTool, _handlePressKey);
    registerTool(_typeTextTool, _handleTypeText);
    registerTool(_clearTool, _handleClear);
    registerTool(_doubleTapTool, _handleDoubleTap);
    registerTool(_longPressTool, _handleLongPress);
    registerTool(_waitForTool, _handleWaitFor);

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

Provide the WebSocket URI from the Flutter app's console output:
  "A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/"

Convert to WebSocket: ws://127.0.0.1:12345/abc=/ws''',
    inputSchema: Schema.object(
      properties: {
        'uri': Schema.string(
          description: 'VM Service WebSocket URI (ws://...)',
        ),
      },
      required: ['uri'],
    ),
  );

  static final _snapshotTool = Tool(
    name: 'snapshot',
    description: '''Capture the current UI state of the Flutter app.

Returns a tree of user widgets with refs (w0, w1, w2...) that can be used
for subsequent interactions. Each element includes:
- ref: Stable identifier for this snapshot session
- widget: Widget type name
- bounds: Position {x, y, width, height}
- semantics: Label, value, actions, flags (on Semantics widgets)''',
    annotations: ToolAnnotations(title: 'UI Snapshot', readOnlyHint: true),
    inputSchema: Schema.object(properties: {}),
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
    description: 'Set text on a field using semantic action. '
        'Use on Semantics widgets (e.g., w9). For keyboard simulation, use typeText.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Semantics widget ref.'),
        'text': Schema.string(description: 'Text to set.'),
      },
      required: ['ref', 'text'],
    ),
  );

  static final _scrollTool = Tool(
    name: 'scroll',
    description: 'Scroll a scrollable element. '
        'Tries semantic action first, falls back to gesture.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Scrollable element ref.'),
        'direction': Schema.string(
          description: 'Scroll direction: up, down, left, right.',
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
    description: 'Type text into a widget using keyboard simulation. '
        'Use this for TextField widgets (e.g., w10). '
        'For Semantics widgets, use fill instead.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Widget ref (e.g., w10).'),
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
    description: '''Wait for an element with matching label to appear.

Polls the UI until an element with a label or value matching the pattern
is found, or timeout is reached. Useful for waiting after navigation
or async operations.

Returns the ref of the found element.''',
    inputSchema: Schema.object(
      properties: {
        'labelPattern': Schema.string(
          description: 'Regex pattern to match against element labels/values.',
        ),
        'timeout': Schema.int(
          description: 'Timeout in milliseconds (default: 5000).',
        ),
      },
      required: ['labelPattern'],
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
    final result = await _callExtension('ext.flutter_mate.snapshot');

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

    // Build node map for collapsing
    final nodeMap = <String, Map<String, dynamic>>{};
    for (final node in nodes) {
      nodeMap[node['ref'] as String] = node as Map<String, dynamic>;
    }

    // Collapse nodes
    final collapsed = _collapseNodes(nodes, nodeMap);

    final output = StringBuffer();
    output.writeln('${collapsed.length} elements (from ${nodes.length} nodes)');
    output.writeln('');

    for (final entry in collapsed) {
      final chain = entry['chain'] as List<Map<String, dynamic>>;
      final depth = entry['depth'] as int;
      final semantics = entry['semantics'] as Map<String, dynamic>?;
      final textContent = entry['textContent'] as String?;

      final indent = '  ' * depth;

      // Filter layout wrappers from display
      final meaningful = chain
          .where((item) => !_layoutWrappers.contains(item['widget'] as String))
          .toList();
      final display = meaningful.isNotEmpty ? meaningful : [chain.first];
      final chainStr =
          display.map((e) => '[${e['ref']}] ${e['widget']}').join(' → ');

      // Build info parts
      final parts = <String>[];

      // Collect all text from textContent and semantics label, deduplicate
      final allTexts = <String>[];
      final seenTexts = <String>{}; // Track by trimmed lowercase for dedup

      void addText(String? text) {
        if (text == null || text.trim().isEmpty) return;
        // Skip single-character icon glyphs (Private Use Area)
        if (text.length == 1 && text.codeUnitAt(0) >= 0xE000) return;
        final key = text.trim().toLowerCase();
        if (!seenTexts.contains(key)) {
          seenTexts.add(key);
          allTexts.add(text.trim());
        }
      }

      // Add textContent parts (split by |)
      if (textContent != null) {
        for (final t in textContent.split(' | ')) {
          addText(t);
        }
      }

      // Add semantics label
      final label = semantics?['label'] as String?;
      addText(label);

      if (allTexts.isNotEmpty) {
        parts.add('"${allTexts.join(', ')}"');
      }

      // Add semantic value (e.g., current text in a text field)
      final value = semantics?['value'] as String?;
      if (value != null &&
          value.isNotEmpty &&
          !seenTexts.contains(value.trim().toLowerCase())) {
        parts.add('= "$value"');
      }

      // Build extra semantic info in {key: value, ...} format
      final extraParts = <String>[];

      final validationResult = semantics?['validationResult'] as String?;
      if (validationResult == 'invalid') {
        extraParts.add('invalid');
      } else if (validationResult == 'valid') {
        extraParts.add('valid');
      }

      final tooltip = semantics?['tooltip'] as String?;
      if (tooltip != null && tooltip.isNotEmpty) {
        extraParts.add('tooltip: "$tooltip"');
      }

      final headingLevel = semantics?['headingLevel'] as int?;
      if (headingLevel != null && headingLevel > 0) {
        extraParts.add('heading: $headingLevel');
      }

      final linkUrl = semantics?['linkUrl'] as String?;
      if (linkUrl != null && linkUrl.isNotEmpty) {
        extraParts.add('link');
      }

      final role = semantics?['role'] as String?;
      final inputType = semantics?['inputType'] as String?;
      if (inputType != null && inputType != 'none' && inputType != 'text') {
        extraParts.add('type: $inputType');
      } else if (role != null && role != 'none') {
        extraParts.add('role: $role');
      }

      if (extraParts.isNotEmpty) {
        parts.add('{${extraParts.join(', ')}}');
      }

      final actions =
          (semantics?['actions'] as List<dynamic>?)?.cast<String>() ?? [];
      if (actions.isNotEmpty) {
        parts.add('[${actions.join(', ')}]');
      }

      final flags =
          (semantics?['flags'] as List<dynamic>?)?.cast<String>() ?? [];
      final flagsStr = flags
          .where((f) => f.startsWith('is'))
          .map((f) => f.substring(2))
          .join(', ');
      if (flagsStr.isNotEmpty) parts.add('($flagsStr)');

      final scrollPosition = semantics?['scrollPosition'] as num?;
      final scrollExtentMax = semantics?['scrollExtentMax'] as num?;
      if (scrollPosition != null) {
        final pos = scrollPosition.toStringAsFixed(0);
        final max = scrollExtentMax?.toStringAsFixed(0) ?? '?';
        parts.add('{scroll: $pos/$max}');
      }

      final info = parts.isNotEmpty ? ' ${parts.join(' ')}' : '';
      output.writeln('$indent• $chainStr$info');
    }

    return CallToolResult(
      content: [TextContent(text: output.toString())],
    );
  }

  /// Layout wrapper widgets to hide from display
  static const _layoutWrappers = {
    'Padding', 'SizedBox', 'ConstrainedBox', 'LimitedBox', 'OverflowBox',
    'FractionallySizedBox', 'IntrinsicHeight', 'IntrinsicWidth',
    'Center', 'Align', 'Expanded', 'Flexible', 'Positioned', 'Spacer',
    'Container', 'DecoratedBox', 'ColoredBox',
    'Transform', 'RotatedBox', 'FittedBox', 'AspectRatio',
    'ClipRect', 'ClipRRect', 'ClipOval', 'ClipPath',
    'Opacity', 'Offstage', 'Visibility', 'IgnorePointer', 'AbsorbPointer',
    'MetaData', 'KeyedSubtree', 'RepaintBoundary', 'Builder', 'StatefulBuilder',
  };

  /// Collapse nodes with same bounds into chains
  List<Map<String, dynamic>> _collapseNodes(
      List<dynamic> nodes, Map<String, Map<String, dynamic>> nodeMap) {
    final result = <Map<String, dynamic>>[];
    final visited = <String>{};

    void processNode(Map<String, dynamic> node, int displayDepth) {
      final ref = node['ref'] as String;
      if (visited.contains(ref)) return;

      // Skip zero-area spacers
      if (_isHiddenSpacer(node)) {
        visited.add(ref);
        return;
      }

      // Start a chain
      final chain = <Map<String, dynamic>>[];
      var current = node;
      Map<String, dynamic>? aggregatedSemantics;
      String? aggregatedText;

      while (true) {
        final currentRef = current['ref'] as String;
        visited.add(currentRef);
        chain.add({
          'ref': currentRef,
          'widget': current['widget'] as String? ?? '?',
        });

        final sem = current['semantics'] as Map<String, dynamic>?;
        if (sem != null) aggregatedSemantics ??= sem;

        final text = current['textContent'] as String?;
        if (text != null && text.isNotEmpty) aggregatedText ??= text;

        final children = current['children'] as List<dynamic>? ?? [];
        if (children.isEmpty || children.length > 1) break;

        final widgetType = current['widget'] as String? ?? '';
        if (widgetType == 'Semantics') break;

        final childRef = children.first as String;
        final child = nodeMap[childRef];
        if (child == null) break;

        if (_isHiddenSpacer(child)) {
          visited.add(childRef);
          break;
        }

        final childWidget = child['widget'] as String? ?? '';
        if (childWidget == 'Semantics') break;

        // Always collapse layout wrappers
        if (_layoutWrappers.contains(widgetType) || _sameBounds(current, child)) {
          current = child;
          continue;
        }

        break;
      }

      result.add({
        'chain': chain,
        'depth': displayDepth,
        'semantics': aggregatedSemantics,
        'textContent': aggregatedText,
        'children': current['children'] as List<dynamic>? ?? [],
      });

      final children = current['children'] as List<dynamic>? ?? [];
      for (final childRef in children) {
        final child = nodeMap[childRef as String];
        if (child != null && !visited.contains(childRef)) {
          processNode(child, displayDepth + 1);
        }
      }
    }

    for (final node in nodes) {
      if ((node['depth'] as int?) == 0) {
        processNode(node as Map<String, dynamic>, 0);
      }
    }

    return result;
  }

  bool _isHiddenSpacer(Map<String, dynamic> node) {
    final widget = node['widget'] as String? ?? '';
    if (widget != 'SizedBox' && widget != 'Spacer') return false;
    final bounds = node['bounds'] as Map<String, dynamic>?;
    if (bounds == null) return true;
    final width = (bounds['width'] as num?) ?? 0;
    final height = (bounds['height'] as num?) ?? 0;
    return width < 2 || height < 2;
  }

  bool _sameBounds(Map<String, dynamic> a, Map<String, dynamic> b) {
    final boundsA = a['bounds'] as Map<String, dynamic>?;
    final boundsB = b['bounds'] as Map<String, dynamic>?;
    if (boundsA == null || boundsB == null) return false;
    const tolerance = 1.0;
    return ((boundsA['x'] as num) - (boundsB['x'] as num)).abs() <= tolerance &&
        ((boundsA['y'] as num) - (boundsB['y'] as num)).abs() <= tolerance &&
        ((boundsA['width'] as num) - (boundsB['width'] as num)).abs() <= tolerance &&
        ((boundsA['height'] as num) - (boundsB['height'] as num)).abs() <= tolerance;
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
      final label = result['label'] ?? result['value'];
      return CallToolResult(
        content: [
          TextContent(text: 'Found element: $ref (matched: "$label")'),
        ],
      );
    }

    return CallToolResult(
      content: [TextContent(text: result['error'] ?? 'Element not found')],
      isError: true,
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
