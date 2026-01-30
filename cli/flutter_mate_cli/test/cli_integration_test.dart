/// CLI Integration Tests
///
/// These tests verify the CLI can communicate with a running Flutter app
/// via the daemon mode.
///
/// To run these tests:
/// 1. Start the demo app: `cd apps/demo_app && flutter run -d macos`
/// 2. Copy the VM Service URI
/// 3. Run: `VM_SERVICE_URI=ws://... dart test test/cli_integration_test.dart`
///
/// Or use the new daemon mode:
/// 1. Run: `flutter_mate run -d macos` (in one terminal)
/// 2. Run: `dart test test/cli_integration_test.dart --define=use_daemon=true`
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final vmUri = Platform.environment['VM_SERVICE_URI'] ??
      const String.fromEnvironment('vm_uri', defaultValue: '');
  final useDaemon =
      const String.fromEnvironment('use_daemon', defaultValue: 'false') ==
          'true';

  // Skip if no URI provided and not using daemon
  if (vmUri.isEmpty && !useDaemon) {
    print('''
╔══════════════════════════════════════════════════════════════════════════════╗
║  CLI Integration Tests - SKIPPED                                             ║
║                                                                              ║
║  Option 1: Use daemon mode (recommended)                                     ║
║    flutter_mate run -d macos                                                 ║
║    dart test test/cli_integration_test.dart --define=use_daemon=true         ║
║                                                                              ║
║  Option 2: Provide VM Service URI                                            ║
║    cd apps/demo_app && flutter run -d macos                                  ║
║    VM_SERVICE_URI=ws://... dart test test/cli_integration_test.dart          ║
╚══════════════════════════════════════════════════════════════════════════════╝
''');
    return;
  }

  group('CLI Integration Tests', () {
    late String cliPath;

    setUpAll(() {
      cliPath = 'bin/flutter_mate.dart';
      if (useDaemon) {
        print('Testing with daemon mode (default session)');
      } else {
        print('Testing with VM Service: $vmUri');
      }
    });

    Future<ProcessResult> runCli(List<String> args) async {
      if (useDaemon) {
        // New daemon mode - no URI needed
        return Process.run(
          'dart',
          ['run', cliPath, ...args],
          workingDirectory: Directory.current.path,
        );
      } else {
        // Legacy mode - connect first, then run command
        // First connect
        await Process.run(
          'dart',
          ['run', cliPath, 'connect', vmUri],
          workingDirectory: Directory.current.path,
        );
        // Then run command
        return Process.run(
          'dart',
          ['run', cliPath, ...args],
          workingDirectory: Directory.current.path,
        );
      }
    }

    test('snapshot command returns valid output', () async {
      final result = await runCli(['snapshot', '-j']);

      expect(result.exitCode, 0, reason: 'CLI should exit with 0');

      final stdout = result.stdout as String;
      // Should contain JSON with success
      expect(stdout, contains('"success"'));
    });

    test('snapshot compact mode works', () async {
      final result = await runCli(['snapshot', '-c']);

      expect(result.exitCode, 0);

      final output = result.stdout as String;
      // Compact mode should still show some output
      expect(output, isNotEmpty);
    });

    test('status command works', () async {
      final result = await runCli(['status']);

      expect(result.exitCode, 0);

      final output = result.stdout as String;
      expect(output, contains('Session'));
    });

    test('find command with invalid ref returns error', () async {
      final result = await runCli(['find', 'invalid_ref_99999']);

      // Should handle gracefully
      final combined = '${result.stdout}${result.stderr}';
      expect(combined,
          anyOf(contains('failed'), contains('not found'), contains('Error')));
    });

    test('tap command with invalid ref returns error', () async {
      final result = await runCli(['tap', 'invalid_ref_12345']);

      final combined = '${result.stdout}${result.stderr}';
      expect(combined,
          anyOf(contains('failed'), contains('not found'), contains('Error')));
    });

    test('JSON output flag works', () async {
      final result = await runCli(['snapshot', '-j']);

      expect(result.exitCode, 0);

      final output = result.stdout as String;
      // Should be valid JSON
      expect(() => jsonDecode(output), returnsNormally);
    });

    test('wait command works', () async {
      final stopwatch = Stopwatch()..start();
      final result = await runCli(['wait', '500']);
      stopwatch.stop();

      expect(result.exitCode, 0);
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(450));
      expect(result.stdout, contains('Waited'));
    });

    test('help flag shows usage', () async {
      final result = await Process.run(
        'dart',
        ['run', cliPath, '--help'],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0);
      expect(result.stdout, contains('flutter_mate'));
      expect(result.stdout, contains('run'));
      expect(result.stdout, contains('connect'));
      expect(result.stdout, contains('snapshot'));
    });

    test('version flag works', () async {
      final result = await Process.run(
        'dart',
        ['run', cliPath, '--version'],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0);
      expect(result.stdout, contains('flutter_mate'));
    });

    test('session list command works', () async {
      final result = await Process.run(
        'dart',
        ['run', cliPath, 'session', 'list'],
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0);
      // Should show sessions or "No active sessions"
      final output = result.stdout as String;
      expect(output, anyOf(contains('session'), contains('No active')));
    });
  });
}
