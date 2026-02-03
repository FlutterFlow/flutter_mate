import 'dart:io';

import 'package:flutter_mate_cli/vm_service_client.dart';

/// Manages the state of a daemon session.
///
/// Each session has a VM Service connection to a Flutter app.
class SessionState {
  /// Session name (e.g., "default", "staging").
  final String name;

  /// VM Service client for communicating with the Flutter app.
  VmServiceClient? vmClient;

  /// VM Service WebSocket URI.
  String? vmUri;

  SessionState(this.name);

  /// Whether we have a VM Service connection.
  bool get isConnected => vmClient != null;

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

  /// Full cleanup: disconnect.
  Future<void> close() async {
    await disconnect();
  }

  /// Get status info for this session.
  Map<String, dynamic> toStatusJson() => {
        'session': name,
        'connected': isConnected,
        'uri': vmUri,
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
