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

The CLI uses a daemon architecture for fast, persistent connections:

```bash
# First, launch your Flutter app separately
flutter run -d macos
# or
flutter run -d chrome --web-browser-flag="--headless"

# Then connect using the VM Service URI from the Flutter console
flutter_mate connect ws://127.0.0.1:12345/abc=/ws

# Now run commands (no URI needed - daemon maintains connection)
flutter_mate snapshot
flutter_mate snapshot -c                 # Compact mode
flutter_mate snapshot --depth 3          # Limit tree depth
flutter_mate tap w10
flutter_mate setText w5 "hello@example.com"
flutter_mate screenshot --path out.png

# Check connection status
flutter_mate status

# Session management (for multiple apps)
flutter_mate -s staging connect ws://127.0.0.1:54321/xyz=/ws
flutter_mate -s staging snapshot
flutter_mate session list

# Cleanup
flutter_mate close
```

## Commands

### App Lifecycle

| Command | Description |
|---------|-------------|
| `connect <uri>` | Connect to running Flutter app by VM Service URI |
| `close` | Disconnect and stop daemon |
| `status` | Show connection status |
| `session list` | List active sessions |

### Introspection

| Command | Description |
|---------|-------------|
| `snapshot` | Get UI tree (options: `-c`, `--depth N`, `--from wX`) |
| `find <ref>` | Get detailed element info |
| `screenshot` | Capture screenshot (options: `--ref wX`, `--path file.png`) |
| `getText <ref>` | Get element text |

### Interactions

| Command | Description |
|---------|-------------|
| `tap <ref>` | Tap element |
| `doubleTap <ref>` | Double tap element |
| `longPress <ref>` | Long press element |
| `hover <ref>` | Hover over element |
| `drag <from> <to>` | Drag between elements |
| `focus <ref>` | Focus element |

### Text Input

| Command | Description |
|---------|-------------|
| `setText <ref> <text>` | Set text (semantic action) |
| `typeText <ref> <text>` | Type text (keyboard simulation) |
| `clear <ref>` | Clear text field |

### Scrolling & Keyboard

| Command | Description |
|---------|-------------|
| `scroll <ref> [dir]` | Scroll element (up, down, left, right) |
| `swipe <dir>` | Swipe gesture |
| `pressKey <key>` | Press keyboard key |
| `keyDown <key>` | Press key down (hold) |
| `keyUp <key>` | Release key |

### Waiting

| Command | Description |
|---------|-------------|
| `wait <ms>` | Wait milliseconds |
| `waitFor <pattern>` | Wait for element to appear (`--timeout`, `--poll`) |
| `waitForDisappear <pattern>` | Wait for element to disappear |
| `waitForValue <ref> <pattern>` | Wait for element value to match |

### Global Options

| Option | Description |
|--------|-------------|
| `-s, --session <name>` | Session name (default: "default") |
| `-j, --json` | Output as JSON |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

## Examples

```bash
# Headless testing workflow
# Terminal 1: Start your Flutter app
flutter run -d chrome --web-browser-flag="--headless"

# Terminal 2: Connect and run commands
flutter_mate connect ws://127.0.0.1:12345/abc=/ws
flutter_mate snapshot -c
flutter_mate setText w10 "test@example.com"
flutter_mate setText w13 "password123"
flutter_mate tap w17
flutter_mate waitFor "Dashboard"
flutter_mate screenshot --path result.png
flutter_mate close

# Multiple sessions (for testing multiple apps simultaneously)
flutter_mate -s app1 connect ws://127.0.0.1:12345/abc=/ws
flutter_mate -s app2 connect ws://127.0.0.1:54321/xyz=/ws
flutter_mate -s app1 snapshot
flutter_mate -s app2 tap w5
flutter_mate session list
flutter_mate -s app1 close
flutter_mate -s app2 close
```

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
| `waitFor` | Wait for element to appear |
| `waitForDisappear` | Wait for element to disappear |
| `waitForValue` | Wait for element value to match pattern |

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

## Architecture

The CLI uses a daemon architecture for performance:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  flutter_mate   │────▶│     Daemon      │────▶│   Flutter App   │
│     CLI         │     │  (Unix socket)  │     │  (VM Service)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘

Session files: ~/.flutter_mate/
  - default.sock    # Unix socket for IPC
  - default.pid     # Daemon process ID
  - default.uri     # Connected VM Service URI
```

Benefits:
- **Fast commands** - No reconnection overhead per command
- **Session persistence** - Connection maintained across CLI invocations
- **Multiple sessions** - Run tests against multiple apps simultaneously
