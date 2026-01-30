import 'dart:io';

import 'package:flutter_mate_cli/vm_service_client.dart';

/// Manages the state of a daemon session.
///
/// Each session can have:
/// - A VM Service connection to a Flutter app
/// - Optionally, a Flutter process that we launched (via `run` command)
class SessionState {
  /// Session name (e.g., "default", "staging").
  final String name;

  /// VM Service client for communicating with the Flutter app.
  VmServiceClient? vmClient;

  /// VM Service WebSocket URI.
  String? vmUri;

  /// Flutter process (only set if we launched it via `run` command).
  /// If null, the app was started externally and we connected via `connect`.
  Process? flutterProcess;

  /// Buffer for Flutter process stdout (for log streaming).
  final List<String> logBuffer = [];

  /// Maximum number of log lines to keep in buffer.
  static const int maxLogBufferSize = 1000;

  SessionState(this.name);

  /// Whether we have a VM Service connection.
  bool get isConnected => vmClient != null;

  /// Whether we launched the Flutter app (vs. connected to existing).
  bool get isLaunched => flutterProcess != null;

  /// Whether we can kill the app (only if we launched it).
  bool get canKillApp => flutterProcess != null;

  /// Whether we can hot reload (only if we launched it).
  bool get canHotReload => flutterProcess != null;

  /// Add a log line to the buffer.
  void addLog(String line) {
    logBuffer.add(line);
    if (logBuffer.length > maxLogBufferSize) {
      logBuffer.removeAt(0);
    }
  }

  /// Clear the log buffer.
  void clearLogs() {
    logBuffer.clear();
  }

  /// Get recent logs.
  List<String> getLogs([int? count]) {
    if (count == null || count >= logBuffer.length) {
      return List.from(logBuffer);
    }
    return logBuffer.sublist(logBuffer.length - count);
  }

  /// Disconnect from VM Service.
  Future<void> disconnect() async {
    try {
      await vmClient?.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    }
    vmClient = null;
    vmUri = null;
  }

  /// Kill the Flutter process if we launched it.
  Future<void> killFlutterProcess() async {
    if (flutterProcess != null) {
      flutterProcess!.kill(ProcessSignal.sigterm);
      // Give it a moment to exit gracefully
      await Future.delayed(const Duration(milliseconds: 500));
      // Force kill if still running
      flutterProcess!.kill(ProcessSignal.sigkill);
      flutterProcess = null;
    }
  }

  /// Full cleanup: disconnect and kill process.
  Future<void> close() async {
    await disconnect();
    await killFlutterProcess();
    clearLogs();
  }

  /// Get status info for this session.
  Map<String, dynamic> toStatusJson() => {
        'session': name,
        'connected': isConnected,
        'launched': isLaunched,
        'uri': vmUri,
        'canHotReload': canHotReload,
        'canKillApp': canKillApp,
        'logBufferSize': logBuffer.length,
      };
}

// ════════════════════════════════════════════════════════════════════════════
// SESSION PATHS
// ════════════════════════════════════════════════════════════════════════════

/// Get the base directory for session files.
///
/// Priority: FLUTTER_MATE_DIR > XDG_RUNTIME_DIR > ~/.flutter_mate
String getAppDir() {
  // 1. Explicit override
  final override = Platform.environment['FLUTTER_MATE_DIR'];
  if (override != null && override.isNotEmpty) {
    return override;
  }

  // 2. XDG_RUNTIME_DIR (Linux standard)
  final xdgRuntime = Platform.environment['XDG_RUNTIME_DIR'];
  if (xdgRuntime != null && xdgRuntime.isNotEmpty) {
    return '$xdgRuntime/flutter_mate';
  }

  // 3. Home directory fallback
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty) {
    return '$home/.flutter_mate';
  }

  // 4. Last resort: temp directory
  return '${Directory.systemTemp.path}/flutter_mate';
}

/// Get the socket path for a session.
String getSocketPath(String session) {
  if (Platform.isWindows) {
    // Windows doesn't support Unix sockets, use TCP port instead
    // Return port number as string
    return _getPortForSession(session).toString();
  }
  return '${getAppDir()}/$session.sock';
}

/// Get the PID file path for a session.
String getPidPath(String session) {
  return '${getAppDir()}/$session.pid';
}

/// Get the URI file path for a session (stores VM Service URI).
String getUriPath(String session) {
  return '${getAppDir()}/$session.uri';
}

/// Get the Flutter process PID file path.
String getFlutterPidPath(String session) {
  return '${getAppDir()}/$session.flutter_pid';
}

/// Get a consistent TCP port for a session (Windows fallback).
int _getPortForSession(String session) {
  var hash = 0;
  for (var i = 0; i < session.length; i++) {
    hash = ((hash << 5) - hash + session.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  // Port range 49152-65535 (dynamic/private ports)
  return 49152 + (hash.abs() % 16383);
}

/// Ensure the app directory exists.
void ensureAppDirExists() {
  final dir = Directory(getAppDir());
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

/// Clean up all session files.
void cleanupSessionFiles(String session) {
  final files = [
    getSocketPath(session),
    getPidPath(session),
    getUriPath(session),
    getFlutterPidPath(session),
  ];

  for (final path in files) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  // Also try to delete socket file (Unix)
  if (!Platform.isWindows) {
    try {
      final socketFile = File(getSocketPath(session));
      if (socketFile.existsSync()) {
        socketFile.deleteSync();
      }
    } catch (_) {
      // Ignore
    }
  }
}
