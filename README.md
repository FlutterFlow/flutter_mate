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

// Get UI snapshot (collapsed tree with refs)
final snapshot = await FlutterMate.snapshot();
print(snapshot);
// 25 elements (from 111 nodes)
// • [w1] LoginPage → [w2] Scaffold
//   • [w6] Column
//     • [w9] Semantics "Email" [tap, focus, setText] (TextField)
//       • [w10] TextField

// Interact with elements by ref
await FlutterMate.tap('w10');  // auto: semantic or gesture
await FlutterMate.setText('w9', 'hello@example.com');  // semantic action
await FlutterMate.typeText('w10', 'hello@example.com'); // keyboard simulation
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
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
# Output:
# 25 elements (from 111 nodes)
# • [w1] LoginPage → [w2] Scaffold
#   • [w6] Column
#     • [w9] Semantics "Email" [tap, focus, setText] (TextField)
#       • [w10] TextField "Email"

flutter_mate --uri ws://127.0.0.1:12345/abc=/ws setText w9 "hello@example.com"  
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10

# 4. Interactive mode (REPL)
flutter_mate --uri ws://127.0.0.1:12345/abc=/ws attach
flutter_mate> snapshot
flutter_mate> setText w9 test@example.com
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
- "Fill the email field with <test@example.com>"
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
      url: https://github.com/FlutterFlow/flutter_mate
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

## Snapshot Format

The snapshot uses a **collapsed tree format** that makes complex UIs readable:

```
25 elements (from 111 nodes)

• [w1] LoginPage → [w2] Scaffold
  • [w6] Column
    • [w7] Text "Welcome Back"
    • [w9] Semantics "Email" [tap, focus, setText] (TextField)
      • [w10] TextField "Email"
    • [w17] Semantics "Login" [tap, focus] (Button)
      • [w18] ElevatedButton
        • [w19] Text "Login"
```

**Key features:**

- **Bounds-based collapsing**: Widgets with same bounds are chained with `→`
- **Layout wrapper hiding**: `Padding`, `Container`, `Expanded`, etc. are hidden
- **Text content extraction**: Shows actual text from `Text`, `Icon`, wrapper widgets
- **Semantic info inline**: Labels, actions, and flags shown on Semantics nodes
- **Ref preservation**: All refs remain valid for interaction

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
| `setText(ref, text)` | `SemanticsAction.setText` | Set text field |

**Best for**: Standard Flutter widgets with proper semantics labels.

### Tier 2: Gesture/Input Simulation (Low-Level)

Mimics actual user input by injecting pointer events and using platform APIs.

| Method | Simulation | Description |
|--------|------------|-------------|
| `tap(ref)` | Auto: semantic then gesture | Tap (smart fallback) |
| `longPress(ref)` | Auto: semantic then gesture | Long press (smart fallback) |
| `doubleTap(ref)` | Two quick tap sequences | Double tap (gesture only) |
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
| `snapshot({compact, depth, fromRef})` | Get UI tree with refs, labels, actions |
| `screenshot({ref})` | Capture screenshot (full screen or element) |
| `annotatedScreenshot()` | Screenshot with ref labels overlaid |
| `waitFor(pattern, {timeout})` | Wait for element matching pattern |

#### Snapshot Options

| Option | Description |
|--------|-------------|
| `compact: true` | Only show widgets with meaningful info |
| `depth: 3` | Limit tree depth (for large UIs) |
| `fromRef: "w15"` | Start tree from specific element as root |

### Actions (Automatic Tier Selection)

| Method | Description |
|--------|-------------|
| `tap(ref)` | Tap element (semantic → gesture fallback) |
| `longPress(ref)` | Long press (semantic → gesture) |
| `doubleTap(ref)` | Double tap element (gesture) |
| `setText(ref, text)` | Set text via semantic action |
| `scroll(ref, direction)` | Scroll (semantic → gesture) |
| `focus(ref)` | Focus element (semantic) |

### Gesture Simulation (Tier 2 Only)

| Method | Description |
|--------|-------------|
| `tapAt(Offset)` | Tap at screen position |
| `longPressAt(Offset)` | Long press at position |
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
| `fillByName(name, text)` | Fill by registered controller name |

---

## CLI Commands

```bash
flutter_mate --uri <ws://...> <command> [args]

Commands:
  snapshot              Get UI tree (collapsed format)
  snapshot -c           Compact mode: only widgets with info
  snapshot --depth 3    Limit tree depth
  snapshot --from w15   Start from specific element as root
  screenshot            Capture full screenshot (saves to file)
  screenshot <ref>      Capture element screenshot
  screenshot -a         Annotated screenshot with ref labels
  tap <ref>             Tap element (semantic → gesture fallback)
  doubleTap <ref>       Double tap element
  longPress <ref>       Long press element
  hover <ref>           Hover over element (trigger onHover)
  drag <from> <to>      Drag from one element to another
  setText <ref> <text>  Set text (semantic action)
  typeText <ref> <text> Type text (keyboard simulation)
  clear <ref>           Clear text field
  scroll <ref> [dir]    Scroll element (up/down/left/right)
  swipe <dir>           Swipe gesture from center
  focus <ref>           Focus element
  pressKey <key>        Press keyboard key (enter, tab, escape, etc.)
  keyDown <key>         Press key down (hold)
  keyUp <key>           Release key
  find <ref>            Get detailed element info
  getText <ref>         Get text content from element
  wait <ms>             Wait milliseconds
  extensions            List available service extensions
  attach                Interactive REPL mode

Options:
  --uri, -u             VM Service WebSocket URI (required)
  --json, -j            Output as JSON
  --compact, -c         Compact snapshot mode
  --help, -h            Show help
```

