/// Action definitions and executor for flutter_mate.
///
/// This module provides the translation layer between structured action commands
/// (from an AI agent, CLI, or MCP server) and the actual SDK execution.
///
/// ## Architecture
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │                     AGENT (LLM)                             │
/// │  Receives: snapshot, tool definitions                       │
/// │  Outputs: structured action JSON                            │
/// └─────────────────────────────────────────────────────────────┘
///                            │
///                            ▼
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   ACTION SCHEMA                             │
/// │  [MateAction.toolDefinitions] - for LLM function calling    │
/// └─────────────────────────────────────────────────────────────┘
///                            │
///                            ▼
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   STRUCTURED ACTION                         │
/// │  { "action": "tap", "ref": "w5" }                          │
/// │  { "action": "fill", "ref": "w10", "text": "hello" }       │
/// └─────────────────────────────────────────────────────────────┘
///                            │
///                            ▼
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   ACTION EXECUTOR                           │
/// │  [ActionExecutor.execute] - calls FlutterMate SDK           │
/// └─────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Usage
///
/// ```dart
/// // Get tool definitions for the LLM
/// final tools = MateAction.toolDefinitions;
///
/// // Execute an action from the agent
/// final result = await ActionExecutor.execute({
///   'action': 'tap',
///   'ref': 'w5',
/// });
/// ```
library;

import 'dart:convert';
import 'dart:ui' show Offset;

import 'flutter_mate.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ACTION TYPES
// ══════════════════════════════════════════════════════════════════════════════

/// All available automation actions.
enum MateActionType {
  /// Take a snapshot of the current UI state.
  snapshot,

  /// Tap on an element by ref.
  tap,

  /// Tap at specific coordinates.
  tapAt,

  /// Fill a text field with text.
  fill,

  /// Clear a text field.
  clear,

  /// Scroll an element in a direction.
  scroll,

  /// Focus on an element.
  focus,

  /// Type text character by character (simulates keyboard input).
  typeText,

  /// Press a keyboard key.
  pressKey,

  /// Wait for a specified duration.
  wait,
}

// ══════════════════════════════════════════════════════════════════════════════
// TOOL DEFINITIONS (for LLM function calling / MCP)
// ══════════════════════════════════════════════════════════════════════════════

/// Tool definitions that can be passed to an LLM for function calling.
///
/// These follow the OpenAI/Anthropic function calling format and can be used
/// directly with MCP (Model Context Protocol).
class MateAction {
  MateAction._();

  /// Get all tool definitions for LLM function calling.
  ///
  /// Returns a list of tool definitions in the standard format that can be
  /// passed to OpenAI, Anthropic, or MCP-compatible systems.
  ///
  /// ```dart
  /// final tools = MateAction.toolDefinitions;
  /// // Pass to your LLM API
  /// ```
  static List<Map<String, dynamic>> get toolDefinitions => [
        snapshotTool,
        tapTool,
        tapAtTool,
        fillTool,
        clearTool,
        scrollTool,
        focusTool,
        typeTextTool,
        pressKeyTool,
        waitTool,
      ];

