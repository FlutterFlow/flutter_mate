import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';
import 'package:demo_app/main.dart';

/// FlutterMate widget tests
///
/// In widget tests, FlutterMate is best used for:
/// - Finding elements by semantic label (no widget keys needed)
/// - Inspecting UI state via snapshots
///
/// For actual interactions (tap, type), use standard tester methods
/// because widget tests use mocked input that doesn't integrate with
/// gesture injection.
void main() {
  group('FlutterMate Demo Tests', () {
    testWidgets('can take snapshot and find elements by label', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Take a snapshot
      final snapshot = await FlutterMate.snapshot(interactiveOnly: true);

      // Verify we have some nodes
      expect(snapshot.nodes, isNotEmpty);

      // Print nodes for debugging
      // ignore: avoid_print
      print('Found ${snapshot.nodes.length} interactive nodes:');
      for (final node in snapshot.nodes) {
        // ignore: avoid_print
        print('  ${node.ref}: ${node.label ?? "(no label)"}');
      }

      // Test findByLabel - the key feature for tests!
      final emailRef = await FlutterMate.findByLabel('Email');
      final passwordRef = await FlutterMate.findByLabel('Password');
      final loginRef = await FlutterMate.findByLabel('Login');

      expect(emailRef, isNotNull, reason: 'Email field should exist');
      expect(passwordRef, isNotNull, reason: 'Password field should exist');
      expect(loginRef, isNotNull, reason: 'Login button should exist');

      // ignore: avoid_print
      print('Found: email=$emailRef, password=$passwordRef, login=$loginRef');

      semanticsHandle.dispose();
    });

    testWidgets('can find all elements matching pattern', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Find all elements with "field" in label
      final fieldRefs = await FlutterMate.findAllByLabel('field');

      // ignore: avoid_print
      print('Found ${fieldRefs.length} elements matching "field": $fieldRefs');

      expect(fieldRefs.length, greaterThanOrEqualTo(2),
          reason: 'Should have email and password fields');

      semanticsHandle.dispose();
    });

    testWidgets('snapshot contains correct element properties', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      final snapshot = await FlutterMate.snapshot();

      // Find login button
      final loginNode = snapshot.nodes.firstWhere(
        (n) => n.label == 'Login' && n.flags.contains('isButton'),
        orElse: () => throw Exception('Login button not found'),
      );

      expect(loginNode.flags, contains('isButton'));
      expect(loginNode.actions, contains('tap'));

      // Find email field
      final emailNode = snapshot.nodes.firstWhere(
        (n) =>
            n.label?.contains('Email') == true &&
            n.flags.contains('isTextField'),
        orElse: () => throw Exception('Email field not found'),
      );

      expect(emailNode.flags, contains('isTextField'));

      semanticsHandle.dispose();
    });

    testWidgets('can use findByLabel with standard tester actions',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Use FlutterMate to find by label (no widget keys needed!)
      final emailRef = await FlutterMate.findByLabel('Email');
      expect(emailRef, isNotNull);

      // Get the actual widget using standard tester (by semantics label)
      final emailFinder = find.bySemanticsLabel(RegExp('Email'));

      // Use standard tester methods for reliable actions in tests
      await tester.enterText(emailFinder.first, 'test@example.com');
      await tester.pump();

      // Verify via snapshot
      final snapshot = await FlutterMate.snapshot();
      final emailNode = snapshot.nodes.firstWhere(
        (n) => n.label?.contains('Email') == true,
      );
      
      // ignore: avoid_print
      print('Email value: ${emailNode.value}');

      semanticsHandle.dispose();
    });
  });
}
