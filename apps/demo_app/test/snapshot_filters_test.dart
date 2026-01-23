import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/flutter_mate.dart';
import 'package:demo_app/main.dart';

/// Tests for snapshot filtering features (depth, fromRef, compact)
void main() {
  group('Snapshot Depth Filter', () {
    testWidgets('maxDepth limits tree depth', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();

      // Shallow snapshot (depth 3)
      final shallowSnapshot = await SnapshotService.snapshot(maxDepth: 3);

      expect(fullSnapshot.success, isTrue);
      expect(shallowSnapshot.success, isTrue);

      // All nodes in shallow should be at depth <= 3
      for (final node in shallowSnapshot.nodes) {
        expect(node.depth, lessThanOrEqualTo(3),
            reason: 'Node ${node.ref} at depth ${node.depth} exceeds limit');
      }

      // Shallow should have fewer nodes than full
      expect(shallowSnapshot.nodes.length, lessThan(fullSnapshot.nodes.length));

      semanticsHandle.dispose();
    });

    testWidgets('depth 0 returns only root node', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      final snapshot = await SnapshotService.snapshot(maxDepth: 0);

      expect(snapshot.success, isTrue);
      expect(snapshot.nodes.length, equals(1));
      expect(snapshot.nodes.first.ref, equals('w0'));
      expect(snapshot.nodes.first.depth, equals(0));

      semanticsHandle.dispose();
    });

    testWidgets('refs are stable across different depth limits', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();
      final fullRefs = {for (final n in fullSnapshot.nodes) n.ref: n.widget};

      // Depth 5 snapshot
      final depth5Snapshot = await SnapshotService.snapshot(maxDepth: 5);

      // Depth 3 snapshot
      final depth3Snapshot = await SnapshotService.snapshot(maxDepth: 3);

      // All refs in depth-limited snapshots should match full snapshot
      for (final node in depth5Snapshot.nodes) {
        expect(fullRefs[node.ref], equals(node.widget),
            reason: 'Ref ${node.ref} widget mismatch');
      }

      for (final node in depth3Snapshot.nodes) {
        expect(fullRefs[node.ref], equals(node.widget),
            reason: 'Ref ${node.ref} widget mismatch');
      }

      semanticsHandle.dispose();
    });
  });

  group('Snapshot fromRef Filter', () {
    testWidgets('fromRef returns subtree starting at specified node',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot first
      final fullSnapshot = await SnapshotService.snapshot();

      // Find a mid-level node with children
      final midNode = fullSnapshot.nodes.firstWhere(
        (n) => n.depth >= 3 && n.children.isNotEmpty,
        orElse: () => fullSnapshot.nodes[fullSnapshot.nodes.length ~/ 2],
      );

      // Get subtree
      final subtreeSnapshot =
          await SnapshotService.snapshot(fromRef: midNode.ref);

      expect(subtreeSnapshot.success, isTrue);
      expect(subtreeSnapshot.nodes, isNotEmpty);

      // First node should be the specified ref
      expect(subtreeSnapshot.nodes.first.ref, equals(midNode.ref));

      // All nodes should be descendants (or the root itself)
      final subtreeRefs = subtreeSnapshot.nodes.map((n) => n.ref).toSet();
      expect(subtreeRefs.contains(midNode.ref), isTrue);

      semanticsHandle.dispose();
    });

    testWidgets('fromRef preserves original ref values', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();
      final fullRefMap = {for (final n in fullSnapshot.nodes) n.ref: n};

      // Find a node at depth >= 4
      final deepNode = fullSnapshot.nodes.firstWhere(
        (n) => n.depth >= 4,
        orElse: () => fullSnapshot.nodes.last,
      );

      // Subtree snapshot
      final subtreeSnapshot =
          await SnapshotService.snapshot(fromRef: deepNode.ref);

      // All refs should match their full snapshot counterparts
      for (final node in subtreeSnapshot.nodes) {
        final fullNode = fullRefMap[node.ref];
        expect(fullNode, isNotNull,
            reason: 'Ref ${node.ref} not found in full snapshot');
        expect(node.widget, equals(fullNode!.widget),
            reason: 'Widget type mismatch for ${node.ref}');
        expect(node.depth, equals(fullNode.depth),
            reason: 'Depth mismatch for ${node.ref}');
      }

      semanticsHandle.dispose();
    });

    testWidgets('fromRef with invalid ref returns error', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Try invalid ref
      final snapshot = await SnapshotService.snapshot(fromRef: 'w99999');

      expect(snapshot.success, isFalse);
      expect(snapshot.error, isNotNull);
      expect(snapshot.error, contains('not found'));

      semanticsHandle.dispose();
    });
  });

  group('Snapshot fromRef + Depth Combined', () {
    testWidgets('fromRef with depth is relative to subtree root',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();

      // Find a node at depth >= 3 with children
      final midNode = fullSnapshot.nodes.firstWhere(
        (n) => n.depth >= 3 && n.children.length >= 1,
        orElse: () => fullSnapshot.nodes.firstWhere(
          (n) => n.children.isNotEmpty,
        ),
      );

      final rootDepth = midNode.depth;

      // Get subtree with depth limit of 1 (root + direct children)
      final limitedSubtree = await SnapshotService.snapshot(
        fromRef: midNode.ref,
        maxDepth: 1,
      );

      expect(limitedSubtree.success, isTrue);

      // All nodes should be within 1 level of the subtree root
      for (final node in limitedSubtree.nodes) {
        expect(node.depth, lessThanOrEqualTo(rootDepth + 1),
            reason:
                'Node ${node.ref} at depth ${node.depth} exceeds limit (root: $rootDepth + 1)');
      }

      semanticsHandle.dispose();
    });

    testWidgets('fromRef with depth 0 returns only the specified node',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();

      // Pick any node with children
      final node = fullSnapshot.nodes.firstWhere(
        (n) => n.children.isNotEmpty,
      );

      // Get only that node (depth 0 relative to fromRef)
      final singleNodeSnapshot = await SnapshotService.snapshot(
        fromRef: node.ref,
        maxDepth: 0,
      );

      expect(singleNodeSnapshot.success, isTrue);
      expect(singleNodeSnapshot.nodes.length, equals(1));
      expect(singleNodeSnapshot.nodes.first.ref, equals(node.ref));

      semanticsHandle.dispose();
    });
  });

  group('Snapshot Compact Mode', () {
    testWidgets('compact mode filters structural nodes', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();

      // Compact snapshot
      final compactSnapshot = await SnapshotService.snapshot(compact: true);

      expect(fullSnapshot.success, isTrue);
      expect(compactSnapshot.success, isTrue);

      // Compact should have fewer or equal nodes
      expect(compactSnapshot.nodes.length, lessThanOrEqualTo(fullSnapshot.nodes.length));

      semanticsHandle.dispose();
    });

    testWidgets('compact mode preserves nodes with semantic info',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Compact snapshot
      final compactSnapshot = await SnapshotService.snapshot(compact: true);

      // Find nodes that have semantics labels
      final nodesWithLabels = compactSnapshot.nodes.where(
        (n) => n.semantics?.label != null && n.semantics!.label!.isNotEmpty,
      );

      // These should be preserved in compact mode
      expect(nodesWithLabels, isNotEmpty,
          reason: 'Compact mode should preserve nodes with semantic labels');

      semanticsHandle.dispose();
    });
  });

  group('Snapshot Ref Stability', () {
    testWidgets('refs are consistent across multiple snapshots', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Take 3 snapshots
      final snapshot1 = await SnapshotService.snapshot();
      final snapshot2 = await SnapshotService.snapshot();
      final snapshot3 = await SnapshotService.snapshot();

      // All should have same number of nodes
      expect(snapshot1.nodes.length, equals(snapshot2.nodes.length));
      expect(snapshot2.nodes.length, equals(snapshot3.nodes.length));

      // All refs should match
      for (int i = 0; i < snapshot1.nodes.length; i++) {
        expect(snapshot1.nodes[i].ref, equals(snapshot2.nodes[i].ref));
        expect(snapshot2.nodes[i].ref, equals(snapshot3.nodes[i].ref));
      }

      semanticsHandle.dispose();
    });

    testWidgets('refs are consistent between full and filtered snapshots',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Full snapshot
      final fullSnapshot = await SnapshotService.snapshot();

      // Various filtered snapshots
      final compactSnapshot = await SnapshotService.snapshot(compact: true);
      final depth5Snapshot = await SnapshotService.snapshot(maxDepth: 5);

      // Build full ref map
      final fullRefMap = {for (final n in fullSnapshot.nodes) n.ref: n.widget};

      // Verify compact refs match
      for (final node in compactSnapshot.nodes) {
        expect(fullRefMap.containsKey(node.ref), isTrue,
            reason: 'Compact ref ${node.ref} not in full snapshot');
        expect(fullRefMap[node.ref], equals(node.widget));
      }

      // Verify depth-limited refs match
      for (final node in depth5Snapshot.nodes) {
        expect(fullRefMap.containsKey(node.ref), isTrue,
            reason: 'Depth-limited ref ${node.ref} not in full snapshot');
        expect(fullRefMap[node.ref], equals(node.widget));
      }

      semanticsHandle.dispose();
    });
  });

  group('FlutterMate Convenience Methods', () {
    testWidgets('FlutterMate.snapshot() uses SnapshotService', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      FlutterMate.initializeForTest();

      await tester.pumpWidget(const DemoApp());
      await tester.pumpAndSettle();

      // Both should return same data
      final mate = await FlutterMate.snapshot();
      final service = await SnapshotService.snapshot();

      expect(mate.success, equals(service.success));
      expect(mate.nodes.length, equals(service.nodes.length));

      semanticsHandle.dispose();
    });
  });
}
