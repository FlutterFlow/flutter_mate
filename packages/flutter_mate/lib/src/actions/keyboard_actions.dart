import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/flutter_mate.dart';
import 'gesture_actions.dart';

/// Keyboard / text input simulation
///
/// Uses platform messages to simulate keyboard input, just like a real keyboard.
///
/// How it works:
/// 1. typeText(ref, text) finds the widget from the inspector tree
/// 2. Taps to focus the TextField
/// 3. Sends platform messages with magic client ID -1 (debug builds only)
/// 4. Falls back to EditableTextState in release builds
///
/// Usage:
///   await FlutterMate.snapshot();  // Cache elements
///   await KeyboardActions.typeText('w10', 'hello@example.com');
class KeyboardActions {
  /// Type text into a text field by ref
  ///
  /// In debug builds, uses platform message simulation with magic client ID -1.
  /// In release builds, falls back to EditableTextState.updateEditingValue().
  ///
  /// ```dart
  /// await KeyboardActions.typeText('w10', 'hello@example.com');
  /// ```
  static Future<bool> typeText(String ref, String text) async {
    FlutterMate.ensureInitialized();

    debugPrint('FlutterMate: typeText "$text" into $ref');

    try {
      // Find the Element from cached inspector tree
      final element = FlutterMate.cachedElements[ref];
      if (element == null) {
        debugPrint(
            'FlutterMate: Element not found for $ref. Did you call snapshot() first?');
        return false;
      }

      // Find the center of the element for tapping
      RenderObject? ro;
      if (element is RenderObjectElement) {
        ro = element.renderObject;
      } else {
        // Walk down to find RenderObject
        void findRenderObject(Element el) {
          if (ro != null) return;
          if (el is RenderObjectElement) {
            ro = el.renderObject;
            return;
          }
          el.visitChildren(findRenderObject);
        }

        findRenderObject(element);
      }

      if (ro == null || ro is! RenderBox) {
        debugPrint('FlutterMate: No RenderBox found for $ref');
        return false;
      }

      final box = ro as RenderBox;
      if (!box.hasSize) {
        debugPrint('FlutterMate: RenderBox has no size for $ref');
        return false;
      }

      // Calculate center and tap to focus
      final center = box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
      debugPrint('FlutterMate: Tapping to focus at $center');
      await GestureActions.tapAt(center);

      // Wait for focus and text input connection to be established
      await FlutterMate.delay(const Duration(milliseconds: 150));

      // Get current text from the focused field
      final focusNode = FocusManager.instance.primaryFocus;
      String currentText = '';
      if (focusNode != null) {
        final editableState = _findEditableTextState(focusNode.context);
        if (editableState != null) {
          currentText = editableState.currentTextEditingValue.text;
        }
      }

      // In debug builds, use platform messages with magic client ID -1
      // In release builds, magic ID won't work - use EditableTextState fallback
      bool isDebugMode = false;
      assert(() {
        isDebugMode = true;
        return true;
      }());

      if (isDebugMode) {
        // Type character by character using platform messages
        for (int i = 0; i < text.length; i++) {
          currentText += text[i];
          await FlutterMate.dispatchTextInput(currentText);
        }
        debugPrint('FlutterMate: Typed "$text" via platform messages');
        return true;
      } else {
        // Release mode: fall back to EditableTextState
        debugPrint(
            'FlutterMate: Release mode - using EditableTextState fallback');
        return _typeTextViaEditableState(text);
      }
    } catch (e, stack) {
      debugPrint('FlutterMate: typeText error: $e\n$stack');
      return false;
    }
  }

  /// Type text into the currently focused field (fallback method)
  static Future<bool> _typeTextViaEditableState(String text) async {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) {
      debugPrint('FlutterMate: No focused element');
      return false;
    }

    final editableState = _findEditableTextState(focusNode.context);
    if (editableState == null) {
      debugPrint('FlutterMate: No EditableTextState found');
      return false;
    }

    String currentText = editableState.currentTextEditingValue.text;

    for (int i = 0; i < text.length; i++) {
      currentText += text[i];
      editableState.updateEditingValue(TextEditingValue(
        text: currentText,
        selection: TextSelection.collapsed(offset: currentText.length),
      ));
      if (!FlutterMate.isTestMode) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }

