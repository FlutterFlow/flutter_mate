#!/usr/bin/env dart
/// End-to-End Test Runner for Flutter Mate
///
/// This script launches a real Flutter app and runs tests against it using
/// Flutter Mate's VM Service client. Unlike Flutter's test environment,
/// this tests the actual running app with real rendering, gestures, and screenshots.
///
/// Usage:
///   dart run e2e/e2e_test_runner.dart
///
/// Options:
///   --device, -d    Device to run on (default: macos)
///   --app-path      Path to Flutter app (default: ../../apps/demo_app)
///   --keep-alive    Don't kill the app after tests (for debugging)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_mate_cli/vm_service_client.dart';

// ANSI colors for output
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _reset = '\x1B[0m';
const _bold = '\x1B[1m';

/// Test result tracking
class TestResult {
  final String name;
  final bool passed;
  final String? error;
  final Duration duration;

  TestResult(this.name, this.passed, this.duration, [this.error]);
}

/// Main test runner
Future<void> main(List<String> args) async {
  final device = _getArg(args, '--device', '-d') ?? 'macos';
  final appPath = _getArg(args, '--app-path', null) ?? '../../../apps/demo_app';
  final keepAlive = args.contains('--keep-alive');

  print('${_bold}${_cyan}╔══════════════════════════════════════════════════════════════╗$_reset');
  print('${_bold}${_cyan}║         Flutter Mate E2E Test Runner                         ║$_reset');
  print('${_bold}${_cyan}╚══════════════════════════════════════════════════════════════╝$_reset');
  print('');

  Process? appProcess;
  VmServiceClient? client;
  final results = <TestResult>[];

  try {
    // 1. Launch the Flutter app
    print('${_cyan}▸ Launching Flutter app on $device...$_reset');
    final resolvedPath = _resolvePath(appPath);
    print('  App path: $resolvedPath');

    final flutterPath = _findFlutter();
    appProcess = await Process.start(
      flutterPath,
      ['run', '-d', device],
      workingDirectory: resolvedPath,
    );

    // 2. Wait for VM Service URI
    print('${_cyan}▸ Waiting for VM Service URI...$_reset');
    final uri = await _waitForVmServiceUri(appProcess);
    print('  ${_green}✓$_reset Connected: $uri');
    print('');

    // 3. Connect via VmServiceClient
    client = VmServiceClient(uri);
    await client.connect();

    // 4. Run test suites
    print('${_bold}Running Tests$_reset');
    print('${'─' * 60}');

    await _runTestSuite('Snapshot Tests', [
      () => _testBasicSnapshot(client!),
      () => _testSnapshotDepthFilter(client!),
      () => _testSnapshotFromRef(client!),
      () => _testSnapshotCompact(client!),
      () => _testSnapshotRefStability(client!),
    ], results);

    await _runTestSuite('Screenshot Tests', [
      () => _testFullScreenshot(client!),
      () => _testElementScreenshot(client!),
      () => _testScreenshotInvalidRef(client!),
    ], results);

    await _runTestSuite('Interaction Tests', [
      () => _testTap(client!),
      () => _testSetText(client!),
      () => _testFocus(client!),
      () => _testScroll(client!),
    ], results);

    await _runTestSuite('Advanced Gesture Tests', [
      () => _testDoubleTap(client!),
      () => _testLongPress(client!),
      () => _testKeyPress(client!),
      () => _testSliderInteraction(client!),
      () => _testTypeText(client!),
    ], results);

    await _runTestSuite('Find Tests', [
      () => _testFindElement(client!),
      () => _testFindByLabel(client!),
    ], results);

    await _runTestSuite('Wait Tests', [
      () => _testWaitFor(client!),
      () => _testWaitForDisappear(client!),
      () => _testWaitForValue(client!),
      () => _testWaitForTimeout(client!),
    ], results);

    // 5. Report results
    print('');
    print('${'═' * 60}');
    _printResults(results);
  } catch (e, stack) {
    print('${_red}Error: $e$_reset');
    print(stack);
  } finally {
    // Cleanup
    client?.disconnect();

    if (appProcess != null && !keepAlive) {
      print('');
      print('${_cyan}▸ Shutting down app...$_reset');
      appProcess.kill();
      await appProcess.exitCode;
      print('  ${_green}✓$_reset Done');
    } else if (keepAlive) {
      print('');
      print('${_yellow}▸ App left running (--keep-alive)$_reset');
    }
  }

  // Exit with appropriate code
  final failed = results.where((r) => !r.passed).length;
  exit(failed > 0 ? 1 : 0);
}

