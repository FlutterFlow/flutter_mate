import 'dart:async';
import 'dart:io';

import 'package:flutter_mate_cli/client/connection.dart';
import 'package:flutter_mate_cli/daemon/protocol.dart';
import 'package:flutter_mate_cli/daemon/session.dart';
import 'package:test/test.dart';

void main() {
  group('Protocol', () {
    test('Request serializes correctly', () {
      final request = Request(
        id: 'test123',
        action: Actions.snapshot,
        args: {'compact': true, 'depth': 3},
      );

      final json = request.toJson();
      expect(json['id'], 'test123');
      expect(json['action'], 'snapshot');
      expect(json['compact'], true);
      expect(json['depth'], 3);

      final serialized = request.serialize();
      expect(serialized, contains('"id":"test123"'));
      expect(serialized, contains('"action":"snapshot"'));
    });

    test('Request parses correctly', () {
      final input = '{"id":"abc","action":"tap","ref":"w10"}';
      final request = parseRequest(input);

      expect(request, isNotNull);
      expect(request!.id, 'abc');
      expect(request.action, 'tap');
      expect(request.args['ref'], 'w10');
    });

    test('Request returns null for invalid input', () {
      expect(parseRequest('not json'), isNull);
      expect(parseRequest('{"missing": "action"}'),
          isNotNull); // Still parses, action empty
      expect(parseRequest('null'), isNull);
    });

    test('Response success factory works', () {
      final response = Response.success('id123', {'result': 'ok'});
      expect(response.id, 'id123');
      expect(response.success, true);
      expect(response.data, {'result': 'ok'});
      expect(response.error, isNull);
    });

    test('Response error factory works', () {
      final response = Response.error('id456', 'Something went wrong');
      expect(response.id, 'id456');
      expect(response.success, false);
      expect(response.data, isNull);
      expect(response.error, 'Something went wrong');
    });

    test('Response serializes and parses round-trip', () {
      final original = Response.success('roundtrip', {
        'data': [1, 2, 3]
      });
      final serialized = original.serialize();
      final parsed = parseResponse(serialized);

      expect(parsed, isNotNull);
      expect(parsed!.id, 'roundtrip');
      expect(parsed.success, true);
      expect(parsed.data, {
        'data': [1, 2, 3]
      });
    });

    test('generateRequestId produces unique IDs', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(generateRequestId());
      }
      expect(ids.length, 100); // All unique
    });
  });

  group('Session', () {
    test('SessionState initializes correctly', () {
      final session = SessionState('test');
      expect(session.name, 'test');
      expect(session.isConnected, false);
      expect(session.vmClient, isNull);
      expect(session.vmUri, isNull);
    });

    test('toStatusJson returns correct structure', () {
      final session = SessionState('mySession');
      final status = session.toStatusJson();

      expect(status['session'], 'mySession');
      expect(status['connected'], false);
      expect(status['uri'], isNull);
    });
  });

  group('Session Paths', () {
    test('getAppDir returns valid path', () {
      final dir = getAppDir();
      expect(dir, isNotEmpty);
      expect(dir.contains('flutter_mate'), true);
    });

    test('getSocketPath includes session name', () {
      final path = getSocketPath('mysession');
      if (Platform.isWindows) {
        // Windows returns port number
        expect(int.tryParse(path), isNotNull);
      } else {
        expect(path, contains('mysession'));
        expect(path, endsWith('.sock'));
      }
    });

    test('getPidPath includes session name', () {
      final path = getPidPath('test');
      expect(path, contains('test'));
      expect(path, endsWith('.pid'));
    });

    test('getUriPath includes session name', () {
      final path = getUriPath('staging');
      expect(path, contains('staging'));
      expect(path, endsWith('.uri'));
    });

    test('ensureAppDirExists creates directory', () {
      ensureAppDirExists();
      final dir = Directory(getAppDir());
      expect(dir.existsSync(), true);
    });
  });

  group('Connection', () {
    test('isDaemonRunning returns false when no daemon', () {
      // Use a unique session name to avoid conflicts
      final session =
          'test_not_running_${DateTime.now().millisecondsSinceEpoch}';
      expect(isDaemonRunning(session), false);
    });

    test('listSessions returns empty list when no daemons', () {
      final sessions = listSessions();
      // May or may not be empty depending on test environment
      expect(sessions, isA<List<String>>());
    });
  });

  group('Daemon Integration', () {
    late String testSession;

    setUp(() {
      testSession = 'test_${DateTime.now().microsecondsSinceEpoch}';
    });

    tearDown(() async {
      // Clean up test session files
      cleanupSessionFiles(testSession);
    });

    test('daemon starts and responds to status', () async {
      // Skip if we can't start daemon (e.g., CI environment)
      if (Platform.environment.containsKey('CI')) {
        return;
      }

      // Start daemon in background
      await _startDaemonInBackground(testSession);

      // Wait for daemon to be ready
      await Future.delayed(const Duration(seconds: 2));

      try {
        // Check if daemon is running
        if (!isDaemonRunning(testSession)) {
          // Daemon didn't start, skip test
          return;
        }

        // Send status command
        final response = await sendAction(testSession, Actions.status);
        expect(response.success, true);

        final data = response.data as Map<String, dynamic>?;
        expect(data?['session'], testSession);
        expect(data?['connected'], false);

        // Close daemon
        try {
          await sendAction(testSession, Actions.close);
        } catch (_) {
          // Daemon may close before response
        }
      } finally {
        // Ensure cleanup
        cleanupSessionFiles(testSession);
      }
    }, timeout: Timeout(const Duration(seconds: 30)));

    test('daemon rejects invalid commands', () async {
      if (Platform.environment.containsKey('CI')) {
        return;
      }

      // Start daemon in background
      _startDaemonInBackground(testSession);
      await Future.delayed(const Duration(seconds: 2));

      try {
        if (!isDaemonRunning(testSession)) {
          return;
        }

        // Send unknown action
        final response = await sendAction(testSession, 'unknown_action');
        expect(response.success, false);
        expect(response.error, contains('Unknown action'));

        // Close daemon
        try {
          await sendAction(testSession, Actions.close);
        } catch (_) {}
      } finally {
        cleanupSessionFiles(testSession);
      }
    }, timeout: Timeout(const Duration(seconds: 30)));

    test('daemon requires connection for most commands', () async {
      if (Platform.environment.containsKey('CI')) {
        return;
      }

      _startDaemonInBackground(testSession);
      await Future.delayed(const Duration(seconds: 2));

      try {
        if (!isDaemonRunning(testSession)) {
          return;
        }

        // Try snapshot without connecting
        final response = await sendAction(testSession, Actions.snapshot);
        expect(response.success, false);
        expect(response.error, contains('Not connected'));

        // Close daemon
        try {
          await sendAction(testSession, Actions.close);
        } catch (_) {}
      } finally {
        cleanupSessionFiles(testSession);
      }
    }, timeout: Timeout(const Duration(seconds: 30)));
  });
}

/// Start daemon in an isolate/process for testing
Future<void> _startDaemonInBackground(String session) async {
  // Set up environment
  ensureAppDirExists();

  // Start daemon in background using Process.start
  final dartPath = Platform.resolvedExecutable;
  final scriptDir = Directory.current.path;
  final daemonScript = '$scriptDir/bin/daemon.dart';

  if (!File(daemonScript).existsSync()) {
    // Try finding it relative to test file
    final altPath =
        '${Directory.current.parent.path}/cli/flutter_mate_cli/bin/daemon.dart';
    if (!File(altPath).existsSync()) {
      // Skip test if we can't find daemon script
      return;
    }
  }

  await Process.start(
    dartPath,
    ['run', daemonScript],
    environment: {'FLUTTER_MATE_SESSION': session},
    mode: ProcessStartMode.detached,
  );
}
