import 'dart:convert';
import 'dart:developer';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../actions/semantic_actions.dart';
import '../actions/gesture_actions.dart';
import '../actions/keyboard_actions.dart';
import '../snapshot/snapshot.dart';
import 'semantics_utils.dart';

/// VM Service extensions for external control via CLI
///
/// These extensions are registered with prefix `ext.flutter_mate.*`
/// and allow external tools to control the app.
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
      registerExtension('ext.flutter_mate.snapshot', (method, params) async {
        final snap = await SnapshotService.snapshot();
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

      // ext.flutter_mate.debugTrees - Get both trees for debugging
      registerExtension('ext.flutter_mate.debugTrees', (method, params) async {
        final result = await _getDebugTrees();
        return ServiceExtensionResponse.result(jsonEncode(result));
      });

      _registered = true;
      debugPrint('FlutterMate: Service extensions registered');
      return true;
    }());
  }

  /// Get both inspector tree and semantics tree for debugging/matching
  static Future<Map<String, dynamic>> _getDebugTrees() async {
    // Get inspector summary tree
    final service = WidgetInspectorService.instance;
    final inspectorJson =
        service.getRootWidgetSummaryTree('flutter_mate_debug');
    final inspectorTree = jsonDecode(inspectorJson) as Map<String, dynamic>?;

    // Get semantics tree using shared utility
    final semanticsNodes = <Map<String, dynamic>>[];
    final rootNode = getRootSemanticsNode();

    if (rootNode != null) {
      void walkSemantics(SemanticsNode node, int depth) {
        final data = node.getSemanticsData();
        final rect = node.rect;
        final transform = node.transform;

        Offset? globalTopLeft;
        if (transform != null) {
          globalTopLeft = MatrixUtils.transformPoint(transform, rect.topLeft);
        }

        semanticsNodes.add({
          'id': node.id,
          'depth': depth,
          'label': data.label.isNotEmpty ? data.label : null,
          'value': data.value.isNotEmpty ? data.value : null,
          'hint': data.hint.isNotEmpty ? data.hint : null,
          'rect': {
            'x': globalTopLeft?.dx ?? rect.left,
            'y': globalTopLeft?.dy ?? rect.top,
            'width': rect.width,
            'height': rect.height,
          },
          'actions': getActionsFromData(data),
          'flags': getFlagsFromData(data),
        });

        node.visitChildren((child) {
          walkSemantics(child, depth + 1);
          return true;
        });
      }

      walkSemantics(rootNode, 0);
    }

    return {
      'inspectorTree': inspectorTree,
      'semanticsNodes': semanticsNodes,
    };
  }
}

/// Scroll direction for scroll actions
enum ScrollDirection { up, down, left, right }
