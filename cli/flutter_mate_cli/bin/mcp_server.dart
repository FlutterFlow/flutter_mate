/// Flutter Mate MCP Server - Model Context Protocol for AI agents
///
/// This server provides Flutter automation tools via MCP, enabling
/// integration with Cursor, Claude, and other MCP-compatible clients.
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
///
/// ## Environment Variables
///
/// - `FLUTTER_MATE_URI` - VM Service WebSocket URI (optional, can use connect tool)
///
/// ## Available Tools
///
/// - `connect` - Connect to a Flutter app
/// - `snapshot` - Get UI tree with element refs
/// - `tap`, `doubleTap`, `longPress` - Tap actions
/// - `fill`, `typeText`, `clear` - Text input
/// - `scroll`, `focus` - Navigation
/// - `pressKey` - Keyboard input
/// - `waitFor` - Wait for element to appear
library;

import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:flutter_mate_cli/flutter_mate_mcp.dart';

void main(List<String> args) {
  // Check for URI in args or environment
  String? wsUri;

  // Parse --uri=... from args
  for (final arg in args) {
    if (arg.startsWith('--uri=')) {
      wsUri = arg.substring(6);
      break;
    }
  }

  // Fall back to environment variable
  wsUri ??= io.Platform.environment['FLUTTER_MATE_URI'];

  // Normalize URI if provided
  if (wsUri != null) {
    if (wsUri.startsWith('http://')) {
      wsUri = wsUri.replaceFirst('http://', 'ws://');
    }
    if (!wsUri.endsWith('/ws')) {
      wsUri = wsUri.endsWith('/') ? '${wsUri}ws' : '$wsUri/ws';
    }
  }

  // Create the server and connect it to stdio
  FlutterMateServer(
    stdioChannel(input: io.stdin, output: io.stdout),
    wsUri: wsUri,
  );
}

/// MCP server with Flutter Mate automation tools.
base class FlutterMateServer extends MCPServer
    with LoggingSupport, ToolsSupport, FlutterMateSupport {
  FlutterMateServer(super.channel, {String? wsUri})
      : super.fromStreamChannel(
          implementation: Implementation(
            name: 'flutter_mate',
            version: '0.1.0',
          ),
          instructions: '''Flutter Mate - Automate Flutter apps via AI.

## Quick Start

1. Run your Flutter app: flutter run
2. Copy the VM Service URI from console
3. Use the connect tool: connect(uri: "ws://127.0.0.1:12345/abc=/ws")
4. Take a snapshot: snapshot()
5. Interact with elements by ref: tap(ref: "w5")

## Workflow

1. Always start with snapshot() to see available elements
2. Elements have refs like w0, w1, w2...
3. Use refs to interact: tap, fill, scroll, focus
4. Take another snapshot after navigation to get new refs

## Example

snapshot() → see w9 is Semantics for text field, w10 is TextField, w18 is Submit
setText(ref: "w9", text: "hello@example.com")  // semantic action
tap(ref: "w18")  // auto: semantic or gesture
snapshot() → verify navigation occurred
''',
        ) {
    // Set the URI if provided
    if (wsUri != null) {
      setVmServiceUri(wsUri);
    }
  }
}
