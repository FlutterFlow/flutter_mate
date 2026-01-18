import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mate/src/protocol.dart';

void main() {
  group('Command.parse', () {
    test('parses tap command from JSON string', () {
      final result = Command.parse('{"action": "tap", "ref": "w5"}');

      expect(result.isValid, isTrue);
      expect(result.command, isA<TapCommand>());
      expect((result.command as TapCommand).ref, 'w5');
    });

    test('parses tap command from Map', () {
      final result = Command.parse({'action': 'tap', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      expect(result.command, isA<TapCommand>());
    });

    test('preserves command id', () {
      final result = Command.parse({
        'id': 'cmd-123',
        'action': 'tap',
        'ref': 'w5',
      });

      expect(result.isValid, isTrue);
      expect(result.id, 'cmd-123');
      expect(result.command?.id, 'cmd-123');
    });

    test('returns error for missing action', () {
      final result = Command.parse({'ref': 'w5'});

      expect(result.isValid, isFalse);
      expect(result.error, contains('Missing required field: action'));
    });

    test('returns error for unknown action', () {
      final result = Command.parse({'action': 'unknownAction', 'ref': 'w5'});

      expect(result.isValid, isFalse);
      expect(result.error, contains('Unknown action'));
    });

    test('returns error for invalid input type', () {
      final result = Command.parse(12345);

      expect(result.isValid, isFalse);
      expect(result.error, contains('Invalid input type'));
    });

    test('returns error for malformed JSON', () {
      final result = Command.parse('{invalid json}');

      expect(result.isValid, isFalse);
      expect(result.error, contains('Parse error'));
    });
  });

  group('SnapshotCommand', () {
    test('parses with defaults', () {
      final result = Command.parse({'action': 'snapshot'});

      expect(result.isValid, isTrue);
      final cmd = result.command as SnapshotCommand;
      expect(cmd.interactive, isTrue);
      expect(cmd.compact, isFalse);
      expect(cmd.maxDepth, isNull);
      expect(cmd.selector, isNull);
    });

    test('parses with all options', () {
      final result = Command.parse({
        'action': 'snapshot',
        'interactive': false,
        'compact': true,
        'maxDepth': 5,
        'selector': 'w3',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as SnapshotCommand;
      expect(cmd.interactive, isFalse);
      expect(cmd.compact, isTrue);
      expect(cmd.maxDepth, 5);
      expect(cmd.selector, 'w3');
    });

    test('toJson roundtrips correctly', () {
      final cmd = SnapshotCommand(
        id: 'test-1',
        interactive: false,
        maxDepth: 3,
        compact: true,
        selector: 'w1',
      );

      final json = cmd.toJson();
      final parsed = Command.parse(json);

      expect(parsed.isValid, isTrue);
      final restored = parsed.command as SnapshotCommand;
      expect(restored.interactive, cmd.interactive);
      expect(restored.maxDepth, cmd.maxDepth);
      expect(restored.compact, cmd.compact);
      expect(restored.selector, cmd.selector);
    });
  });

  group('TapCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'tap', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      final cmd = result.command as TapCommand;
      expect(cmd.ref, 'w5');
    });

    test('toJson roundtrips', () {
      final cmd = TapCommand(id: 'tap-1', ref: 'w10');
      final json = cmd.toJson();

      expect(json['action'], 'tap');
      expect(json['ref'], 'w10');
      expect(json['id'], 'tap-1');
    });
  });

  group('TapAtCommand', () {
    test('parses coordinates', () {
      final result = Command.parse({'action': 'tapAt', 'x': 100.5, 'y': 200.0});

      expect(result.isValid, isTrue);
      final cmd = result.command as TapAtCommand;
      expect(cmd.x, 100.5);
      expect(cmd.y, 200.0);
    });

    test('handles integer coordinates', () {
      final result = Command.parse({'action': 'tapAt', 'x': 100, 'y': 200});

      expect(result.isValid, isTrue);
      final cmd = result.command as TapAtCommand;
      expect(cmd.x, 100.0);
      expect(cmd.y, 200.0);
    });
  });

  group('DoubleTapCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'doubleTap', 'ref': 'w3'});

      expect(result.isValid, isTrue);
      expect((result.command as DoubleTapCommand).ref, 'w3');
    });
  });

  group('LongPressCommand', () {
    test('parses with default duration', () {
      final result = Command.parse({'action': 'longPress', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      final cmd = result.command as LongPressCommand;
      expect(cmd.ref, 'w5');
      expect(cmd.durationMs, isNull);
    });

    test('parses with custom duration', () {
      final result = Command.parse({
        'action': 'longPress',
        'ref': 'w5',
        'durationMs': 1000,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as LongPressCommand;
      expect(cmd.durationMs, 1000);
    });
  });

  group('FillCommand', () {
    test('parses correctly', () {
      final result = Command.parse({
        'action': 'fill',
        'ref': 'w5',
        'text': 'hello@test.com',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as FillCommand;
      expect(cmd.ref, 'w5');
      expect(cmd.text, 'hello@test.com');
    });
  });

  group('TypeTextCommand', () {
    test('parses with text only', () {
      final result = Command.parse({
        'action': 'typeText',
        'text': 'Hello World',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as TypeTextCommand;
      expect(cmd.text, 'Hello World');
      expect(cmd.delayMs, isNull);
    });

    test('parses with delay', () {
      final result = Command.parse({
        'action': 'typeText',
        'text': 'Slow typing',
        'delayMs': 100,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as TypeTextCommand;
      expect(cmd.delayMs, 100);
    });
  });

  group('ClearCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'clear', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      expect((result.command as ClearCommand).ref, 'w5');
    });
  });

  group('ScrollCommand', () {
    test('parses with direction', () {
      final result = Command.parse({
        'action': 'scroll',
        'ref': 'w10',
        'direction': 'down',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as ScrollCommand;
      expect(cmd.ref, 'w10');
      expect(cmd.direction, 'down');
      expect(cmd.amount, isNull);
    });

    test('parses with amount', () {
      final result = Command.parse({
        'action': 'scroll',
        'ref': 'w10',
        'direction': 'up',
        'amount': 500.0,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as ScrollCommand;
      expect(cmd.amount, 500.0);
    });
  });

  group('SwipeCommand', () {
    test('parses with direction only', () {
      final result = Command.parse({
        'action': 'swipe',
        'direction': 'left',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as SwipeCommand;
      expect(cmd.direction, 'left');
    });

    test('parses with all options', () {
      final result = Command.parse({
        'action': 'swipe',
        'direction': 'right',
        'startX': 50.0,
        'startY': 100.0,
        'distance': 300.0,
        'durationMs': 500,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as SwipeCommand;
      expect(cmd.startX, 50.0);
      expect(cmd.startY, 100.0);
      expect(cmd.distance, 300.0);
      expect(cmd.durationMs, 500);
    });
  });

  group('FocusCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'focus', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      expect((result.command as FocusCommand).ref, 'w5');
    });
  });

  group('PressKeyCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'pressKey', 'key': 'enter'});

      expect(result.isValid, isTrue);
      expect((result.command as PressKeyCommand).key, 'enter');
    });
  });

  group('ToggleCommand', () {
    test('parses without value', () {
      final result = Command.parse({'action': 'toggle', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      final cmd = result.command as ToggleCommand;
      expect(cmd.value, isNull);
    });

    test('parses with value', () {
      final result = Command.parse({
        'action': 'toggle',
        'ref': 'w5',
        'value': true,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as ToggleCommand;
      expect(cmd.value, isTrue);
    });
  });

  group('SelectCommand', () {
    test('parses correctly', () {
      final result = Command.parse({
        'action': 'select',
        'ref': 'w5',
        'value': 'Option 1',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as SelectCommand;
      expect(cmd.ref, 'w5');
      expect(cmd.value, 'Option 1');
    });
  });

  group('WaitCommand', () {
    test('parses with milliseconds', () {
      final result = Command.parse({
        'action': 'wait',
        'milliseconds': 1000,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as WaitCommand;
      expect(cmd.milliseconds, 1000);
    });

    test('parses with condition', () {
      final result = Command.parse({
        'action': 'wait',
        'for': 'w5',
        'state': 'visible',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as WaitCommand;
      expect(cmd.forRef, 'w5');
      expect(cmd.state, 'visible');
    });
  });

  group('BackCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'back'});

      expect(result.isValid, isTrue);
      expect(result.command, isA<BackCommand>());
    });
  });

  group('NavigateCommand', () {
    test('parses with route only', () {
      final result = Command.parse({
        'action': 'navigate',
        'route': '/home',
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as NavigateCommand;
      expect(cmd.route, '/home');
      expect(cmd.arguments, isNull);
    });

    test('parses with arguments', () {
      final result = Command.parse({
        'action': 'navigate',
        'route': '/profile',
        'arguments': {'userId': 123},
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as NavigateCommand;
      expect(cmd.arguments?['userId'], 123);
    });
  });

  group('GetTextCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'getText', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      expect((result.command as GetTextCommand).ref, 'w5');
    });
  });

  group('IsVisibleCommand', () {
    test('parses correctly', () {
      final result = Command.parse({'action': 'isVisible', 'ref': 'w5'});

      expect(result.isValid, isTrue);
      expect((result.command as IsVisibleCommand).ref, 'w5');
    });
  });

  group('ScreenshotCommand', () {
    test('parses with defaults', () {
      final result = Command.parse({'action': 'screenshot'});

      expect(result.isValid, isTrue);
      final cmd = result.command as ScreenshotCommand;
      expect(cmd.fullPage, isFalse);
      expect(cmd.selector, isNull);
    });

    test('parses with options', () {
      final result = Command.parse({
        'action': 'screenshot',
        'selector': 'w5',
        'fullPage': true,
      });

      expect(result.isValid, isTrue);
      final cmd = result.command as ScreenshotCommand;
      expect(cmd.selector, 'w5');
      expect(cmd.fullPage, isTrue);
    });
  });

  group('CommandResponse', () {
    test('ok creates success response', () {
      final response = CommandResponse.ok('cmd-1', {'count': 5});

      expect(response.success, isTrue);
      expect(response.id, 'cmd-1');
      expect(response.data, {'count': 5});
      expect(response.error, isNull);
    });

    test('fail creates error response', () {
      final response = CommandResponse.fail('cmd-2', 'Element not found');

      expect(response.success, isFalse);
      expect(response.id, 'cmd-2');
      expect(response.error, 'Element not found');
      expect(response.data, isNull);
    });

    test('toJson includes all fields', () {
      final response = CommandResponse(
        id: 'cmd-1',
        success: true,
        data: 'test data',
      );

      final json = response.toJson();
      expect(json['id'], 'cmd-1');
      expect(json['success'], isTrue);
      expect(json['data'], 'test data');
    });

    test('serialize produces valid JSON', () {
      final response = CommandResponse.ok('cmd-1', {'key': 'value'});
      final serialized = response.serialize();

      final decoded = jsonDecode(serialized);
      expect(decoded['success'], isTrue);
      expect(decoded['data']['key'], 'value');
    });
  });

  group('Command.toolDefinitions', () {
    test('returns list of tool definitions', () {
      final tools = Command.toolDefinitions;

      expect(tools, isNotEmpty);
      expect(tools.length, greaterThan(10));

      // Check structure
      for (final tool in tools) {
        expect(tool['name'], isA<String>());
        expect(tool['description'], isA<String>());
        expect(tool['inputSchema'], isA<Map>());
      }
    });

    test('includes all major commands', () {
      final tools = Command.toolDefinitions;
      final names = tools.map((t) => t['name']).toSet();

      expect(names, contains('snapshot'));
      expect(names, contains('tap'));
      expect(names, contains('fill'));
      expect(names, contains('scroll'));
      expect(names, contains('typeText'));
      expect(names, contains('longPress'));
      expect(names, contains('doubleTap'));
    });
  });
}
