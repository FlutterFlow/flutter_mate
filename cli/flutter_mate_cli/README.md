# flutter_mate_cli

Command-line interface and MCP server for Flutter Mate.

## Installation

```bash
cd cli/flutter_mate_cli
dart pub get

# Run directly
dart run bin/flutter_mate.dart --help

# Or install globally
dart pub global activate --source path .
flutter_mate --help
```

## CLI Usage

```bash
# Get the VM Service URI from Flutter console when running your app:
#   A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/

# Convert to WebSocket URI and use:
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot

# Snapshot options
flutter_mate --uri ws://... snapshot -c        # Compact mode (only meaningful widgets)
flutter_mate --uri ws://... snapshot --depth 3 # Limit tree depth
flutter_mate --uri ws://... snapshot --from w6 # Start from specific element as root

# Take screenshots
flutter_mate --uri ws://... screenshot                 # Full screen (saves to PNG)
flutter_mate --uri ws://... screenshot --ref w10       # Element only
flutter_mate --uri ws://... screenshot --path out.png  # Custom path

# Interact with elements
flutter_mate --uri ws://... tap w10
flutter_mate --uri ws://... setText w5 "hello@example.com"
flutter_mate --uri ws://... scroll w15 down

# Interactive REPL mode
flutter_mate --uri ws://... attach
flutter_mate> snapshot
flutter_mate> sc              # compact snapshot
flutter_mate> tap w10
flutter_mate> help
```

## Commands

| Command | Description |
|---------|-------------|
| `snapshot` | Get UI tree (options: `-c`, `--depth N`, `--from wX`) |
| `screenshot` | Capture screenshot (options: `--ref wX`, `--path file.png`) |
| `tap <ref>` | Tap element |
| `doubleTap <ref>` | Double tap element |
| `longPress <ref>` | Long press element |
| `hover <ref>` | Hover over element |
| `drag <from> <to>` | Drag between elements |
| `setText <ref> <text>` | Set text (semantic action) |
| `typeText <ref> <text>` | Type text (keyboard simulation) |
| `clear <ref>` | Clear text field |
| `scroll <ref> [dir]` | Scroll element |
| `swipe <dir>` | Swipe gesture |
| `focus <ref>` | Focus element |
| `pressKey <key>` | Press keyboard key |
| `keyDown <key>` | Press key down |
| `keyUp <key>` | Release key |
| `find <ref>` | Get detailed element info |
| `getText <ref>` | Get element text |
| `wait <ms>` | Wait milliseconds |
| `extensions` | List service extensions |
| `attach` | Interactive REPL mode |

### Snapshot Options

| Option | Description |
|--------|-------------|
| `-c, --compact` | Only show widgets with meaningful info |
| `-d, --depth N` | Limit tree depth (e.g., `--depth 3`) |
| `-f, --from wX` | Start from specific element as root (requires prior snapshot) |

## MCP Server

For AI agent integration with Cursor, Claude, or other MCP clients:

```bash
# Run the MCP server
dart run bin/mcp_server.dart

# Or with a pre-configured URI
FLUTTER_MATE_URI=ws://127.0.0.1:12345/abc=/ws dart run bin/mcp_server.dart
```

### Cursor Configuration

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "flutter_mate": {
      "command": "dart",
      "args": ["run", "/path/to/flutter_mate_cli/bin/mcp_server.dart"],
      "env": {
        "FLUTTER_MATE_URI": "ws://127.0.0.1:12345/abc=/ws"
      }
    }
  }
}
```

### MCP Tools

| Tool | Description |
|------|-------------|
| `connect` | Connect to Flutter app by VM Service URI |
| `snapshot` | Get UI tree (`compact`, `depth`, `fromRef` options) |
| `screenshot` | Capture screenshot (full screen or by `ref`) |
| `find` | Get detailed element info by ref |
| `tap` | Tap element |
| `doubleTap` | Double tap element |
| `longPress` | Long press element |
| `hover` | Hover over element |
| `drag` | Drag from one element to another |
| `setText` | Set text via semantic action |
| `typeText` | Type text via keyboard simulation |
| `clear` | Clear text field |
| `scroll` | Scroll element in a direction |
| `focus` | Focus element |
| `pressKey` | Press keyboard key |
| `keyDown` | Press key down (hold) |
| `keyUp` | Release key |
| `waitFor` | Wait for element matching pattern |

## Snapshot Format

The snapshot shows a collapsed widget tree:

```
• [w1] MyApp → [w2] MaterialApp → [w3] LoginScreen
  • [w6] Column
    • [w9] TextField (Email) {valid, type: email} [tap, focus] (TextField, Focusable)
    • [w15] TextField (Password) value = "****" [tap, focus] (Obscured)
    • [w20] ElevatedButton (Submit) [tap] (Button, Enabled)
```

Format: `[ref] Widget (text) value="..." {state} [actions] (flags)`

- **ref** - Use with commands like `tap w9`
- **text** - Semantic label, hint, or text content
- **value** - Typed text in fields
- **state** - Validation, input type, etc.
- **actions** - Available semantic actions
- **flags** - Widget properties (Button, TextField, etc.)