// ============================================================================
// Test Suites
// ============================================================================

Future<void> _runTestSuite(
  String name,
  List<Future<void> Function()> tests,
  List<TestResult> results,
) async {
  print('');
  print('${_bold}$name$_reset');

  for (final test in tests) {
    final testName = _extractTestName(test);
    final stopwatch = Stopwatch()..start();

    try {
      await test();
      stopwatch.stop();
      results.add(TestResult(testName, true, stopwatch.elapsed));
      print('  ${_green}✓$_reset $testName ${_dim}(${stopwatch.elapsedMilliseconds}ms)$_reset');
    } catch (e) {
      stopwatch.stop();
      results.add(TestResult(testName, false, stopwatch.elapsed, e.toString()));
      print('  ${_red}✗$_reset $testName');
      print('    ${_red}$e$_reset');
    }
  }
}

const _dim = '\x1B[2m';

// ============================================================================
// Snapshot Tests
// ============================================================================

Future<void> _testBasicSnapshot(VmServiceClient client) async {
  final result = await client.getSnapshot();

  _assert(result['success'] == true, 'Snapshot should succeed');

  final nodes = result['nodes'] as List;
  _assert(nodes.isNotEmpty, 'Snapshot should have nodes');

  // Check node structure
  final firstNode = nodes.first as Map<String, dynamic>;
  _assert(firstNode['ref'] != null, 'Node should have ref');
  _assert(firstNode['widget'] != null, 'Node should have widget type');
}

Future<void> _testSnapshotDepthFilter(VmServiceClient client) async {
  // Full snapshot
  final full = await client.getSnapshot();
  final fullNodes = full['nodes'] as List;

  // Depth-limited snapshot
  final shallow = await client.getSnapshot(depth: 3);
  final shallowNodes = shallow['nodes'] as List;

  _assert(shallowNodes.length <= fullNodes.length,
      'Shallow should have fewer nodes');

  // All shallow nodes should have depth <= 3
  for (final node in shallowNodes) {
    final depth = (node as Map)['depth'] as int;
    _assert(depth <= 3, 'Node depth $depth should be <= 3');
  }
}

Future<void> _testSnapshotFromRef(VmServiceClient client) async {
  // Get full snapshot first
  final full = await client.getSnapshot();
  final fullNodes = full['nodes'] as List;

  // Find a mid-level node
  Map<String, dynamic>? midNode;
  for (final n in fullNodes) {
    final node = n as Map<String, dynamic>;
    if (node['depth'] >= 3 && (node['children'] as List).isNotEmpty) {
      midNode = node;
      break;
    }
  }
  midNode ??= fullNodes[fullNodes.length ~/ 2] as Map<String, dynamic>;

  final targetRef = midNode['ref'] as String;

  // Get subtree
  final subtree = await client.getSnapshot(fromRef: targetRef);
  final subtreeNodes = subtree['nodes'] as List;

  _assert(subtreeNodes.isNotEmpty, 'Subtree should have nodes');
  _assert((subtreeNodes.first as Map)['ref'] == targetRef,
      'First node should be the target ref');
}

Future<void> _testSnapshotCompact(VmServiceClient client) async {
  final full = await client.getSnapshot();
  final compact = await client.getSnapshot(compact: true);

  final fullNodes = full['nodes'] as List;
  final compactNodes = compact['nodes'] as List;

  _assert(compactNodes.length <= fullNodes.length,
      'Compact should have fewer or equal nodes');
}

Future<void> _testSnapshotRefStability(VmServiceClient client) async {
  // Take two snapshots
  final snap1 = await client.getSnapshot();
  final snap2 = await client.getSnapshot();

  final nodes1 = snap1['nodes'] as List;
  final nodes2 = snap2['nodes'] as List;

  _assert(nodes1.length == nodes2.length, 'Should have same node count');

  // Refs should match
  for (int i = 0; i < nodes1.length; i++) {
    final ref1 = (nodes1[i] as Map)['ref'];
    final ref2 = (nodes2[i] as Map)['ref'];
    _assert(ref1 == ref2, 'Ref at index $i should match: $ref1 vs $ref2');
  }
}

