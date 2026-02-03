import 'package:flutter_mate_cli/client/commands.dart';
import 'package:flutter_mate_cli/daemon/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('Command Builders', () {
    group('App Lifecycle', () {
      test('buildConnectCommand creates correct request', () {
        final request = buildConnectCommand('ws://localhost:12345/abc=/ws');

        expect(request.action, Actions.connect);
        expect(request.args['uri'], 'ws://localhost:12345/abc=/ws');
      });

      test('buildCloseCommand creates correct request', () {
        final request = buildCloseCommand();

        expect(request.action, Actions.close);
        expect(request.args, isEmpty);
      });

      test('buildStatusCommand creates correct request', () {
        final request = buildStatusCommand();

        expect(request.action, Actions.status);
        expect(request.args, isEmpty);
      });
    });

    group('Introspection', () {
      test('buildSnapshotCommand with no options', () {
        final request = buildSnapshotCommand();

        expect(request.action, Actions.snapshot);
        expect(request.args, isEmpty);
      });

      test('buildSnapshotCommand with all options', () {
        final request = buildSnapshotCommand(
          compact: true,
          depth: 5,
          fromRef: 'w10',
        );

        expect(request.action, Actions.snapshot);
        expect(request.args['compact'], true);
        expect(request.args['depth'], 5);
        expect(request.args['from'], 'w10');
      });

      test('buildSnapshotCommand with partial options', () {
        final request = buildSnapshotCommand(compact: true);

        expect(request.args['compact'], true);
        expect(request.args.containsKey('depth'), false);
        expect(request.args.containsKey('from'), false);
      });

      test('buildFindCommand creates correct request', () {
        final request = buildFindCommand('w25');

        expect(request.action, Actions.find);
        expect(request.args['ref'], 'w25');
      });

      test('buildScreenshotCommand with no ref', () {
        final request = buildScreenshotCommand();

        expect(request.action, Actions.screenshot);
        expect(request.args, isEmpty);
      });

      test('buildScreenshotCommand with ref', () {
        final request = buildScreenshotCommand(ref: 'w5');

        expect(request.action, Actions.screenshot);
        expect(request.args['ref'], 'w5');
      });

      test('buildGetTextCommand creates correct request', () {
        final request = buildGetTextCommand('w15');

        expect(request.action, Actions.getText);
        expect(request.args['ref'], 'w15');
      });
    });

    group('Interactions', () {
      test('buildTapCommand creates correct request', () {
        final request = buildTapCommand('w10');

        expect(request.action, Actions.tap);
        expect(request.args['ref'], 'w10');
      });

      test('buildDoubleTapCommand creates correct request', () {
        final request = buildDoubleTapCommand('w20');

        expect(request.action, Actions.doubleTap);
        expect(request.args['ref'], 'w20');
      });

      test('buildLongPressCommand creates correct request', () {
        final request = buildLongPressCommand('w30');

        expect(request.action, Actions.longPress);
        expect(request.args['ref'], 'w30');
      });

      test('buildHoverCommand creates correct request', () {
        final request = buildHoverCommand('w40');

        expect(request.action, Actions.hover);
        expect(request.args['ref'], 'w40');
      });

      test('buildDragCommand creates correct request', () {
        final request = buildDragCommand('w5', 'w10');

        expect(request.action, Actions.drag);
        expect(request.args['from'], 'w5');
        expect(request.args['to'], 'w10');
      });

      test('buildFocusCommand creates correct request', () {
        final request = buildFocusCommand('w50');

        expect(request.action, Actions.focus);
        expect(request.args['ref'], 'w50');
      });
    });

    group('Text Input', () {
      test('buildSetTextCommand creates correct request', () {
        final request = buildSetTextCommand('w10', 'hello@example.com');

        expect(request.action, Actions.setText);
        expect(request.args['ref'], 'w10');
        expect(request.args['text'], 'hello@example.com');
      });

      test('buildTypeTextCommand creates correct request', () {
        final request = buildTypeTextCommand('w15', 'typing this');

        expect(request.action, Actions.typeText);
        expect(request.args['ref'], 'w15');
        expect(request.args['text'], 'typing this');
      });

      test('buildClearCommand creates correct request', () {
        final request = buildClearCommand('w20');

        expect(request.action, Actions.clear);
        expect(request.args['ref'], 'w20');
      });
    });

    group('Scrolling', () {
      test('buildScrollCommand creates correct request', () {
        final request = buildScrollCommand('w10', 'down');

        expect(request.action, Actions.scroll);
        expect(request.args['ref'], 'w10');
        expect(request.args['direction'], 'down');
      });

      test('buildSwipeCommand creates correct request', () {
        final request = buildSwipeCommand('left');

        expect(request.action, Actions.swipe);
        expect(request.args['direction'], 'left');
      });
    });

    group('Keyboard', () {
      test('buildPressKeyCommand creates correct request', () {
        final request = buildPressKeyCommand('enter');

        expect(request.action, Actions.pressKey);
        expect(request.args['key'], 'enter');
      });

      test('buildKeyDownCommand without modifiers', () {
        final request = buildKeyDownCommand('shift');

        expect(request.action, Actions.keyDown);
        expect(request.args['key'], 'shift');
        expect(request.args.containsKey('control'), false);
        expect(request.args.containsKey('shift'), false);
      });

      test('buildKeyDownCommand with modifiers', () {
        final request = buildKeyDownCommand(
          'a',
          control: true,
          shift: true,
          alt: true,
          command: true,
        );

        expect(request.action, Actions.keyDown);
        expect(request.args['key'], 'a');
        expect(request.args['control'], true);
        expect(request.args['shift'], true);
        expect(request.args['alt'], true);
        expect(request.args['command'], true);
      });

      test('buildKeyUpCommand creates correct request', () {
        final request = buildKeyUpCommand('escape');

        expect(request.action, Actions.keyUp);
        expect(request.args['key'], 'escape');
      });
    });

    group('Waiting', () {
      test('buildWaitCommand creates correct request', () {
        final request = buildWaitCommand(2000);

        expect(request.action, Actions.wait);
        expect(request.args['ms'], 2000);
      });

      test('buildWaitForCommand with no options', () {
        final request = buildWaitForCommand('Loading');

        expect(request.action, Actions.waitFor);
        expect(request.args['pattern'], 'Loading');
        expect(request.args.containsKey('timeout'), false);
        expect(request.args.containsKey('poll'), false);
      });

      test('buildWaitForCommand with all options', () {
        final request = buildWaitForCommand(
          'Dashboard',
          timeout: 10000,
          poll: 500,
        );

        expect(request.action, Actions.waitFor);
        expect(request.args['pattern'], 'Dashboard');
        expect(request.args['timeout'], 10000);
        expect(request.args['poll'], 500);
      });

      test('buildWaitForDisappearCommand creates correct request', () {
        final request = buildWaitForDisappearCommand('Spinner', timeout: 5000);

        expect(request.action, Actions.waitForDisappear);
        expect(request.args['pattern'], 'Spinner');
        expect(request.args['timeout'], 5000);
      });

      test('buildWaitForValueCommand creates correct request', () {
        final request = buildWaitForValueCommand('w10', 'Valid', poll: 100);

        expect(request.action, Actions.waitForValue);
        expect(request.args['ref'], 'w10');
        expect(request.args['pattern'], 'Valid');
        expect(request.args['poll'], 100);
      });
    });
  });

  group('Argument Parsing Helpers', () {
    test('extractRef with valid args', () {
      expect(extractRef(['w10']), 'w10');
      expect(extractRef(['w10', 'extra']), 'w10');
    });

    test('extractRef with empty args', () {
      expect(extractRef([]), null);
    });

    test('extractRefAndText with valid args', () {
      final result = extractRefAndText(['w10', 'hello', 'world']);
      expect(result.$1, 'w10');
      expect(result.$2, 'hello world');
    });

    test('extractRefAndText with only ref', () {
      final result = extractRefAndText(['w10']);
      expect(result.$1, 'w10');
      expect(result.$2, null);
    });

    test('extractRefAndText with empty args', () {
      final result = extractRefAndText([]);
      expect(result.$1, null);
      expect(result.$2, null);
    });

    test('extractFromTo with valid args', () {
      final result = extractFromTo(['w5', 'w10']);
      expect(result.$1, 'w5');
      expect(result.$2, 'w10');
    });

    test('extractFromTo with insufficient args', () {
      expect(extractFromTo(['w5']), (null, null));
      expect(extractFromTo([]), (null, null));
    });

    test('parseIntArg with valid int', () {
      expect(parseIntArg('123'), 123);
      expect(parseIntArg('-456'), -456);
    });

    test('parseIntArg with invalid input', () {
      expect(parseIntArg(null), null);
      expect(parseIntArg('abc'), null);
      expect(parseIntArg('12.5'), null);
    });
  });

  group('Request ID Uniqueness', () {
    test('each command gets unique ID', () {
      final ids = <String>{};

      ids.add(buildTapCommand('w1').id);
      ids.add(buildTapCommand('w1').id);
      ids.add(buildSnapshotCommand().id);
      ids.add(buildCloseCommand().id);

      expect(ids.length, 4); // All unique
    });
  });
}
