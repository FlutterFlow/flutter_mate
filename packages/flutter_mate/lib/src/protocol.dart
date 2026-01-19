/// Flutter Mate Protocol - Command schemas for automation
///
/// Inspired by [agent-browser](https://github.com/vercel-labs/agent-browser)
/// protocol, adapted for Flutter's widget and semantics system.
///
/// ## Architecture
///
/// ```
/// ┌──────────────────────────────────────────────────────────────────┐
/// │                         AI AGENT (LLM)                           │
/// │  Receives: snapshot with refs, tool definitions                  │
/// │  Outputs: Command JSON matching this protocol                    │
/// └──────────────────────────────────────────────────────────────────┘
///                                │
///                                ▼
/// ┌──────────────────────────────────────────────────────────────────┐
///   Protocol (this file)                                            │
/// │  • Command schemas (tap, fill, scroll, etc.)                    │
/// │  • Response format (success/error)                              │
/// │  • Ref system (w0, w1, w2...)                                   │
/// └──────────────────────────────────────────────────────────────────┘
///                                │
///                                ▼
/// ┌──────────────────────────────────────────────────────────────────┐
/// │                     CommandExecutor                              │
/// │  Parses JSON → Validates → Executes via FlutterMate SDK        │
/// └──────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Ref System
///
/// Elements are identified by refs assigned during snapshot:
/// - `w0`, `w1`, `w2`... for widget tree nodes
/// - Refs are stable until the next snapshot
/// - Use `snapshot` to get current refs before interacting
///
/// ## Usage
///
/// ```dart
/// // Parse and validate a command
/// final result = Command.parse('{"action": "tap", "ref": "w5"}');
/// if (result.isValid) {
///   final response = await executor.execute(result.command!);
/// }
///
/// // Get tool definitions for LLM
/// final tools = Command.toolDefinitions;
/// ```
library;

import 'dart:convert';

// ══════════════════════════════════════════════════════════════════════════════
// COMMAND TYPES
// ══════════════════════════════════════════════════════════════════════════════

/// All available command actions.
enum CommandAction {
  // ─────────────────────────────────────────────────────────────────────────
  // Connection
  // ─────────────────────────────────────────────────────────────────────────
  /// Attach to a running Flutter app via VM Service URI.
  attach,

  /// Disconnect from the Flutter app.
  disconnect,

  // ─────────────────────────────────────────────────────────────────────────
  // Inspection
  // ─────────────────────────────────────────────────────────────────────────
  /// Get UI snapshot with element refs.
  snapshot,

  /// Take a screenshot of the current screen.
  screenshot,

  /// Get text content of an element.
  getText,

  /// Check if an element is visible.
  isVisible,

  /// Check if an element is enabled.
  isEnabled,

  // ─────────────────────────────────────────────────────────────────────────
  // Interaction - Touch
  // ─────────────────────────────────────────────────────────────────────────
  /// Tap on an element.
  tap,

  /// Tap at specific coordinates.
  tapAt,

  /// Double tap on an element.
  doubleTap,

  /// Long press on an element.
  longPress,

  /// Drag from one element/position to another.
  drag,

  /// Swipe in a direction.
  swipe,

  /// Scroll a scrollable element.
  scroll,

  // ─────────────────────────────────────────────────────────────────────────
  // Interaction - Text Input
  // ─────────────────────────────────────────────────────────────────────────
  /// Fill a text field (replaces content).
  fill,

  /// Type text character by character.
  typeText,

  /// Clear a text field.
  clear,

  // ─────────────────────────────────────────────────────────────────────────
  // Interaction - Keyboard
  // ─────────────────────────────────────────────────────────────────────────
  /// Press a keyboard key.
  pressKey,

  // ─────────────────────────────────────────────────────────────────────────
  // Interaction - Form Controls
  // ─────────────────────────────────────────────────────────────────────────
  /// Focus on an element.
  focus,

  /// Toggle a switch or checkbox.
  toggle,

  /// Select an option from a dropdown.
  select,

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────
  /// Navigate to a named route.
  navigate,

  /// Go back (pop navigation).
  back,

  // ─────────────────────────────────────────────────────────────────────────
  // Utility
  // ─────────────────────────────────────────────────────────────────────────
  /// Wait for a condition or duration.
  wait,
}

