import 'package:flutter_mate_cli/snapshot_formatter.dart';
import 'package:test/test.dart';

void main() {
  group('parseNodes', () {
    test('parses raw JSON nodes into CombinedNode map', () {
      final rawNodes = [
        {
          'ref': 'w0',
          'widget': 'Container',
          'depth': 0,
          'children': ['w1'],
        },
        {
          'ref': 'w1',
          'widget': 'Text',
          'depth': 1,
          'children': [],
          'textContent': 'Hello',
        },
      ];

      final nodeMap = parseNodes(rawNodes);

      expect(nodeMap.length, equals(2));
      expect(nodeMap['w0']?.widget, equals('Container'));
      expect(nodeMap['w1']?.widget, equals('Text'));
      expect(nodeMap['w1']?.textContent, equals('Hello'));
    });

    test('handles empty nodes list', () {
      final nodeMap = parseNodes([]);
      expect(nodeMap, isEmpty);
    });

    test('parses bounds correctly', () {
      final rawNodes = [
        {
          'ref': 'w0',
          'widget': 'Box',
          'depth': 0,
          'children': [],
          'bounds': {'x': 10.0, 'y': 20.0, 'width': 100.0, 'height': 50.0},
        },
      ];

      final nodeMap = parseNodes(rawNodes);
      final bounds = nodeMap['w0']!.bounds!;

      expect(bounds.x, equals(10.0));
      expect(bounds.y, equals(20.0));
      expect(bounds.width, equals(100.0));
      expect(bounds.height, equals(50.0));
    });

    test('parses semantics correctly', () {
      final rawNodes = [
        {
          'ref': 'w0',
          'widget': 'Button',
          'depth': 0,
          'children': [],
          'semantics': {
            'id': 5,
            'label': 'Click me',
            'flags': ['isButton'],
            'actions': ['tap'],
          },
        },
      ];

      final nodeMap = parseNodes(rawNodes);
      final semantics = nodeMap['w0']!.semantics!;

      expect(semantics.id, equals(5));
      expect(semantics.label, equals('Click me'));
      expect(semantics.flags, contains('isButton'));
      expect(semantics.actions, contains('tap'));
    });
  });

  group('collapseNodes', () {
    test('collapses single-child chains', () {
      final nodeMap = parseNodes([
        {'ref': 'w0', 'widget': 'Container', 'depth': 0, 'children': ['w1']},
        {'ref': 'w1', 'widget': 'Padding', 'depth': 1, 'children': ['w2']},
        {'ref': 'w2', 'widget': 'Text', 'depth': 2, 'children': [], 'textContent': 'Hello'},
      ]);

      final collapsed = collapseNodes(nodeMap);

      // Should collapse Container -> Padding -> Text into one entry
      expect(collapsed.length, equals(1));
      expect(collapsed.first.chain.length, greaterThanOrEqualTo(1));
    });

    test('does not collapse multi-child nodes', () {
      final nodeMap = parseNodes([
        {'ref': 'w0', 'widget': 'Column', 'depth': 0, 'children': ['w1', 'w2']},
        {'ref': 'w1', 'widget': 'Text', 'depth': 1, 'children': [], 'textContent': 'A'},
        {'ref': 'w2', 'widget': 'Text', 'depth': 1, 'children': [], 'textContent': 'B'},
      ]);

      final collapsed = collapseNodes(nodeMap);

      // Column should stay separate, with 2 children
      expect(collapsed.length, equals(3));
    });

    test('handles empty node map', () {
      final collapsed = collapseNodes({});
      expect(collapsed, isEmpty);
    });

    test('finds root at minimum depth when non-zero', () {
      // Simulates --from flag where root is not at depth 0
      final nodeMap = parseNodes([
        {'ref': 'w5', 'widget': 'AppBar', 'depth': 3, 'children': ['w6']},
        {'ref': 'w6', 'widget': 'Text', 'depth': 4, 'children': [], 'textContent': 'Title'},
      ]);

      final collapsed = collapseNodes(nodeMap);

      // Should find w5 as root (minimum depth is 3)
      expect(collapsed.length, greaterThanOrEqualTo(1));
      expect(collapsed.first.chain.first.ref, equals('w5'));
      // Display depth should start at 0
      expect(collapsed.first.depth, equals(0));
    });
  });

  group('formatCollapsedEntry', () {
    test('formats entry with text content', () {
      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Text')],
        depth: 0,
        textContent: 'Hello World',
      );

      final formatted = formatCollapsedEntry(entry);

      expect(formatted, contains('[w0]'));
      expect(formatted, contains('Text'));
      expect(formatted, contains('Hello World'));
    });

    test('formats entry with semantics label', () {
      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Button')],
        depth: 0,
        semantics: SemanticsInfo(id: 1, label: 'Submit', flags: {}, actions: {}),
      );

      final formatted = formatCollapsedEntry(entry);

      expect(formatted, contains('Submit'));
    });

    test('formats entry with flags', () {
      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'TextField')],
        depth: 0,
        semantics: SemanticsInfo(
          id: 1,
          flags: {'isTextField', 'isFocusable'},
          actions: {},
        ),
      );

      final formatted = formatCollapsedEntry(entry);

      expect(formatted, contains('TextField'));
      expect(formatted, contains('Focusable'));
    });

    test('formats entry with actions', () {
      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Button')],
        depth: 0,
        semantics: SemanticsInfo(
          id: 1,
          flags: {},
          actions: {'tap', 'longPress'},
        ),
      );

      final formatted = formatCollapsedEntry(entry);

      expect(formatted, contains('[tap'));
      expect(formatted, contains('longPress'));
    });

    test('applies correct indentation', () {
      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Text')],
        depth: 2,
        textContent: 'Deep',
      );

      final formatted = formatCollapsedEntry(entry);

      // Should have indentation for depth 2
      expect(formatted, startsWith('    ')); // 2 * 2 spaces
    });

    test('formats chain with multiple widgets', () {
      final entry = CollapsedEntry(
        chain: [
          ChainItem(ref: 'w0', widget: 'MaterialApp'),
          ChainItem(ref: 'w1', widget: 'Scaffold'),
          ChainItem(ref: 'w2', widget: 'Column'),
        ],
        depth: 0,
      );

      final formatted = formatCollapsedEntry(entry);

      expect(formatted, contains('MaterialApp'));
      expect(formatted, contains('Scaffold'));
      expect(formatted, contains('Column'));
      expect(formatted, contains('→'));
    });

    test('compact mode shows only last widget', () {
      final entry = CollapsedEntry(
        chain: [
          ChainItem(ref: 'w0', widget: 'MaterialApp'),
          ChainItem(ref: 'w1', widget: 'Scaffold'),
          ChainItem(ref: 'w2', widget: 'Column'),
        ],
        depth: 0,
      );

      final formatted = formatCollapsedEntry(entry, compact: true);

      expect(formatted, contains('[w2]'));
      expect(formatted, contains('Column'));
      // Should not show intermediate widgets
      expect(formatted, isNot(contains('MaterialApp')));
    });
  });

  group('formatSnapshot', () {
    test('formats nodes list', () {
      final nodes = [
        {'ref': 'w0', 'widget': 'App', 'depth': 0, 'children': ['w1']},
        {
          'ref': 'w1',
          'widget': 'Text',
          'depth': 1,
          'children': [],
          'textContent': 'Hello'
        },
      ];

      final lines = formatSnapshot(nodes);
      final formatted = lines.join('\n');

      expect(formatted, contains('[w0]'));
      expect(formatted, contains('Hello'));
    });

    test('handles empty nodes list', () {
      final lines = formatSnapshot([]);
      expect(lines, isEmpty);
    });

    test('compact mode filters structural nodes', () {
      final nodes = [
        {'ref': 'w0', 'widget': 'Column', 'depth': 0, 'children': ['w1']},
        {
          'ref': 'w1',
          'widget': 'Text',
          'depth': 1,
          'children': [],
          'textContent': 'Hello'
        },
      ];

      final normalLines = formatSnapshot(nodes);
      final compactLines = formatSnapshot(nodes, compact: true);

      // Compact should have fewer or equal lines
      expect(compactLines.length, lessThanOrEqualTo(normalLines.length));
    });
  });

  group('hasAdditionalInfo', () {
    test('returns true for node with text', () {
      final nodeMap = parseNodes([
        {'ref': 'w0', 'widget': 'Text', 'depth': 0, 'children': [], 'textContent': 'Hi'},
      ]);

      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Text')],
        depth: 0,
        textContent: 'Hi',
      );

      expect(hasAdditionalInfo(entry, nodeMap), isTrue);
    });

    test('returns true for node with semantics', () {
      final nodeMap = parseNodes([
        {
          'ref': 'w0',
          'widget': 'Button',
          'depth': 0,
          'children': [],
          'semantics': {'id': 1, 'label': 'Click', 'flags': [], 'actions': []}
        },
      ]);

      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Button')],
        depth: 0,
        semantics: SemanticsInfo(id: 1, label: 'Click', flags: {}, actions: {}),
      );

      expect(hasAdditionalInfo(entry, nodeMap), isTrue);
    });

    test('returns false for structural node', () {
      final nodeMap = parseNodes([
        {'ref': 'w0', 'widget': 'Column', 'depth': 0, 'children': ['w1']},
      ]);

      final entry = CollapsedEntry(
        chain: [ChainItem(ref: 'w0', widget: 'Column')],
        depth: 0,
      );

      expect(hasAdditionalInfo(entry, nodeMap), isFalse);
    });
  });

  group('escapeString', () {
    test('escapes newlines', () {
      expect(escapeString('Hello\nWorld'), equals(r'Hello\nWorld'));
    });

    test('escapes tabs', () {
      expect(escapeString('Hello\tWorld'), equals(r'Hello\tWorld'));
    });

    test('escapes quotes', () {
      expect(escapeString('Say "Hi"'), equals(r'Say \"Hi\"'));
    });

    test('escapes dollar signs by default', () {
      expect(escapeString('Cost: \$100'), equals(r'Cost: \$100'));
    });

    test('preserves dollar signs when disabled', () {
      expect(escapeString('Cost: \$100', escapeDollar: false), equals(r'Cost: $100'));
    });
  });

  group('formatElementDetails', () {
    test('formats element with all properties', () {
      final element = {
        'ref': 'w5',
        'widget': 'ElevatedButton',
        'bounds': {'x': 100.0, 'y': 200.0, 'width': 150.0, 'height': 48.0},
        'textContent': 'Submit',
        'semantics': {
          'id': 10,
          'label': 'Submit button',
          'flags': ['isButton', 'isFocusable'],
          'actions': ['tap'],
        },
        'children': ['w6'],
      };

      final lines = formatElementDetails(element);
      final formatted = lines.join('\n');

      expect(formatted, contains('[w5]'));
      expect(formatted, contains('ElevatedButton'));
      expect(formatted, contains('100')); // x position
      expect(formatted, contains('200')); // y position
      expect(formatted, contains('Submit button')); // label
      expect(formatted, contains('isButton'));
      expect(formatted, contains('Children: 1'));
    });

    test('handles element without bounds', () {
      final element = {
        'ref': 'w0',
        'widget': 'Text',
        'textContent': 'Hello',
        'children': [],
      };

      final lines = formatElementDetails(element);
      final formatted = lines.join('\n');

      expect(formatted, contains('[w0]'));
      expect(formatted, contains('Text'));
      expect(formatted, isNot(contains('Bounds')));
    });
  });
}