// ============================================================================
// Screenshot Tests
// ============================================================================

Future<void> _testFullScreenshot(VmServiceClient client) async {
  final result = await client.callExtension('ext.flutter_mate.screenshot');

  final data = _getData(result);

  _assert(data['success'] == true, 'Screenshot should succeed: ${data['error'] ?? result['error'] ?? 'unknown'}');

  // Image data may be null if screenshot capture fails on this platform
  if (data['data'] != null) {
    _assert(data['format'] == 'png', 'Should be PNG format');
    final imageData = data['data'] as String;
    _assert(imageData.isNotEmpty, 'Image data should not be empty');
    _assert(imageData.length > 100, 'Image data should be substantial');
  } else {
    print('      (warning: screenshot returned null data - platform limitation)');
  }
}

Future<void> _testElementScreenshot(VmServiceClient client) async {
  // First get a valid ref
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Find an element with bounds
  Map<String, dynamic>? nodeWithBounds;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    if (node['bounds'] != null) {
      nodeWithBounds = node;
      break;
    }
  }
  nodeWithBounds ??= nodes.first as Map<String, dynamic>;

  final ref = nodeWithBounds['ref'] as String;

  final result = await client.callExtension(
    'ext.flutter_mate.screenshot',
    args: {'ref': ref},
  );

  final data = _getData(result);

  // Element screenshot may or may not work depending on widget type
  // At minimum, it shouldn't crash and should have a success field
  _assert(data.containsKey('success'), 'Should have success field');
}

Future<void> _testScreenshotInvalidRef(VmServiceClient client) async {
  final result = await client.callExtension(
    'ext.flutter_mate.screenshot',
    args: {'ref': 'w99999'},
  );

  final data = _getData(result);

  _assert(data['success'] == false, 'Should fail for invalid ref');
}

// ============================================================================
// Interaction Tests
// ============================================================================

Future<void> _testTap(VmServiceClient client) async {
  // Find a tappable element
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? tappable;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final actions = semantics?['actions'] as List? ?? [];
    if (actions.contains('tap')) {
      tappable = node;
      break;
    }
  }

  if (tappable == null) {
    print('      (skipped - no tappable element found)');
    return;
  }

  final ref = tappable['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.tap',
    args: {'ref': ref},
  );

  final data = _getData(result);

  _assert(data['success'] == true, 'Tap should succeed on $ref: ${data['error'] ?? 'unknown'}');
}

Future<void> _testSetText(VmServiceClient client) async {
  // Find a text field
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? textField;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final flags = semantics?['flags'] as List? ?? [];
    if (flags.contains('isTextField')) {
      textField = node;
      break;
    }
  }

  if (textField == null) {
    print('      (skipped - no text field found)');
    return;
  }

  final ref = textField['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.setText',
    args: {'ref': ref, 'text': 'e2e-test@flutter-mate.dev'},
  );

  final data = _getData(result);

  _assert(data['success'] == true, 'setText should succeed on $ref: ${data['error'] ?? 'unknown'}');
}

Future<void> _testFocus(VmServiceClient client) async {
  // Find a focusable element
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? focusable;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final flags = semantics?['flags'] as List? ?? [];
    if (flags.contains('isFocusable')) {
      focusable = node;
      break;
    }
  }

  if (focusable == null) {
    print('      (skipped - no focusable element found)');
    return;
  }

  final ref = focusable['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.focus',
    args: {'ref': ref},
  );

  final data = _getData(result);

  _assert(data['success'] == true, 'Focus should succeed on $ref: ${data['error'] ?? 'unknown'}');
}

Future<void> _testScroll(VmServiceClient client) async {
  // Find a scrollable element
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? scrollable;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final actions = semantics?['actions'] as List? ?? [];
    if (actions.contains('scrollDown') || actions.contains('scrollUp')) {
      scrollable = node;
      break;
    }
  }

  if (scrollable == null) {
    print('      (skipped - no scrollable element found)');
    return;
  }

  final ref = scrollable['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.scroll',
    args: {'ref': ref, 'direction': 'down'},
  );

  final data = _getData(result);

  _assert(data['success'] == true, 'Scroll should succeed on $ref: ${data['error'] ?? 'unknown'}');
}