  /// Snapshot tool - capture current UI state.
  static Map<String, dynamic> get snapshotTool => {
        'name': 'snapshot',
        'description': '''Capture the current UI state of the Flutter app.

Returns a structured representation of all visible elements with:
- ref: Unique identifier for interaction (e.g., "w5", "w10")
- widget: Widget type (e.g., "Text", "ElevatedButton", "TextField")
- bounds: Position and size {x, y, width, height}
- semantics: Accessibility info (label, value, actions, flags)

Use the ref to interact with elements via tap, fill, scroll, etc.

Example output:
```json
{
  "success": true,
  "nodes": [
    {"ref": "w5", "widget": "Text", "semantics": {"label": "Welcome"}},
    {"ref": "w10", "widget": "ElevatedButton", "semantics": {"label": "Sign In", "actions": ["tap"]}}
  ]
}
```''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'interactiveOnly': {
              'type': 'boolean',
              'description':
                  'If true, only return elements with actions (tappable, fillable, etc.). Default: true.',
            },
            'consolidate': {
              'type': 'boolean',
              'description':
                  'If true, skip wrapper widgets for cleaner output. Default: true.',
            },
          },
        },
      };

  /// Tap tool - tap on an element.
  static Map<String, dynamic> get tapTool => {
        'name': 'tap',
        'description': '''Tap on a UI element by its ref.

Performs a tap gesture on the element, triggering onTap handlers, button presses, etc.

Use snapshot first to get element refs.

Example: tap(ref: "w10") to tap the Sign In button.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description':
                  'The element ref from snapshot (e.g., "w5", "w10").',
            },
          },
          'required': ['ref'],
        },
      };

  /// TapAt tool - tap at coordinates.
  static Map<String, dynamic> get tapAtTool => {
        'name': 'tapAt',
        'description': '''Tap at specific screen coordinates.

Use when you need to tap at a specific position, e.g., for custom gestures
or elements without refs.

Coordinates are in logical pixels from top-left of screen.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'x': {
              'type': 'number',
              'description': 'X coordinate in logical pixels.',
            },
            'y': {
              'type': 'number',
              'description': 'Y coordinate in logical pixels.',
            },
          },
          'required': ['x', 'y'],
        },
      };

  /// Fill tool - fill a text field.
  static Map<String, dynamic> get fillTool => {
        'name': 'fill',
        'description': '''Fill a text field with the specified text.

Replaces any existing text in the field. The element must be a TextField
or similar text input widget.

Use snapshot to find text fields (look for semantics.actions containing "setText").

Example: fill(ref: "w15", text: "user@example.com")''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'The text field ref from snapshot.',
            },
            'text': {
              'type': 'string',
              'description': 'The text to enter.',
            },
          },
          'required': ['ref', 'text'],
        },
      };

  /// Clear tool - clear a text field.
  static Map<String, dynamic> get clearTool => {
        'name': 'clear',
        'description': '''Clear all text from a text field.

Removes all content from the specified text field.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'The text field ref from snapshot.',
            },
          },
          'required': ['ref'],
        },
      };

  /// Scroll tool - scroll a scrollable.
  static Map<String, dynamic> get scrollTool => {
        'name': 'scroll',
        'description': '''Scroll a scrollable element.

Scrolls the specified element (ListView, SingleChildScrollView, etc.)
in the given direction.

Use to reveal off-screen content before interacting with it.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'The scrollable element ref.',
            },
            'direction': {
              'type': 'string',
              'enum': ['up', 'down', 'left', 'right'],
              'description': 'Direction to scroll.',
            },
            'amount': {
              'type': 'number',
              'description':
                  'Distance to scroll in logical pixels. Default: 300.',
            },
          },
          'required': ['ref', 'direction'],
        },
      };

  /// Focus tool - focus on an element.
  static Map<String, dynamic> get focusTool => {
        'name': 'focus',
        'description': '''Focus on a form field or focusable element.

Gives keyboard focus to the element. Useful for text fields before typing.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'The element ref to focus.',
            },
          },
          'required': ['ref'],
        },
      };

  /// TypeText tool - type text character by character.
  static Map<String, dynamic> get typeTextTool => {
        'name': 'typeText',
        'description': '''Type text character by character.

Simulates keyboard input, typing each character sequentially.
Use after focusing on a text field.

This is more realistic than fill() as it triggers per-character callbacks.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'The text to type.',
            },
          },
          'required': ['text'],
        },
      };

  /// PressKey tool - press a keyboard key.
  static Map<String, dynamic> get pressKeyTool => {
        'name': 'pressKey',
        'description': '''Press a keyboard key.

Simulates pressing a keyboard key. Useful for:
- Navigation: "enter", "tab", "escape", "arrowUp", "arrowDown", "arrowLeft", "arrowRight"
- Editing: "backspace", "delete"
- Shortcuts: Use with modifiers for shortcuts

Common keys: enter, tab, escape, backspace, delete, 
arrowUp, arrowDown, arrowLeft, arrowRight''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'key': {
              'type': 'string',
              'description': 'The key to press (e.g., "enter", "tab", "escape").',
            },
          },
          'required': ['key'],
        },
      };

  /// Wait tool - pause execution.
  static Map<String, dynamic> get waitTool => {
        'name': 'wait',
        'description': '''Wait for a specified duration.

Pauses execution to allow animations, network requests, or state changes
to complete before the next action.

Use sparingly - prefer waiting for specific UI changes when possible.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'milliseconds': {
              'type': 'integer',
              'description': 'Duration to wait in milliseconds.',
            },
          },
          'required': ['milliseconds'],
        },
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTION RESULT
// ══════════════════════════════════════════════════════════════════════════════

/// Result of executing an action.
class ActionResult {
  /// Whether the action succeeded.
  final bool success;

  /// Error message if the action failed.
  final String? error;