// ══════════════════════════════════════════════════════════════════════════════
// COMMAND SCHEMAS
// ══════════════════════════════════════════════════════════════════════════════

/// Base command that all commands extend.
abstract class Command {
  /// Unique identifier for this command (for request/response correlation).
  final String? id;

  /// The action to perform.
  CommandAction get action;

  const Command({this.id});

  /// Convert to JSON map.
  Map<String, dynamic> toJson();

  /// Parse a JSON string or map into a Command.
  static ParseResult parse(dynamic input) {
    try {
      Map<String, dynamic> json;
      if (input is String) {
        json = jsonDecode(input) as Map<String, dynamic>;
      } else if (input is Map<String, dynamic>) {
        json = input;
      } else {
        return ParseResult.error('Invalid input type: ${input.runtimeType}');
      }

      final id = json['id'] as String?;
      final actionStr = json['action'] as String?;

      if (actionStr == null) {
        return ParseResult.error('Missing required field: action', id: id);
      }

      // Parse action
      final action = CommandAction.values.asNameByValue(actionStr);
      if (action == null) {
        return ParseResult.error('Unknown action: $actionStr', id: id);
      }

      // Delegate to specific command parser
      return _parseCommand(action, json, id);
    } catch (e) {
      return ParseResult.error('Parse error: $e');
    }
  }

  /// Get tool definitions for LLM function calling.
  static List<Map<String, dynamic>> get toolDefinitions => [
        SnapshotCommand.toolDefinition,
        TapCommand.toolDefinition,
        TapAtCommand.toolDefinition,
        DoubleTapCommand.toolDefinition,
        LongPressCommand.toolDefinition,
        FillCommand.toolDefinition,
        TypeTextCommand.toolDefinition,
        ClearCommand.toolDefinition,
        ScrollCommand.toolDefinition,
        SwipeCommand.toolDefinition,
        FocusCommand.toolDefinition,
        PressKeyCommand.toolDefinition,
        ToggleCommand.toolDefinition,
        SelectCommand.toolDefinition,
        WaitCommand.toolDefinition,
        BackCommand.toolDefinition,
        NavigateCommand.toolDefinition,
        GetTextCommand.toolDefinition,
        IsVisibleCommand.toolDefinition,
        ScreenshotCommand.toolDefinition,
      ];
}

// ══════════════════════════════════════════════════════════════════════════════
// INDIVIDUAL COMMAND TYPES
// ══════════════════════════════════════════════════════════════════════════════

/// Snapshot command - capture UI state.
class SnapshotCommand extends Command {
  @override
  CommandAction get action => CommandAction.snapshot;

  /// Maximum depth of tree to return (optional).
  final int? maxDepth;

  /// Scope snapshot to elements under this ref (optional).
  final String? selector;

