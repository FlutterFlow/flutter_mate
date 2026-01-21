/// Re-exports for backward compatibility
///
/// This file maintains the original API surface by re-exporting
/// from the new modular structure.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'core/flutter_mate.dart' as core;
import 'core/service_extensions.dart';
import 'snapshot/snapshot.dart';
import 'snapshot/combined_snapshot.dart';
import 'actions/semantic_actions.dart' as semantic;
import 'actions/gesture_actions.dart' as gesture;
import 'actions/keyboard_actions.dart' as keyboard;
import 'actions/helpers.dart' as helpers;

export 'package:flutter/widgets.dart' show TextEditingController;
export 'core/service_extensions.dart' show ScrollDirection;

/// Flutter Mate SDK — Automate Flutter apps
///
/// Use this class for:
/// - **AI agents** that navigate and interact with your UI
/// - **Automated testing** without widget keys
/// - **Accessibility automation** using the semantics tree
///
/// ## Quick Start
///
/// ```dart
/// // 1. Initialize at app startup
/// await FlutterMate.initialize();
///
/// // 2. Get UI snapshot with element refs
/// final snapshot = await FlutterMate.snapshot();
/// print(snapshot);
///
/// // 3. Interact with elements
/// await FlutterMate.tap('w18');  // auto: semantic or gesture
/// await FlutterMate.setText('w9', 'hello@example.com');  // semantic action
/// await FlutterMate.typeText('w10', 'hello@example.com');  // keyboard sim
/// ```
class FlutterMate {
  // === Initialization ===

  /// Initialize Flutter Mate
  static Future<void> initialize() => core.FlutterMate.initialize();

  /// Initialize for widget tests
  static void initializeForTest() => core.FlutterMate.initializeForTest();

  /// Dispose Flutter Mate resources
  static void dispose() => core.FlutterMate.dispose();

  /// Whether running in test mode
  static bool get isTestMode => core.FlutterMate.isTestMode;

  // === Text Controller Registration ===

  /// Register a TextEditingController for use with fillByName
  static void registerTextField(
          String name, TextEditingController controller) =>
      core.FlutterMate.registerTextField(name, controller);

  /// Unregister a TextEditingController
  static void unregisterTextField(String name) =>
      core.FlutterMate.unregisterTextField(name);

  /// Fill a text field by its registered name
  static Future<bool> fillByName(String name, String text) =>
      core.FlutterMate.fillByName(name, text);

  // === Snapshot ===

  /// Get a snapshot of the current UI
  static Future<CombinedSnapshot> snapshot() => SnapshotService.snapshot();

  // === Semantic Actions ===

  /// Tap on an element by ref (smart: semantic or gesture)
  static Future<bool> tap(String ref) => semantic.SemanticActions.tap(ref);

  /// Long press on an element by ref
  static Future<bool> longPress(String ref) =>
      semantic.SemanticActions.longPress(ref);

  /// Set text on an element using semantic setText action
  static Future<bool> setText(String ref, String text) =>
      semantic.SemanticActions.setText(ref, text);

  /// Scroll an element
  static Future<bool> scroll(String ref, ScrollDirection direction,
          {double distance = 200}) =>
      semantic.SemanticActions.scroll(ref, direction, distance: distance);

  /// Focus on an element by ref
  static Future<bool> focus(String ref) => semantic.SemanticActions.focus(ref);

  /// Alias for [setText] for backwards compatibility
  @Deprecated('Use setText instead')
  static Future<bool> fill(String ref, String text) => setText(ref, text);

  // === Gesture Actions ===

  /// Double tap on an element by ref
  static Future<bool> doubleTap(String ref) =>
      gesture.GestureActions.doubleTap(ref);

  /// Simulate a tap at screen coordinates
  static Future<void> tapAt(Offset position) =>
      gesture.GestureActions.tapAt(position);

  /// Simulate a double tap at specific coordinates
  static Future<void> doubleTapAt(Offset position) =>
      gesture.GestureActions.doubleTapAt(position);

  /// Simulate a long press at screen coordinates
  static Future<void> longPressAt(Offset position,
          {Duration pressDuration = const Duration(milliseconds: 600)}) =>
      gesture.GestureActions.longPressAt(position,
          pressDuration: pressDuration);

  /// Simulate a drag/swipe gesture
  static Future<void> drag({
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 200),
    int steps = 10,
  }) =>
      gesture.GestureActions.drag(
        from: from,
        to: to,
        duration: duration,
        steps: steps,
      );

  /// Simulate a scroll gesture on an element
  static Future<bool> scrollGesture(String ref, Offset delta) =>
      gesture.GestureActions.scrollGesture(ref, delta);

  // === Keyboard Actions ===

  /// Type text into a text field by ref
  static Future<bool> typeText(String ref, String text) =>
      keyboard.KeyboardActions.typeText(ref, text);

  /// Clear the currently focused text field
  static Future<bool> clearText() => keyboard.KeyboardActions.clearText();

  /// Simulate pressing a specific key
  static Future<bool> pressKey(LogicalKeyboardKey key) =>
      keyboard.KeyboardActions.pressKey(key);

  /// Simulate pressing Enter key
  static Future<bool> pressEnter() => keyboard.KeyboardActions.pressEnter();

  /// Simulate pressing Tab key
  static Future<bool> pressTab() => keyboard.KeyboardActions.pressTab();

  /// Simulate pressing Escape key
  static Future<bool> pressEscape() => keyboard.KeyboardActions.pressEscape();

  /// Simulate pressing Backspace key
  static Future<bool> pressBackspace() =>
      keyboard.KeyboardActions.pressBackspace();

  /// Simulate pressing arrow keys
  static Future<bool> pressArrowUp() => keyboard.KeyboardActions.pressArrowUp();
  static Future<bool> pressArrowDown() =>
      keyboard.KeyboardActions.pressArrowDown();
  static Future<bool> pressArrowLeft() =>
      keyboard.KeyboardActions.pressArrowLeft();
  static Future<bool> pressArrowRight() =>
      keyboard.KeyboardActions.pressArrowRight();

  /// Simulate keyboard shortcut
  static Future<bool> pressShortcut(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
    bool command = false,
  }) =>
      keyboard.KeyboardActions.pressShortcut(
        key,
        control: control,
        shift: shift,
        alt: alt,
        command: command,
      );

  // === Helpers ===

  /// Find element ref by semantic label
  static Future<String?> findByLabel(String label) =>
      helpers.findByLabel(label);

  /// Find all element refs matching a label pattern
  static Future<List<String>> findAllByLabel(String labelPattern) =>
      helpers.findAllByLabel(labelPattern);

  /// Tap element by label
  static Future<bool> tapByLabel(String label) => semantic.tapByLabel(label);

  /// Fill text field by label
  static Future<bool> fillByLabel(String label, String text) =>
      semantic.fillByLabel(label, text);

  /// Long press element by label
  static Future<bool> longPressByLabel(String label) =>
      semantic.longPressByLabel(label);

  /// Double tap element by label
  static Future<bool> doubleTapByLabel(String label) =>
      gesture.doubleTapByLabel(label);

  /// Focus element by label
  static Future<bool> focusByLabel(String label) =>
      semantic.focusByLabel(label);

  /// Wait for an element to appear
  static Future<String?> waitFor(
    String labelPattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) =>
      helpers.waitFor(
        labelPattern,
        timeout: timeout,
        pollInterval: pollInterval,
      );
}
