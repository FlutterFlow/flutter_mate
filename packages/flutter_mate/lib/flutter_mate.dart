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
/// await FlutterMate.fill('w5', 'hello@example.com');
/// await FlutterMate.tap('w10');
/// ```
///
/// ## AI Agent Integration
///
/// For AI agents, use the action system for structured command execution:
///
/// ```dart
/// // Get tool definitions for your LLM
/// final tools = MateAction.toolDefinitions;
///
/// // Execute actions from agent output
/// final result = await ActionExecutor.execute({
///   'action': 'tap',
///   'ref': 'w5',
/// });
/// ```
///
/// ## External Control via CLI
///
/// ```bash
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
/// ```
///
/// See the README for more examples and API documentation.
library flutter_mate;

export 'src/actions.dart' show MateAction, ActionExecutor, ActionResult;
export 'src/command_executor.dart' show CommandExecutor;
export 'src/combined_snapshot.dart'
    show CombinedSnapshot, CombinedNode, SemanticsInfo, CombinedRect;
export 'src/flutter_mate.dart' show FlutterMate, ScrollDirection;
export 'src/protocol.dart'
    show Command, CommandAction, CommandResponse, ParseResult;
export 'src/protocol.dart'
    show
        SnapshotCommand,
        TapCommand,
        TapAtCommand,
        DoubleTapCommand,
        LongPressCommand,
        FillCommand,
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