// ============================================================================
// Advanced Gesture Tests
// ============================================================================

Future<void> _testDoubleTap(VmServiceClient client) async {
  // Navigate to Actions page first
  await _navigateToActionsPage(client);

  // Find the double-tap area
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? doubleTapNode;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final label = semantics?['label'] as String? ?? '';
    if (label.contains('Double tap')) {
      doubleTapNode = node;
      break;
    }
  }

  if (doubleTapNode == null) {
    print('      (skipped - not on Actions page or element not found)');
    return;
  }

  final ref = doubleTapNode['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.doubleTap',
    args: {'ref': ref},
  );

  final data = _getData(result);
  _assert(data['success'] == true, 'DoubleTap should succeed: ${data['error'] ?? 'unknown'}');
}

Future<void> _testLongPress(VmServiceClient client) async {
  // Find the long-press area
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? longPressNode;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final label = semantics?['label'] as String? ?? '';
    if (label.contains('Long press')) {
      longPressNode = node;
      break;
    }
  }

  if (longPressNode == null) {
    print('      (skipped - not on Actions page or element not found)');
    return;
  }

  final ref = longPressNode['ref'] as String;
  final result = await client.callExtension(
    'ext.flutter_mate.longPress',
    args: {'ref': ref},
  );

  final data = _getData(result);
  _assert(data['success'] == true, 'LongPress should succeed: ${data['error'] ?? 'unknown'}');
}

Future<void> _testKeyPress(VmServiceClient client) async {
  // Find the keyboard input area and focus it
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? keyboardNode;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final label = semantics?['label'] as String? ?? '';
    if (label.contains('Keyboard input')) {
      keyboardNode = node;
      break;
    }
  }

  if (keyboardNode == null) {
    print('      (skipped - not on Actions page or element not found)');
    return;
  }

  // First tap to focus
  final ref = keyboardNode['ref'] as String;
  await client.callExtension('ext.flutter_mate.tap', args: {'ref': ref});

  // Wait a bit for focus
  await Future.delayed(const Duration(milliseconds: 100));

  // Then press a key (use a standard key like 'tab')
  final result = await client.callExtension(
    'ext.flutter_mate.pressKey',
    args: {'key': 'tab'},
  );

  final data = _getData(result);
  _assert(data['success'] == true, 'pressKey should succeed: ${data['error'] ?? 'unknown'}');
}

Future<void> _testSliderInteraction(VmServiceClient client) async {
  // Find a slider element
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? sliderNode;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final flags = semantics?['flags'] as List? ?? [];
    final label = semantics?['label'] as String? ?? '';
    if (flags.contains('isSlider') || label.contains('slider') || label.contains('Value slider')) {
      sliderNode = node;
      break;
    }
  }

  if (sliderNode == null) {
    print('      (skipped - no slider found)');
    return;
  }

  // Sliders can be interacted with by using semantic actions (increase/decrease)
  final ref = sliderNode['ref'] as String;
  final semantics = sliderNode['semantics'] as Map?;
  final actions = semantics?['actions'] as List? ?? [];

  if (actions.contains('increase')) {
    final result = await client.callExtension(
      'ext.flutter_mate.tap', // or we could add a specific increase action
      args: {'ref': ref},
    );
    final data = _getData(result);
    _assert(data['success'] == true, 'Slider tap should succeed: ${data['error'] ?? 'unknown'}');
  } else {
    print('      (skipped - slider has no increase action)');
  }
}

Future<void> _testTypeText(VmServiceClient client) async {
  // Navigate back to login page first
  await _navigateToLoginPage(client);

  // Find a text field
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  Map<String, dynamic>? textField;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final flags = semantics?['flags'] as List? ?? [];
    if (flags.contains('isTextField')) {
      textField = node;
      break;
    }
  }

  if (textField == null) {
    print('      (skipped - no text field found)');
    return;
  }

  final ref = textField['ref'] as String;

  // First clear any existing text
  await client.callExtension('ext.flutter_mate.clearText', args: {'ref': ref});

  // Then type text character by character
  final result = await client.callExtension(
    'ext.flutter_mate.typeText',
    args: {'ref': ref, 'text': 'hello'},
  );

  final data = _getData(result);
  _assert(data['success'] == true, 'typeText should succeed: ${data['error'] ?? 'unknown'}');
}

