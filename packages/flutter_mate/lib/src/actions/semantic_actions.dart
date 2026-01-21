import 'package:flutter/rendering.dart' hide ScrollDirection;

import '../core/flutter_mate.dart';
import '../core/service_extensions.dart';
import 'gesture_actions.dart';
import 'helpers.dart';

/// Semantics-based actions
///
/// These use Flutter's accessibility system to interact with elements.
/// Most reliable way to interact with standard Flutter widgets.
class SemanticActions {
  /// Tap on an element by ref
  ///
  /// Tries semantic tap action first (for Semantics widgets).
  /// Falls back to gesture-based tap if semantic action not available.
  ///
  /// ```dart
  /// await SemanticActions.tap('w5');
  /// ```
  static Future<bool> tap(String ref) async {
    FlutterMate.ensureInitialized();

    // Check if this ref has semantic tap action
    final lastSnapshot = FlutterMate.lastSnapshot;
    if (lastSnapshot != null) {
      final node = lastSnapshot[ref];
      if (node?.semantics?.hasAction('tap') == true) {
        debugPrint('FlutterMate: tap via semantic action on $ref');
        return _performAction(ref, SemanticsAction.tap);
      }
    }

    // Fallback to gesture-based tap
    debugPrint('FlutterMate: tap via gesture on $ref');
    return GestureActions.tapGesture(ref);
  }

  /// Long press on an element by ref
  ///
  /// Tries semantic longPress action first (for Semantics widgets).
  /// Falls back to gesture-based long press if semantic action not available.
  ///
  /// ```dart
  /// await SemanticActions.longPress('w5');
  /// ```
  static Future<bool> longPress(String ref) async {
    FlutterMate.ensureInitialized();

    // Check if this ref has semantic longPress action
    final lastSnapshot = FlutterMate.lastSnapshot;
    if (lastSnapshot != null) {
      final node = lastSnapshot[ref];
      if (node?.semantics?.hasAction('longPress') == true) {
        debugPrint('FlutterMate: longPress via semantic action on $ref');
        return _performAction(ref, SemanticsAction.longPress);
      }
    }

    // Fallback to gesture-based long press
    debugPrint('FlutterMate: longPress via gesture on $ref');
    return GestureActions.longPressGesture(ref);
  }

  /// Set text on an element using semantic setText action
  ///
  /// This is the semantic way to set text fields. For keyboard simulation,
  /// use [KeyboardActions.typeText] instead.
  ///
  /// ```dart
  /// await SemanticActions.setText('w9', 'hello@example.com');
  /// ```
  static Future<bool> setText(String ref, String text) async {
    FlutterMate.ensureInitialized();

    final node = findSemanticsNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: setText - Node not found: $ref');
      return false;
    }

    final data = node.getSemanticsData();

    // Try to focus first
    if (data.hasAction(SemanticsAction.focus)) {
      node.owner?.performAction(node.id, SemanticsAction.focus);
      await FlutterMate.delay(const Duration(milliseconds: 50));
    }

    // Try setText even if not advertised - it often works anyway!
    // TextField may handle it internally even without advertising
    node.owner?.performAction(node.id, SemanticsAction.setText, text);
    await FlutterMate.delay(const Duration(milliseconds: 100));

    return true;
  }

  /// Scroll an element
  ///
  /// First tries semantic scroll action on the node or its ancestors.
  /// Falls back to gesture-based scrolling if no semantic scroll is available.
  ///
  /// ```dart
  /// await SemanticActions.scroll('w10', ScrollDirection.down);
  /// ```
  static Future<bool> scroll(String ref, ScrollDirection direction,
      {double distance = 200}) async {
    // NOTE: SemanticsAction scroll directions refer to VIEW movement, not content:
    // - scrollUp = view moves up = content moves down = reveals content BELOW
    // - scrollDown = view moves down = content moves up = reveals content ABOVE
    //
    // When user says "scroll down" they mean "see content below", so we use scrollUp
    final action = switch (direction) {
      ScrollDirection.up => SemanticsAction.scrollDown, // see content above
      ScrollDirection.down => SemanticsAction.scrollUp, // see content below
      ScrollDirection.left => SemanticsAction.scrollRight,
      ScrollDirection.right => SemanticsAction.scrollLeft,
    };

    // Find the node
    final node = findSemanticsNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: Scroll - Node not found: $ref');
      return false;
    }

    // Tier 1: Try semantic scrolling first
    // Walk up the tree to find a scrollable ancestor
    SemanticsNode? current = node;
    while (current != null) {
      final data = current.getSemanticsData();
      if (data.hasAction(action)) {
        debugPrint('FlutterMate: Scroll via semantic action on w${current.id}');
        current.owner?.performAction(current.id, action);
        await FlutterMate.delay(const Duration(milliseconds: 300));
        return true;
      }
      current = current.parent;
    }

    // Tier 2: Fall back to gesture-based scrolling
    debugPrint('FlutterMate: No semantic scroll available, using gesture');
    return GestureActions.scrollGestureByDirection(ref, direction, distance);
  }

  /// Focus on an element by ref
  static Future<bool> focus(String ref) async {
    return _performAction(ref, SemanticsAction.focus);
  }

  // === Private helper methods ===

  static Future<bool> _performAction(String ref, SemanticsAction action) async {
    FlutterMate.ensureInitialized();

    final node = findSemanticsNode(ref);
    if (node == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final data = node.getSemanticsData();
    if (!data.hasAction(action)) {
      debugPrint('FlutterMate: Node $ref does not support $action');
      return false;
    }

    node.owner?.performAction(node.id, action);
    await FlutterMate.delay(const Duration(milliseconds: 100));

    return true;
  }
}

/// Tap element by label (convenience method)
Future<bool> tapByLabel(String label) async {
  final ref = await findByLabel(label);
  if (ref == null) {
    debugPrint('FlutterMate: tapByLabel - No element found with label: $label');
    return false;
  }
  return SemanticActions.tap(ref);
}

/// Fill text field by label (convenience method)
Future<bool> fillByLabel(String label, String text) async {
  final ref = await findByLabel(label);
  if (ref == null) {
    debugPrint(
        'FlutterMate: fillByLabel - No element found with label: $label');
    return false;
  }
  return SemanticActions.setText(ref, text);
}

/// Long press element by label (convenience method)
Future<bool> longPressByLabel(String label) async {
  final ref = await findByLabel(label);
  if (ref == null) {
    debugPrint(
        'FlutterMate: longPressByLabel - No element found with label: $label');
    return false;
  }
  return SemanticActions.longPress(ref);
}

/// Focus element by label (convenience method)
Future<bool> focusByLabel(String label) async {
  final ref = await findByLabel(label);
  if (ref == null) {
    debugPrint(
        'FlutterMate: focusByLabel - No element found with label: $label');
    return false;
  }
  return SemanticActions.focus(ref);
}
