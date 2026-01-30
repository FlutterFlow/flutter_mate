import 'dart:convert';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client that connects to a Flutter app via VM Service Protocol.
///
/// Communicates with a running Flutter app through the Dart VM Service,
/// calling FlutterMate service extensions to perform UI automation.
///
/// All actions (tap, scroll, type, etc.) are executed via registered
/// `ext.flutter_mate.*` service extensions in the SDK.
class VmServiceClient {
  VmService? _service;
  String? _mainIsolateId;
  final String wsUri;

  /// Whether semantics has been ensured for this session.
  bool _semanticsEnsured = false;

  VmServiceClient(this.wsUri);

  /// Connect to the Flutter app's VM Service
  Future<void> connect() async {
    _service = await vmServiceConnectUri(wsUri);

    // Get the main isolate
    final vm = await _service!.getVM();
    for (final isolate in vm.isolates ?? []) {
      if (isolate.name == 'main') {
        _mainIsolateId = isolate.id;
        break;
      }
    }

    // If no 'main' isolate, use the first one
    _mainIsolateId ??= vm.isolates?.first.id;

    if (_mainIsolateId == null) {
      throw Exception('No isolates found');
    }
  }

  /// Disconnect from the VM Service
  Future<void> disconnect() async {
    await _service?.dispose();
    _service = null;
    _semanticsEnsured = false;
  }

  /// List available service extensions
  Future<List<String>> listServiceExtensions() async {
    _ensureConnected();

    final isolate = await _service!.getIsolate(_mainIsolateId!);
    return isolate.extensionRPCs ?? [];
  }