---

## MCP Tools Reference

When using the MCP server, the following tools are available:

| Tool | Description |
|------|-------------|
| `connect` | Connect to a Flutter app by VM Service URI |
| `snapshot` | Get UI tree with element refs (`compact`, `depth`, `fromRef` options) |
| `screenshot` | Capture screenshot (full screen or specific element) |
| `annotatedScreenshot` | Screenshot with ref labels overlaid for visual grounding |
| `find` | Get detailed element info by ref |
| `tap` | Tap element by ref |
| `doubleTap` | Double tap element |
| `longPress` | Long press element |
| `hover` | Hover over element (trigger onHover) |
| `drag` | Drag from one element to another |
| `setText` | Set text via semantic action |
| `typeText` | Type text via keyboard simulation |
| `clear` | Clear text field |
| `scroll` | Scroll element in a direction |
| `focus` | Focus element |
| `pressKey` | Press keyboard key |
| `keyDown` | Press key down (hold) |
| `keyUp` | Release key |
| `waitFor` | Wait for element matching pattern to appear |

---

## Example: In-App AI Agent

```dart
class LoginAgent {
  Future<void> login(String email, String password) async {
    // Get UI snapshot
    final snapshot = await FlutterMate.snapshot();
    
    // Find and fill fields by label (using Semantics widget refs)
    for (final node in snapshot.nodes) {
      if (node.label?.toLowerCase().contains('email') == true) {
        await FlutterMate.setText(node.ref, email);
      }
      if (node.label?.toLowerCase().contains('password') == true) {
        await FlutterMate.setText(node.ref, password);
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
        
        Reply with JSON: {"action": "tap|setText|scroll|done", "ref": "wX", "text": "..."}
      ''');
      
      final action = jsonDecode(response);
      if (action['action'] == 'done') break;
      
      switch (action['action']) {
        case 'tap': await FlutterMate.tap(action['ref']);
        case 'setText': await FlutterMate.setText(action['ref'], action['text']);
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
│  tap, setText│  │  Claude...)  │  │                  │
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

## Why Flutter Mate?

Flutter apps render to a canvas, making them opaque to standard platform accessibility and automation tools. While Flutter has a semantics tree, it often doesn't work well with external agents:

1. **Incomplete semantics** — Many widgets don't expose proper accessibility info
2. **Broken control** — Platform accessibility actions often don't trigger Flutter handlers
3. **Platform gaps** — Desktop platforms (macOS, Windows) have weaker accessibility bridges

Flutter Mate bypasses these issues by connecting directly to Flutter's internals via VM Service, giving AI agents reliable access to the widget tree and control mechanisms.

### Hybrid Agent Support

For maximum reliability, Flutter Mate supports both **structured** and **visual** approaches:

| Approach | Use Case |
|----------|----------|
| **Structured snapshot** | Precise interaction via refs, querying state, finding elements |
| **Screenshot** | Visual verification, understanding context, handling custom paint |
| **Annotated screenshot** | Visual grounding with ref labels for coordinate-free interaction |

```dart
// Structured: precise interaction
final snapshot = await FlutterMate.snapshot();
await FlutterMate.tap('w15');

// Visual: verification and context
final image = await FlutterMate.screenshot();
final annotated = await FlutterMate.annotatedScreenshot();
```

---

## Project Structure

```
flutter_mate/
├── packages/
│   ├── flutter_mate/               # Flutter SDK
│   │   └── lib/
│   │       ├── flutter_mate.dart   # Public API exports
│   │       └── src/
│   │           ├── core/           # Initialization & service extensions
│   │           ├── snapshot/       # UI tree capture
│   │           ├── actions/        # Semantic, gesture, keyboard actions
│   │           ├── protocol.dart   # Command schemas
│   │           └── actions.dart    # Action types
│   └── flutter_mate_types/         # Shared types (pure Dart, no Flutter)
│       └── lib/
│           └── src/snapshot.dart   # CombinedSnapshot, CombinedNode, etc.
├── apps/
│   └── demo_app/                   # Demo Flutter app
└── cli/
    └── flutter_mate_cli/           # CLI and MCP server
        ├── bin/
        │   ├── flutter_mate.dart   # CLI tool
        │   └── mcp_server.dart     # MCP server
        └── lib/
            ├── vm_service_client.dart
            ├── flutter_mate_mcp.dart
            └── snapshot_formatter.dart
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
- [x] Collapsed snapshot format (bounds-based, layout wrapper hiding)
- [x] Text content extraction for widgets
- [ ] Screenshot capture (full screen and element-level)
- [ ] Annotated screenshots (ref labels overlaid for visual grounding)
- [ ] Progressive snapshot options (depth limit, subtree from ref)
- [ ] Hybrid agent support (structured + visual)
- [ ] Record & replay
- [ ] Test generation from recordings
- [ ] Web platform JS injection (zero-code automation)

---

## License

MIT
