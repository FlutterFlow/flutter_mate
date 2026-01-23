/// Flutter Mate — Automation SDK for Flutter apps
///
/// Build in-app AI agents or control apps externally via VM Service.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_mate/flutter_mate.dart';
///
/// // Initialize at app startup
/// await FlutterMate.initialize();
///
/// // Get UI snapshot (widget tree + semantics)
/// final snapshot = await FlutterMate.snapshot();
/// print(snapshot);
///
/// // Interact with elements using refs
/// await FlutterMate.setText('w9', 'hello@example.com');
/// await FlutterMate.tap('w10');
/// ```
///
/// ## Available Actions
///
/// **Touch:**
/// - [FlutterMate.tap] - Tap element (semantic → gesture fallback)
/// - [FlutterMate.doubleTap] - Double tap element
/// - [FlutterMate.longPress] - Long press element
/// - [FlutterMate.hover] - Hover over element (trigger onHover)
/// - [FlutterMate.drag] - Drag gesture between points
/// - [FlutterMate.dragFromTo] - Drag from one element to another
///
/// **Text Input:**
/// - [FlutterMate.setText] - Set text via semantic action
/// - [FlutterMate.typeText] - Type text via keyboard simulation
/// - [FlutterMate.clearText] - Clear focused text field
///
/// **Keyboard:**
/// - [FlutterMate.pressKey] - Press a key (down + up)
/// - [FlutterMate.keyDown] / [FlutterMate.keyUp] - Fine-grained control
/// - [FlutterMate.pressEnter], [FlutterMate.pressTab], etc.
///
/// **Navigation:**
/// - [FlutterMate.scroll] - Scroll element
/// - [FlutterMate.focus] - Focus element
/// - [FlutterMate.waitFor] - Wait for element to appear
///
/// ## External Control via CLI
///
/// ```bash
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws -c snapshot  # compact mode
/// ```
///
/// See the README for more examples and API documentation.
library flutter_mate;

// Facade (main public API)
export 'src/flutter_mate.dart' show FlutterMate;
export 'src/core/service_extensions.dart' show ScrollDirection;

// Snapshot
export 'src/snapshot/combined_snapshot.dart'
    show CombinedSnapshot, CombinedNode, SemanticsInfo, CombinedRect;
export 'src/snapshot/snapshot.dart' show SnapshotService;
export 'src/snapshot/screenshot.dart' show ScreenshotService;

// Actions (also accessible via FlutterMate facade)
export 'src/actions/semantic_actions.dart'
    show
        SemanticActions,
        tapByLabel,
        fillByLabel,
        longPressByLabel,
        focusByLabel;
export 'src/actions/gesture_actions.dart' show GestureActions, doubleTapByLabel;
export 'src/actions/keyboard_actions.dart' show KeyboardActions;
export 'src/actions/helpers.dart'
    show findByLabel, findAllByLabel, waitFor, findSemanticsNode;
export 'src/core/semantics_utils.dart'
    show
        getActionsFromData,
        getFlagsFromData,
        getRootSemanticsNode,
        searchSemanticsNodeById;

// Protocol and tools
export 'src/actions.dart' show MateAction, ActionExecutor, ActionResult;
export 'src/command_executor.dart' show CommandExecutor;
export 'src/protocol.dart'
    show Command, CommandAction, CommandResponse, ParseResult;
export 'src/protocol.dart'
    show
        SnapshotCommand,
        TapCommand,
        TapAtCommand,
        DoubleTapCommand,
        LongPressCommand,
        SetTextCommand,
        TypeTextCommand,
        ClearCommand,
        ScrollCommand,
        SwipeCommand,
        FocusCommand,
        PressKeyCommand,
        ToggleCommand,
        SelectCommand,
        WaitCommand,
        BackCommand,
        NavigateCommand,
        GetTextCommand,
        IsVisibleCommand,
        ScreenshotCommand;
