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
      return {
        'success': true,
        'result': result.json?['result'] ?? result.json,
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

  /// Get widget tree using built-in Flutter inspector extension.
  ///
  /// This works on ANY Flutter debug app - no code changes needed!
  Future<Map<String, dynamic>> getWidgetTree({bool summaryOnly = true}) async {
    _ensureConnected();

    try {
      final result = await _service!.callServiceExtension(
        'ext.flutter.inspector.getRootWidgetTree',
        isolateId: _mainIsolateId,
        args: {
          'groupName': 'flutter-mate-cli',
          'isSummaryTree': summaryOnly ? 'true' : 'false',
          'withPreviews': 'true',
          'fullDetails': 'false',
        },
      );

      final tree = result.json?['result'];
      if (tree == null) {
        return {'success': false, 'error': 'No widget tree returned'};
      }
      return {'success': true, 'tree': tree};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get semantics tree via FlutterMate service extension
  ///
  /// Requires FlutterMate.initialize() in the app
  Future<Map<String, dynamic>> getSemanticsTree() async {
    _ensureConnected();

    // Use ext.flutter_mate.snapshot which is async and works reliably
    final result = await callExtension(
      'ext.flutter_mate.snapshot',
      args: {'interactiveOnly': 'true'},
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

      // Extract nodes from snapshot
      final nodes = snapshotData['nodes'] as List<dynamic>? ?? [];
      _cachedSemanticsNodes =
          nodes.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return {'success': true, 'nodes': _cachedSemanticsNodes};
    }

    return {
      'success': false,
      'error': result['error'] ?? 'Extension not available'
    };
  }

  /// Get combined snapshot: widget tree + semantics merged.
  ///
  /// Uses built-in Flutter extensions + FlutterMate if available.
  Future<Map<String, dynamic>> getCombinedSnapshot(
      {bool summaryOnly = true}) async {
    // Get widget tree
    final widgetResult = await getWidgetTree(summaryOnly: summaryOnly);
    if (widgetResult['success'] != true) {
      return widgetResult;
    }

    // Get semantics
    final semanticsResult = await getSemanticsTree();

    // Build combined result
    final widgetTree = widgetResult['tree'] as Map<String, dynamic>;

    // Flatten widget tree
    final nodes = <Map<String, dynamic>>[];
    _flattenWidgetTree(widgetTree, nodes, 0);

    int semanticsCount = 0;

    // Merge semantics into widget tree (PURE VM - no FlutterMate needed!)
    if (semanticsResult['success'] == true) {
      final semNodes = semanticsResult['nodes'] as List<dynamic>? ?? [];
      semanticsCount = semNodes.length;

      // Merge semantics into widget tree by matching types
      for (final sem in semNodes) {
        final semMap = sem as Map<String, dynamic>;
        final label = semMap['label'] as String?;
        final actions =
            (semMap['actions'] as List<dynamic>?)?.cast<String>() ?? [];
        final flags = (semMap['flags'] as List<dynamic>?)?.cast<String>() ?? [];
        final ref = semMap['ref'] as String?;

        if (label == null && actions.isEmpty) continue;

        // Find matching widget
        for (final widget in nodes) {
          if (widget['semantics'] != null) continue;

          final type = widget['type'] as String;
          if (_semanticsMatchesWidget(semMap, type)) {
            widget['semantics'] = {
              'ref': ref,
              'label': label,
              'actions': actions,
              'flags': flags,
            };
            break;
          }
        }
      }
    }

    // Get raw semantics nodes for display
    final rawSemanticsNodes = semanticsResult['success'] == true
        ? semanticsResult['nodes'] as List<dynamic>? ?? []
        : <dynamic>[];

    return {
      'success': true,
      'timestamp': DateTime.now().toIso8601String(),
      'nodes': nodes,
      'widgetCount': nodes.length,
      'semanticsCount': semanticsCount,
      'semanticsSource': semanticsResult['source'] ?? 'unknown',
      'semanticsNodes': rawSemanticsNodes,
    };
  }

  void _flattenWidgetTree(
      Map<String, dynamic> node, List<Map<String, dynamic>> result, int depth) {
    final description = node['description'] as String? ?? '';
    final widgetType = _extractWidgetType(description);

    // Skip internal/noise widgets in summary
    if (_isNoiseWidget(widgetType)) {
      // Still process children
      final children = node['children'] as List<dynamic>? ?? [];
      for (final child in children) {
        _flattenWidgetTree(child as Map<String, dynamic>, result, depth);
      }
      return;
    }

    final id = 'w${result.length}';
    final textPreview = node['textPreview'] as String?;
    result.add({
      'id': id,
      'type': widgetType,
      'description': description,
      'depth': depth,
      'hasChildren': (node['children'] as List<dynamic>?)?.isNotEmpty ?? false,
      if (textPreview != null && textPreview.isNotEmpty) 'text': textPreview,
    });

    final children = node['children'] as List<dynamic>? ?? [];
    for (final child in children) {
      _flattenWidgetTree(child as Map<String, dynamic>, result, depth + 1);
    }
  }

  bool _semanticsMatchesWidget(Map<String, dynamic> sem, String widgetType) {
    final flags = sem['flags'] as List<dynamic>? ?? [];
    final actions = sem['actions'] as List<dynamic>? ?? [];
    final label = sem['label'] as String? ?? '';

    // Button widgets - match by type OR by tap action
    if (widgetType.contains('Button') &&
        actions.any((a) => a.toString().contains('tap'))) {
      return true;
    }

    // ElevatedButton, TextButton, IconButton
    if (widgetType.contains('Button') && label.isNotEmpty) {
      return true;
    }

    // Text fields - match by type OR by focus action
    if (widgetType.contains('TextField') &&
        (flags.any((f) => f.toString().contains('isTextField')) ||
            actions.any((a) => a.toString().contains('focus')))) {
      return true;
    }

    return false;
  }

  String _extractWidgetType(String description) {
    // Description is usually like "Text" or "Container(...)"
    final match = RegExp(r'^(\w+)').firstMatch(description);
    return match?.group(1) ?? description;
  }

  bool _isNoiseWidget(String type) {
    const noise = {
      'KeyedSubtree',
      'Semantics',
      'MergeSemantics',
      'ExcludeSemantics',
      'BlockSemantics',
      'IndexedSemantics',
      'RepaintBoundary',
      'Builder',
      'StatefulBuilder',
      'LayoutBuilder',
      'OrientationBuilder',
      'StreamBuilder',
      'FutureBuilder',
      'ValueListenableBuilder',
      'AnimatedBuilder',
      'ListenableBuilder',
      'TweenAnimationBuilder',
    };
    return noise.contains(type);
  }

  /// Type text by sending platform channel message.
  Future<Map<String, dynamic>> typeText(String text) async {
    return callExtension('ext.flutter_mate.typeText', args: {'text': text});
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
  List<Map<String, dynamic>>? _cachedSemanticsNodes;

  /// Refresh semantics cache
  Future<void> _refreshSemantics() async {
    final result = await getSemanticsTree();
    if (result['success'] == true) {
      _cachedSemanticsNodes =
          (result['nodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
    }
  }

  /// Find a semantics node by ref
  Future<Map<String, dynamic>?> _findNodeByRef(String ref) async {
    if (_cachedSemanticsNodes == null) {
      await _refreshSemantics();
    }

    // Clean ref: "s5" -> look for ref "s5" or id 5
    final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;

    for (final node in _cachedSemanticsNodes ?? []) {
      if (node['ref'] == cleanRef) return node;
      // Also try matching by id
      final id = node['id'];
      if (id != null && 's$id' == cleanRef) return node;
    }

    // Refresh and try again
    await _refreshSemantics();
    for (final node in _cachedSemanticsNodes ?? []) {
      if (node['ref'] == cleanRef) return node;
    }

    return null;
  }

  /// Tap on an element by ref
  Future<Map<String, dynamic>> tap(String ref) async {
    return callExtension('ext.flutter_mate.tap', args: {'ref': ref});
  }

  /// Fill text in a field by ref
  Future<Map<String, dynamic>> fill(String ref, String text) async {
    return callExtension('ext.flutter_mate.fill',
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