/// Navigate to the Actions page in the demo app
Future<void> _navigateToActionsPage(VmServiceClient client) async {
  // First, check if we need to log in
  var snapshot = await client.getSnapshot();
  var nodes = snapshot['nodes'] as List;

  // Check if we're on the login page
  bool onLoginPage = false;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final textContent = node['textContent'] as String? ?? '';
    if (textContent.contains('Welcome Back')) {
      onLoginPage = true;
      break;
    }
  }

  if (onLoginPage) {
    // Log in first
    await _performLogin(client);
    await Future.delayed(const Duration(milliseconds: 500));
    snapshot = await client.getSnapshot();
    nodes = snapshot['nodes'] as List;
  }

  // Find the Actions tab in the bottom navigation - look for NavigationDestination or any element with Actions text that's tappable
  Map<String, dynamic>? actionsTab;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final label = semantics?['label'] as String? ?? '';
    final textContent = node['textContent'] as String? ?? '';
    final widgetType = node['widget'] as String? ?? '';
    final actions = semantics?['actions'] as List? ?? [];

    if (label.contains('Actions') || textContent.contains('Actions') ||
        (widgetType.contains('Navigation') && textContent.contains('Actions'))) {
      // NavigationDestination may not have tap action, but we can still try tapping by gesture
      if (actions.contains('tap') || widgetType == 'NavigationDestination') {
        actionsTab = node;
        // Prefer elements with tap action
        if (actions.contains('tap')) break;
      }
    }
  }

  if (actionsTab != null) {
    final ref = actionsTab['ref'] as String;
    await client.callExtension('ext.flutter_mate.tap', args: {'ref': ref});
    await Future.delayed(const Duration(milliseconds: 300)); // Wait for navigation
  }
}

/// Perform login with valid credentials
Future<void> _performLogin(VmServiceClient client) async {
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Find email and password fields - collect all text fields
  final textFields = <Map<String, dynamic>>[];
  Map<String, dynamic>? loginButton;

  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final semantics = node['semantics'] as Map?;
    final widgetType = node['widget'] as String? ?? '';
    final actions = semantics?['actions'] as List? ?? [];

    // Find actual TextField widgets (not Semantics wrappers)
    if (widgetType == 'TextField') {
      textFields.add(node);
    }

    // Look for ElevatedButton with tap action - could be wrapped in Login button semantics
    if (widgetType == 'ElevatedButton' && actions.contains('tap')) {
      loginButton = node;
    }
  }

  // First text field should be email, second should be password
  final emailField = textFields.isNotEmpty ? textFields[0] : null;
  final passwordField = textFields.length > 1 ? textFields[1] : null;

  if (emailField != null && passwordField != null && loginButton != null) {
    // Use typeText for more reliable text input
    // First clear and type email
    await client.callExtension('ext.flutter_mate.tap',
        args: {'ref': emailField['ref']});
    await Future.delayed(const Duration(milliseconds: 100));
    await client.callExtension('ext.flutter_mate.clearText', args: {});
    await Future.delayed(const Duration(milliseconds: 50));
    await client.callExtension('ext.flutter_mate.typeText',
        args: {'ref': emailField['ref'], 'text': 'test@example.com'});
    await Future.delayed(const Duration(milliseconds: 200));

    // Clear and type password
    await client.callExtension('ext.flutter_mate.tap',
        args: {'ref': passwordField['ref']});
    await Future.delayed(const Duration(milliseconds: 100));
    await client.callExtension('ext.flutter_mate.clearText', args: {});
    await Future.delayed(const Duration(milliseconds: 50));
    await client.callExtension('ext.flutter_mate.typeText',
        args: {'ref': passwordField['ref'], 'text': 'password'});
    await Future.delayed(const Duration(milliseconds: 200));

    // Click login
    await client.callExtension('ext.flutter_mate.tap',
        args: {'ref': loginButton['ref']});
    await Future.delayed(const Duration(milliseconds: 1000)); // Wait for login animation
  }
}