  const SnapshotCommand({
    super.id,
    this.maxDepth,
    this.selector,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'snapshot',
        if (maxDepth != null) 'maxDepth': maxDepth,
        if (selector != null) 'selector': selector,
      };

  static SnapshotCommand fromJson(Map<String, dynamic> json, String? id) =>
      SnapshotCommand(
        id: id,
        maxDepth: json['maxDepth'] as int?,
        selector: json['selector'] as String?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'snapshot',
        'description': '''Capture the current UI state of the Flutter app.

Returns a tree of user widgets with refs (w0, w1, w2...) that can be used
for subsequent interactions. Each element includes:
- ref: Stable identifier for this snapshot session
- widget: Widget type name  
- textContent: Text content for Text/Icon widgets
- bounds: Position {x, y, width, height}
- semantics: Label, value, actions, flags (on Semantics widgets)''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'maxDepth': {
              'type': 'integer',
              'description': 'Maximum tree depth to return (optional).',
            },
            'selector': {
              'type': 'string',
              'description': 'Scope to subtree under this ref (optional).',
            },
          },
        },
      };
}

/// Tap command - tap on an element.
class TapCommand extends Command {
  @override
  CommandAction get action => CommandAction.tap;

  /// Element ref to tap.
  final String ref;

  const TapCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'tap',
        'ref': ref,
      };

  static TapCommand fromJson(Map<String, dynamic> json, String? id) =>
      TapCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'tap',
        'description':
            'Tap on an element by ref. Use snapshot first to get refs.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'Element ref from snapshot (e.g., "w5").',
            },
          },
          'required': ['ref'],
        },
      };
}

/// TapAt command - tap at coordinates.
class TapAtCommand extends Command {
  @override
  CommandAction get action => CommandAction.tapAt;

  final double x;
  final double y;

  const TapAtCommand({super.id, required this.x, required this.y});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'tapAt',
        'x': x,
        'y': y,
      };

  static TapAtCommand fromJson(Map<String, dynamic> json, String? id) =>
      TapAtCommand(
        id: id,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'tapAt',
        'description':
            'Tap at specific screen coordinates (logical pixels from top-left).',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number', 'description': 'X coordinate.'},
            'y': {'type': 'number', 'description': 'Y coordinate.'},
          },
          'required': ['x', 'y'],
        },
      };
}

/// DoubleTap command.
class DoubleTapCommand extends Command {
  @override
  CommandAction get action => CommandAction.doubleTap;

  final String ref;

  const DoubleTapCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'doubleTap',
        'ref': ref,
      };

  static DoubleTapCommand fromJson(Map<String, dynamic> json, String? id) =>
      DoubleTapCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'doubleTap',
        'description': 'Double tap on an element.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
          },
          'required': ['ref'],
        },
      };
}

/// LongPress command.
class LongPressCommand extends Command {
  @override
  CommandAction get action => CommandAction.longPress;

  final String ref;
  final int? durationMs;

  const LongPressCommand({super.id, required this.ref, this.durationMs});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'longPress',
        'ref': ref,
        if (durationMs != null) 'durationMs': durationMs,
      };

  static LongPressCommand fromJson(Map<String, dynamic> json, String? id) =>
      LongPressCommand(
        id: id,
        ref: json['ref'] as String,
        durationMs: json['durationMs'] as int?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'longPress',
        'description': 'Long press on an element.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
            'durationMs': {
              'type': 'integer',
              'description': 'Press duration in milliseconds. Default: 500.',
            },
          },
          'required': ['ref'],
        },
      };
}

/// Fill command - fill a text field.
class FillCommand extends Command {
  @override
  CommandAction get action => CommandAction.fill;

  final String ref;
  final String text;

  const FillCommand({super.id, required this.ref, required this.text});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'fill',
        'ref': ref,
        'text': text,
      };

  static FillCommand fromJson(Map<String, dynamic> json, String? id) =>
      FillCommand(
        id: id,
        ref: json['ref'] as String,
        text: json['text'] as String,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'fill',
        'description':
            'Fill a text field with text. Replaces existing content.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Text field ref.'},
            'text': {'type': 'string', 'description': 'Text to enter.'},
          },
          'required': ['ref', 'text'],
        },
      };
}

/// TypeText command - type text into a widget using keyboard simulation.
///
/// Unlike `fill` which uses semantic setText, this uses platform message
/// simulation to type character by character like a real keyboard.
class TypeTextCommand extends Command {
  @override
  CommandAction get action => CommandAction.typeText;

  final String ref;
  final String text;
  final int? delayMs;

  const TypeTextCommand({
    super.id,
    required this.ref,
    required this.text,
    this.delayMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'typeText',
        'ref': ref,
        'text': text,
        if (delayMs != null) 'delayMs': delayMs,
      };

  static TypeTextCommand fromJson(Map<String, dynamic> json, String? id) =>
      TypeTextCommand(
        id: id,
        ref: json['ref'] as String,
        text: json['text'] as String,
        delayMs: json['delayMs'] as int?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'typeText',
        'description': 'Type text into a widget using keyboard simulation. '
            'Use this for TextField widgets (e.g., w10). '
            'For Semantics widgets, use fill instead.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {
              'type': 'string',
              'description': 'Widget ref (e.g., w10 for TextField).',
            },
            'text': {'type': 'string', 'description': 'Text to type.'},
            'delayMs': {
              'type': 'integer',
              'description': 'Delay between characters in ms.',
            },
          },
          'required': ['ref', 'text'],
        },
      };
}

/// Clear command - clear text field.
class ClearCommand extends Command {
  @override
  CommandAction get action => CommandAction.clear;

  final String ref;

  const ClearCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'clear',
        'ref': ref,
      };

  static ClearCommand fromJson(Map<String, dynamic> json, String? id) =>
      ClearCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'clear',
        'description': 'Clear all text from a text field.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Text field ref.'},
          },
          'required': ['ref'],
        },
      };
}

/// Scroll command.
class ScrollCommand extends Command {
  @override
  CommandAction get action => CommandAction.scroll;

  final String ref;
  final String direction; // up, down, left, right
  final double? amount;

  const ScrollCommand({
    super.id,
    required this.ref,
    required this.direction,
    this.amount,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'scroll',
        'ref': ref,
        'direction': direction,
        if (amount != null) 'amount': amount,
      };

  static ScrollCommand fromJson(Map<String, dynamic> json, String? id) =>
      ScrollCommand(
        id: id,
        ref: json['ref'] as String,
        direction: json['direction'] as String,
        amount: (json['amount'] as num?)?.toDouble(),
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'scroll',
        'description': 'Scroll a scrollable element.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Scrollable element ref.'},
            'direction': {
              'type': 'string',
              'enum': ['up', 'down', 'left', 'right'],
              'description': 'Scroll direction.',
            },
            'amount': {
              'type': 'number',
              'description': 'Scroll amount in pixels. Default: 300.',
            },
          },
          'required': ['ref', 'direction'],
        },
      };
}

/// Swipe command.
class SwipeCommand extends Command {
  @override
  CommandAction get action => CommandAction.swipe;

  final String direction; // up, down, left, right
  final double? startX;
  final double? startY;
  final double? distance;
  final int? durationMs;

  const SwipeCommand({
    super.id,
    required this.direction,
    this.startX,
    this.startY,
    this.distance,
    this.durationMs,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'swipe',
        'direction': direction,
        if (startX != null) 'startX': startX,
        if (startY != null) 'startY': startY,
        if (distance != null) 'distance': distance,
        if (durationMs != null) 'durationMs': durationMs,
      };

  static SwipeCommand fromJson(Map<String, dynamic> json, String? id) =>
      SwipeCommand(
        id: id,
        direction: json['direction'] as String,
        startX: (json['startX'] as num?)?.toDouble(),
        startY: (json['startY'] as num?)?.toDouble(),
        distance: (json['distance'] as num?)?.toDouble(),
        durationMs: json['durationMs'] as int?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'swipe',
        'description':
            'Perform a swipe gesture. Useful for dismissing, navigating between pages.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'direction': {
              'type': 'string',
              'enum': ['up', 'down', 'left', 'right'],
              'description': 'Swipe direction.',
            },
            'startX': {
              'type': 'number',
              'description': 'Start X. Default: center of screen.',
            },
            'startY': {
              'type': 'number',
              'description': 'Start Y. Default: center of screen.',
            },
            'distance': {
              'type': 'number',
              'description': 'Swipe distance in pixels. Default: 200.',
            },
            'durationMs': {
              'type': 'integer',
              'description': 'Swipe duration in ms. Default: 300.',
            },
          },
          'required': ['direction'],
        },
      };
}

/// Focus command.
class FocusCommand extends Command {
  @override
  CommandAction get action => CommandAction.focus;

  final String ref;

  const FocusCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'focus',
        'ref': ref,
      };

  static FocusCommand fromJson(Map<String, dynamic> json, String? id) =>
      FocusCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'focus',
        'description': 'Focus on an element (for text input, etc.).',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
          },
          'required': ['ref'],
        },
      };
}

/// PressKey command.
class PressKeyCommand extends Command {
  @override
  CommandAction get action => CommandAction.pressKey;

  final String key;

  const PressKeyCommand({super.id, required this.key});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'pressKey',
        'key': key,
      };

  static PressKeyCommand fromJson(Map<String, dynamic> json, String? id) =>
      PressKeyCommand(id: id, key: json['key'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'pressKey',
        'description': '''Press a keyboard key.

Common keys: enter, tab, escape, backspace, delete,
arrowUp, arrowDown, arrowLeft, arrowRight''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string', 'description': 'Key name to press.'},
          },
          'required': ['key'],
        },
      };
}

