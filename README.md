# Flutter Mate 🤖

**Automation SDK for Flutter apps** — build in-app AI agents or control apps externally via VM Service.

Like [Vercel's agent-browser](https://github.com/vercel-labs/agent-browser) but for Flutter!

## Two Ways to Use

### 1. 📱 Dart SDK (In-App AI Agent)

For building AI agents that run **inside** your Flutter app:

```dart
import 'package:flutter_mate/flutter_mate.dart';

// Initialize once at startup
await FlutterMate.initialize();

// Get UI snapshot
final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
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

---

## API Reference

### Core

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize FlutterMate (call once at startup) |
| `dispose()` | Clean up resources |
| `snapshot({interactiveOnly})` | Get UI tree with refs, labels, actions |
| `waitFor(pattern, {timeout})` | Wait for element matching pattern |

### Semantics-Based Actions

| Method | Description |
|--------|-------------|
| `tap(ref)` | Tap element via semantics |
| `longPress(ref)` | Long press element |
| `fill(ref, text)` | Fill text field via semantics |
| `scroll(ref, direction)` | Scroll (up/down/left/right) |
| `focus(ref)` | Focus element |

### Gesture Simulation

| Method | Description |
|--------|-------------|
| `tapAt(Offset)` | Tap at screen position |
| `tapGesture(ref)` | Tap element center via gesture |
| `longPressAt(Offset, {duration})` | Long press at position |
| `drag({from, to, duration})` | Drag gesture |
| `scrollGesture(ref, delta)` | Scroll via gesture |

### Keyboard / Text Input

| Method | Description |
|--------|-------------|
| `typeText(text)` | Type into focused field (platform channel) |
| `clearText()` | Clear current field |
| `nextConnection()` | Track new text field focus |
| `pressKey(LogicalKeyboardKey)` | Press any key |
| `pressEnter/Tab/Escape/Backspace()` | Common keys |
| `pressArrowUp/Down/Left/Right()` | Arrow keys |
| `pressShortcut(key, {ctrl, shift, alt, cmd})` | Keyboard shortcuts |

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
  snapshot              Get UI tree (-i for interactive only)
  tap <ref>             Tap element
  fill <ref> <text>     Fill text field
  scroll <ref> [dir]    Scroll (up/down/left/right)
  focus <ref>           Focus element
  extensions            List available service extensions
  attach                Interactive REPL mode

Options:
  --uri, -u             VM Service WebSocket URI (required)
  --json, -j            Output as JSON
  --interactive, -i     Show only interactive elements
  --help, -h            Show help
```

---

## Example: In-App AI Agent

```dart
class LoginAgent {
  Future<void> login(String email, String password) async {
    // Get UI snapshot
    final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
    
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

## Example: Keyboard Simulation

```dart
// 1. Tap to focus field
FlutterMate.tapAt(emailFieldCenter);
await Future.delayed(Duration(milliseconds: 300));

// 2. Track the new text input connection
FlutterMate.nextConnection();

// 3. Type like a real keyboard (character by character)
await FlutterMate.typeText('test@example.com');

// 4. Press Tab to move to next field
await FlutterMate.pressTab();

// 5. Type password
FlutterMate.nextConnection();
await FlutterMate.typeText('password');

// 6. Press Enter to submit
await FlutterMate.pressEnter();
```

---

## Example: LLM Integration

```dart
class LLMAgent {
  final LLMClient llm;
  
  Future<void> executeGoal(String goal) async {
    while (true) {
      final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
      
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
│  │  • Gesture/keyboard simulation                       │    │
│  │  • Service extensions (ext.flutter_mate.*)           │    │
│  └─────────────────────────────────────────────────────┘    │
│                          ▲                                   │
│                          │ VM Service Protocol               │
│                          │ (WebSocket)                       │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   flutter_mate CLI                           │
│  • snapshot, tap, fill, scroll, focus                        │
│  • Interactive REPL mode                                     │
│  • JSON output for AI integration                            │
└─────────────────────────────────────────────────────────────┘
```

---

## How It Works

Flutter Mate leverages Flutter's **Semantics Tree** — the same tree used for accessibility. This tree contains:

- **Labels and values** for UI elements
- **Available actions** (tap, scroll, focus, setText)
- **Element types** (button, text field, link, etc.)
- **Position and bounds**

For keyboard simulation, we use Flutter's **platform channels** (`flutter/textinput`) to send text input exactly like a real keyboard would.

Service extensions (`ext.flutter_mate.*`) expose the SDK functionality via VM Service Protocol, enabling external control without modifying app code.

---

## Project Structure

```
flutter_mate/
├── packages/
│   └── flutter_mate/           # Dart SDK
│       ├── lib/
│       │   ├── flutter_mate.dart
│       │   └── src/
│       │       ├── flutter_mate.dart  # Main API
│       │       └── snapshot.dart      # Snapshot types
│       └── pubspec.yaml
├── apps/
│   └── demo_app/               # Demo Flutter app
└── cli/
    └── flutter_mate_cli/       # CLI tool (VM Service)
        ├── bin/
        │   └── flutter_mate.dart
        └── lib/
            └── vm_service_client.dart
```

---

## Roadmap

- [x] Dart SDK for in-app automation
- [x] Semantics-based actions (tap, fill, scroll)
- [x] Gesture simulation (tapAt, drag, scroll)
- [x] Keyboard/text input simulation
- [x] VM Service CLI for external control
- [x] Interactive REPL mode
- [ ] Screenshot capture
- [ ] Record & replay
- [ ] Test generation from recordings
- [ ] Web platform testing
- [ ] Visual element matching (fallback)

---

## License

MIT
