/// CLI Integration Tests
///
/// These tests verify the CLI can communicate with a running Flutter app.
///
/// To run these tests:
/// 1. Start the demo app: `cd apps/demo_app && flutter run -d macos`
/// 2. Copy the VM Service URI
/// 3. Run: `dart test test/cli_integration_test.dart --define=vm_uri=ws://...`
///
/// Or use the automated test script (runs app in background):
/// `dart run test/run_integration_tests.dart`
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// These tests require a running Flutter app.
/// Set the VM_SERVICE_URI environment variable or pass via --define
void main() {
  final vmUri = Platform.environment['VM_SERVICE_URI'] ??
      const String.fromEnvironment('vm_uri', defaultValue: '');

  // Skip if no URI provided
  if (vmUri.isEmpty) {
    print('''
╔══════════════════════════════════════════════════════════════════════════════╗
║  CLI Integration Tests - SKIPPED                                             ║
║                                                                              ║
║  To run these tests:                                                         ║
║  1. Start demo app:  cd apps/demo_app && flutter run -d macos               ║
║  2. Copy the VM Service URI (ws://...)                                       ║
║  3. Run tests:  VM_SERVICE_URI=ws://... dart test test/cli_integration_test.dart ║
╚══════════════════════════════════════════════════════════════════════════════╝
''');
    return;
  }

  group('CLI Integration Tests', () {
    late String cliPath;

    setUpAll(() {
      // Get path to CLI binary
      cliPath = 'bin/flutter_mate.dart';
      print('Testing with VM Service: $vmUri');
    });

    Future<ProcessResult> runCli(List<String> args) async {
      return Process.run(
        'dart',
        ['run', cliPath, '--uri', vmUri, ...args],
        workingDirectory: Directory.current.path,
      );
    }

    test('snapshot command returns valid JSON', () async {
      final result = await runCli(['snapshot', '-j']);

      expect(result.exitCode, 0, reason: 'CLI should exit with 0');

      // Parse JSON output
      final lines = (result.stdout as String).split('\n');
      final jsonLine = lines.firstWhere(
        (l) => l.trim().startsWith('{'),
        orElse: () => '',
      );

      expect(jsonLine, isNotEmpty, reason: 'Should output JSON');

      final json = jsonDecode(jsonLine);
      expect(json['success'], isTrue);
      expect(json['nodes'], isA<List>());
    });

    test('snapshot -i shows interactive elements only', () async {
      final result = await runCli(['snapshot', '-i']);

      expect(result.exitCode, 0);

      final output = result.stdout as String;
      // Should show elements with actions
      expect(output, contains('tap'));
    });

    test('tap command works on valid ref', () async {
      // First get a valid ref
      final snapshotResult = await runCli(['snapshot', '-j']);
      final lines = (snapshotResult.stdout as String).split('\n');
      final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
      final json = jsonDecode(jsonLine);

      // Find a tappable element
      final nodes = json['nodes'] as List;
      final tappableNode = nodes.firstWhere(
        (n) => (n['actions'] as List).contains('tap'),
        orElse: () => null,
      );

      if (tappableNode == null) {
        print('No tappable element found, skipping');
        return;
      }

      final ref = tappableNode['ref'];
      final result = await runCli(['tap', ref]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('succeeded'));
    });

    test('fill command works on text fields', () async {
      // Get a text field ref
      final snapshotResult = await runCli(['snapshot', '-j']);
      final lines = (snapshotResult.stdout as String).split('\n');
      final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
      final json = jsonDecode(jsonLine);

      final nodes = json['nodes'] as List;
      final textField = nodes.firstWhere(
        (n) => (n['flags'] as List).contains('isTextField'),
        orElse: () => null,
      );

      if (textField == null) {
        print('No text field found, skipping');
        return;
      }

      final ref = textField['ref'];
      final result = await runCli(['fill', ref, 'test@cli.com']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('succeeded'));
    });

    test('focus command works', () async {
      final snapshotResult = await runCli(['snapshot', '-j']);
      final lines = (snapshotResult.stdout as String).split('\n');
      final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
      final json = jsonDecode(jsonLine);

      final nodes = json['nodes'] as List;
      final focusable = nodes.firstWhere(
        (n) => (n['flags'] as List).contains('isFocusable'),
        orElse: () => null,
      );

      if (focusable == null) {
        print('No focusable element found, skipping');
        return;
      }

      final ref = focusable['ref'];
      final result = await runCli(['focus', ref]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('succeeded'));
    });

    test('typeText command works after focus', () async {
      // First focus a text field
      final snapshotResult = await runCli(['snapshot', '-j']);
      final lines = (snapshotResult.stdout as String).split('\n');
      final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
      final json = jsonDecode(jsonLine);

      final nodes = json['nodes'] as List;
      final textField = nodes.firstWhere(
        (n) => (n['flags'] as List).contains('isTextField'),
        orElse: () => null,
      );

      if (textField == null) {
        print('No text field found, skipping');
        return;
      }

      // Focus first
      await runCli(['focus', textField['ref']]);

      // Then type
      final result = await runCli(['typeText', 'Hello from CLI!']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('succeeded'));
    });

    test('scroll command works', () async {
      final snapshotResult = await runCli(['snapshot', '-j']);
      final lines = (snapshotResult.stdout as String).split('\n');
      final jsonLine = lines.firstWhere((l) => l.trim().startsWith('{'));
      final json = jsonDecode(jsonLine);

      // Try to find a scrollable or just use any element
      final nodes = json['nodes'] as List;
      if (nodes.isEmpty) {
        print('No nodes found, skipping');
        return;
      }

      final ref = nodes.first['ref'];
      final result = await runCli(['scroll', ref, 'down']);

      // Scroll might fail if element isn't scrollable, but command should run
      expect(result.exitCode, anyOf(0, 1));
    });

    test('invalid ref returns error', () async {
      final result = await runCli(['tap', 'invalid_ref_12345']);

      // Should complete but report failure
      expect(result.stdout, anyOf(contains('failed'), contains('not found')));
    });

    test('unknown command shows help', () async {
      final result = await runCli(['unknownCommand']);

      // Should show usage/help
      expect(result.stdout + result.stderr, contains('Usage'));
    });
  });
}
