import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';

import '../actions/semantic_actions.dart';
import '../actions/gesture_actions.dart';
import '../actions/keyboard_actions.dart';
import '../snapshot/snapshot.dart';
import '../snapshot/screenshot.dart';

/// VM Service extensions for external control via CLI/MCP.
///
/// Registers `ext.flutter_mate.*` service extensions that allow external
/// tools to control Flutter apps through the Dart VM Service Protocol.
///
/// ## Available Extensions
///
/// **Snapshot:**
/// - `ext.flutter_mate.snapshot` - Get UI tree with widget refs and semantics
/// - `ext.flutter_mate.find` - Get detailed info about a specific element
///
/// **Ref-based actions (use widget ref from snapshot):**
/// - `ext.flutter_mate.tap` - Tap element (semantic + gesture fallback)
/// - `ext.flutter_mate.setText` - Set text via semantic action
/// - `ext.flutter_mate.scroll` - Scroll element in a direction
/// - `ext.flutter_mate.focus` - Focus element
/// - `ext.flutter_mate.longPress` - Long press element
/// - `ext.flutter_mate.doubleTap` - Double tap element
/// - `ext.flutter_mate.typeText` - Type text via keyboard simulation
/// - `ext.flutter_mate.hover` - Hover over element (triggers onHover)
/// - `ext.flutter_mate.drag` - Drag from one element to another
///
/// **Coordinate-based actions:**
/// - `ext.flutter_mate.tapAt` - Tap at screen coordinates
/// - `ext.flutter_mate.doubleTapAt` - Double tap at coordinates
/// - `ext.flutter_mate.longPressAt` - Long press at coordinates
/// - `ext.flutter_mate.hoverAt` - Hover at coordinates
/// - `ext.flutter_mate.dragTo` - Drag from one point to another
/// - `ext.flutter_mate.swipe` - Swipe gesture from a start position
///
/// **Keyboard:**
/// - `ext.flutter_mate.pressKey` - Press a keyboard key (keydown + keyup)
/// - `ext.flutter_mate.keyDown` - Press key down (without releasing)
/// - `ext.flutter_mate.keyUp` - Release a key
/// - `ext.flutter_mate.clearText` - Clear focused text field
///
/// **Utilities:**
/// - `ext.flutter_mate.ensureSemantics` - Enable semantics tree
class FlutterMateServiceExtensions {
  static bool _registered = false;