/// Toggle command - for switches/checkboxes.
class ToggleCommand extends Command {
  @override
  CommandAction get action => CommandAction.toggle;

  final String ref;
  final bool? value;

  const ToggleCommand({super.id, required this.ref, this.value});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'toggle',
        'ref': ref,
        if (value != null) 'value': value,
      };

  static ToggleCommand fromJson(Map<String, dynamic> json, String? id) =>
      ToggleCommand(
        id: id,
        ref: json['ref'] as String,
        value: json['value'] as bool?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'toggle',
        'description':
            'Toggle a switch or checkbox. Optionally set to specific value.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
            'value': {
              'type': 'boolean',
              'description':
                  'Set to specific value, or toggle if not provided.',
            },
          },
          'required': ['ref'],
        },
      };
}

/// Select command - for dropdowns.
class SelectCommand extends Command {
  @override
  CommandAction get action => CommandAction.select;

  final String ref;
  final String value;

  const SelectCommand({super.id, required this.ref, required this.value});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'select',
        'ref': ref,
        'value': value,
      };

  static SelectCommand fromJson(Map<String, dynamic> json, String? id) =>
      SelectCommand(
        id: id,
        ref: json['ref'] as String,
        value: json['value'] as String,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'select',
        'description': 'Select an option from a dropdown menu.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Dropdown ref.'},
            'value': {
              'type': 'string',
              'description': 'Value/label to select.',
            },
          },
          'required': ['ref', 'value'],
        },
      };
}

