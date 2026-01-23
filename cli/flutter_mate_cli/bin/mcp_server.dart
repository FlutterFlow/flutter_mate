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
/// **Connection:**
/// - `connect` - Connect to a Flutter app via VM Service URI
///
/// **Inspection:**
/// - `snapshot` - Get UI tree with element refs (supports compact mode)
/// - `find` - Get detailed info about a specific element
/// - `screenshot` - Capture screenshot (full screen or specific element)
///
/// **Touch Actions:**
/// - `tap`, `doubleTap`, `longPress` - Tap actions
/// - `hover` - Hover over element (trigger onHover)
/// - `drag` - Drag from one element to another
///
/// **Text Input:**
/// - `setText` - Set text via semantic action
/// - `typeText` - Type text via keyboard simulation
/// - `clear` - Clear text field
///
/// **Navigation:**
/// - `scroll` - Scroll element in a direction
/// - `focus` - Focus element
///
/// **Keyboard:**
/// - `pressKey` - Press a keyboard key
/// - `keyDown`, `keyUp` - Fine-grained key control
///
/// **Wait:**
/// - `waitFor` - Wait for element matching pattern to appear
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
3. Use refs to interact: tap, setText, scroll, focus
4. Take another snapshot after navigation to get new refs

## Snapshot Format

The snapshot shows a collapsed tree where:
- Widgets with same bounds are chained with → (parent → child)
- Layout wrappers (Padding, Center, etc.) are hidden
- Indentation shows hierarchy (• bullet = child level)

### Line Format

Each element line has this structure:
```
[ref] WidgetType (text content) value = "..." {state} [actions] (flags)
```

Sections (all optional except ref and widget):
- `[w123]` - Ref ID, use this to interact with the element
- `WidgetType` - Flutter widget class name (may include debug key like `[GlobalKey#...]`)
- `(Label, Hint, Error)` - Text content: semantic label, hint text, validation errors
- `value = "..."` - Semantic value (e.g., text typed in a field)
- `{valid}` or `{invalid}` - Validation state for form fields
- `{type: email}` - Keyboard type hints
- `[tap, focus, scrollUp]` - Available semantic actions
- `(TextField, Button, Focusable, Enabled, Obscured)` - Semantic flags/traits

### Example Snapshot

```
• [w1] MyApp → [w2] MaterialApp → [w3] LoginScreen
  • [w5] Column
    • [w9] TextFormField (Email, Enter your email) {valid} [tap, focus] (TextField, Focusable, Enabled)
    • [w15] TextFormField (Password) value = "****" {valid} [tap, focus] (TextField, Focusable, Enabled, Obscured)
    • [w20] ElevatedButton (Submit) [tap] (Button, Enabled)
    • [w25] Text (Don't have an account?)
    • [w27] GestureDetector → [w28] Text (Sign Up) [tap]
```

### Using Refs

- `tap(ref: "w20")` - Tap the Submit button
- `setText(ref: "w9", text: "user@example.com")` - Fill email field
- `focus(ref: "w15")` - Focus password field
- `scroll(ref: "w5", direction: "down")` - Scroll the Column

## Tips

- Chained widgets (→) share the same position - pick any ref in the chain
- Actions like [tap] indicate semantic support; if missing, gesture fallback is used
- After navigation, always take a new snapshot - refs change between screens
''',
        ) {
    // Set the URI if provided
    if (wsUri != null) {
      setVmServiceUri(wsUri);
    }
  }
}
