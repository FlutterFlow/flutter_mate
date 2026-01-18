/// FlutterMate MCP Support - Model Context Protocol integration
///
/// Mix this into an MCPServer to add Flutter automation tools.
///
/// ## Available Tools
///
/// - `connect` - Connect to a running Flutter app
/// - `snapshot` - Get UI tree with element refs
/// - `tap` - Tap element by ref
/// - `fill` - Fill text field
/// - `scroll` - Scroll element
/// - `focus` - Focus element
/// - `pressKey` - Press keyboard key
/// - `typeText` - Type text character by character
/// - `clear` - Clear text field
/// - `doubleTap` - Double tap element
/// - `longPress` - Long press element
/// - `toggle` - Toggle switch/checkbox
/// - `select` - Select dropdown option
/// - `wait` - Wait for duration
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
    final result = await super.initialize(request);

    // Register all Flutter Mate tools
    registerTool(_connectTool, _handleConnect);
    registerTool(_snapshotTool, _handleSnapshot);
    registerTool(_tapTool, _handleTap);
    registerTool(_fillTool, _handleFill);
    registerTool(_scrollTool, _handleScroll);
    registerTool(_focusTool, _handleFocus);
    registerTool(_pressKeyTool, _handlePressKey);
    registerTool(_typeTextTool, _handleTypeText);
    registerTool(_clearTool, _handleClear);
    registerTool(_doubleTapTool, _handleDoubleTap);
    registerTool(_longPressTool, _handleLongPress);
    registerTool(_toggleTool, _handleToggle);
    registerTool(_selectTool, _handleSelect);
    registerTool(_waitTool, _handleWait);

    return result;
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

Returns a tree of elements with refs (w0, w1, w2...) that can be used
for subsequent interactions. Each element includes:
- ref: Stable identifier for this snapshot session
- widget: Widget type name
- bounds: Position {x, y, width, height}
- semantics: Label, value, actions, flags

Use interactive=true (default) to only get actionable elements.''',
    annotations: ToolAnnotations(title: 'UI Snapshot', readOnlyHint: true),
    inputSchema: Schema.object(
      properties: {
        'interactive': Schema.bool(
          description: 'Only return elements with actions. Default: true.',
        ),
      },
    ),
  );

  static final _tapTool = Tool(
    name: 'tap',
    description: 'Tap on an element by ref. Use snapshot first to get refs.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(
          description: 'Element ref from snapshot (e.g., "w5").',
        ),
      },
      required: ['ref'],
    ),
  );

  static final _fillTool = Tool(
    name: 'fill',
    description: 'Fill a text field with text. Replaces existing content.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Text field ref.'),
        'text': Schema.string(description: 'Text to enter.'),
      },
      required: ['ref', 'text'],
    ),
  );

  static final _scrollTool = Tool(
    name: 'scroll',
    description: 'Scroll a scrollable element.',
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
    description: 'Type text character by character. More realistic than fill.',
    inputSchema: Schema.object(
      properties: {
        'text': Schema.string(description: 'Text to type.'),
      },
      required: ['text'],
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
    description: 'Long press on an element.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _toggleTool = Tool(
    name: 'toggle',
    description: 'Toggle a switch or checkbox.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Element ref.'),
      },
      required: ['ref'],
    ),
  );

  static final _selectTool = Tool(
    name: 'select',
    description: 'Select an option from a dropdown menu.',
    inputSchema: Schema.object(
      properties: {
        'ref': Schema.string(description: 'Dropdown ref.'),
        'value': Schema.string(description: 'Value/label to select.'),
      },
      required: ['ref', 'value'],
    ),
  );

  static final _waitTool = Tool(
    name: 'wait',
    description: 'Wait for a duration in milliseconds.',
    inputSchema: Schema.object(
      properties: {
        'milliseconds': Schema.int(description: 'Wait duration.'),
      },
      required: ['milliseconds'],
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
    final interactive = (request.arguments?['interactive'] as bool?) ?? true;

    final result = await _callExtension(
      'ext.flutter_mate.snapshotCombined',
      args: {'consolidate': 'true'},
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

    // Filter to interactive if requested
    var nodes = data['nodes'] as List<dynamic>? ?? [];
    if (interactive) {
      nodes = nodes.where((n) {
        final semantics = n['semantics'] as Map<String, dynamic>?;
        final actions = semantics?['actions'] as List<dynamic>?;
        return actions != null && actions.isNotEmpty;
      }).toList();
    }

    final output = StringBuffer();
    output.writeln('📱 Flutter UI Snapshot');
    output.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    output.writeln('Elements: ${nodes.length}');
    output.writeln('');

    for (final node in nodes) {
      final ref = node['ref'] as String;
      final widget = node['widget'] as String;
      final semantics = node['semantics'] as Map<String, dynamic>?;
      final label = semantics?['label'] as String?;
      final value = semantics?['value'] as String?;
      final actions =
          (semantics?['actions'] as List<dynamic>?)?.cast<String>() ?? [];

      final parts = <String>[];
      if (label != null) parts.add('"$label"');
      if (value != null && value.isNotEmpty) parts.add('= "$value"');
      if (actions.isNotEmpty) parts.add('[${actions.join(", ")}]');

      output.writeln('$ref: $widget ${parts.join(" ")}');
    }

    output.writeln('');
    output.writeln('💡 Use refs to interact: tap w5, fill w10 "text"');

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

  Future<CallToolResult> _handleFill(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    final text = request.arguments?['text'] as String?;
    if (ref == null) return _missingArg('ref');
    if (text == null) return _missingArg('text');

    final result = await _callExtension(
      'ext.flutter_mate.fill',
      args: {'ref': ref, 'text': text},
    );

    return _simpleResult(result, 'fill');
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
    final text = request.arguments?['text'] as String?;
    if (text == null) return _missingArg('text');

    final result = await _callExtension(
      'ext.flutter_mate.typeText',
      args: {'text': text},
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

    // Double tap: two quick taps
    await _callExtension('ext.flutter_mate.tap', args: {'ref': ref});
    await Future.delayed(const Duration(milliseconds: 50));
    final result =
        await _callExtension('ext.flutter_mate.tap', args: {'ref': ref});

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

  Future<CallToolResult> _handleToggle(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    if (ref == null) return _missingArg('ref');

    // Toggle is just a tap
    final result = await _callExtension(
      'ext.flutter_mate.tap',
      args: {'ref': ref},
    );

    return _simpleResult(result, 'toggle');
  }

  Future<CallToolResult> _handleSelect(CallToolRequest request) async {
    final ref = request.arguments?['ref'] as String?;
    final value = request.arguments?['value'] as String?;
    if (ref == null) return _missingArg('ref');
    if (value == null) return _missingArg('value');

    // Open dropdown
    await _callExtension('ext.flutter_mate.tap', args: {'ref': ref});
    await Future.delayed(const Duration(milliseconds: 200));

    // Find and tap the option (simplified - would need snapshot + find)
    return CallToolResult(
      content: [
        TextContent(
          text: 'Select opened dropdown. Use snapshot to find and tap option.',
        ),
      ],
    );
  }

  Future<CallToolResult> _handleWait(CallToolRequest request) async {
    final ms = request.arguments?['milliseconds'] as int?;
    if (ms == null) return _missingArg('milliseconds');

    await Future.delayed(Duration(milliseconds: ms));

    return CallToolResult(
      content: [TextContent(text: 'Waited ${ms}ms')],
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