  /// Register all service extensions
  static void register() {
    // Only register once (extensions persist across test runs in same VM)
    if (_registered) return;

    // Only register in debug/profile mode
    assert(() {
      // ext.flutter_mate.tap - Tap element by ref
      registerExtension('ext.flutter_mate.tap', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await SemanticActions.tap(ref);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'tap failed: element may not support tap action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.setText - Set text on element (semantic action)
      registerExtension('ext.flutter_mate.setText', (method, params) async {
        final ref = params['ref'];
        final text = params['text'];
        if (ref == null || text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref or text parameter',
          );
        }
        final success = await SemanticActions.setText(ref, text);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'setText failed: element may not support setText action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.scroll - Scroll element
      registerExtension('ext.flutter_mate.scroll', (method, params) async {
        final ref = params['ref'];
        final dirStr = params['direction'] ?? 'down';
        final distanceStr = params['distance'];
        final distance =
            distanceStr != null ? double.tryParse(distanceStr) ?? 300.0 : 300.0;
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final direction = switch (dirStr) {
          'up' => ScrollDirection.up,
          'left' => ScrollDirection.left,
          'right' => ScrollDirection.right,
          _ => ScrollDirection.down,
        };
        final success =
            await SemanticActions.scroll(ref, direction, distance: distance);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'scroll failed: element may not support scroll action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.focus - Focus element
      registerExtension('ext.flutter_mate.focus', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await SemanticActions.focus(ref);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'focus failed: element may not support focus action',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.snapshot - Get UI snapshot (widget tree + semantics)
      // Options:
      //   compact=true - filter to only nodes with meaningful info
      //   depth=N - limit tree depth
      //   fromRef=wX - start from specific element as root
      registerExtension('ext.flutter_mate.snapshot', (method, params) async {
        final compact = params['compact'] == 'true';
        final depthStr = params['depth'];
        final maxDepth = depthStr != null ? int.tryParse(depthStr) : null;
        final fromRef = params['fromRef'];
        
        final snap = await SnapshotService.snapshot(
          compact: compact,
          maxDepth: maxDepth,
          fromRef: fromRef,
        );
        return ServiceExtensionResponse.result(jsonEncode(snap.toJson()));
      });

      // ext.flutter_mate.longPress - Long press element by ref
      registerExtension('ext.flutter_mate.longPress', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await SemanticActions.longPress(ref);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'longPress failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.doubleTap - Double tap element by ref
      registerExtension('ext.flutter_mate.doubleTap', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await GestureActions.doubleTap(ref);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'doubleTap failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.typeText - Type text into a text field by ref
      registerExtension('ext.flutter_mate.typeText', (method, params) async {
        final ref = params['ref'];
        final text = params['text'];
        if (ref == null || text == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref or text parameter',
          );
        }
        final success = await KeyboardActions.typeText(ref, text);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'typeText failed: element not found or not a text field',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.clearText - Clear focused text field
      registerExtension('ext.flutter_mate.clearText', (method, params) async {
        final success = await KeyboardActions.clearText();
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.pressKey - Press a keyboard key
      registerExtension('ext.flutter_mate.pressKey', (method, params) async {
        final key = params['key'];
        if (key == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing key parameter',
          );
        }
        final logicalKey = KeyboardActions.parseLogicalKey(key);
        if (logicalKey == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Unknown key: $key',
          );
        }
        final success = await KeyboardActions.pressKey(logicalKey);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.ensureSemantics - Ensure semantics tree is available
      registerExtension('ext.flutter_mate.ensureSemantics',
          (method, params) async {
        try {
          WidgetsBinding.instance.ensureSemantics();
          return ServiceExtensionResponse.result(jsonEncode({'success': true}));
        } catch (e) {
          return ServiceExtensionResponse.result(
              jsonEncode({'success': false, 'error': e.toString()}));
        }
      });

      // ext.flutter_mate.tapAt - Tap at screen coordinates
      registerExtension('ext.flutter_mate.tapAt', (method, params) async {
        final x = double.tryParse(params['x'] ?? '');
        final y = double.tryParse(params['y'] ?? '');
        if (x == null || y == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing or invalid x/y coordinates',
          );
        }
        await GestureActions.tapAt(Offset(x, y));
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.doubleTapAt - Double tap at screen coordinates
      registerExtension('ext.flutter_mate.doubleTapAt', (method, params) async {
        final x = double.tryParse(params['x'] ?? '');
        final y = double.tryParse(params['y'] ?? '');
        if (x == null || y == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing or invalid x/y coordinates',
          );
        }
        await GestureActions.doubleTapAt(Offset(x, y));
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.longPressAt - Long press at screen coordinates
      registerExtension('ext.flutter_mate.longPressAt', (method, params) async {
        final x = double.tryParse(params['x'] ?? '');
        final y = double.tryParse(params['y'] ?? '');
        final durationMs = int.tryParse(params['durationMs'] ?? '500') ?? 500;
        if (x == null || y == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing or invalid x/y coordinates',
          );
        }
        await GestureActions.longPressAt(Offset(x, y),
            pressDuration: Duration(milliseconds: durationMs));
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.swipe - Swipe gesture
      registerExtension('ext.flutter_mate.swipe', (method, params) async {
        final direction = params['direction'] ?? 'up';
        final startX = double.tryParse(params['startX'] ?? '200') ?? 200;
        final startY = double.tryParse(params['startY'] ?? '400') ?? 400;
        final distance = double.tryParse(params['distance'] ?? '200') ?? 200;

        final success = await GestureActions.swipe(
          direction: direction,
          startX: startX,
          startY: startY,
          distance: distance,
        );
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.hover - Hover over element by ref
      registerExtension('ext.flutter_mate.hover', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }
        final success = await GestureActions.hover(ref);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'hover failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.hoverAt - Hover at screen coordinates
      registerExtension('ext.flutter_mate.hoverAt', (method, params) async {
        final x = double.tryParse(params['x'] ?? '');
        final y = double.tryParse(params['y'] ?? '');
        if (x == null || y == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing or invalid x/y coordinates',
          );
        }
        await GestureActions.hoverAt(Offset(x, y));
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.drag - Drag from one element to another by refs
      registerExtension('ext.flutter_mate.drag', (method, params) async {
        final fromRef = params['fromRef'];
        final toRef = params['toRef'];
        if (fromRef == null || toRef == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing fromRef or toRef parameter',
          );
        }
        final success = await GestureActions.dragFromTo(fromRef, toRef);
        if (!success) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'drag failed: element not found or no bounds',
          }));
        }
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.dragTo - Drag from one point to another
      registerExtension('ext.flutter_mate.dragTo', (method, params) async {
        final fromX = double.tryParse(params['fromX'] ?? '');
        final fromY = double.tryParse(params['fromY'] ?? '');
        final toX = double.tryParse(params['toX'] ?? '');
        final toY = double.tryParse(params['toY'] ?? '');
        if (fromX == null || fromY == null || toX == null || toY == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing or invalid coordinates',
          );
        }
        await GestureActions.drag(
          from: Offset(fromX, fromY),
          to: Offset(toX, toY),
        );
        return ServiceExtensionResponse.result(jsonEncode({'success': true}));
      });

      // ext.flutter_mate.keyDown - Press key down (without releasing)
      registerExtension('ext.flutter_mate.keyDown', (method, params) async {
        final key = params['key'];
        if (key == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing key parameter',
          );
        }
        final logicalKey = KeyboardActions.parseLogicalKey(key);
        if (logicalKey == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Unknown key: $key',
          );
        }
        final control = params['control'] == 'true';
        final shift = params['shift'] == 'true';
        final alt = params['alt'] == 'true';
        final command = params['command'] == 'true';

        final success = await KeyboardActions.keyDown(logicalKey,
            control: control, shift: shift, alt: alt, command: command);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.keyUp - Release a key
      registerExtension('ext.flutter_mate.keyUp', (method, params) async {
        final key = params['key'];
        if (key == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing key parameter',
          );
        }
        final logicalKey = KeyboardActions.parseLogicalKey(key);
        if (logicalKey == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Unknown key: $key',
          );
        }
        final control = params['control'] == 'true';
        final shift = params['shift'] == 'true';
        final alt = params['alt'] == 'true';
        final command = params['command'] == 'true';

        final success = await KeyboardActions.keyUp(logicalKey,
            control: control, shift: shift, alt: alt, command: command);
        return ServiceExtensionResponse.result(
            jsonEncode({'success': success}));
      });

      // ext.flutter_mate.find - Get detailed info about a specific element
      registerExtension('ext.flutter_mate.find', (method, params) async {
        final ref = params['ref'];
        if (ref == null) {
          return ServiceExtensionResponse.error(
            ServiceExtensionResponse.invalidParams,
            'Missing ref parameter',
          );
        }

        final snap = await SnapshotService.snapshot();
        final node = snap[ref];
        if (node == null) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'Element not found: $ref',
          }));
        }

        return ServiceExtensionResponse.result(jsonEncode({
          'success': true,
          'element': node.toJson(),
        }));
      });

      // ext.flutter_mate.screenshot - Capture screenshot of entire app
      registerExtension('ext.flutter_mate.screenshot', (method, params) async {
        final ref = params['ref'];
        final pixelRatio =
            double.tryParse(params['pixelRatio'] ?? '1.0') ?? 1.0;

        String? base64;
        if (ref != null && ref.isNotEmpty) {
          // Capture specific element
          base64 = await ScreenshotService.captureElementAsBase64(ref,
              pixelRatio: pixelRatio);
        } else {
          // Capture full screen
          base64 = await ScreenshotService.captureAsBase64(pixelRatio: pixelRatio);
        }

        if (base64 == null) {
          return ServiceExtensionResponse.result(jsonEncode({
            'success': false,
            'error': 'Screenshot capture failed',
          }));
        }

        return ServiceExtensionResponse.result(jsonEncode({
          'success': true,
          'image': base64,
          'format': 'png',
          'encoding': 'base64',
        }));
      });

      _registered = true;
      debugPrint('FlutterMate: Service extensions registered');
      return true;
    }());
  }
}

/// Scroll direction for scroll actions
enum ScrollDirection { up, down, left, right }
