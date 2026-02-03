import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';
import 'package:demo_app/main.dart';

/// Helper to set up FlutterMate tests with common boilerplate
Future<SemanticsHandle> setupTest(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  FlutterMate.initializeForTest(tester: tester);
  await FlutterMate.pumpApp(const DemoApp());
  return handle;
}

/// Tests for screenshot functionality
///
/// Note: Actual screenshot capture doesn't work in Flutter's test environment
/// due to rendering limitations. These tests verify the API contracts and
/// error handling rather than actual image capture.
void main() {
  group('ScreenshotService', () {
    testWidgets('captureElement returns null for non-existent ref',
        (tester) async {
      final semanticsHandle = await setupTest(tester);

      // Take a snapshot first to populate cache
      SnapshotService.snapshot();

      // Try to capture non-existent element - should return null immediately
      final bytes = await ScreenshotService.captureElement('w99999');

      expect(bytes, isNull);

      semanticsHandle.dispose();
    });

    testWidgets('captureElementAsBase64 returns null for non-existent ref',
        (tester) async {
      final semanticsHandle = await setupTest(tester);

      // Take a snapshot first to populate cache
      SnapshotService.snapshot();

      // Try to capture non-existent element
      final base64 = await ScreenshotService.captureElementAsBase64('w99999');

      expect(base64, isNull);

      semanticsHandle.dispose();
    });

    // Note: Full screenshot capture tests are skipped in test environment
    // because the rendering pipeline doesn't work the same way as in a real app.
    // The screenshot functionality should be tested manually or via integration tests.
  });
}
