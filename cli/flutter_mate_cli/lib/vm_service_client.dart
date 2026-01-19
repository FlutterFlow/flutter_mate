import 'dart:async';
import 'dart:convert';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client that connects to a Flutter app via VM Service Protocol
///
/// This allows controlling Flutter apps externally through
/// the Dart VM Service - NO code changes required in the app!
class VmServiceClient {
  VmService? _service;
  String? _mainIsolateId;
  final String wsUri;

  /// Whether semantics has been ensured for this session.
  bool _semanticsEnsured = false;

  VmServiceClient(this.wsUri);

  /// Connect to the Flutter app's VM Service
  Future<void> connect() async {
    print('Connecting to VM Service at $wsUri...');
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

    print('Connected! Main isolate: $_mainIsolateId');
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
  // PURE VM SERVICE METHODS (No custom extensions needed!)
  // ══════════════════════════════════════════════════════════════════════════

  /// Ensure semantics tree is available (call once per session).
  Future<bool> ensureSemantics() async {
    if (_semanticsEnsured) return true;

    try {
      // Use WidgetsBinding which includes RendererBinding mixin
      final result =
          await evaluate('WidgetsBinding.instance.ensureSemantics()');
      _semanticsEnsured = result != null;
      return _semanticsEnsured;
    } catch (e) {
      print('Note: ensureSemantics: $e');
      // Semantics might already be active
      _semanticsEnsured = true;
      return true;
    }
  }

  /// Get UI snapshot via FlutterMate service extension
  ///
  /// Returns widget tree with semantics. Requires FlutterMate.initialize() in the app.
  Future<Map<String, dynamic>> getSnapshot() async {
    _ensureConnected();

    final result = await callExtension('ext.flutter_mate.snapshot');

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

      // Extract nodes from snapshot
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
    try {
      // Pointer down
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerDownEvent(position: Offset($x, $y), pointer: 1))');
      // Pointer up
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerUpEvent(position: Offset($x, $y), pointer: 1))');
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Perform a swipe gesture.
  Future<Map<String, dynamic>> swipe({
    required String direction,
    double startX = 200,
    double startY = 400,
    double distance = 200,
  }) async {
    try {
      // Calculate end position
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
      }

      // Pointer down at start
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerDownEvent(position: Offset($startX, $startY), pointer: 1))');

      // Move in steps
      const steps = 5;
      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;
        await evaluate('WidgetsBinding.instance.handlePointerEvent('
            'PointerMoveEvent(position: Offset($x, $y), pointer: 1, '
            'delta: Offset(${(endX - startX) / steps}, ${(endY - startY) / steps})))');
        await Future.delayed(const Duration(milliseconds: 16));
      }