  /// Result data (varies by action type).
  final dynamic data;

  /// Timestamp when the action completed.
  final DateTime timestamp;

  const ActionResult({
    required this.success,
    this.error,
    this.data,
    required this.timestamp,
  });

  /// Create a successful result.
  factory ActionResult.ok([dynamic data]) => ActionResult(
        success: true,
        data: data,
        timestamp: DateTime.now(),
      );

  /// Create a failed result.
  factory ActionResult.fail(String error) => ActionResult(
        success: false,
        error: error,
        timestamp: DateTime.now(),
      );

  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() => {
        'success': success,
        if (error != null) 'error': error,
        if (data != null) 'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTION EXECUTOR
// ══════════════════════════════════════════════════════════════════════════════

/// Executes actions from structured JSON commands.
///
/// This is the translation layer between agent-generated commands and the
/// FlutterMate SDK.
///
/// ```dart
/// // Execute a single action
/// final result = await ActionExecutor.execute({
///   'action': 'tap',
///   'ref': 'w5',
/// });
///
/// // Execute a sequence of actions
/// final results = await ActionExecutor.executeSequence([
///   {'action': 'fill', 'ref': 'w10', 'text': 'hello@example.com'},
///   {'action': 'fill', 'ref': 'w15', 'text': 'password123'},
///   {'action': 'tap', 'ref': 'w20'},
/// ]);
/// ```
class ActionExecutor {
  ActionExecutor._();

  /// Execute a single action from a JSON command.
  ///
  /// The command should have an 'action' field specifying the action type,
  /// plus any required parameters for that action.
  ///
  /// Returns an [ActionResult] indicating success/failure and any data.
  static Future<ActionResult> execute(Map<String, dynamic> command) async {
    final actionName = command['action'] as String?;
    if (actionName == null) {
      return ActionResult.fail('Missing required field: action');
    }

    try {
      switch (actionName) {
        case 'snapshot':
          return await _executeSnapshot(command);
        case 'tap':
          return await _executeTap(command);
        case 'tapAt':
          return await _executeTapAt(command);
        case 'fill':
          return await _executeFill(command);
        case 'clear':
          return await _executeClear(command);
        case 'scroll':
          return await _executeScroll(command);
        case 'focus':
          return await _executeFocus(command);
        case 'typeText':
          return await _executeTypeText(command);
        case 'pressKey':
          return await _executePressKey(command);
        case 'wait':
          return await _executeWait(command);
        default:
          return ActionResult.fail('Unknown action: $actionName');
      }
    } catch (e, stack) {
      return ActionResult.fail('Action failed: $e\n$stack');
    }
  }

  /// Execute a sequence of actions.
  ///
  /// Stops on first failure unless [continueOnError] is true.
  ///
  /// Returns a list of results, one per action.
  static Future<List<ActionResult>> executeSequence(
    List<Map<String, dynamic>> commands, {
    bool continueOnError = false,
  }) async {
    final results = <ActionResult>[];

    for (final command in commands) {
      final result = await execute(command);
      results.add(result);

      if (!result.success && !continueOnError) {
        break;
      }
    }

    return results;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Action Handlers
  // ──────────────────────────────────────────────────────────────────────────

  static Future<ActionResult> _executeSnapshot(
      Map<String, dynamic> command) async {
    final interactiveOnly = command['interactiveOnly'] as bool? ?? true;
    final consolidate = command['consolidate'] as bool? ?? true;

    final snapshot = await FlutterMate.snapshotCombined(
      consolidate: consolidate,
    );

    if (!snapshot.success) {
      return ActionResult.fail(snapshot.error ?? 'Snapshot failed');
    }

    // Filter to interactive only if requested
    var nodes = snapshot.nodes;
    if (interactiveOnly) {
      nodes = nodes.where((n) {
        final actions = n.semantics?.actions;
        return actions != null && actions.isNotEmpty;
      }).toList();
    }

    return ActionResult.ok({
      'nodeCount': nodes.length,
      'nodes': nodes.map((n) => n.toJson()).toList(),
    });
  }

  static Future<ActionResult> _executeTap(Map<String, dynamic> command) async {
    final ref = command['ref'] as String?;
    if (ref == null) {
      return ActionResult.fail('Missing required field: ref');
    }

    final success = await FlutterMate.tap(ref);
    if (success) {
      return ActionResult.ok();
    } else {
      return ActionResult.fail('Failed to tap element: $ref');
    }
  }

  static Future<ActionResult> _executeTapAt(
      Map<String, dynamic> command) async {
    final x = (command['x'] as num?)?.toDouble();
    final y = (command['y'] as num?)?.toDouble();

    if (x == null || y == null) {
      return ActionResult.fail('Missing required fields: x, y');
    }

    await FlutterMate.tapAt(Offset(x, y));
    return ActionResult.ok();
  }

  static Future<ActionResult> _executeFill(
      Map<String, dynamic> command) async {
    final ref = command['ref'] as String?;
    final text = command['text'] as String?;

    if (ref == null) {
      return ActionResult.fail('Missing required field: ref');
    }
    if (text == null) {
      return ActionResult.fail('Missing required field: text');
    }

    final success = await FlutterMate.fill(ref, text);
    if (success) {
      return ActionResult.ok();
    } else {
      return ActionResult.fail('Failed to fill element: $ref');
    }
  }

  static Future<ActionResult> _executeClear(
      Map<String, dynamic> command) async {
    // clearText() clears the currently focused text field
    // First focus the element if ref is provided
    final ref = command['ref'] as String?;
    if (ref != null) {
      final focused = await FlutterMate.focus(ref);
      if (!focused) {
        return ActionResult.fail('Failed to focus element: $ref');
      }
    }

    final success = await FlutterMate.clearText();
    if (success) {
      return ActionResult.ok();
    } else {
      return ActionResult.fail('Failed to clear text field');
    }
  }

  static Future<ActionResult> _executeScroll(
      Map<String, dynamic> command) async {
    final ref = command['ref'] as String?;
    final directionStr = command['direction'] as String?;
    // Note: amount parameter is accepted but not used by current SDK
    // final amount = (command['amount'] as num?)?.toDouble() ?? 300.0;

    if (ref == null) {
      return ActionResult.fail('Missing required field: ref');
    }
    if (directionStr == null) {
      return ActionResult.fail('Missing required field: direction');
    }

    final direction = switch (directionStr.toLowerCase()) {
      'up' => ScrollDirection.up,
      'down' => ScrollDirection.down,
      'left' => ScrollDirection.left,
      'right' => ScrollDirection.right,
      _ => null,
    };

    if (direction == null) {
      return ActionResult.fail(
          'Invalid direction: $directionStr. Must be up, down, left, or right.');
    }

    final success = await FlutterMate.scroll(ref, direction);
    if (success) {
      return ActionResult.ok();
    } else {
      return ActionResult.fail('Failed to scroll element: $ref');
    }
  }

  static Future<ActionResult> _executeFocus(
      Map<String, dynamic> command) async {
    final ref = command['ref'] as String?;
    if (ref == null) {
      return ActionResult.fail('Missing required field: ref');
    }

    final success = await FlutterMate.focus(ref);
    if (success) {
      return ActionResult.ok();
    } else {
      return ActionResult.fail('Failed to focus element: $ref');
    }
  }

  static Future<ActionResult> _executeTypeText(
      Map<String, dynamic> command) async {
    final text = command['text'] as String?;
    if (text == null) {
      return ActionResult.fail('Missing required field: text');
    }

    await FlutterMate.typeText(text);
    return ActionResult.ok();
  }

  static Future<ActionResult> _executePressKey(
      Map<String, dynamic> command) async {
    final key = command['key'] as String?;
    if (key == null) {
      return ActionResult.fail('Missing required field: key');
    }

    // Map common key names to SDK methods
    switch (key.toLowerCase()) {
      case 'enter':
        await FlutterMate.pressEnter();
      case 'tab':
        await FlutterMate.pressTab();
      case 'escape':
        await FlutterMate.pressEscape();
      case 'backspace':
        await FlutterMate.pressBackspace();
      case 'arrowup':
        await FlutterMate.pressArrowUp();
      case 'arrowdown':
        await FlutterMate.pressArrowDown();
      case 'arrowleft':
        await FlutterMate.pressArrowLeft();
      case 'arrowright':
        await FlutterMate.pressArrowRight();
      default:
        return ActionResult.fail('Unknown key: $key');
    }

    return ActionResult.ok();
  }

  static Future<ActionResult> _executeWait(
      Map<String, dynamic> command) async {
    final ms = command['milliseconds'] as int?;
    if (ms == null) {
      return ActionResult.fail('Missing required field: milliseconds');
    }

    await Future.delayed(Duration(milliseconds: ms));
    return ActionResult.ok();
  }
}
