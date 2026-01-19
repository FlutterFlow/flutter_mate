import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';
import 'package:demo_app/main.dart';

/// FlutterMate widget tests
///
/// FlutterMate in tests enables:
/// - Finding elements by semantic label (no widget keys needed!)
/// - Inspecting UI state via snapshots
/// - Gesture/text simulation (requires proper pump() calls)
void main() {
  group('FlutterMate Snapshot Tests', () {
    testWidgets('can take snapshot and find elements by label', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Take a snapshot
      final snapshot = await FlutterMate.snapshot(interactiveOnly: true);

      // Verify we have some nodes
      expect(snapshot.nodes, isNotEmpty);

      // Test findByLabel
      final emailRef = await FlutterMate.findByLabel('Email');
      final passwordRef = await FlutterMate.findByLabel('Password');
      final loginRef = await FlutterMate.findByLabel('Login');

      expect(emailRef, isNotNull, reason: 'Email field should exist');
      expect(passwordRef, isNotNull, reason: 'Password field should exist');
      expect(loginRef, isNotNull, reason: 'Login button should exist');

      semanticsHandle.dispose();
    });

    testWidgets('can find all elements matching pattern', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Find all elements with "field" in label
      final fieldRefs = await FlutterMate.findAllByLabel('field');

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
  });

  group('FlutterMate Gesture Tests', () {
    testWidgets('can tap element using gesture', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Find the email field
      final emailRef = await FlutterMate.findByLabel('Email');
      expect(emailRef, isNotNull);

      // Tap it using FlutterMate gesture
      final success = await FlutterMate.tapGesture(emailRef!);
      await tester.pump();

      expect(success, isTrue);

      semanticsHandle.dispose();
    });

    testWidgets('tapAt works with coordinates', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Get the login button position
      final loginRef = await FlutterMate.findByLabel('Login');
      expect(loginRef, isNotNull);

      final snapshot = await FlutterMate.snapshot();
      final loginNode = snapshot[loginRef!];
      expect(loginNode, isNotNull);

      // Tap at the button's center coordinates
      await FlutterMate.tapAt(loginNode!.rect.center);
      await tester.pumpAndSettle(); // Settle all animations and timers

      // If we got here without crash, tap worked
      semanticsHandle.dispose();
    });

    testWidgets('can perform drag gesture', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Perform a drag gesture on the login page (just test it doesn't crash)
      await FlutterMate.drag(
        from: const Offset(200, 400),
        to: const Offset(200, 200),
        duration: const Duration(milliseconds: 100),
      );
      await tester.pump();

      // We're still on the login page - just verify no crash
      final loginRef = await FlutterMate.findByLabel('Login');
      expect(loginRef, isNotNull);

      semanticsHandle.dispose();
    });
  });

  group('FlutterMate Text Input Tests', () {
    testWidgets('can type text using FlutterMate', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // First tap to focus
      final emailRef = await FlutterMate.findByLabel('Email');
      await FlutterMate.tapGesture(emailRef!);
      await tester.pump();

      // Now type text
      final typed = await FlutterMate.typeText('test@example.com');
      await tester.pumpAndSettle();

      expect(typed, isTrue);

      // Verify by checking the actual TextField widget
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      final actualText = textField.controller?.text ?? '';

      expect(actualText, equals('test@example.com'));

      semanticsHandle.dispose();
    });

    testWidgets('can clear text field', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Focus and type some text first using tester (reliable)
      await tester.enterText(find.byType(TextField).first, 'hello@test.com');
      await tester.pump();

      // Verify text was entered
      var textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, 'hello@test.com');

      // Clear using FlutterMate
      final emailRef = await FlutterMate.findByLabel('Email');
      final cleared = await FlutterMate.clearText();
      await tester.pump();

      expect(cleared, isTrue);

      // Verify text was cleared
      textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, isEmpty);

      semanticsHandle.dispose();
    });
  });

  group('FlutterMate Combined Usage', () {
    testWidgets('use FlutterMate find + standard tester actions',
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

      // Use standard tester methods for actions
      await tester.enterText(emailFinder.first, 'combined@test.com');
      await tester.pump();

      // Verify the text was entered
      final textField = tester.widget<TextField>(find.byType(TextField).first);
      expect(textField.controller?.text, 'combined@test.com');

      semanticsHandle.dispose();
    });

    testWidgets('full login flow with FlutterMate', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Find elements
      final emailRef = await FlutterMate.findByLabel('Email');
      final passwordRef = await FlutterMate.findByLabel('Password');
      final loginRef = await FlutterMate.findByLabel('Login');

      expect(emailRef, isNotNull);
      expect(passwordRef, isNotNull);
      expect(loginRef, isNotNull);

      // Fill email
      await FlutterMate.tapGesture(emailRef!);
      await tester.pump();
      await FlutterMate.typeText('user@example.com');
      await tester.pump();

      // Fill password (use tester.enterText for reliability)
      await tester.enterText(
        find.bySemanticsLabel(RegExp('Password')).first,
        'password123',
      );
      await tester.pump();

      // Tap login
      await FlutterMate.tapGesture(loginRef!);
      await tester.pumpAndSettle();

      // Login was attempted (even if validation fails)
      semanticsHandle.dispose();
    });
  });
}