    debugPrint('FlutterMate: Typed "$text" via EditableTextState (fallback)');
    return true;
  }

  /// Find EditableTextState from a BuildContext
  static EditableTextState? _findEditableTextState(BuildContext? context) {
    if (context == null) return null;

    EditableTextState? found;

    // Search subtree first
    void visitor(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visitor);
    }

    (context as Element).visitChildren(visitor);

    // If not in subtree, check ancestors
    if (found == null) {
      context.visitAncestorElements((element) {
        if (element is StatefulElement && element.state is EditableTextState) {
          found = element.state as EditableTextState;
          return false;
        }
        return true;
      });
    }

    return found;
  }

  /// Clear the currently focused text field
  static Future<bool> clearText() async {
    FlutterMate.ensureInitialized();

    debugPrint('FlutterMate: clearText');

    try {
      final focusNode = FocusManager.instance.primaryFocus;
      if (focusNode == null) {
        debugPrint('FlutterMate: No focused element');
        return false;
      }

      final editableState = _findEditableTextState(focusNode.context);
      if (editableState == null) {
        debugPrint('FlutterMate: No EditableTextState found');
        return false;
      }

      // Use updateEditingValue to clear - same as platform input
      editableState.updateEditingValue(const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ));
      debugPrint('FlutterMate: Text cleared');
      return true;
    } catch (e) {
      debugPrint('FlutterMate: clearText error: $e');
      return false;
    }
  }

  /// Simulate pressing a specific key
  ///
  /// ```dart
  /// await KeyboardActions.pressKey(LogicalKeyboardKey.enter);
  /// await KeyboardActions.pressKey(LogicalKeyboardKey.tab);
  /// ```
  static Future<bool> pressKey(LogicalKeyboardKey key) async {
    FlutterMate.ensureInitialized();

    try {
      final messenger = WidgetsBinding.instance.defaultBinaryMessenger;
      final keyId = key.keyId;

      await _sendKeyEventWithLogicalKey(messenger, 'keydown', keyId, 0);
      await FlutterMate.delay(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, 0);
      await FlutterMate.delay(const Duration(milliseconds: 30));

      return true;
    } catch (e) {
      debugPrint('FlutterMate: pressKey error: $e');
      return false;
    }
  }

  static Future<void> _sendKeyEventWithLogicalKey(
    BinaryMessenger messenger,
    String type,
    int logicalKeyId,
    int modifiers,
  ) async {
    final message = const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'type': type,
      'keymap': 'macos',
      'keyCode': logicalKeyId & 0xFFFF,
      'modifiers': modifiers,
    });

    if (message != null) {
      await messenger.send('flutter/keyevent', message);
    }
  }

  /// Simulate pressing Enter key
  static Future<bool> pressEnter() => pressKey(LogicalKeyboardKey.enter);

  /// Simulate pressing Tab key
  static Future<bool> pressTab() => pressKey(LogicalKeyboardKey.tab);

  /// Simulate pressing Escape key
  static Future<bool> pressEscape() => pressKey(LogicalKeyboardKey.escape);

  /// Simulate pressing Backspace key
  static Future<bool> pressBackspace() =>
      pressKey(LogicalKeyboardKey.backspace);

  /// Simulate pressing arrow keys
  static Future<bool> pressArrowUp() => pressKey(LogicalKeyboardKey.arrowUp);
  static Future<bool> pressArrowDown() =>
      pressKey(LogicalKeyboardKey.arrowDown);
  static Future<bool> pressArrowLeft() =>
      pressKey(LogicalKeyboardKey.arrowLeft);
  static Future<bool> pressArrowRight() =>
      pressKey(LogicalKeyboardKey.arrowRight);

  /// Simulate keyboard shortcut (e.g., Cmd+A, Ctrl+C)
  ///
  /// ```dart
  /// await KeyboardActions.pressShortcut(LogicalKeyboardKey.keyA, command: true);  // Cmd+A
  /// await KeyboardActions.pressShortcut(LogicalKeyboardKey.keyC, control: true);  // Ctrl+C
  /// ```
  static Future<bool> pressShortcut(
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
    bool command = false,
  }) async {
    FlutterMate.ensureInitialized();

    try {
      final messenger = WidgetsBinding.instance.defaultBinaryMessenger;

      // macOS modifier flags
      int modifiers = 0;
      if (shift) modifiers |= 0x20000;
      if (control) modifiers |= 0x40000;
      if (alt) modifiers |= 0x80000;
      if (command) modifiers |= 0x100000;

      final keyId = key.keyId;

      await _sendKeyEventWithLogicalKey(messenger, 'keydown', keyId, modifiers);
      await FlutterMate.delay(const Duration(milliseconds: 30));
      await _sendKeyEventWithLogicalKey(messenger, 'keyup', keyId, modifiers);
      await FlutterMate.delay(const Duration(milliseconds: 30));

      return true;
    } catch (e) {
      debugPrint('FlutterMate: pressShortcut error: $e');
      return false;
    }
  }

  /// Parse a key name string to LogicalKeyboardKey
  static LogicalKeyboardKey? parseLogicalKey(String key) {
    return switch (key.toLowerCase()) {
      'enter' => LogicalKeyboardKey.enter,
      'tab' => LogicalKeyboardKey.tab,
      'escape' => LogicalKeyboardKey.escape,
      'backspace' => LogicalKeyboardKey.backspace,
      'delete' => LogicalKeyboardKey.delete,
      'space' => LogicalKeyboardKey.space,
      'arrowup' => LogicalKeyboardKey.arrowUp,
      'arrowdown' => LogicalKeyboardKey.arrowDown,
      'arrowleft' => LogicalKeyboardKey.arrowLeft,
      'arrowright' => LogicalKeyboardKey.arrowRight,
      _ => null,
    };
  }
}
