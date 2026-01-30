import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mate_cli/vm_service_client.dart';

import 'protocol.dart';
import 'session.dart';

/// The daemon server that manages Flutter app connections.
///
/// Listens on a Unix socket (or TCP port on Windows) and processes
/// commands from CLI clients.
class FlutterMateDaemon {
  final String sessionName;
  final SessionState session;

  ServerSocket? _server;
  bool _shuttingDown = false;

  FlutterMateDaemon(this.sessionName) : session = SessionState(sessionName);

  /// Start the daemon server.
  Future<void> start() async {
    // Ensure app directory exists
    ensureAppDirExists();

    // Clean up any stale files
    cleanupSessionFiles(sessionName);

    // Write PID file
    final pidFile = File(getPidPath(sessionName));
    pidFile.writeAsStringSync(pid.toString());

    // Start server
    if (Platform.isWindows) {
      await _startTcpServer();
    } else {
      await _startUnixSocketServer();
    }

    // Set up signal handlers
    _setupSignalHandlers();

    // Keep process alive
    await _waitForShutdown();
  }

  Future<void> _startUnixSocketServer() async {
    final socketPath = getSocketPath(sessionName);

    // Remove stale socket file if exists
    final socketFile = File(socketPath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
    }

    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );

    _server!.listen(_handleClient);
  }

  Future<void> _startTcpServer() async {
    final port = int.parse(getSocketPath(sessionName));
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleClient);
  }

  void _handleClient(Socket client) {
    var buffer = '';

    client.listen(
      (data) async {
        buffer += utf8.decode(data);

        // Process complete lines (newline-delimited JSON)
        while (buffer.contains('\n')) {
          final newlineIdx = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIdx);
          buffer = buffer.substring(newlineIdx + 1);

          if (line.trim().isEmpty) continue;

          final response = await _processLine(line);
          client.write('${response.serialize()}\n');
          await client.flush();

          // Check if we should shut down after this command
          if (_shuttingDown) {
            await Future.delayed(const Duration(milliseconds: 100));
            await _shutdown();
          }
        }
      },
      onError: (_) {
        // Client disconnected, ignore
      },
      onDone: () {
        // Client disconnected
      },
    );
  }

  Future<Response> _processLine(String line) async {
    final request = parseRequest(line);
    if (request == null) {
      return Response.error('unknown', 'Invalid JSON');
    }

    try {
      return await _executeCommand(request);
    } catch (e) {
      return Response.error(request.id, e.toString());
    }
  }

  Future<Response> _executeCommand(Request request) async {
    // Add timeout to all commands to prevent hanging
    return await _executeCommandWithTimeout(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          Response.error(request.id, 'Command timed out after 30s'),
    );
  }

  Future<Response> _executeCommandWithTimeout(Request request) async {
    switch (request.action) {
      // ════════════════════════════════════════════════════════════════════
      // APP LIFECYCLE
      // ════════════════════════════════════════════════════════════════════

      case Actions.run:
        return _handleRun(request);

      case Actions.connect:
        return _handleConnect(request);

      case Actions.close:
        return _handleClose(request);

      case Actions.status:
        return _handleStatus(request);

      // ════════════════════════════════════════════════════════════════════
      // INTROSPECTION
      // ════════════════════════════════════════════════════════════════════

      case Actions.snapshot:
        return _handleSnapshot(request);

      case Actions.find:
        return _handleFind(request);

      case Actions.screenshot:
        return _handleScreenshot(request);

      case Actions.getText:
        return _handleGetText(request);

      // ════════════════════════════════════════════════════════════════════
      // INTERACTIONS
      // ════════════════════════════════════════════════════════════════════

      case Actions.tap:
        return _handleTap(request);

      case Actions.doubleTap:
        return _handleDoubleTap(request);

      case Actions.longPress:
        return _handleLongPress(request);

      case Actions.hover:
        return _handleHover(request);

      case Actions.drag:
        return _handleDrag(request);

      case Actions.focus:
        return _handleFocus(request);

      // ════════════════════════════════════════════════════════════════════
      // TEXT INPUT
      // ════════════════════════════════════════════════════════════════════

      case Actions.setText:
        return _handleSetText(request);

      case Actions.typeText:
        return _handleTypeText(request);

      case Actions.clear:
        return _handleClear(request);

      // ════════════════════════════════════════════════════════════════════
      // SCROLLING
      // ════════════════════════════════════════════════════════════════════

      case Actions.scroll:
        return _handleScroll(request);

      case Actions.swipe:
        return _handleSwipe(request);

      // ════════════════════════════════════════════════════════════════════
      // KEYBOARD
      // ════════════════════════════════════════════════════════════════════

      case Actions.pressKey:
        return _handlePressKey(request);

      case Actions.keyDown:
        return _handleKeyDown(request);

      case Actions.keyUp:
        return _handleKeyUp(request);

      // ════════════════════════════════════════════════════════════════════
      // WAITING
      // ════════════════════════════════════════════════════════════════════

      case Actions.wait:
        return _handleWait(request);

      case Actions.waitFor:
        return _handleWaitFor(request);

      case Actions.waitForDisappear:
        return _handleWaitForDisappear(request);

      case Actions.waitForValue:
        return _handleWaitForValue(request);

      default:
        return Response.error(request.id, 'Unknown action: ${request.action}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP LIFECYCLE HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleRun(Request request) async {
    if (session.isConnected) {
      return Response.error(
          request.id, 'Already connected. Use "close" first.');
    }

    final flutterArgs = request.args['args'] as List<dynamic>? ?? [];
    final args = flutterArgs.cast<String>();

    try {
      final uri = await _launchFlutterApp(args);
      return Response.success(request.id, {
        'uri': uri,
        'launched': true,
      });
    } catch (e) {
      return Response.error(request.id, 'Failed to launch app: $e');
    }
  }

  Future<Response> _handleConnect(Request request) async {
    if (session.isConnected) {
      return Response.error(
          request.id, 'Already connected. Use "close" first.');
    }

    final uri = request.args['uri'] as String?;
    if (uri == null || uri.isEmpty) {
      return Response.error(request.id, 'Missing required argument: uri');
    }

    try {
      // Normalize URI
      final normalizedUri = _normalizeVmServiceUri(uri);

      session.vmClient = VmServiceClient(normalizedUri);
      await session.vmClient!.connect();
      session.vmUri = normalizedUri;

      // Write URI to file for status display
      File(getUriPath(sessionName)).writeAsStringSync(normalizedUri);

      return Response.success(request.id, {
        'uri': normalizedUri,
        'launched': false,
      });
    } catch (e) {
      session.vmClient = null;
      session.vmUri = null;
      return Response.error(request.id, 'Failed to connect: $e');
    }
  }

  Future<Response> _handleClose(Request request) async {
    _shuttingDown = true;
    await session.close();
    return Response.success(request.id, {'closed': true});
  }

  Future<Response> _handleStatus(Request request) async {
    return Response.success(request.id, session.toStatusJson());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTROSPECTION HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleSnapshot(Request request) async {
    _ensureConnected(request.id);

    final compact =
        request.args['compact'] == true || request.args['compact'] == 'true';
    final depth = _parseInt(request.args['depth']);
    final fromRef = request.args['from'] as String?;

    final result = await session.vmClient!.getSnapshot(
      compact: compact,
      depth: depth,
      fromRef: fromRef,
    );

    if (result['success'] == true) {
      return Response.success(request.id, result);
    }
    return Response.error(request.id, result['error'] ?? 'Snapshot failed');
  }

  Future<Response> _handleFind(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.find(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Find failed');
  }

  Future<Response> _handleScreenshot(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;

    final result = await session.vmClient!.callExtension(
      'ext.flutter_mate.screenshot',
      args: ref != null ? {'ref': ref} : null,
    );

    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Screenshot failed');
  }

  Future<Response> _handleGetText(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.getText(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result);
    }
    return Response.error(request.id, result['error'] ?? 'getText failed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERACTION HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleTap(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.tap(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Tap failed');
  }

  Future<Response> _handleDoubleTap(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.doubleTap(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'DoubleTap failed');
  }

  Future<Response> _handleLongPress(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.longPress(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'LongPress failed');
  }

  Future<Response> _handleHover(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.hover(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Hover failed');
  }

  Future<Response> _handleDrag(Request request) async {
    _ensureConnected(request.id);

    final fromRef = request.args['from'] as String?;
    final toRef = request.args['to'] as String?;
    if (fromRef == null || toRef == null) {
      return Response.error(request.id, 'Missing required arguments: from, to');
    }

    final result = await session.vmClient!.drag(fromRef, toRef);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Drag failed');
  }

  Future<Response> _handleFocus(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.focus(ref);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Focus failed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT INPUT HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleSetText(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    final text = request.args['text'] as String?;
    if (ref == null || text == null) {
      return Response.error(
          request.id, 'Missing required arguments: ref, text');
    }

    final result = await session.vmClient!.setText(ref, text);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'SetText failed');
  }

  Future<Response> _handleTypeText(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    final text = request.args['text'] as String?;
    if (ref == null || text == null) {
      return Response.error(
          request.id, 'Missing required arguments: ref, text');
    }

    final result = await session.vmClient!.typeText(ref, text);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'TypeText failed');
  }

  Future<Response> _handleClear(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    // Focus the field first, then clear
    await session.vmClient!.focus(ref);
    final result = await session.vmClient!.clearText();
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Clear failed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCROLL HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleScroll(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    final direction = request.args['direction'] as String? ?? 'down';
    if (ref == null || ref.isEmpty) {
      return Response.error(request.id, 'Missing required argument: ref');
    }

    final result = await session.vmClient!.scroll(ref, direction);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Scroll failed');
  }

  Future<Response> _handleSwipe(Request request) async {
    _ensureConnected(request.id);

    final direction = request.args['direction'] as String? ?? 'down';

    final result = await session.vmClient!.swipe(direction: direction);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'Swipe failed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KEYBOARD HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handlePressKey(Request request) async {
    _ensureConnected(request.id);

    final key = request.args['key'] as String?;
    if (key == null || key.isEmpty) {
      return Response.error(request.id, 'Missing required argument: key');
    }

    final result = await session.vmClient!.pressKey(key);
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'PressKey failed');
  }

  Future<Response> _handleKeyDown(Request request) async {
    _ensureConnected(request.id);

    final key = request.args['key'] as String?;
    if (key == null || key.isEmpty) {
      return Response.error(request.id, 'Missing required argument: key');
    }

    final control = request.args['control'] == true;
    final shift = request.args['shift'] == true;
    final alt = request.args['alt'] == true;
    final command = request.args['command'] == true;

    final result = await session.vmClient!.keyDown(
      key,
      control: control,
      shift: shift,
      alt: alt,
      command: command,
    );
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'KeyDown failed');
  }

  Future<Response> _handleKeyUp(Request request) async {
    _ensureConnected(request.id);

    final key = request.args['key'] as String?;
    if (key == null || key.isEmpty) {
      return Response.error(request.id, 'Missing required argument: key');
    }

    final control = request.args['control'] == true;
    final shift = request.args['shift'] == true;
    final alt = request.args['alt'] == true;
    final command = request.args['command'] == true;

    final result = await session.vmClient!.keyUp(
      key,
      control: control,
      shift: shift,
      alt: alt,
      command: command,
    );
    if (result['success'] == true) {
      return Response.success(request.id, result['result']);
    }
    return Response.error(request.id, result['error'] ?? 'KeyUp failed');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WAIT HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Response> _handleWait(Request request) async {
    final ms = _parseInt(request.args['ms']) ?? 1000;
    await Future.delayed(Duration(milliseconds: ms));
    return Response.success(request.id, {'waited': ms});
  }

  Future<Response> _handleWaitFor(Request request) async {
    _ensureConnected(request.id);

    final pattern = request.args['pattern'] as String?;
    if (pattern == null || pattern.isEmpty) {
      return Response.error(request.id, 'Missing required argument: pattern');
    }

    final timeout = _parseInt(request.args['timeout']) ?? 5000;
    final poll = _parseInt(request.args['poll']) ?? 200;

    final result = await session.vmClient!.waitFor(
      pattern,
      timeout: Duration(milliseconds: timeout),
      pollInterval: Duration(milliseconds: poll),
    );

    if (result['success'] == true) {
      return Response.success(request.id, result);
    }
    return Response.error(request.id, result['error'] ?? 'WaitFor timed out');
  }

  Future<Response> _handleWaitForDisappear(Request request) async {
    _ensureConnected(request.id);

    final pattern = request.args['pattern'] as String?;
    if (pattern == null || pattern.isEmpty) {
      return Response.error(request.id, 'Missing required argument: pattern');
    }

    final timeout = _parseInt(request.args['timeout']) ?? 5000;
    final poll = _parseInt(request.args['poll']) ?? 200;

    final result = await session.vmClient!.waitForDisappear(
      pattern,
      timeout: Duration(milliseconds: timeout),
      pollInterval: Duration(milliseconds: poll),
    );

    if (result['success'] == true) {
      return Response.success(request.id, result);
    }
    return Response.error(
        request.id, result['error'] ?? 'WaitForDisappear timed out');
  }

  Future<Response> _handleWaitForValue(Request request) async {
    _ensureConnected(request.id);

    final ref = request.args['ref'] as String?;
    final pattern = request.args['pattern'] as String?;
    if (ref == null || pattern == null) {
      return Response.error(
          request.id, 'Missing required arguments: ref, pattern');
    }

    final timeout = _parseInt(request.args['timeout']) ?? 5000;
    final poll = _parseInt(request.args['poll']) ?? 200;

    final result = await session.vmClient!.waitForValue(
      ref,
      pattern,
      timeout: Duration(milliseconds: timeout),
      pollInterval: Duration(milliseconds: poll),
    );

    if (result['success'] == true) {
      return Response.success(request.id, result);
    }
    return Response.error(
        request.id, result['error'] ?? 'WaitForValue timed out');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP LAUNCHING
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _launchFlutterApp(List<String> args) async {
    // Find flutter executable
    final flutterPath = _findFlutter();

    // Start flutter run process
    final process = await Process.start(
      flutterPath,
      ['run', ...args],
      mode: ProcessStartMode.normal,
    );

    session.flutterProcess = process;

    // Write flutter PID to file
    File(getFlutterPidPath(sessionName))
        .writeAsStringSync(process.pid.toString());

    // Capture stdout and extract VM Service URI
    final uriCompleter = Completer<String>();
    final buffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen((data) {
      buffer.write(data);
      session.addLog(data);

      // Look for VM Service URI
      if (!uriCompleter.isCompleted) {
        final uri = _extractVmServiceUri(buffer.toString());
        if (uri != null) {
          uriCompleter.complete(uri);
        }
      }
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      session.addLog('[stderr] $data');
    });

    // Wait for URI with timeout
    final uri = await uriCompleter.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        process.kill();
        throw TimeoutException('Timed out waiting for VM Service URI');
      },
    );

    // Connect to VM Service
    session.vmClient = VmServiceClient(uri);
    await session.vmClient!.connect();
    session.vmUri = uri;

    // Write URI to file
    File(getUriPath(sessionName)).writeAsStringSync(uri);

    return uri;
  }

  String? _extractVmServiceUri(String output) {
    // Look for patterns like:
    // "A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/"
    // "The Dart VM service is listening on http://127.0.0.1:12345/abc=/"
    final wsPattern = RegExp(r'ws://[^\s]+');
    final httpPattern = RegExp(r'http://127\.0\.0\.1:\d+/[^\s]+');

    final wsMatch = wsPattern.firstMatch(output);
    if (wsMatch != null) {
      return wsMatch.group(0);
    }

    final httpMatch = httpPattern.firstMatch(output);
    if (httpMatch != null) {
      return _normalizeVmServiceUri(httpMatch.group(0)!);
    }

    return null;
  }

  String _normalizeVmServiceUri(String uri) {
    var normalized = uri;

    // Convert http:// to ws://
    if (normalized.startsWith('http://')) {
      normalized = normalized.replaceFirst('http://', 'ws://');
    } else if (normalized.startsWith('https://')) {
      normalized = normalized.replaceFirst('https://', 'wss://');
    }

    // Add /ws suffix if needed
    if (!normalized.endsWith('/ws')) {
      if (normalized.endsWith('/')) {
        normalized = '${normalized}ws';
      } else {
        normalized = '$normalized/ws';
      }
    }

    return normalized;
  }

  String _findFlutter() {
    // Check FLUTTER_ROOT
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final flutterBin = Platform.isWindows
          ? '$flutterRoot/bin/flutter.bat'
          : '$flutterRoot/bin/flutter';
      if (File(flutterBin).existsSync()) {
        return flutterBin;
      }
    }

    // Check common locations
    final candidates = [
      '/usr/local/bin/flutter',
      '${Platform.environment['HOME']}/flutter/bin/flutter',
      '${Platform.environment['HOME']}/Development/flutter/bin/flutter',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // Fall back to PATH
    return 'flutter';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _ensureConnected(String requestId) {
    if (!session.isConnected) {
      throw StateError('Not connected. Use "run" or "connect" first.');
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  void _setupSignalHandlers() {
    // Handle shutdown signals
    ProcessSignal.sigint.watch().listen((_) => _shutdown());
    ProcessSignal.sigterm.watch().listen((_) => _shutdown());

    // SIGHUP only on Unix
    if (!Platform.isWindows) {
      ProcessSignal.sighup.watch().listen((_) => _shutdown());
    }
  }

  final _shutdownCompleter = Completer<void>();

  Future<void> _waitForShutdown() async {
    await _shutdownCompleter.future;
  }

  Future<void> _shutdown() async {
    if (_shutdownCompleter.isCompleted) return;

    await session.close();
    await _server?.close();
    cleanupSessionFiles(sessionName);

    _shutdownCompleter.complete();
    exit(0);
  }
}

/// Start the daemon for a session.
Future<void> startDaemon(String session) async {
  final daemon = FlutterMateDaemon(session);
  await daemon.start();
}
