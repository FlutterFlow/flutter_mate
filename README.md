# Flutter Mate 🤖

**Automation SDK for Flutter apps** — build in-app AI agents or control apps externally via VM Service.

Like [Vercel's agent-browser](https://github.com/vercel-labs/agent-browser) but for Flutter!

## Three Ways to Use

### 1. 📱 Dart SDK (In-App AI Agent)

For building AI agents that run **inside** your Flutter app:

```dart
import 'package:flutter_mate/flutter_mate.dart';

// Initialize once at startup
await FlutterMate.initialize();

// Get UI snapshot (widget tree + semantics)
final snapshot = await FlutterMate.snapshot();
print(snapshot);  // Pretty-printed UI tree with refs

// Interact with elements by ref
await FlutterMate.fill('w5', 'hello@example.com');
await FlutterMate.tap('w10');
await FlutterMate.scroll('w15', ScrollDirection.down);

// Wait for element to appear
final ref = await FlutterMate.waitFor('Submit');
if (ref != null) await FlutterMate.tap(ref);
```

### 2. 🖥️ CLI via VM Service (External Control)

Control **any Flutter debug app** from the command line:

```bash
# 1. Run your Flutter app
flutter run

# 2. Copy the VM Service URI from console:
#    A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/

# 3. Use the CLI (convert http:// to ws:// and add /ws)
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -i
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws fill w5 "hello@example.com"  
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10

# 4. Interactive mode (REPL)
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws attach
flutter_mate> snapshot
flutter_mate> fill w5 test@example.com
flutter_mate> tap w10
```

### 3. 🤖 MCP Server (AI Agent Integration)

Integrate with **Cursor**, **Claude**, or any MCP-compatible client for AI-powered automation:

```json
// ~/.cursor/mcp.json
{
  "mcpServers": {
    "flutter_mate": {
      "command": "dart",
      "args": ["run", "/path/to/flutter_mate/cli/flutter_mate_cli/bin/mcp_server.dart"],
      "env": {
        "FLUTTER_MATE_URI": "ws://127.0.0.1:12345/abc=/ws"
      }
    }
  }
}
```

Once configured, ask Cursor/Claude to:
- "Take a snapshot of the Flutter app"
- "Fill the email field with test@example.com"
- "Tap the Submit button"
- "Scroll down and find the settings option"

---

## Installation

### Dart SDK (In-App)

```yaml
# pubspec.yaml
dependencies:
  flutter_mate:
    git:
      url: https://github.com/user/flutter_mate
      path: packages/flutter_mate
```

```dart
// main.dart
import 'package:flutter_mate/flutter_mate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMate.initialize();
  runApp(MyApp());
}
```

### CLI (External Control)

```bash
cd cli/flutter_mate_cli
dart pub get

# Run directly
dart run bin/flutter_mate.dart --help

# Or install globally
dart pub global activate --source path .
flutter_mate --help
```

### MCP Server (AI Integration)

```bash
cd cli/flutter_mate_cli
dart pub get

# Test the MCP server
dart run bin/mcp_server.dart --uri=ws://127.0.0.1:12345/abc=/ws
```

---

## Two-Tier Action System

Flutter Mate uses a two-tier approach for maximum compatibility:

### Tier 1: Semantic Actions (High-Level)

Uses Flutter's accessibility system via `SemanticsOwner.performAction()`.

| Method | Semantic Action | Description |
|--------|-----------------|-------------|
| `tap(ref)` | `SemanticsAction.tap` | Tap element |
| `focus(ref)` | `SemanticsAction.focus` | Focus element |
| `scroll(ref, dir)` | `SemanticsAction.scrollUp/Down` | Scroll container |
| `fill(ref, text)` | Focus + typeText | Fill text field |

**Best for**: Standard Flutter widgets with proper semantics labels.

### Tier 2: Gesture/Input Simulation (Low-Level)

Mimics actual user input by injecting pointer events and using platform APIs.

| Method | Simulation | Description |
|--------|------------|-------------|
| `tapGesture(ref)` | `PointerDown` → `PointerUp` | Tap via gesture |
| `longPressGesture(ref)` | `PointerDown` → delay → `PointerUp` | Long press |
| `doubleTap(ref)` | Two quick tap sequences | Double tap |
| `drag(from, to)` | `PointerDown` → `Move` → `Up` | Drag gesture |
| `typeText(text)` | `updateEditingValue()` | Type like real keyboard |
| `pressKey(key)` | `KeyDownEvent` + `KeyUpEvent` | Keyboard input |

**Best for**: Custom widgets, GestureDetector callbacks, input formatters.

### Fallback Strategy

Most actions try Tier 1 first, then fall back to Tier 2:

| Action | Primary (Tier 1) | Fallback (Tier 2) |
|--------|------------------|-------------------|
| `tap` | Semantic action | Gesture injection |
| `longPress` | — | Gesture only (more reliable) |
| `doubleTap` | — | Gesture only |
| `scroll` | Semantic action | Gesture injection |
| `typeText` | — | `updateEditingValue()` |

---

## API Reference

### Core

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize FlutterMate (call once at startup) |
| `dispose()` | Clean up resources |
| `snapshot()` | Get UI tree with refs, labels, actions |
| `waitFor(pattern, {timeout})` | Wait for element matching pattern |

### Actions (Automatic Tier Selection)

| Method | Description |
|--------|-------------|
| `tap(ref)` | Tap element (semantic → gesture fallback) |
| `longPress(ref)` | Long press element (gesture) |
| `doubleTap(ref)` | Double tap element (gesture) |
| `fill(ref, text)` | Focus + type into text field |
| `scroll(ref, direction)` | Scroll (semantic → gesture fallback) |
| `focus(ref)` | Focus element (semantic) |

### Gesture Simulation (Tier 2 Only)

| Method | Description |
|--------|-------------|
| `tapAt(Offset)` | Tap at screen position |
| `tapGesture(ref)` | Tap element center via gesture |
| `longPressGesture(ref)` | Long press via gesture |
| `drag({from, to, duration})` | Drag gesture |
| `scrollGestureByDirection(ref, dir)` | Scroll via gesture |

### Text Input

| Method | Description |
|--------|-------------|
| `typeText(text)` | Type into focused field (uses `updateEditingValue`) |
| `clearText()` | Clear focused field |
| `pressKey(LogicalKeyboardKey)` | Press any key |
| `pressEnter/Tab/Escape/Backspace()` | Common keys |
| `pressArrowUp/Down/Left/Right()` | Arrow keys |

### Registered Controllers (Convenience)

| Method | Description |
|--------|-------------|
| `registerTextField(name, controller)` | Register controller by name |
| `unregisterTextField(name)` | Unregister |
| `fillByName(name, text)` | Fill by registered name |

---

## CLI Commands

```bash
flutter_mate --uri <ws://...> <command> [args]

Commands:
  snapshot              Get UI tree (-i for interactive only, -m combined for widget tree)
  tap <ref>             Tap element (semantic → gesture fallback)
  doubleTap <ref>       Double tap element (gesture)
  longPress <ref>       Long press element (gesture)
  fill <ref> <text>     Focus + type into text field
  clear <ref>           Clear text field
  typeText <text>       Type text (uses updateEditingValue)
  pressKey <key>        Press keyboard key (enter, tab, escape, etc.)
  scroll <ref> [dir]    Scroll (semantic → gesture fallback)
  focus <ref>           Focus element (semantic)
  wait <ms>             Wait milliseconds
  extensions            List available service extensions
  attach                Interactive REPL mode

Options:
  --uri, -u             VM Service WebSocket URI (required)
  --json, -j            Output as JSON
  --help, -h            Show help
```

---

## MCP Tools Reference

When using the MCP server, the following tools are available:

| Tool | Description |
|------|-------------|
| `connect` | Connect to a Flutter app by VM Service URI |
| `snapshot` | Get UI tree with element refs |
| `tap` | Tap element by ref |
| `doubleTap` | Double tap element |
| `longPress` | Long press element |
| `fill` | Fill text field |
| `clear` | Clear text field |
| `typeText` | Type text character by character |
| `pressKey` | Press keyboard key |
| `scroll` | Scroll element |
| `focus` | Focus element |
| `wait` | Wait for duration |

---

## Example: In-App AI Agent

```dart
class LoginAgent {
  Future<void> login(String email, String password) async {
    // Get UI snapshot
    final snapshot = await FlutterMate.snapshot();
    
    // Find and fill fields by label
    for (final node in snapshot.nodes) {
      if (node.label?.toLowerCase().contains('email') == true) {
        await FlutterMate.fill(node.ref, email);
      }
      if (node.label?.toLowerCase().contains('password') == true) {
        await FlutterMate.fill(node.ref, password);
      }
    }
    
    // Find and tap login button
    final loginRef = await FlutterMate.waitFor('Login');
    if (loginRef != null) {
      await FlutterMate.tap(loginRef);
    }
  }
}
```

---

## Example: Text Input Simulation

```dart
// 1. Focus the email field
await FlutterMate.focus('w5');

// 2. Type like a real keyboard (uses updateEditingValue internally)
await FlutterMate.typeText('test@example.com');

// 3. Press Tab to move to next field
await FlutterMate.pressTab();

// 4. Type password (automatically uses newly focused field)
await FlutterMate.typeText('password123');

// 5. Press Enter to submit
await FlutterMate.pressEnter();
```

This triggers input formatters and `onChanged` callbacks correctly because
`typeText` uses `EditableTextState.updateEditingValue()` — the same method
called when the platform sends keyboard input.

---

## Example: LLM Integration

```dart
class LLMAgent {
  final LLMClient llm;
  
  Future<void> executeGoal(String goal) async {
    while (true) {
      final snapshot = await FlutterMate.snapshot();
      
      final response = await llm.complete('''
        Goal: $goal
        
        Current UI:
        ${jsonEncode(snapshot.toJson())}
        
        Reply with JSON: {"action": "tap|fill|scroll|done", "ref": "wX", "text": "..."}
      ''');
      
      final action = jsonDecode(response);
      if (action['action'] == 'done') break;
      
      switch (action['action']) {
        case 'tap': await FlutterMate.tap(action['ref']);
        case 'fill': await FlutterMate.fill(action['ref'], action['text']);
        case 'scroll': await FlutterMate.scroll(action['ref'], ScrollDirection.down);
      }
      
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (debug mode)                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  FlutterMate SDK                                     │    │
│  │  • Semantics tree access                             │    │
│  │  • Widget tree introspection                         │    │
│  │  • Gesture/keyboard simulation                       │    │
│  │  • Service extensions (ext.flutter_mate.*)           │    │
│  └─────────────────────────────────────────────────────┘    │
│                          ▲                                   │
│                          │ VM Service Protocol               │
│                          │ (WebSocket)                       │
└──────────────────────────┼──────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────┐
│  CLI Tool    │  │  MCP Server  │  │  Custom Client   │
│  snapshot    │  │  (Cursor,    │  │  (Your Code)     │
│  tap, fill   │  │  Claude...)  │  │                  │
└──────────────┘  └──────────────┘  └──────────────────┘
```

---

## How It Works

### Tier 1: Semantics Tree

Flutter Mate leverages Flutter's **Semantics Tree** — the same tree used for accessibility. This tree contains:

- **Labels and values** for UI elements
- **Available actions** (tap, scroll, focus, setText)
- **Element types** (button, text field, link, etc.)
- **Position and bounds**

Actions like `tap()` and `scroll()` use `SemanticsOwner.performAction()` to trigger the same behavior as screen readers.

### Tier 2: Gesture/Input Simulation

When semantic actions aren't available or don't trigger the right callbacks, Flutter Mate falls back to low-level simulation:

- **Pointer Events**: Inject `PointerDownEvent`, `PointerMoveEvent`, `PointerUpEvent` via `GestureBinding.handlePointerEvent()`
- **Text Input**: Call `EditableTextState.updateEditingValue()` — the exact method the platform calls for keyboard input
- **Key Events**: Dispatch `KeyDownEvent`/`KeyUpEvent` via `HardwareKeyboard`

This ensures input formatters, `onChanged` callbacks, and `GestureDetector` handlers all work correctly.

### Service Extensions

Service extensions (`ext.flutter_mate.*`) expose the SDK functionality via VM Service Protocol, enabling external control from CLI or MCP without modifying app code.

---

## Project Structure

```
flutter_mate/
├── packages/
│   └── flutter_mate/               # Dart SDK
│       ├── lib/
│       │   ├── flutter_mate.dart
│       │   └── src/
│       │       ├── flutter_mate.dart     # Main API & service extensions
│       │       ├── combined_snapshot.dart # Snapshot data structures
│       │       ├── protocol.dart         # Command definitions
│       │       ├── command_executor.dart # Execute commands
│       │       └── actions.dart          # Action types
│       └── pubspec.yaml
├── apps/
│   └── demo_app/                   # Demo Flutter app
└── cli/
    └── flutter_mate_cli/           # CLI and MCP server
        ├── bin/
        │   ├── flutter_mate.dart   # CLI tool
        │   └── mcp_server.dart     # MCP server
        └── lib/
            ├── vm_service_client.dart
            └── flutter_mate_mcp.dart
```

---

## Roadmap

- [x] Dart SDK for in-app automation
- [x] Two-tier action system (semantic + gesture fallback)
- [x] Realistic text input via `updateEditingValue()`
- [x] Keyboard simulation (press any key, shortcuts)
- [x] VM Service CLI for external control
- [x] Interactive REPL mode
- [x] Combined widget tree + semantics snapshot
- [x] MCP Server for AI agent integration
- [ ] Screenshot capture
- [ ] Record & replay
- [ ] Test generation from recordings
- [ ] Web platform JS injection (zero-code automation)
- [ ] Visual element matching (fallback)

---

## License

MIT
