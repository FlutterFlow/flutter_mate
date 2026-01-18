import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';
import 'package:demo_app/main.dart';

void main() {
  group('FlutterMate Demo Tests', () {
    testWidgets('can take snapshot and find elements by label', (tester) async {
      // Use tester's semantics (automatically disposed by test framework)
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

      // Test findByLabel
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
        (n) => n.label?.contains('Email') == true && n.flags.contains('isTextField'),
        orElse: () => throw Exception('Email field not found'),
      );

      expect(emailNode.flags, contains('isTextField'));

      semanticsHandle.dispose();
    });
  });
}
