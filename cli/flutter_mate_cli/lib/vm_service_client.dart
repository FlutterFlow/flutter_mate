import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client that connects to a Flutter app via VM Service Protocol
///
/// This allows controlling Flutter apps externally through
/// the Dart VM Service.
class VmServiceClient {
  VmService? _service;
  String? _mainIsolateId;
  final String wsUri;

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
      return result.toString();
    } catch (e) {
      print('Evaluate error: $e');
      return null;
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
  // Look for patterns like:
  // Debug service listening on ws://127.0.0.1:63385/xxx=/ws
  // A Dart VM Service on Chrome is available at: http://127.0.0.1:63385/xxx=

  final wsPattern = RegExp(r'ws://[^\s]+');
  final httpPattern = RegExp(r'http://127\.0\.0\.1:\d+/[^\s]+');

  final wsMatch = wsPattern.firstMatch(consoleOutput);
  if (wsMatch != null) {
    return wsMatch.group(0);
  }

  final httpMatch = httpPattern.firstMatch(consoleOutput);
  if (httpMatch != null) {
    // Convert HTTP to WebSocket URL
    var url = httpMatch.group(0)!;
    url = url.replaceFirst('http://', 'ws://');
    if (!url.endsWith('/ws')) {
      url = url.endsWith('/') ? '${url}ws' : '$url/ws';
    }
    return url;
  }

  return null;
}
