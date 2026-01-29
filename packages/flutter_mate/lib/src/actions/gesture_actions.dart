import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/flutter_mate.dart';
import '../core/service_extensions.dart';
import '../snapshot/snapshot.dart';
import 'helpers.dart';

/// Gesture simulation actions
///
/// These inject raw pointer events to simulate touches and drags.
/// Use when you need precise control over gesture timing and position.
class GestureActions {
  static int _pointerIdCounter = 0;

  /// Double tap on an element by ref
  ///
  /// Uses gesture simulation to trigger GestureDetector.onDoubleTap callbacks.
  static Future<bool> doubleTap(String ref) async {
    return doubleTapGesture(ref);
  }

  /// Double tap via gesture simulation
  static Future<bool> doubleTapGesture(String ref) async {
    FlutterMate.ensureInitialized();

    final snap = SnapshotService.snapshot();
    final nodeInfo = snap[ref];
    if (nodeInfo == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final centerPoint = nodeInfo.center;
    if (centerPoint == null) {
      debugPrint('FlutterMate: Node has no bounds: $ref');
      return false;
    }

    await doubleTapAt(Offset(centerPoint.x, centerPoint.y));
    return true;
  }

  /// Simulate a double tap at specific coordinates
  static Future<void> doubleTapAt(Offset position) async {
    FlutterMate.ensureInitialized();

    debugPrint('FlutterMate: doubleTapAt $position');

    // First tap
    await tapAt(position);
    // Short delay between taps (must be <300ms for double tap recognition)
    await FlutterMate.delay(const Duration(milliseconds: 100));
    // Second tap
    await tapAt(position);

    await FlutterMate.delay(const Duration(milliseconds: 50));
  }

  /// Internal gesture-based tap
  static Future<bool> tapGesture(String ref) async {
    final element = FlutterMate.cachedElements[ref];
    if (element == null) {
      debugPrint('FlutterMate: tapGesture - Element not found: $ref');
      return false;
    }

    RenderObject? ro = element.renderObject;
    while (ro != null && ro is! RenderBox) {
      if (ro is RenderObjectElement) {
        ro = (ro as RenderObjectElement).renderObject;
      } else {
        break;
      }
    }

    if (ro == null || ro is! RenderBox || !ro.hasSize) {
      debugPrint('FlutterMate: tapGesture - No RenderBox for: $ref');
      return false;
    }

    final box = ro;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    await tapAt(center);
    return true;
  }

  /// Long press via gesture simulation
  static Future<bool> longPressGesture(String ref) async {
    FlutterMate.ensureInitialized();

    final snap = SnapshotService.snapshot();
    final nodeInfo = snap[ref];
    if (nodeInfo == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    // Calculate center of element
    final centerPoint = nodeInfo.center;
    if (centerPoint == null) {
      debugPrint('FlutterMate: Node has no bounds: $ref');
      return false;
    }

    await longPressAt(Offset(centerPoint.x, centerPoint.y));
    return true;
  }

  /// Scroll using gesture simulation, staying within element bounds
  static Future<bool> scrollGestureByDirection(
      String ref, ScrollDirection direction, double distance) async {
    FlutterMate.ensureInitialized();

    // Find the semantics node directly (not through snapshot which is slow)
    final node = findSemanticsNode(ref);
    if (node == null) {
      debugPrint(
          'FlutterMate: scrollGestureByDirection - Node not found: $ref');
      return false;
    }

    // Get the node's rect in global coordinates
    final localRect = node.rect;
    final transform = node.transform;

    Offset topLeft = localRect.topLeft;
    Offset bottomRight = localRect.bottomRight;
    if (transform != null) {
      topLeft = MatrixUtils.transformPoint(transform, localRect.topLeft);
      bottomRight =
          MatrixUtils.transformPoint(transform, localRect.bottomRight);
    }

    final centerX = (topLeft.dx + bottomRight.dx) / 2;
    final topY = topLeft.dy + (bottomRight.dy - topLeft.dy) * 0.25;
    final bottomY = topLeft.dy + (bottomRight.dy - topLeft.dy) * 0.75;

    // User direction refers to content they want to see:
    // - "scroll down" = see content below = drag finger UP (bottom to top)
    // - "scroll up" = see content above = drag finger DOWN (top to bottom)
    final (Offset from, Offset to) = switch (direction) {
      ScrollDirection.down =>
        // See content below: swipe up (drag from bottom to top)
        (Offset(centerX, bottomY), Offset(centerX, topY)),
      ScrollDirection.up =>
        // See content above: swipe down (drag from top to bottom)
        (Offset(centerX, topY), Offset(centerX, bottomY)),
      ScrollDirection.left => () {
          // See content on left: swipe right
          final leftX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.25;
          final rightX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.75;
          final centerY = (topLeft.dy + bottomRight.dy) / 2;
          return (Offset(leftX, centerY), Offset(rightX, centerY));
        }(),
      ScrollDirection.right => () {
          // See content on right: swipe left
          final leftX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.25;
          final rightX = topLeft.dx + (bottomRight.dx - topLeft.dx) * 0.75;
          final centerY = (topLeft.dy + bottomRight.dy) / 2;
          return (Offset(rightX, centerY), Offset(leftX, centerY));
        }(),
    };

    debugPrint('FlutterMate: scrollGesture $direction from $from to $to');

    await drag(from: from, to: to);

    return true;
  }

  /// Simulate a tap at screen coordinates
  ///
  /// This sends real pointer events, mimicking actual user touch.
  /// ```dart
  /// await GestureActions.tapAt(Offset(100, 200));
  /// ```
  static Future<void> tapAt(Offset position) async {
    FlutterMate.ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Pointer down
    FlutterMate.dispatchPointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
    ));

    await FlutterMate.delay(const Duration(milliseconds: 50));

    // Pointer up
    FlutterMate.dispatchPointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + const Duration(milliseconds: 50),
    ));

    await FlutterMate.delay(const Duration(milliseconds: 50));
  }

  /// Simulate a drag/swipe gesture
  ///
  /// ```dart
  /// await GestureActions.drag(
  ///   from: Offset(200, 500),
  ///   to: Offset(200, 200),
  ///   duration: Duration(milliseconds: 300),
  /// );
  /// ```
  static Future<void> drag({
    required Offset from,
    required Offset to,
    Duration duration = const Duration(milliseconds: 200),
    int steps = 10,
  }) async {
    FlutterMate.ensureInitialized();

    final pointerId = ++_pointerIdCounter;
    final startTime =
        Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
    final stepDuration = duration ~/ steps;
    final totalDelta = to - from;
    final stepDelta = totalDelta / steps.toDouble();

    debugPrint('FlutterMate: drag from $from to $to');

    // Pointer down at start - use touch device kind for scrolling
    FlutterMate.dispatchPointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: from,
      timeStamp: startTime,
      kind: PointerDeviceKind.touch,
    ));

    await FlutterMate.delay(const Duration(milliseconds: 16));

    // Move through intermediate points with acceleration
    var currentPosition = from;
    for (var i = 1; i <= steps; i++) {
      currentPosition = from + stepDelta * i.toDouble();

      FlutterMate.dispatchPointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: stepDelta,
        timeStamp: startTime + stepDuration * i,
        kind: PointerDeviceKind.touch,
      ));

      await FlutterMate.delay(const Duration(milliseconds: 8));
    }

    // Quick final moves to add velocity
    for (var i = 0; i < 3; i++) {
      currentPosition = currentPosition + stepDelta * 0.5;
      FlutterMate.dispatchPointerEvent(PointerMoveEvent(
        pointer: pointerId,
        position: currentPosition,
        delta: stepDelta * 0.5,
        timeStamp: startTime + duration + Duration(milliseconds: i * 8),
        kind: PointerDeviceKind.touch,
      ));
      await FlutterMate.delay(const Duration(milliseconds: 8));
    }

    // Pointer up at end
    FlutterMate.dispatchPointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: currentPosition,
      timeStamp: startTime + duration + const Duration(milliseconds: 50),
      kind: PointerDeviceKind.touch,
    ));

    // Wait for scroll physics to settle
    await FlutterMate.delay(const Duration(milliseconds: 300));
  }

  /// Simulate a scroll gesture on an element
  ///
  /// ```dart
  /// await GestureActions.scrollGesture('w15', Offset(0, -200));
  /// ```
  static Future<bool> scrollGesture(String ref, Offset delta) async {
    FlutterMate.ensureInitialized();

    final snap = SnapshotService.snapshot();
    final node = snap[ref];
    if (node == null) {
      debugPrint('FlutterMate: scrollGesture - Node not found: $ref');
      return false;
    }

    final centerPoint = node.center;
    if (centerPoint == null) {
      debugPrint('FlutterMate: scrollGesture - Node has no bounds: $ref');
      return false;
    }

    final center = Offset(centerPoint.x, centerPoint.y);
    debugPrint(
        'FlutterMate: scrollGesture from $center delta $delta (to ${center + delta})');

    await drag(
      from: center,
      to: center + delta,
      duration: const Duration(milliseconds: 300),
    );

    // Wait for scroll physics to settle
    await FlutterMate.delay(const Duration(milliseconds: 100));

    return true;
  }

  /// Simulate a hover (mouse enter) over an element by ref
  ///
  /// Sends PointerHoverEvent to trigger onHover/onEnter callbacks.
  /// ```dart
  /// await GestureActions.hover('w15');
  /// ```
  static Future<bool> hover(String ref) async {
    FlutterMate.ensureInitialized();

    final snap = SnapshotService.snapshot();
    final nodeInfo = snap[ref];
    if (nodeInfo == null) {
      debugPrint('FlutterMate: Node not found: $ref');
      return false;
    }

    final centerPoint = nodeInfo.center;
    if (centerPoint == null) {
      debugPrint('FlutterMate: Node has no bounds: $ref');
      return false;
    }

    await hoverAt(Offset(centerPoint.x, centerPoint.y));
    return true;
  }

  /// Simulate a hover at specific coordinates
  ///
  /// Sends mouse enter and hover events to trigger hover callbacks.
  static Future<void> hoverAt(Offset position) async {
    FlutterMate.ensureInitialized();

    debugPrint('FlutterMate: hoverAt $position');

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Send hover event (mouse device kind required for hover)
    FlutterMate.dispatchPointerEvent(PointerHoverEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.mouse,
    ));

    await FlutterMate.delay(const Duration(milliseconds: 100));
  }

  /// Move mouse to position (for hover effects)
  static Future<void> mouseMoveTo(Offset position) async {
    FlutterMate.ensureInitialized();

    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    FlutterMate.dispatchPointerEvent(PointerHoverEvent(
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.mouse,
    ));

    await FlutterMate.delay(const Duration(milliseconds: 16));
  }

  /// Drag from one element to another
  ///
  /// ```dart
  /// await GestureActions.dragFromTo('w10', 'w20');
  /// ```
  static Future<bool> dragFromTo(String fromRef, String toRef) async {
    FlutterMate.ensureInitialized();

    final snap = SnapshotService.snapshot();
    final fromNode = snap[fromRef];
    final toNode = snap[toRef];

    if (fromNode == null) {
      debugPrint('FlutterMate: From node not found: $fromRef');
      return false;
    }
    if (toNode == null) {
      debugPrint('FlutterMate: To node not found: $toRef');
      return false;
    }

    final fromCenter = fromNode.center;
    final toCenter = toNode.center;
    if (fromCenter == null || toCenter == null) {
      debugPrint('FlutterMate: Nodes have no bounds');
      return false;
    }

    await drag(
      from: Offset(fromCenter.x, fromCenter.y),
      to: Offset(toCenter.x, toCenter.y),
    );
    return true;
  }

  /// Simulate a long press at screen coordinates
  static Future<void> longPressAt(
    Offset position, {
    Duration pressDuration = const Duration(milliseconds: 600),
  }) async {
    FlutterMate.ensureInitialized();

    debugPrint('FlutterMate: longPressAt $position');

    final pointerId = ++_pointerIdCounter;
    final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Pointer down - use touch for gesture recognition
    FlutterMate.dispatchPointerEvent(PointerDownEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now,
      kind: PointerDeviceKind.touch,
    ));

    // Hold for long press duration (must be >500ms for recognition)
    await FlutterMate.delay(pressDuration);

    // Pointer up
    FlutterMate.dispatchPointerEvent(PointerUpEvent(
      pointer: pointerId,
      position: position,
      timeStamp: now + pressDuration,
    ));

    await FlutterMate.delay(const Duration(milliseconds: 50));
  }

  /// Swipe gesture from a starting position in a direction
  ///
  /// [direction] - 'up', 'down', 'left', or 'right'
  /// [startX], [startY] - Starting position
  /// [distance] - Distance to swipe in pixels
  static Future<bool> swipe({
    required String direction,
    double startX = 200,
    double startY = 400,
    double distance = 200,
  }) async {
    FlutterMate.ensureInitialized();

    double endX = startX, endY = startY;
    switch (direction.toLowerCase()) {
      case 'up':
        endY = startY - distance;
      case 'down':
        endY = startY + distance;
      case 'left':
        endX = startX - distance;
      case 'right':
        endX = startX + distance;
      default:
        debugPrint('FlutterMate: Invalid swipe direction: $direction');
        return false;
    }

    await drag(
      from: Offset(startX, startY),
      to: Offset(endX, endY),
      duration: const Duration(milliseconds: 200),
    );

    return true;
  }
}

/// Double tap element by label (convenience method)
Future<bool> doubleTapByLabel(String label) async {
  final ref = await findByLabel(label);
  if (ref == null) {
    debugPrint(
        'FlutterMate: doubleTapByLabel - No element found with label: $label');
    return false;
  }
  return GestureActions.doubleTap(ref);
}