/// Wait command.
class WaitCommand extends Command {
  @override
  CommandAction get action => CommandAction.wait;

  final int? milliseconds;
  final String? forRef;
  final String? state; // visible, hidden, enabled, disabled

  const WaitCommand({
    super.id,
    this.milliseconds,
    this.forRef,
    this.state,
  });

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'wait',
        if (milliseconds != null) 'milliseconds': milliseconds,
        if (forRef != null) 'for': forRef,
        if (state != null) 'state': state,
      };

  static WaitCommand fromJson(Map<String, dynamic> json, String? id) =>
      WaitCommand(
        id: id,
        milliseconds: json['milliseconds'] as int?,
        forRef: json['for'] as String?,
        state: json['state'] as String?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'wait',
        'description': '''Wait for a duration or condition.

Either specify milliseconds for a fixed wait, or wait for an element
to reach a specific state.''',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'milliseconds': {
              'type': 'integer',
              'description': 'Fixed wait duration.',
            },
            'for': {
              'type': 'string',
              'description': 'Wait for this element ref.',
            },
            'state': {
              'type': 'string',
              'enum': ['visible', 'hidden', 'enabled', 'disabled'],
              'description': 'State to wait for.',
            },
          },
        },
      };
}

/// Back command - pop navigation.
class BackCommand extends Command {
  @override
  CommandAction get action => CommandAction.back;

  const BackCommand({super.id});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'back',
      };

  static BackCommand fromJson(Map<String, dynamic> json, String? id) =>
      BackCommand(id: id);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'back',
        'description': 'Navigate back (pop the navigation stack).',
        'inputSchema': {'type': 'object', 'properties': {}},
      };
}

/// Navigate command - go to route.
class NavigateCommand extends Command {
  @override
  CommandAction get action => CommandAction.navigate;

  final String route;
  final Map<String, dynamic>? arguments;

  const NavigateCommand({super.id, required this.route, this.arguments});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'navigate',
        'route': route,
        if (arguments != null) 'arguments': arguments,
      };

  static NavigateCommand fromJson(Map<String, dynamic> json, String? id) =>
      NavigateCommand(
        id: id,
        route: json['route'] as String,
        arguments: json['arguments'] as Map<String, dynamic>?,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'navigate',
        'description': 'Navigate to a named route.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'route': {'type': 'string', 'description': 'Route name.'},
            'arguments': {
              'type': 'object',
              'description': 'Route arguments.',
            },
          },
          'required': ['route'],
        },
      };
}

/// GetText command - get element text.
class GetTextCommand extends Command {
  @override
  CommandAction get action => CommandAction.getText;

  final String ref;

  const GetTextCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'getText',
        'ref': ref,
      };

  static GetTextCommand fromJson(Map<String, dynamic> json, String? id) =>
      GetTextCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'getText',
        'description': 'Get the text content of an element.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
          },
          'required': ['ref'],
        },
      };
}

/// IsVisible command.
class IsVisibleCommand extends Command {
  @override
  CommandAction get action => CommandAction.isVisible;

  final String ref;

  const IsVisibleCommand({super.id, required this.ref});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'isVisible',
        'ref': ref,
      };

  static IsVisibleCommand fromJson(Map<String, dynamic> json, String? id) =>
      IsVisibleCommand(id: id, ref: json['ref'] as String);

  static Map<String, dynamic> get toolDefinition => {
        'name': 'isVisible',
        'description': 'Check if an element is visible on screen.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'ref': {'type': 'string', 'description': 'Element ref.'},
          },
          'required': ['ref'],
        },
      };
}

