import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/src/snapshot.dart';

void main() {
  group('Snapshot', () {
    test('can be created with nodes', () {
      final snapshot = Snapshot(
        success: true,
        timestamp: DateTime(2026, 1, 19),
        nodes: [
          SnapshotNode(
            ref: 'w0',
            id: 0,
            depth: 0,
            label: 'Test Button',
            actions: ['tap'],
            flags: ['isButton'],
            rect: Rect(x: 0, y: 0, width: 100, height: 50),
            isInteractive: true,
          ),
        ],
        refs: {},
      );

      expect(snapshot.success, isTrue);
      expect(snapshot.nodes.length, 1);
      expect(snapshot.nodes.first.label, 'Test Button');
    });

    test('access node by ref with [] operator', () {
      final node = SnapshotNode(
        ref: 'w5',
        id: 5,
        depth: 1,
        label: 'Email',
        actions: ['tap', 'focus'],
        flags: ['isTextField'],
        rect: Rect(x: 10, y: 20, width: 200, height: 48),
        isInteractive: true,
      );

      final snapshot = Snapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: [node],
        refs: {'w5': node},
      );

      // Direct access
      expect(snapshot['w5'], equals(node));

      // With @ prefix
      expect(snapshot['@w5'], equals(node));

      // Non-existent ref
      expect(snapshot['w99'], isNull);
    });

    test('interactive getter filters correctly', () {
      final interactiveNode = SnapshotNode(
        ref: 'w1',
        id: 1,
        depth: 0,
        label: 'Button',
        actions: ['tap'],
        flags: ['isButton'],
        rect: Rect(x: 0, y: 0, width: 100, height: 50),
        isInteractive: true,
      );

      final nonInteractiveNode = SnapshotNode(
        ref: 'w2',
        id: 2,
        depth: 0,
        label: 'Text',
        actions: [],
        flags: [],
        rect: Rect(x: 0, y: 50, width: 100, height: 20),
        isInteractive: false,
      );

      final snapshot = Snapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: [interactiveNode, nonInteractiveNode],
        refs: {'w1': interactiveNode, 'w2': nonInteractiveNode},
      );

      expect(snapshot.interactive.length, 1);
      expect(snapshot.interactive.first.ref, 'w1');
    });

    test('toJson includes all fields', () {
      final snapshot = Snapshot(
        success: true,
        timestamp: DateTime(2026, 1, 19, 10, 30, 0),
        nodes: [
          SnapshotNode(
            ref: 'w0',
            id: 0,
            depth: 0,
            label: 'Test',
            value: 'Value',
            hint: 'Hint',
            actions: ['tap'],
            flags: ['isButton'],
            rect: Rect(x: 0, y: 0, width: 100, height: 50),
            isInteractive: true,
          ),
        ],
        refs: {},
      );

      final json = snapshot.toJson();

      expect(json['success'], isTrue);
      expect(json['timestamp'], '2026-01-19T10:30:00.000');
      expect(json['nodeCount'], 1);
      expect(json['nodes'], isA<List>());
    });

    test('toString shows readable format', () {
      final snapshot = Snapshot(
        success: true,
        timestamp: DateTime(2026, 1, 19),
        nodes: [
          SnapshotNode(
            ref: 'w0',
            id: 0,
            depth: 0,
            label: 'Login',
            actions: ['tap'],
            flags: ['isButton'],
            rect: Rect(x: 0, y: 0, width: 100, height: 50),
            isInteractive: true,
          ),
        ],
        refs: {},
      );

      final str = snapshot.toString();

      expect(str, contains('Flutter Mate Snapshot'));
      expect(str, contains('w0'));
      expect(str, contains('Login'));
      expect(str, contains('[tap]'));
    });

    test('failed snapshot shows error', () {
      final snapshot = Snapshot(
        success: false,
        error: 'Connection failed',
        timestamp: DateTime.now(),
        nodes: [],
        refs: {},
      );

      expect(snapshot.toString(), contains('failed'));
      expect(snapshot.toString(), contains('Connection failed'));
    });
  });

  group('SnapshotNode', () {
    test('hasAction checks correctly', () {
      final node = SnapshotNode(
        ref: 'w0',
        id: 0,
        depth: 0,
        actions: ['tap', 'focus', 'longPress'],
        flags: [],
        rect: Rect(x: 0, y: 0, width: 100, height: 50),
        isInteractive: true,
      );

      expect(node.hasAction('tap'), isTrue);
      expect(node.hasAction('focus'), isTrue);
      expect(node.hasAction('scroll'), isFalse);
    });

    test('hasFlag checks correctly', () {
      final node = SnapshotNode(
        ref: 'w0',
        id: 0,
        depth: 0,
        actions: [],
        flags: ['isButton', 'isEnabled', 'isFocusable'],
        rect: Rect(x: 0, y: 0, width: 100, height: 50),
        isInteractive: true,
      );

      expect(node.hasFlag('isButton'), isTrue);
      expect(node.hasFlag('isEnabled'), isTrue);
      expect(node.hasFlag('isTextField'), isFalse);
    });

    test('typeIcon returns correct icons', () {
      expect(
        SnapshotNode(
          ref: 'w0',
          id: 0,
          depth: 0,
          actions: [],
          flags: ['isButton'],
          rect: Rect(x: 0, y: 0, width: 100, height: 50),
          isInteractive: true,
        ).typeIcon,
        '🔘',
      );

      expect(
        SnapshotNode(
          ref: 'w1',
          id: 1,
          depth: 0,
          actions: [],
          flags: ['isTextField'],
          rect: Rect(x: 0, y: 0, width: 100, height: 50),
          isInteractive: true,
        ).typeIcon,
        '📝',
      );

      expect(
        SnapshotNode(
          ref: 'w2',
          id: 2,
          depth: 0,
          actions: [],
          flags: ['isLink'],
          rect: Rect(x: 0, y: 0, width: 100, height: 50),
          isInteractive: true,
        ).typeIcon,
        '🔗',
      );

      expect(
        SnapshotNode(
          ref: 'w3',
          id: 3,
          depth: 0,
          actions: [],
          flags: ['isSlider'],
          rect: Rect(x: 0, y: 0, width: 100, height: 50),
          isInteractive: true,
        ).typeIcon,
        '🎚️',
      );
    });

    test('toJson includes optional fields only when present', () {
      final nodeWithAll = SnapshotNode(
        ref: 'w0',
        id: 0,
        depth: 0,
        label: 'Label',
        value: 'Value',
        hint: 'Hint',
        actions: ['tap'],
        flags: ['isButton'],
        rect: Rect(x: 0, y: 0, width: 100, height: 50),
        isInteractive: true,
      );

      final jsonWithAll = nodeWithAll.toJson();
      expect(jsonWithAll['label'], 'Label');
      expect(jsonWithAll['value'], 'Value');
      expect(jsonWithAll['hint'], 'Hint');

      final nodeWithoutOptional = SnapshotNode(
        ref: 'w1',
        id: 1,
        depth: 0,
        actions: [],
        flags: [],
        rect: Rect(x: 0, y: 0, width: 100, height: 50),
        isInteractive: false,
      );

      final jsonWithout = nodeWithoutOptional.toJson();
      expect(jsonWithout.containsKey('label'), isFalse);
      expect(jsonWithout.containsKey('value'), isFalse);
      expect(jsonWithout.containsKey('hint'), isFalse);
    });
  });

  group('Rect', () {
    test('center calculates correctly', () {
      final rect = Rect(x: 100, y: 200, width: 50, height: 30);

      expect(rect.center.dx, 125.0);
      expect(rect.center.dy, 215.0);
    });

    test('toJson returns map', () {
      final rect = Rect(x: 10, y: 20, width: 100, height: 50);
      final json = rect.toJson();

      expect(json['x'], 10);
      expect(json['y'], 20);
      expect(json['width'], 100);
      expect(json['height'], 50);
    });
  });
}