      // Pointer up at end
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerUpEvent(position: Offset($endX, $endY), pointer: 1))');

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Double tap at coordinates.
  Future<Map<String, dynamic>> doubleTapAt(double x, double y) async {
    await tapAt(x, y);
    await Future.delayed(const Duration(milliseconds: 50));
    return tapAt(x, y);
  }

  /// Long press at coordinates.
  Future<Map<String, dynamic>> longPressAt(double x, double y,
      {int durationMs = 500}) async {
    try {
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerDownEvent(position: Offset($x, $y), pointer: 1))');
      await Future.delayed(Duration(milliseconds: durationMs));
      await evaluate('WidgetsBinding.instance.handlePointerEvent('
          'PointerUpEvent(position: Offset($x, $y), pointer: 1))');
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REF-BASED ACTIONS
  // These find an element by its ref (from semantics tree) and perform actions.
  // ══════════════════════════════════════════════════════════════════════════

  /// Cache of semantics nodes for ref lookup
  List<Map<String, dynamic>>? _cachedNodes;

  /// Refresh snapshot cache
  Future<void> _refreshSnapshot() async {
    final result = await getSnapshot();
    if (result['success'] == true) {
      _cachedNodes =
          (result['nodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
    }
  }

  /// Find a semantics node by ref
  Future<Map<String, dynamic>?> _findNodeByRef(String ref) async {
    if (_cachedNodes == null) {
      await _refreshSnapshot();
    }

    // Clean ref: "s5" -> look for ref "s5" or id 5
    final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;

    for (final node in _cachedNodes ?? []) {
      if (node['ref'] == cleanRef) return node;
      // Also try matching by id
      final id = node['id'];
      if (id != null && 's$id' == cleanRef) return node;
    }

    // Refresh and try again
    await _refreshSnapshot();
    for (final node in _cachedNodes ?? []) {
      if (node['ref'] == cleanRef) return node;
    }

    return null;
  }

  /// Tap on an element by ref (semantic action)
  Future<Map<String, dynamic>> tap(String ref) async {
    return callExtension('ext.flutter_mate.tap', args: {'ref': ref});
  }

  /// Tap on an element by ref using pointer events (gesture-based)
  /// Use this for widgets without semantic tap support (e.g., NavigationDestination)
  /// @deprecated Use tap() instead - it now auto-falls back to gesture
  @Deprecated('Use tap() instead')
  Future<Map<String, dynamic>> tapGesture(String ref) async {
    // Just call tap - it handles both semantic and gesture
    return tap(ref);
  }

  /// Set text on a field by ref (semantic action)
  Future<Map<String, dynamic>> setText(String ref, String text) async {
    return callExtension('ext.flutter_mate.setText',
        args: {'ref': ref, 'text': text});
  }

  /// @deprecated Use setText() instead
  @Deprecated('Use setText() instead')
  Future<Map<String, dynamic>> fill(String ref, String text) =>
      setText(ref, text);

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

  /// Get text from an element by ref
  Future<Map<String, dynamic>> getText(String ref) async {
    try {
      final node = await _findNodeByRef(ref);
      if (node == null) {
        return {'success': false, 'error': 'Node not found: $ref'};
      }

      // Return the label or value from the cached node
      final label = node['label'] as String?;
      final value = node['value'] as String?;

      return {
        'success': true,
        'text': label ?? value ?? '',
        'label': label,
        'value': value,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Wait for an element with matching label to appear
  ///
  /// Polls the semantics tree until an element with a label matching
  /// the pattern is found, or timeout is reached.
  ///
  /// Returns the ref if found, null if timeout.
  Future<Map<String, dynamic>> waitFor(
    String labelPattern, {
    Duration timeout = const Duration(seconds: 5),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    _ensureConnected();

    final pattern = RegExp(labelPattern, caseSensitive: false);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Refresh semantics cache
      await _refreshSnapshot();

      // Search for matching node
      for (final node in _cachedNodes ?? []) {
        final label = node['label'] as String?;
        final value = node['value'] as String?;

        if (label != null && pattern.hasMatch(label)) {
          return {'success': true, 'ref': node['ref'], 'label': label};
        }
        if (value != null && pattern.hasMatch(value)) {
          return {'success': true, 'ref': node['ref'], 'value': value};
        }
      }

      await Future.delayed(pollInterval);
    }

    return {
      'success': false,
      'error': 'Timeout waiting for element matching: $labelPattern'
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Evaluate Dart expression in the app's context
  Future<String?> evaluate(String expression) async {
    _ensureConnected();

    try {
      final isolate = await _service!.getIsolate(_mainIsolateId!);

      // Find the root library
      final rootLib = isolate.rootLib;
      if (rootLib == null) {
        return null;
      }

      final result = await _service!.evaluate(
        _mainIsolateId!,
        rootLib.id!,
        expression,
      );

      if (result is InstanceRef) {
        return result.valueAsString;
      }
      if (result is ErrorRef) {
        throw Exception(result.message);
      }
      return result.toString();
    } catch (e) {
      print('Evaluate error: $e');
      rethrow;
    }
  }

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
