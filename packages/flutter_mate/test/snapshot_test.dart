import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';

void main() {
  group('SnapshotService', () {
    testWidgets('snapshot returns nodes with stable refs', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Take two snapshots
      final snapshot1 = SnapshotService.snapshot();
      final snapshot2 = SnapshotService.snapshot();

      expect(snapshot1.success, isTrue);
      expect(snapshot2.success, isTrue);
      expect(snapshot1.nodes.length, equals(snapshot2.nodes.length));

      // Refs should be stable
      for (int i = 0; i < snapshot1.nodes.length; i++) {
        expect(snapshot1.nodes[i].ref, equals(snapshot2.nodes[i].ref));
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with maxDepth limits tree depth', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = SnapshotService.snapshot();

      // Depth-limited snapshot
      final shallowSnapshot = SnapshotService.snapshot(maxDepth: 3);

      expect(fullSnapshot.success, isTrue);
      expect(shallowSnapshot.success, isTrue);

      // Shallow should have fewer or equal nodes
      expect(shallowSnapshot.nodes.length, lessThanOrEqualTo(fullSnapshot.nodes.length));

      // All nodes in shallow should have depth <= 3
      for (final node in shallowSnapshot.nodes) {
        expect(node.depth, lessThanOrEqualTo(3));
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with maxDepth preserves refs', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = SnapshotService.snapshot();

      // Depth-limited snapshot
      final shallowSnapshot = SnapshotService.snapshot(maxDepth: 3);

      // Build ref map from full snapshot
      final fullRefMap = {for (final n in fullSnapshot.nodes) n.ref: n};

      // Each node in shallow snapshot should have the same ref in full snapshot
      for (final node in shallowSnapshot.nodes) {
        expect(fullRefMap.containsKey(node.ref), isTrue,
            reason: 'Ref ${node.ref} should exist in full snapshot');
        expect(fullRefMap[node.ref]!.widget, equals(node.widget),
            reason: 'Widget type should match for ref ${node.ref}');
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with fromRef returns subtree', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot first
      final fullSnapshot = SnapshotService.snapshot();
      expect(fullSnapshot.nodes.length, greaterThan(2));

      // Find a node with children
      final nodeWithChildren = fullSnapshot.nodes.firstWhere(
        (n) => n.children.isNotEmpty,
        orElse: () => fullSnapshot.nodes.first,
      );

      // Get subtree from that node
      final subtreeSnapshot =
          SnapshotService.snapshot(fromRef: nodeWithChildren.ref);

      expect(subtreeSnapshot.success, isTrue);
      expect(subtreeSnapshot.nodes, isNotEmpty);

      // First node should be the fromRef node
      expect(subtreeSnapshot.nodes.first.ref, equals(nodeWithChildren.ref));

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with fromRef preserves original refs', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = SnapshotService.snapshot();

      // Find a mid-tree node
      final midNode = fullSnapshot.nodes.firstWhere(
        (n) => n.depth >= 2 && n.children.isNotEmpty,
        orElse: () => fullSnapshot.nodes[fullSnapshot.nodes.length ~/ 2],
      );

      // Subtree snapshot
      final subtreeSnapshot =
          SnapshotService.snapshot(fromRef: midNode.ref);

      expect(subtreeSnapshot.success, isTrue);

      // Build ref map from full snapshot
      final fullRefMap = {for (final n in fullSnapshot.nodes) n.ref: n};

      // Each node in subtree should have same ref and widget type
      for (final node in subtreeSnapshot.nodes) {
        expect(fullRefMap.containsKey(node.ref), isTrue,
            reason: 'Ref ${node.ref} should exist in full snapshot');
        expect(fullRefMap[node.ref]!.widget, equals(node.widget));
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with fromRef and maxDepth combines correctly',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = SnapshotService.snapshot();

      // Find a node at depth 2 or less with children
      final rootNode = fullSnapshot.nodes.firstWhere(
        (n) => n.depth <= 2 && n.children.isNotEmpty,
        orElse: () => fullSnapshot.nodes.first,
      );

      final rootDepth = rootNode.depth;

      // Get subtree with depth limit of 1 (should show root + direct children)
      final limitedSubtree = SnapshotService.snapshot(
        fromRef: rootNode.ref,
        maxDepth: 1,
      );

      expect(limitedSubtree.success, isTrue);

      // All nodes should be within 1 level of the root
      for (final node in limitedSubtree.nodes) {
        expect(node.depth, lessThanOrEqualTo(rootDepth + 1),
            reason:
                'Node at depth ${node.depth} exceeds limit (root: $rootDepth + 1)');
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot with invalid fromRef returns error', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Try to get subtree from non-existent ref
      final snapshot = SnapshotService.snapshot(fromRef: 'w99999');

      expect(snapshot.success, isFalse);
      expect(snapshot.error, contains('not found'));

      semanticsHandle.dispose();
    });

    testWidgets('snapshot compact mode filters structural nodes',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = SnapshotService.snapshot();

      // Compact snapshot
      final compactSnapshot = SnapshotService.snapshot(compact: true);

      expect(fullSnapshot.success, isTrue);
      expect(compactSnapshot.success, isTrue);

      // Compact should have fewer or equal nodes
      expect(compactSnapshot.nodes.length, lessThanOrEqualTo(fullSnapshot.nodes.length));

      // Compact mode keeps nodes with info and their ancestors
      // Just verify we have fewer nodes (structural ones filtered)

      semanticsHandle.dispose();
    });

    testWidgets('snapshot nodes have correct structure', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      final snapshot = SnapshotService.snapshot();

      expect(snapshot.success, isTrue);
      expect(snapshot.nodes, isNotEmpty);

      for (final node in snapshot.nodes) {
        // Ref should be in wN format
        expect(node.ref, matches(RegExp(r'^w\d+$')));

        // Widget type should be non-empty
        expect(node.widget, isNotEmpty);

        // Depth should be non-negative
        expect(node.depth, greaterThanOrEqualTo(0));

        // Children should be valid refs
        for (final childRef in node.children) {
          expect(childRef, matches(RegExp(r'^w\d+$')));
        }
      }

      semanticsHandle.dispose();
    });

    testWidgets('snapshot depth 0 returns only root', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const _TestApp());
      await tester.pumpAndSettle();

      final snapshot = SnapshotService.snapshot(maxDepth: 0);

      expect(snapshot.success, isTrue);
      expect(snapshot.nodes.length, equals(1));
      expect(snapshot.nodes.first.depth, equals(0));
      expect(snapshot.nodes.first.ref, equals('w0'));

      semanticsHandle.dispose();
    });
  });

  group('CombinedSnapshot', () {
    test('toJson and fromJson roundtrip correctly', () {
      final snapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime(2024, 1, 15, 10, 30),
        nodes: [
          CombinedNode(
            ref: 'w0',
            widget: 'Container',
            depth: 0,
            bounds: CombinedRect(x: 0, y: 0, width: 100, height: 100),
            children: ['w1', 'w2'],
            textContent: 'Hello',
            semantics: SemanticsInfo(
              id: 1,
              label: 'Test label',
              flags: {'isButton'},
              actions: {'tap'},
            ),
          ),
        ],
      );

      final json = snapshot.toJson();
      final restored = CombinedSnapshot.fromJson(json);

      expect(restored.success, equals(snapshot.success));
      expect(restored.nodes.length, equals(snapshot.nodes.length));
      expect(restored.nodes.first.ref, equals('w0'));
      expect(restored.nodes.first.widget, equals('Container'));
      expect(restored.nodes.first.textContent, equals('Hello'));
      expect(restored.nodes.first.semantics?.label, equals('Test label'));
    });

    test('operator [] returns node by ref', () {
      final snapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: [
          CombinedNode(ref: 'w0', widget: 'A', depth: 0, children: []),
          CombinedNode(ref: 'w1', widget: 'B', depth: 1, children: []),
          CombinedNode(ref: 'w2', widget: 'C', depth: 1, children: []),
        ],
      );

      expect(snapshot['w0']?.widget, equals('A'));
      expect(snapshot['w1']?.widget, equals('B'));
      expect(snapshot['w2']?.widget, equals('C'));
      expect(snapshot['w99'], isNull);
    });
  });

  group('CombinedNode', () {
    test('center returns correct position', () {
      final node = CombinedNode(
        ref: 'w0',
        widget: 'Box',
        depth: 0,
        bounds: CombinedRect(x: 100, y: 200, width: 50, height: 80),
        children: [],
      );

      expect(node.center?.x, equals(125.0)); // 100 + 50/2
      expect(node.center?.y, equals(240.0)); // 200 + 80/2
    });

    test('center returns null without bounds', () {
      final node = CombinedNode(
        ref: 'w0',
        widget: 'Box',
        depth: 0,
        children: [],
      );

      expect(node.center, isNull);
    });

    test('hasAdditionalInfo returns true with semantics', () {
      final node = CombinedNode(
        ref: 'w0',
        widget: 'Button',
        depth: 0,
        children: [],
        semantics: SemanticsInfo(id: 1, label: 'Click me', flags: {}, actions: {}),
      );

      expect(node.hasAdditionalInfo, isTrue);
    });

    test('hasAdditionalInfo returns true with text content', () {
      final node = CombinedNode(
        ref: 'w0',
        widget: 'Text',
        depth: 0,
        children: [],
        textContent: 'Hello World',
      );

      expect(node.hasAdditionalInfo, isTrue);
    });

    test('hasAdditionalInfo returns false for structural node', () {
      final node = CombinedNode(
        ref: 'w0',
        widget: 'Column',
        depth: 0,
        children: ['w1', 'w2'],
      );

      expect(node.hasAdditionalInfo, isFalse);
    });
  });

  group('SemanticsInfo', () {
    test('toJson and fromJson roundtrip correctly', () {
      final info = SemanticsInfo(
        id: 42,
        label: 'Submit button',
        value: 'enabled',
        hint: 'Double tap to activate',
        role: 'button',
        flags: {'isButton', 'isFocusable'},
        actions: {'tap', 'focus'},
      );

      final json = info.toJson();
      final restored = SemanticsInfo.fromJson(json);

      expect(restored.id, equals(42));
      expect(restored.label, equals('Submit button'));
      expect(restored.value, equals('enabled'));
      expect(restored.hint, equals('Double tap to activate'));
      expect(restored.role, equals('button'));
      expect(restored.flags, containsAll({'isButton', 'isFocusable'}));
      expect(restored.actions, containsAll({'tap', 'focus'}));
    });
  });
}

/// Simple test app for snapshot testing
class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test App')),
        body: Column(
          children: [
            const Text('Header'),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