  /// Call a service extension by name
  Future<Map<String, dynamic>> callExtension(
    String extension, {
    Map<String, String>? args,
  }) async {
    _ensureConnected();

    try {
      final result = await _service!.callServiceExtension(
        extension,
        isolateId: _mainIsolateId,
        args: args,
      );

      // Parse the inner result from the service extension
      final innerResult = result.json?['result'] ?? result.json;
      Map<String, dynamic> parsed;

      if (innerResult is String) {
        try {
          parsed = jsonDecode(innerResult) as Map<String, dynamic>;
        } catch (_) {
          parsed = {'success': true, 'result': innerResult};
        }
      } else if (innerResult is Map) {
        parsed = Map<String, dynamic>.from(innerResult);
      } else {
        parsed = {'success': true, 'result': innerResult};
      }

      // Propagate the inner success status
      return {
        'success': parsed['success'] ?? true,
        if (parsed['error'] != null) 'error': parsed['error'],
        'result': parsed,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COORDINATE-BASED ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Ensure semantics tree is available (call once per session).
  Future<bool> ensureSemantics() async {
    if (_semanticsEnsured) return true;

    final result = await callExtension('ext.flutter_mate.ensureSemantics');
    _semanticsEnsured = result['success'] == true;
    return _semanticsEnsured;
  }

  /// Get UI snapshot via FlutterMate service extension
  ///
  /// Returns widget tree with semantics. Requires FlutterMate.initialize() in the app.
  ///
  /// Options:
  /// - [compact]: Only returns nodes with meaningful info (text, semantics,
  ///   actions, flags). This significantly reduces response size.
  /// - [depth]: Limit tree depth. Useful for large UIs.
  /// - [fromRef]: Start from specific element as root. Requires prior snapshot.
  /// - [json]: If true, returns raw JSON nodes (for `--json` output).
  ///   If false (default), returns pre-formatted text lines for display.
  Future<Map<String, dynamic>> getSnapshot({
    bool compact = false,
    int? depth,
    String? fromRef,
    bool json = false,
  }) async {
    _ensureConnected();

    final args = <String, String>{};
    if (compact) args['compact'] = 'true';
    if (depth != null) args['depth'] = depth.toString();
    if (fromRef != null) args['fromRef'] = fromRef;
    if (json) args['json'] = 'true';

    final result = await callExtension(
      'ext.flutter_mate.snapshot',
      args: args.isNotEmpty ? args : null,
    );

    if (result['success'] == true) {
      final data = result['result'];
      Map<String, dynamic> snapshotData;
      if (data is String) {
        snapshotData = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        snapshotData = Map<String, dynamic>.from(data);
      } else {
        return {'success': false, 'error': 'Invalid response format'};
      }

      // Check if formatted output was requested
      if (snapshotData['formatted'] == true) {
        final lines = snapshotData['lines'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'formatted': true,
          'lines': lines.cast<String>(),
        };
      }

      // Extract nodes from snapshot (raw JSON mode)
      final nodes = snapshotData['nodes'] as List<dynamic>? ?? [];
      _cachedNodes =
          nodes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return {'success': true, 'nodes': _cachedNodes};
    }

    return {
      'success': false,
      'error': result['error'] ?? 'Extension not available'
    };
  }

  /// Type text into a widget using keyboard simulation.
  ///
  /// [ref] - Widget ref (e.g., w10 for TextField)
  /// [text] - Text to type
  Future<Map<String, dynamic>> typeText(String ref, String text) async {
    return callExtension('ext.flutter_mate.typeText',
        args: {'ref': ref, 'text': text});
  }

  /// Clear the focused text field
  Future<Map<String, dynamic>> clearText() async {
    return callExtension('ext.flutter_mate.clearText');
  }

  /// Press a keyboard key.
  Future<Map<String, dynamic>> pressKey(String key) async {
    return callExtension('ext.flutter_mate.pressKey', args: {'key': key});
  }

  /// Tap at screen coordinates.
  Future<Map<String, dynamic>> tapAt(double x, double y) async {
    return callExtension('ext.flutter_mate.tapAt', args: {
      'x': x.toString(),
      'y': y.toString(),
    });
  }

  /// Perform a swipe gesture.
  Future<Map<String, dynamic>> swipe({
    required String direction,
    double startX = 200,
    double startY = 400,
    double distance = 200,
  }) async {
    return callExtension('ext.flutter_mate.swipe', args: {
      'direction': direction,
      'startX': startX.toString(),
      'startY': startY.toString(),
      'distance': distance.toString(),
    });
  }

  /// Double tap at coordinates.
  Future<Map<String, dynamic>> doubleTapAt(double x, double y) async {
    return callExtension('ext.flutter_mate.doubleTapAt', args: {
      'x': x.toString(),
      'y': y.toString(),
    });
  }

  /// Long press at coordinates.
  Future<Map<String, dynamic>> longPressAt(double x, double y,
      {int durationMs = 500}) async {
    return callExtension('ext.flutter_mate.longPressAt', args: {
      'x': x.toString(),
      'y': y.toString(),
      'durationMs': durationMs.toString(),
    });
  }

  /// Hover at coordinates (triggers onHover/onEnter).
  Future<Map<String, dynamic>> hoverAt(double x, double y) async {
    return callExtension('ext.flutter_mate.hoverAt', args: {
      'x': x.toString(),
      'y': y.toString(),
    });
  }

  /// Drag from one point to another.
  Future<Map<String, dynamic>> dragTo({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
  }) async {
    return callExtension('ext.flutter_mate.dragTo', args: {
      'fromX': fromX.toString(),
      'fromY': fromY.toString(),
      'toX': toX.toString(),
      'toY': toY.toString(),
    });
  }

  /// Press key down (without releasing).
  Future<Map<String, dynamic>> keyDown(
    String key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
    bool command = false,
  }) async {
    return callExtension('ext.flutter_mate.keyDown', args: {
      'key': key,
      if (control) 'control': 'true',
      if (shift) 'shift': 'true',
      if (alt) 'alt': 'true',
      if (command) 'command': 'true',
    });
  }

  /// Release a key.
  Future<Map<String, dynamic>> keyUp(
    String key, {
    bool control = false,
    bool shift = false,
    bool alt = false,
    bool command = false,
  }) async {
    return callExtension('ext.flutter_mate.keyUp', args: {
      'key': key,
      if (control) 'control': 'true',
      if (shift) 'shift': 'true',
      if (alt) 'alt': 'true',
      if (command) 'command': 'true',
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REF-BASED ACTIONS
  // These find an element by its ref (from semantics tree) and perform actions.
  // ══════════════════════════════════════════════════════════════════════════

  /// Cache of semantics nodes for ref lookup
  List<Map<String, dynamic>>? _cachedNodes;

  /// Refresh snapshot cache (used by waitFor for polling)
  Future<void> _refreshSnapshot() async {
    // Request raw JSON nodes (not formatted lines) for searching
    final result = await getSnapshot(json: true);
    if (result['success'] == true) {
      _cachedNodes =
          (result['nodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
    }
  }

  /// Tap on an element by ref.
  ///
  /// Tries semantic tap first, falls back to gesture-based tap if needed.
  Future<Map<String, dynamic>> tap(String ref) async {
    return callExtension('ext.flutter_mate.tap', args: {'ref': ref});
  }

  /// Set text on a field by ref using semantic action.
  Future<Map<String, dynamic>> setText(String ref, String text) async {
    return callExtension('ext.flutter_mate.setText',
        args: {'ref': ref, 'text': text});
  }

  /// Focus on an element by ref
  Future<Map<String, dynamic>> focus(String ref) async {
    return callExtension('ext.flutter_mate.focus', args: {'ref': ref});
  }

  /// Scroll an element by ref
  Future<Map<String, dynamic>> scroll(String ref, String direction) async {
    return callExtension('ext.flutter_mate.scroll',
        args: {'ref': ref, 'direction': direction});
  }

  /// Long press on an element by ref
  Future<Map<String, dynamic>> longPress(String ref) async {
    return callExtension('ext.flutter_mate.longPress', args: {'ref': ref});
  }

  /// Double tap on an element by ref
  Future<Map<String, dynamic>> doubleTap(String ref) async {
    return callExtension('ext.flutter_mate.doubleTap', args: {'ref': ref});
  }

  /// Hover over an element by ref (triggers onHover/onEnter)
  Future<Map<String, dynamic>> hover(String ref) async {
    return callExtension('ext.flutter_mate.hover', args: {'ref': ref});
  }

  /// Drag from one element to another by refs
  Future<Map<String, dynamic>> drag(String fromRef, String toRef) async {
    return callExtension('ext.flutter_mate.drag',
        args: {'fromRef': fromRef, 'toRef': toRef});
  }

  /// Get detailed info about a specific element by ref
  ///
  /// Returns the full element data including bounds, semantics, text content.
  /// Find an element by ref and get detailed info.
  ///
  /// Options:
  /// - [format]: If true (default), returns pre-formatted text lines for display.
  /// Get detailed info about a specific element.
  /// - [json]: If true, returns raw JSON. If false (default), returns formatted lines.
  Future<Map<String, dynamic>> find(String ref, {bool json = false}) async {
    final args = <String, String>{'ref': ref};
    if (json) args['json'] = 'true';
    return callExtension('ext.flutter_mate.find', args: args);
  }

  /// Get text from an element by ref.
  ///
  /// Uses the `find` extension to get fresh data from the app.
  /// Returns textContent, semantic label, and semantic value.
  Future<Map<String, dynamic>> getText(String ref) async {
    final result = await find(ref);
    if (result['success'] != true) {
      return result;
    }

    final element = result['result']?['element'] as Map<String, dynamic>?;
    if (element == null) {
      return {'success': false, 'error': 'Element not found: $ref'};
    }

    final textContent = element['textContent'] as String?;
    final semantics = element['semantics'] as Map<String, dynamic>?;
    final label = semantics?['label'] as String?;
    final value = semantics?['value'] as String?;

    return {
      'success': true,
      'text': textContent ?? label ?? value ?? '',
      'textContent': textContent,
      'label': label,
      'value': value,
    };
  }

  /// Wait for an element with matching text to appear.
  ///
  /// Polls the snapshot until an element with text matching the pattern
  /// is found, or timeout is reached.
  ///
  /// Searches (in order):
  /// - `textContent` (from Text/RichText widgets)
  /// - `semantics.label`
  /// - `semantics.value`
  /// - `semantics.hint`
  ///
  /// Returns `{success: true, ref, matchedText}` or `{success: false, error}`.
  Future<Map<String, dynamic>> waitFor(
    String labelPattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    _ensureConnected();

    final pattern = RegExp(labelPattern, caseSensitive: false);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Refresh snapshot cache
      await _refreshSnapshot();

      // Search for matching node
      final match = _findMatchingNode(pattern);
      if (match != null) {
        return match;
      }

      await Future.delayed(pollInterval);
    }

    return {
      'success': false,
      'error': 'Timeout waiting for element matching: $labelPattern'
    };
  }

  /// Wait for an element to disappear (no longer match the pattern).
  ///
  /// Polls the snapshot until no element matches the pattern, or timeout.
  /// Useful for waiting for loading spinners, dialogs, or overlays to go away.
  ///
  /// Returns `{success: true}` when element is gone, or `{success: false, error}`.
  Future<Map<String, dynamic>> waitForDisappear(
    String labelPattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    _ensureConnected();

    final pattern = RegExp(labelPattern, caseSensitive: false);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Refresh snapshot cache
      await _refreshSnapshot();

      // Check if any node still matches
      final match = _findMatchingNode(pattern);
      if (match == null) {
        // No match found - element has disappeared
        return {'success': true};
      }

      await Future.delayed(pollInterval);
    }

    return {
      'success': false,
      'error': 'Timeout waiting for element to disappear: $labelPattern'
    };
  }

  /// Wait for a specific element's value/text to match a pattern.
  ///
  /// Polls the element until its text content or semantic value matches,
  /// or timeout is reached. Useful for waiting for form validation,
  /// async data loading, or state changes.
  ///
  /// [ref] - The element ref to watch
  /// [valuePattern] - Regex pattern to match against the element's text/value
  ///
  /// Returns `{success: true, matchedText}` or `{success: false, error}`.
  Future<Map<String, dynamic>> waitForValue(
    String ref,
    String valuePattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    _ensureConnected();

    final pattern = RegExp(valuePattern, caseSensitive: false);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Get fresh data for the element
      final result = await find(ref);
      if (result['success'] != true) {
        await Future.delayed(pollInterval);
        continue;
      }

      final element = result['result']?['element'] as Map<String, dynamic>?;
      if (element == null) {
        await Future.delayed(pollInterval);
        continue;
      }

      // Check textContent
      final textContent = element['textContent'] as String?;
      if (textContent != null && pattern.hasMatch(textContent)) {
        return {'success': true, 'matchedText': textContent};
      }

      // Check semantics value
      final semantics = element['semantics'] as Map<String, dynamic>?;
      if (semantics != null) {
        final value = semantics['value'] as String?;
        if (value != null && pattern.hasMatch(value)) {
          return {'success': true, 'matchedText': value};
        }

        final label = semantics['label'] as String?;
        if (label != null && pattern.hasMatch(label)) {
          return {'success': true, 'matchedText': label};
        }
      }

      await Future.delayed(pollInterval);
    }

    return {
      'success': false,
      'error': 'Timeout waiting for $ref to match: $valuePattern'
    };
  }

  /// Helper to find a node matching a pattern in the cached snapshot.
  Map<String, dynamic>? _findMatchingNode(RegExp pattern) {
    for (final node in _cachedNodes ?? []) {
      final ref = node['ref'] as String?;

      // Check textContent first (text from Text/RichText widgets)
      final textContent = node['textContent'] as String?;
      if (textContent != null && pattern.hasMatch(textContent)) {
        return {'success': true, 'ref': ref, 'matchedText': textContent};
      }

      // Check semantics fields
      final semantics = node['semantics'] as Map<String, dynamic>?;
      if (semantics != null) {
        final label = semantics['label'] as String?;
        if (label != null && pattern.hasMatch(label)) {
          return {'success': true, 'ref': ref, 'matchedText': label};
        }

        final value = semantics['value'] as String?;
        if (value != null && pattern.hasMatch(value)) {
          return {'success': true, 'ref': ref, 'matchedText': value};
        }

        final hint = semantics['hint'] as String?;
        if (hint != null && pattern.hasMatch(hint)) {
          return {'success': true, 'ref': ref, 'matchedText': hint};
        }
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _ensureConnected() {
    if (_service == null) {
      throw StateError('Not connected. Call connect() first.');
    }
  }
}

/// Parse a Flutter debug service URL from console output
String? parseVmServiceUri(String consoleOutput) {
  final wsPattern = RegExp(r'ws://[^\s]+');
  final httpPattern = RegExp(r'http://127\.0\.0\.1:\d+/[^\s]+');

  final wsMatch = wsPattern.firstMatch(consoleOutput);
  if (wsMatch != null) {
    return wsMatch.group(0);
  }

  final httpMatch = httpPattern.firstMatch(consoleOutput);
  if (httpMatch != null) {
    var url = httpMatch.group(0)!;
    url = url.replaceFirst('http://', 'ws://');
    if (!url.endsWith('/ws')) {
      url = url.endsWith('/') ? '${url}ws' : '$url/ws';
    }
    return url;
  }

  return null;
}
