/// CommandExecutor - Bridge between Protocol commands and FlutterMate SDK
///
/// This executor takes typed [Command] objects from protocol.dart and
/// executes them via the FlutterMate SDK, returning [CommandResponse] objects.
///
/// ## Usage
///
/// ```dart
/// // Parse a command from JSON
/// final result = Command.parse('{"action": "tap", "ref": "w5"}');
/// if (result.isValid) {
///   final response = await CommandExecutor.execute(result.command!);
///   print(response.success ? 'OK' : response.error);
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' hide ScrollDirection;
import 'package:flutter/widgets.dart';

import 'core/service_extensions.dart';
import 'snapshot/snapshot.dart';
import 'actions/semantic_actions.dart';
import 'actions/gesture_actions.dart';
import 'actions/keyboard_actions.dart';
import 'actions/helpers.dart';
import 'protocol.dart';

/// Executes [Command] objects via the FlutterMate SDK.
class CommandExecutor {
  CommandExecutor._();

  /// Execute a single command.
  ///
  /// Returns a [CommandResponse] with success status and any result data.
  static Future<CommandResponse> execute(Command command) async {
    try {
      return switch (command) {
        SnapshotCommand cmd => _executeSnapshot(cmd),
        TapCommand cmd => _executeTap(cmd),
        TapAtCommand cmd => _executeTapAt(cmd),
        DoubleTapCommand cmd => _executeDoubleTap(cmd),
        LongPressCommand cmd => _executeLongPress(cmd),
        SetTextCommand cmd => _executeSetText(cmd),
        TypeTextCommand cmd => _executeTypeText(cmd),
        ClearCommand cmd => _executeClear(cmd),
        ScrollCommand cmd => _executeScroll(cmd),
        SwipeCommand cmd => _executeSwipe(cmd),
        FocusCommand cmd => _executeFocus(cmd),
        PressKeyCommand cmd => _executePressKey(cmd),
        ToggleCommand cmd => _executeToggle(cmd),
        SelectCommand cmd => _executeSelect(cmd),
        WaitCommand cmd => _executeWait(cmd),
        BackCommand cmd => _executeBack(cmd),
        NavigateCommand cmd => _executeNavigate(cmd),
        GetTextCommand cmd => _executeGetText(cmd),
        IsVisibleCommand cmd => _executeIsVisible(cmd),
        ScreenshotCommand cmd => _executeScreenshot(cmd),
        _ => throw UnimplementedError(
            'Command not implemented: ${command.action}'),
      };
    } catch (e, stack) {
      return CommandResponse.fail(
        command.id,
        'Execution error: $e\n$stack',
      );
    }
  }

  /// Execute a command from JSON (parses then executes).
  static Future<CommandResponse> executeJson(dynamic json) async {
    final result = Command.parse(json);
    if (!result.isValid) {
      return CommandResponse.fail(result.id, result.error!);
    }
    return execute(result.command!);
  }

