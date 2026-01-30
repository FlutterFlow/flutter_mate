import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mate_cli/daemon/protocol.dart';
import 'package:flutter_mate_cli/daemon/session.dart';

/// Client for communicating with the flutter_mate daemon.
///
/// Handles daemon lifecycle (start if needed) and command sending.

// ════════════════════════════════════════════════════════════════════════════
// DAEMON STATUS
// ════════════════════════════════════════════════════════════════════════════

/// Check if the daemon is running for a session.
bool isDaemonRunning(String session) {
  final pidPath = getPidPath(session);
  final pidFile = File(pidPath);

  if (!pidFile.existsSync()) {
    return false;
  }

  try {
    final pid = int.parse(pidFile.readAsStringSync().trim());
    // Check if process exists by sending signal 0
    return Process.killPid(pid, ProcessSignal.sigcont);
  } catch (_) {
    // PID file invalid or process doesn't exist
    cleanupSessionFiles(session);
    return false;
  }
}

/// Check if the daemon socket is ready to accept connections.
bool isDaemonReady(String session) {
  try {
    if (Platform.isWindows) {
      final port = int.parse(getSocketPath(session));
      final socket = Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 100),
      );
      // If we get here without error, it's ready
      socket.then((s) => s.close());
      return true;
    } else {
      final socketPath = getSocketPath(session);
      final address =
          InternetAddress(socketPath, type: InternetAddressType.unix);
      final socket = Socket.connect(address, 0,
          timeout: const Duration(milliseconds: 100));
      socket.then((s) => s.close());
      return true;
    }
  } catch (_) {
    return false;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DAEMON LIFECYCLE
// ════════════════════════════════════════════════════════════════════════════

/// Result of ensureDaemon call.
class DaemonResult {
  /// True if daemon was already running, false if we started it.
  final bool alreadyRunning;

  DaemonResult({required this.alreadyRunning});
}

/// Ensure the daemon is running for a session.
/// Starts the daemon if it's not running.
Future<DaemonResult> ensureDaemon(String session) async {
  // Check if already running
  if (isDaemonRunning(session)) {
    // Wait a bit for socket to be ready
    for (var i = 0; i < 10; i++) {
      if (await _canConnect(session)) {
        return DaemonResult(alreadyRunning: true);
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // Start daemon
  await _startDaemon(session);

  // Wait for daemon to be ready (up to 5 seconds)
  for (var i = 0; i < 50; i++) {
    if (await _canConnect(session)) {
      return DaemonResult(alreadyRunning: false);
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  throw StateError('Daemon failed to start');
}

Future<void> _startDaemon(String session) async {
  // Find daemon script path
  final daemonPath = _findDaemonScript();

  // Ensure app directory exists
  ensureAppDirExists();

  // Spawn daemon as detached background process
  if (Platform.isWindows) {
    await Process.start(
      'dart',
      ['run', daemonPath],
      environment: {'FLUTTER_MATE_SESSION': session},
      mode: ProcessStartMode.detached,
    );
  } else {
    // On Unix, use nohup-style detachment
    await Process.start(
      'dart',
      ['run', daemonPath],
      environment: {'FLUTTER_MATE_SESSION': session},
      mode: ProcessStartMode.detached,
    );
  }
}

String _findDaemonScript() {
  // Get the path to the current script
  final scriptPath = Platform.script.toFilePath();
  final scriptDir = File(scriptPath).parent.path;

  // Look for daemon.dart relative to flutter_mate.dart
  final candidates = [
    '$scriptDir/daemon.dart',
    '$scriptDir/../bin/daemon.dart',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  // Fall back to package path
  return 'package:flutter_mate_cli/bin/daemon.dart';
}

Future<bool> _canConnect(String session) async {
  try {
    final socket = await _connect(session);
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SOCKET CONNECTION
// ════════════════════════════════════════════════════════════════════════════

Future<Socket> _connect(String session, {Duration? timeout}) async {
  final connectTimeout = timeout ?? const Duration(seconds: 5);

  if (Platform.isWindows) {
    final port = int.parse(getSocketPath(session));
    return Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: connectTimeout,
    );
  } else {
    final socketPath = getSocketPath(session);
    final address = InternetAddress(socketPath, type: InternetAddressType.unix);
    return Socket.connect(address, 0, timeout: connectTimeout);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COMMAND SENDING
// ════════════════════════════════════════════════════════════════════════════

/// Send a command to the daemon and wait for response.
///
/// [timeout] defaults to 30 seconds for most commands.
Future<Response> sendCommand(
  Request request,
  String session, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final socket = await _connect(session, timeout: const Duration(seconds: 5));

  try {
    // Set TCP options (only for TCP sockets, not Unix sockets)
    if (Platform.isWindows) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }

    // Send command
    socket.write('${request.serialize()}\n');
    await socket.flush();

    // Read response with timeout
    final responseCompleter = Completer<Response>();
    var buffer = '';
    StreamSubscription<List<int>>? subscription;

    // Set up timeout
    final timer = Timer(timeout, () {
      if (!responseCompleter.isCompleted) {
        subscription?.cancel();
        responseCompleter.completeError(
          TimeoutException('Command timed out after ${timeout.inSeconds}s'),
        );
      }
    });

    subscription = socket.listen(
      (data) {
        buffer += utf8.decode(data);

        // Look for complete response (newline terminated)
        if (buffer.contains('\n')) {
          final newlineIdx = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIdx);

          final response = parseResponse(line);
          if (response != null && !responseCompleter.isCompleted) {
            timer.cancel();
            subscription?.cancel();
            responseCompleter.complete(response);
          } else if (!responseCompleter.isCompleted) {
            timer.cancel();
            subscription?.cancel();
            responseCompleter.completeError('Invalid response from daemon');
          }
        }
      },
      onError: (e) {
        if (!responseCompleter.isCompleted) {
          timer.cancel();
          subscription?.cancel();
          responseCompleter.completeError('Connection error: $e');
        }
      },
      onDone: () {
        if (!responseCompleter.isCompleted) {
          timer.cancel();
          responseCompleter.completeError('Connection closed');
        }
      },
      cancelOnError: true,
    );

    // Wait for response (timeout is handled by timer above)
    try {
      return await responseCompleter.future;
    } finally {
      subscription.cancel();
      timer.cancel();
    }
  } finally {
    await socket.close();
  }
}

/// Send a command by action name and arguments.
Future<Response> sendAction(
  String session,
  String action, [
  Map<String, dynamic> args = const {},
]) async {
  final request = Request(
    id: generateRequestId(),
    action: action,
    args: args,
  );
  return sendCommand(request, session);
}

// ════════════════════════════════════════════════════════════════════════════
// SESSION MANAGEMENT
// ════════════════════════════════════════════════════════════════════════════

/// List all active sessions.
List<String> listSessions() {
  final appDir = Directory(getAppDir());
  if (!appDir.existsSync()) {
    return [];
  }

  final sessions = <String>[];

  for (final entity in appDir.listSync()) {
    if (entity is File && entity.path.endsWith('.pid')) {
      final name = entity.uri.pathSegments.last.replaceAll('.pid', '');
      if (isDaemonRunning(name)) {
        sessions.add(name);
      }
    }
  }

  return sessions;
}

/// Get the status of a session.
Future<Map<String, dynamic>?> getSessionStatus(String session) async {
  if (!isDaemonRunning(session)) {
    return null;
  }

  try {
    final response = await sendAction(session, Actions.status);
    if (response.success) {
      return response.data as Map<String, dynamic>?;
    }
  } catch (_) {
    // Daemon not responding
  }

  return null;
}