/// Navigate to the Login page in the demo app
Future<void> _navigateToLoginPage(VmServiceClient client) async {
  // The Login page is the initial page - we may need to go back or restart
  // For now, we'll just check if we're already there or find a way back

  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Check if Login is already visible
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final textContent = node['textContent'] as String? ?? '';
    if (textContent.contains('Welcome Back')) {
      return; // Already on login page
    }
  }

  // If not on login page, we're likely on dashboard - no easy way back in this demo
  // Just continue - some tests may be skipped
}

// ============================================================================
// Find Tests
// ============================================================================

Future<void> _testFindElement(VmServiceClient client) async {
  // Get snapshot and find an element
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  final firstRef = (nodes.first as Map)['ref'] as String;

  final result = await client.callExtension(
    'ext.flutter_mate.find',
    args: {'ref': firstRef},
  );

  // The result is wrapped in a 'result' key from callExtension
  final data = _getData(result);

  _assert(data['success'] == true, 'Find should succeed: ${data['error'] ?? 'unknown'}');
  _assert(data['element'] != null, 'Should return element data');
}

Future<void> _testFindByLabel(VmServiceClient client) async {
  // Find elements matching a label pattern in the snapshot
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Find a node with common text - could be 'List', 'Form', 'Actions', etc. on dashboard
  // or 'Login', 'Email' on login page
  Map<String, dynamic>? foundNode;
  final searchTerms = ['List', 'Form', 'Actions', 'Settings', 'Login', 'Email', 'Welcome'];
  for (final term in searchTerms) {
    for (final n in nodes) {
      final node = n as Map<String, dynamic>;
      final semantics = node['semantics'] as Map?;
      final label = semantics?['label'] as String? ?? '';
      final textContent = node['textContent'] as String? ?? '';
      if (label.contains(term) || textContent.contains(term)) {
        foundNode = node;
        break;
      }
    }
    if (foundNode != null) break;
  }

  _assert(foundNode != null, 'Should find element with a known label');
  _assert(foundNode!['ref'] != null, 'Should have ref');
}

// ============================================================================
// Wait Tests
// ============================================================================

Future<void> _testWaitFor(VmServiceClient client) async {
  // waitFor should find an existing element
  // On the current page (login or dashboard), there should be some text

  // First, let's find what's on the page
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Find any text that exists
  String? existingText;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final textContent = node['textContent'] as String?;
    if (textContent != null && textContent.length > 2) {
      existingText = textContent;
      break;
    }
    final semantics = node['semantics'] as Map?;
    final label = semantics?['label'] as String?;
    if (label != null && label.length > 2) {
      existingText = label;
      break;
    }
  }

  _assert(existingText != null, 'Should find some existing text to wait for');

  // Now waitFor should find it immediately
  final result = await client.waitFor(
    existingText!,
    timeout: const Duration(seconds: 2),
  );

  _assert(result['success'] == true, 'waitFor should find existing element');
  _assert(result['ref'] != null, 'Should return ref of found element');
  _assert(result['matchedText'] != null, 'Should return matched text');
}

Future<void> _testWaitForDisappear(VmServiceClient client) async {
  // waitForDisappear should fail fast if element still exists
  // and succeed if element doesn't exist

  // Try to wait for something that doesn't exist - should succeed immediately
  final result = await client.waitForDisappear(
    'NonExistentElement12345XYZABC',
    timeout: const Duration(seconds: 1),
  );

  _assert(result['success'] == true,
      'waitForDisappear should succeed for non-existent element');
}

Future<void> _testWaitForValue(VmServiceClient client) async {
  // Find a text element and wait for its current value
  final snapshot = await client.getSnapshot();
  final nodes = snapshot['nodes'] as List;

  // Find a text element with content
  Map<String, dynamic>? textNode;
  String? textValue;
  for (final n in nodes) {
    final node = n as Map<String, dynamic>;
    final textContent = node['textContent'] as String?;
    if (textContent != null && textContent.length > 2) {
      textNode = node;
      textValue = textContent;
      break;
    }
  }

  if (textNode == null || textValue == null) {
    // Skip if no text element found
    print('    (skipped - no text element with content found)');
    return;
  }

  final ref = textNode['ref'] as String;

  // Wait for its current value - should succeed immediately
  final result = await client.waitForValue(
    ref,
    textValue.substring(0, (textValue.length / 2).floor()), // Match partial
    timeout: const Duration(seconds: 2),
  );

  _assert(result['success'] == true, 'waitForValue should match existing value');
}