  /// Execute a sequence of commands.
  ///
  /// Stops on first failure unless [continueOnError] is true.
  static Future<List<CommandResponse>> executeSequence(
    List<Command> commands, {
    bool continueOnError = false,
  }) async {
    final responses = <CommandResponse>[];

    for (final command in commands) {
      final response = await execute(command);
      responses.add(response);

      if (!response.success && !continueOnError) {
        break;
      }
    }

    return responses;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Command Handlers
  // ════════════════════════════════════════════════════════════════════════════

  static Future<CommandResponse> _executeSnapshot(SnapshotCommand cmd) async {
    final snapshot = SnapshotService.snapshot();

    if (!snapshot.success) {
      return CommandResponse.fail(cmd.id, snapshot.error ?? 'Snapshot failed');
    }

    var nodes = snapshot.nodes;

    // Apply maxDepth filter if specified
    if (cmd.maxDepth != null) {
      nodes = nodes.where((n) => n.depth <= cmd.maxDepth!).toList();
    }

    // Apply selector filter if specified
    if (cmd.selector != null) {
      // Find the subtree under the selector
      final selectorNode = nodes.firstWhere(
        (n) => n.ref == cmd.selector,
        orElse: () => nodes.first,
      );
      // Filter to only include descendants
      nodes = nodes.where((n) {
        // Simple heuristic: check if ref starts after selector in order
        final selectorIdx = int.tryParse(selectorNode.ref.substring(1)) ?? 0;
        final nodeIdx = int.tryParse(n.ref.substring(1)) ?? 0;
        return nodeIdx >= selectorIdx;
      }).toList();
    }

    return CommandResponse.ok(cmd.id, {
      'nodeCount': nodes.length,
      'nodes': nodes.map((n) => n.toJson()).toList(),
    });
  }

  static Future<CommandResponse> _executeTap(TapCommand cmd) async {
    final success = await SemanticActions.tap(cmd.ref);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(cmd.id, 'Failed to tap element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeTapAt(TapAtCommand cmd) async {
    await GestureActions.tapAt(ui.Offset(cmd.x, cmd.y));
    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeDoubleTap(DoubleTapCommand cmd) async {
    // Double tap: tap twice quickly
    final success1 = await SemanticActions.tap(cmd.ref);
    if (!success1) {
      return CommandResponse.fail(
          cmd.id, 'Failed to double tap element: ${cmd.ref}');
    }
    await Future.delayed(const Duration(milliseconds: 50));
    final success2 = await SemanticActions.tap(cmd.ref);
    if (!success2) {
      return CommandResponse.fail(
          cmd.id, 'Failed to complete double tap: ${cmd.ref}');
    }
    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeLongPress(LongPressCommand cmd) async {
    final success = await SemanticActions.longPress(cmd.ref);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(
        cmd.id, 'Failed to long press element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeSetText(SetTextCommand cmd) async {
    final success = await SemanticActions.setText(cmd.ref, cmd.text);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(
        cmd.id, 'Failed to setText on element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeTypeText(TypeTextCommand cmd) async {
    final success = await KeyboardActions.typeText(cmd.ref, cmd.text);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(
        cmd.id, 'Failed to type text into element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeClear(ClearCommand cmd) async {
    // Focus the element first, then clear
    final focused = await SemanticActions.focus(cmd.ref);
    if (!focused) {
      return CommandResponse.fail(
          cmd.id, 'Failed to focus element for clear: ${cmd.ref}');
    }
    final success = await KeyboardActions.clearText();
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(cmd.id, 'Failed to clear text field');
  }

  static Future<CommandResponse> _executeScroll(ScrollCommand cmd) async {
    final direction = switch (cmd.direction.toLowerCase()) {
      'up' => ScrollDirection.up,
      'down' => ScrollDirection.down,
      'left' => ScrollDirection.left,
      'right' => ScrollDirection.right,
      _ => null,
    };

    if (direction == null) {
      return CommandResponse.fail(
          cmd.id, 'Invalid direction: ${cmd.direction}');
    }

    final success = await SemanticActions.scroll(cmd.ref, direction);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(cmd.id, 'Failed to scroll element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeSwipe(SwipeCommand cmd) async {
    // Get screen size for default center position
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = window.physicalSize / window.devicePixelRatio;

    final startX = cmd.startX ?? screenSize.width / 2;
    final startY = cmd.startY ?? screenSize.height / 2;
    final distance = cmd.distance ?? 200.0;
    final duration = cmd.durationMs ?? 300;

    // Calculate end position based on direction
    double endX = startX;
    double endY = startY;

    switch (cmd.direction.toLowerCase()) {
      case 'up':
        endY = startY - distance;
      case 'down':
        endY = startY + distance;
      case 'left':
        endX = startX - distance;
      case 'right':
        endX = startX + distance;
      default:
        return CommandResponse.fail(
            cmd.id, 'Invalid swipe direction: ${cmd.direction}');
    }

    // Perform drag gesture
    await GestureActions.drag(
      from: ui.Offset(startX, startY),
      to: ui.Offset(endX, endY),
      duration: Duration(milliseconds: duration),
    );

    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeFocus(FocusCommand cmd) async {
    final success = await SemanticActions.focus(cmd.ref);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(cmd.id, 'Failed to focus element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executePressKey(PressKeyCommand cmd) async {
    switch (cmd.key.toLowerCase()) {
      case 'enter':
        await KeyboardActions.pressEnter();
      case 'tab':
        await KeyboardActions.pressTab();
      case 'escape':
        await KeyboardActions.pressEscape();
      case 'backspace':
        await KeyboardActions.pressBackspace();
      case 'arrowup':
        await KeyboardActions.pressArrowUp();
      case 'arrowdown':
        await KeyboardActions.pressArrowDown();
      case 'arrowleft':
        await KeyboardActions.pressArrowLeft();
      case 'arrowright':
        await KeyboardActions.pressArrowRight();
      default:
        return CommandResponse.fail(cmd.id, 'Unknown key: ${cmd.key}');
    }
    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeToggle(ToggleCommand cmd) async {
    // Toggle is just a tap on the switch/checkbox
    // If value is specified, we need to check current state first
    // For now, just tap
    final success = await SemanticActions.tap(cmd.ref);
    if (success) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(cmd.id, 'Failed to toggle element: ${cmd.ref}');
  }

  static Future<CommandResponse> _executeSelect(SelectCommand cmd) async {
    // Select: tap to open dropdown, then find and tap the option
    // Step 1: Tap the dropdown
    final opened = await SemanticActions.tap(cmd.ref);
    if (!opened) {
      return CommandResponse.fail(
          cmd.id, 'Failed to open dropdown: ${cmd.ref}');
    }

    // Wait for dropdown to open
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: Find the option by value/label
    final optionRef = await waitFor(cmd.value);
    if (optionRef == null) {
      return CommandResponse.fail(cmd.id, 'Option not found: ${cmd.value}');
    }

    // Step 3: Tap the option
    final selected = await SemanticActions.tap(optionRef);
    if (selected) {
      return CommandResponse.ok(cmd.id);
    }
    return CommandResponse.fail(
        cmd.id, 'Failed to select option: ${cmd.value}');
  }

  static Future<CommandResponse> _executeWait(WaitCommand cmd) async {
    if (cmd.milliseconds != null) {
      // Fixed duration wait
      await Future.delayed(Duration(milliseconds: cmd.milliseconds!));
      return CommandResponse.ok(cmd.id);
    }

    if (cmd.forRef != null) {
      // Wait for element
      const timeout = Duration(seconds: 10);
      final startTime = DateTime.now();

      while (DateTime.now().difference(startTime) < timeout) {
        final snapshot = SnapshotService.snapshot();
        final node = snapshot.nodes.firstWhere(
          (n) => n.ref == cmd.forRef,
          orElse: () => snapshot.nodes.first,
        );

        if (node.ref == cmd.forRef) {
          // Check state if specified
          if (cmd.state == null) {
            return CommandResponse.ok(cmd.id);
          }

          // TODO: Implement state checking
          return CommandResponse.ok(cmd.id);
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      return CommandResponse.fail(
          cmd.id, 'Timeout waiting for element: ${cmd.forRef}');
    }

    // Default: wait 1 second
    await Future.delayed(const Duration(seconds: 1));
    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeBack(BackCommand cmd) async {
    // Try to use the back action from semantics
    // Look for a back button or use navigation pop
    final snapshot = SnapshotService.snapshot();

    // Look for back button
    for (final node in snapshot.nodes) {
      final label = node.semantics?.label?.toLowerCase() ?? '';
      if (label.contains('back') || label.contains('pop')) {
        final success = await SemanticActions.tap(node.ref);
        if (success) {
          return CommandResponse.ok(cmd.id);
        }
      }
    }

    // Fallback: press escape or back key
    await KeyboardActions.pressEscape();
    return CommandResponse.ok(cmd.id);
  }

  static Future<CommandResponse> _executeNavigate(NavigateCommand cmd) async {
    // Navigation requires access to Navigator, which we can't do directly
    // from semantics. This would need a service extension in the app.
    // For now, return not implemented.
    return CommandResponse.fail(
      cmd.id,
      'Navigate command requires app-side implementation. '
      'Use tap on navigation elements instead.',
    );
  }

  static Future<CommandResponse> _executeGetText(GetTextCommand cmd) async {
    final snapshot = SnapshotService.snapshot();
    final node = snapshot[cmd.ref];

    if (node == null) {
      return CommandResponse.fail(cmd.id, 'Element not found: ${cmd.ref}');
    }

    final text = node.semantics?.label ?? node.semantics?.value ?? node.widget;

    return CommandResponse.ok(cmd.id, {'text': text});
  }

  static Future<CommandResponse> _executeIsVisible(IsVisibleCommand cmd) async {
    final snapshot = SnapshotService.snapshot();
    final node = snapshot[cmd.ref];

    if (node == null) {
      return CommandResponse.ok(cmd.id, {'visible': false});
    }

    // Check if bounds are valid (element is rendered)
    final isVisible = node.bounds != null &&
        node.bounds!.width > 0 &&
        node.bounds!.height > 0;

    return CommandResponse.ok(cmd.id, {'visible': isVisible});
  }

  static Future<CommandResponse> _executeScreenshot(
      ScreenshotCommand cmd) async {
    try {
      // Find the root RenderRepaintBoundary
      final renderObject = WidgetsBinding.instance.rootElement?.renderObject;
      if (renderObject == null) {
        return CommandResponse.fail(cmd.id, 'No render object found');
      }

      // Find a RenderRepaintBoundary
      RenderRepaintBoundary? boundary;
      void findBoundary(RenderObject obj) {
        if (obj is RenderRepaintBoundary) {
          boundary = obj;
          return;
        }
        obj.visitChildren(findBoundary);
      }

      findBoundary(renderObject);

      if (boundary == null) {
        return CommandResponse.fail(cmd.id, 'No repaint boundary found');
      }

      // Capture the image
      final image = await boundary!.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        return CommandResponse.fail(cmd.id, 'Failed to capture image');
      }

      // Return base64 encoded PNG
      final base64 = base64Encode(byteData.buffer.asUint8List());
      return CommandResponse.ok(cmd.id, {
        'format': 'png',
        'data': base64,
        'width': image.width,
        'height': image.height,
      });
    } catch (e) {
      return CommandResponse.fail(cmd.id, 'Screenshot failed: $e');
    }
  }
}