/// Screenshot command.
class ScreenshotCommand extends Command {
  @override
  CommandAction get action => CommandAction.screenshot;

  final String? selector;
  final bool fullPage;

  const ScreenshotCommand({super.id, this.selector, this.fullPage = false});

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'action': 'screenshot',
        if (selector != null) 'selector': selector,
        'fullPage': fullPage,
      };

  static ScreenshotCommand fromJson(Map<String, dynamic> json, String? id) =>
      ScreenshotCommand(
        id: id,
        selector: json['selector'] as String?,
        fullPage: json['fullPage'] as bool? ?? false,
      );

  static Map<String, dynamic> get toolDefinition => {
        'name': 'screenshot',
        'description': 'Take a screenshot. Returns base64-encoded PNG.',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'selector': {
              'type': 'string',
              'description': 'Capture only this element.',
            },
            'fullPage': {
              'type': 'boolean',
              'description': 'Capture entire scrollable area.',
            },
          },
        },
      };
}

// ══════════════════════════════════════════════════════════════════════════════
// RESPONSE TYPES
// ══════════════════════════════════════════════════════════════════════════════

/// Result of parsing a command.
class ParseResult {
  final bool isValid;
  final Command? command;
  final String? error;
  final String? id;

  const ParseResult._({
    required this.isValid,
    this.command,
    this.error,
    this.id,
  });

  factory ParseResult.success(Command command) => ParseResult._(
        isValid: true,
        command: command,
        id: command.id,
      );

  factory ParseResult.error(String error, {String? id}) => ParseResult._(
        isValid: false,
        error: error,
        id: id,
      );
}

/// Response from executing a command.
class CommandResponse {
  final String? id;
  final bool success;
  final dynamic data;
  final String? error;

  const CommandResponse({
    this.id,
    required this.success,
    this.data,
    this.error,
  });

  factory CommandResponse.ok(String? id, [dynamic data]) => CommandResponse(
        id: id,
        success: true,
        data: data,
      );

  factory CommandResponse.fail(String? id, String error) => CommandResponse(
        id: id,
        success: false,
        error: error,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'success': success,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      };

  String serialize() => jsonEncode(toJson());
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════════

extension _EnumByName on List<CommandAction> {
  CommandAction? asNameByValue(String name) {
    for (final value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}

ParseResult _parseCommand(
  CommandAction action,
  Map<String, dynamic> json,
  String? id,
) {
  try {
    final command = switch (action) {
      CommandAction.snapshot => SnapshotCommand.fromJson(json, id),
      CommandAction.tap => TapCommand.fromJson(json, id),
      CommandAction.tapAt => TapAtCommand.fromJson(json, id),
      CommandAction.doubleTap => DoubleTapCommand.fromJson(json, id),
      CommandAction.longPress => LongPressCommand.fromJson(json, id),
      CommandAction.fill => FillCommand.fromJson(json, id),
      CommandAction.typeText => TypeTextCommand.fromJson(json, id),
      CommandAction.clear => ClearCommand.fromJson(json, id),
      CommandAction.scroll => ScrollCommand.fromJson(json, id),
      CommandAction.swipe => SwipeCommand.fromJson(json, id),
      CommandAction.focus => FocusCommand.fromJson(json, id),
      CommandAction.pressKey => PressKeyCommand.fromJson(json, id),
      CommandAction.toggle => ToggleCommand.fromJson(json, id),
      CommandAction.select => SelectCommand.fromJson(json, id),
      CommandAction.wait => WaitCommand.fromJson(json, id),
      CommandAction.back => BackCommand.fromJson(json, id),
      CommandAction.navigate => NavigateCommand.fromJson(json, id),
      CommandAction.getText => GetTextCommand.fromJson(json, id),
      CommandAction.isVisible => IsVisibleCommand.fromJson(json, id),
      CommandAction.screenshot => ScreenshotCommand.fromJson(json, id),
      _ => throw UnimplementedError('Command not implemented: $action'),
    };
    return ParseResult.success(command);
  } catch (e) {
    return ParseResult.error('Invalid command arguments: $e', id: id);
  }
}