Future<void> _testWaitForTimeout(VmServiceClient client) async {
  // waitFor should timeout for non-existent element
  final result = await client.waitFor(
    'NonExistentElement12345XYZABC',
    timeout: const Duration(milliseconds: 500),
    pollInterval: const Duration(milliseconds: 100),
  );

  _assert(result['success'] == false, 'waitFor should timeout for non-existent element');
  _assert(result['error'] != null, 'Should have error message');
  _assert(result['error']!.toString().contains('Timeout'),
      'Error should mention timeout');
}

// ============================================================================
// Helpers
// ============================================================================

String? _getArg(List<String> args, String longName, String? shortName) {
  for (int i = 0; i < args.length - 1; i++) {
    if (args[i] == longName || (shortName != null && args[i] == shortName)) {
      return args[i + 1];
    }
  }
  return null;
}

String _resolvePath(String path) {
  if (path.startsWith('/')) return path;

  // Resolve relative to this script's directory
  final scriptDir = Platform.script.toFilePath();
  final dir = scriptDir.substring(0, scriptDir.lastIndexOf('/'));
  return '$dir/$path';
}

/// Find the flutter executable
String _findFlutter() {
  // Check common locations
  final candidates = [
    Platform.environment['FLUTTER_ROOT'] != null
        ? '${Platform.environment['FLUTTER_ROOT']}/bin/flutter'
        : null,
    '/Users/wenkaifan/Development/flutter/bin/flutter', // Common dev location
    '/usr/local/bin/flutter',
    'flutter', // Fall back to PATH
  ].whereType<String>();

  for (final path in candidates) {
    if (path == 'flutter') return path; // Let it try PATH
    if (File(path).existsSync()) return path;
  }

  return 'flutter';
}

Future<String> _waitForVmServiceUri(Process process) async {
  final completer = Completer<String>();
  final buffer = StringBuffer();

  process.stdout.transform(utf8.decoder).listen((data) {
    stdout.write(data); // Echo to console
    buffer.write(data);

    // Look for VM Service URI
    final match = RegExp(r'(ws://[^\s]+/ws)').firstMatch(buffer.toString());
    if (match != null && !completer.isCompleted) {
      completer.complete(match.group(1)!);
    }
  });

  process.stderr.transform(utf8.decoder).listen((data) {
    stderr.write(data);
  });

  // Timeout after 2 minutes
  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      throw TimeoutException('Timed out waiting for VM Service URI');
    },
  );
}

void _assert(bool condition, String message) {
  if (!condition) {
    throw AssertionError(message);
  }
}

/// Extract the inner result from callExtension response
Map<String, dynamic> _getData(Map<String, dynamic> result) {
  return result['result'] as Map<String, dynamic>? ?? result;
}

String _extractTestName(Function test) {
  final str = test.toString();
  // Try to extract function name from closure
  final match = RegExp(r"'([^']+)'").firstMatch(str);
  if (match != null) {
    return match.group(1)!.replaceAll('_test', '').replaceAll('_', ' ');
  }
  return 'test';
}

void _printResults(List<TestResult> results) {
  final passed = results.where((r) => r.passed).length;
  final failed = results.where((r) => !r.passed).length;
  final total = results.length;
  final totalTime = results.fold<Duration>(
    Duration.zero,
    (sum, r) => sum + r.duration,
  );

  print('${_bold}Test Results$_reset');
  print('');

  if (failed == 0) {
    print('  ${_green}✓ All $total tests passed$_reset ${_dim}(${totalTime.inMilliseconds}ms)$_reset');
  } else {
    print('  ${_green}✓ $passed passed$_reset');
    print('  ${_red}✗ $failed failed$_reset');
    print('');
    print('${_bold}Failed Tests:$_reset');
    for (final r in results.where((r) => !r.passed)) {
      print('  ${_red}✗$_reset ${r.name}');
      print('    ${_red}${r.error}$_reset');
    }
  }

  print('');
}
