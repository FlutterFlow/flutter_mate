import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_mate_cli/vm_service_client.dart';

const String version = '0.1.0';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version')
    ..addOption('uri', abbr: 'u', help: 'VM Service WebSocket URI (ws://...)')
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON');

  // Add subcommands with their own options
  final snapshotParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for snapshot')
    ..addFlag('compact',
        abbr: 'c',
        negatable: false,
        help: 'Only show widgets with meaningful info (text, actions, flags)')
    ..addOption('depth',
        abbr: 'd', help: 'Limit tree depth (e.g., --depth 3 for top 3 levels)')
    ..addOption('from',
        abbr: 'f',
        help:
            'Start from specific ref as root (e.g., --from w15). Requires prior snapshot.');
  parser.addCommand('snapshot', snapshotParser);

  final screenshotParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for screenshot')
    ..addOption('ref',
        abbr: 'r', help: 'Capture specific element only (e.g., --ref w10)')
    ..addOption('path',
        abbr: 'p',
        help: 'Output file path (default: screenshot_<timestamp>.png)');
  parser.addCommand('screenshot', screenshotParser);

  final tapParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for tap');
  parser.addCommand('tap', tapParser);

  final setTextParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for setText');
  parser.addCommand('setText', setTextParser);

  final typeTextParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for typeText');
  parser.addCommand('typeText', typeTextParser);

  final scrollParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for scroll');
  parser.addCommand('scroll', scrollParser);

  final findParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for find');
  parser.addCommand('find', findParser);

  // Wait commands with options
  final waitForParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for waitFor')
    ..addOption('timeout',
        abbr: 't', help: 'Timeout in milliseconds (default: 5000)')
    ..addOption('poll',
        abbr: 'p', help: 'Polling interval in milliseconds (default: 200)');
  parser.addCommand('waitFor', waitForParser);

  final waitForDisappearParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for waitForDisappear')
    ..addOption('timeout',
        abbr: 't', help: 'Timeout in milliseconds (default: 5000)')
    ..addOption('poll',
        abbr: 'p', help: 'Polling interval in milliseconds (default: 200)');
  parser.addCommand('waitForDisappear', waitForDisappearParser);

  final waitForValueParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for waitForValue')
    ..addOption('timeout',
        abbr: 't', help: 'Timeout in milliseconds (default: 5000)')
    ..addOption('poll',
        abbr: 'p', help: 'Polling interval in milliseconds (default: 200)');
  parser.addCommand('waitForValue', waitForValueParser);

  // Simple commands without extra options
  parser.addCommand('fill');
  parser.addCommand('focus');
  parser.addCommand('doubleTap');
  parser.addCommand('longPress');
  parser.addCommand('swipe');
  parser.addCommand('hover');
  parser.addCommand('drag');
  parser.addCommand('clear');
  parser.addCommand('pressKey');
  parser.addCommand('keyDown');
  parser.addCommand('keyUp');
  parser.addCommand('back');
  parser.addCommand('wait');
  parser.addCommand('getText');
  parser.addCommand('extensions');
  parser.addCommand('attach');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (results['version'] as bool) {
      print('flutter_mate v$version');
      return;
    }

    final wsUri = results['uri'] as String?;
    final jsonOutput = results['json'] as bool;

    // Determine command first to check for subcommand help
    String command;
    List<String> cmdArgs;
    ArgResults? cmdResults;

    if (results.command != null) {
      command = results.command!.name!;
      cmdArgs = results.command!.rest;
      cmdResults = results.command;
    } else if (results.rest.isNotEmpty) {
      command = results.rest[0];
      cmdArgs = results.rest.skip(1).toList();
    } else {
      _printUsage(parser);
      return;
    }

    // Check for subcommand help
    if (cmdResults != null && cmdResults['help'] == true) {
      _printCommandHelp(command, parser);
      return;
    }

    // Parse command-specific options
    bool compact = false;
    int? depth;
    String? fromRef;
    String? screenshotRef;
    String? screenshotPath;

    if (command == 'snapshot' && cmdResults != null) {
      compact = cmdResults['compact'] as bool? ?? false;
      final depthStr = cmdResults['depth'] as String?;
      depth = depthStr != null ? int.tryParse(depthStr) : null;
      fromRef = cmdResults['from'] as String?;
    } else if (command == 'screenshot' && cmdResults != null) {
      screenshotRef = cmdResults['ref'] as String?;
      screenshotPath = cmdResults['path'] as String?;
    }

    // Parse wait command options
    int? waitTimeout;
    int? waitPoll;
    if ((command == 'waitFor' ||
            command == 'waitForDisappear' ||
            command == 'waitForValue') &&
        cmdResults != null) {
      final timeoutStr = cmdResults['timeout'] as String?;
      final pollStr = cmdResults['poll'] as String?;
      waitTimeout = timeoutStr != null ? int.tryParse(timeoutStr) : null;
      waitPoll = pollStr != null ? int.tryParse(pollStr) : null;
    }

    if (wsUri == null) {
      stderr.writeln('Error: --uri is required');
      stderr.writeln('');
      stderr.writeln(
          'Get the URI from Flutter console output when running your app:');
      stderr.writeln(
          '  A Dart VM Service on macOS is available at: http://127.0.0.1:xxxxx/yyy=/');
      stderr.writeln('');
      stderr.writeln('Convert to WebSocket URI and use:');
      stderr.writeln(
          '  flutter_mate --uri ws://127.0.0.1:xxxxx/yyy=/ws snapshot');
      exit(1);
    }

    // Normalize URI
    var uri = wsUri;
    if (uri.startsWith('http://')) {
      uri = uri.replaceFirst('http://', 'ws://');
    }
    if (!uri.endsWith('/ws')) {
      uri = uri.endsWith('/') ? '${uri}ws' : '$uri/ws';
    }

    await _executeCommand(
      command: command,
      args: cmdArgs,
      wsUri: uri,
      jsonOutput: jsonOutput,
      compact: compact,
      depth: depth,
      fromRef: fromRef,
      screenshotRef: screenshotRef,
      screenshotPath: screenshotPath,
      waitTimeout: waitTimeout,
      waitPoll: waitPoll,
    );
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

Future<void> _executeCommand({
  required String command,
  required List<String> args,
  required String wsUri,
  required bool jsonOutput,
  required bool compact,
  int? depth,
  String? fromRef,
  String? screenshotRef,
  String? screenshotPath,
  int? waitTimeout,
  int? waitPoll,
}) async {
  final client = VmServiceClient(wsUri);

  try {
    await client.connect();

    switch (command) {
      case 'snapshot':
        await _snapshot(client, jsonOutput,
            compact: compact, depth: depth, fromRef: fromRef);
        break;
      case 'tap':
        if (args.isEmpty) {
          stderr.writeln('Error: tap requires a ref (e.g., tap w123)');
          exit(1);
        }
        final tapResult = await client.tap(args[0]);
        _printResult('tap', tapResult, jsonOutput);
        break;
      case 'setText':
        if (args.length < 2) {
          stderr.writeln(
              'Error: setText requires ref and text (e.g., setText w5 "hello")');
          exit(1);
        }
        final setTextResult = await client.setText(args[0], args[1]);
        _printResult('setText', setTextResult, jsonOutput);
        break;
      case 'scroll':
        if (args.isEmpty) {
          stderr
              .writeln('Error: scroll requires a ref (e.g., scroll w10 down)');
          exit(1);
        }
        final direction = args.length > 1 ? args[1] : 'down';
        final scrollResult = await client.scroll(args[0], direction);
        _printResult('scroll', scrollResult, jsonOutput);
        break;
      case 'focus':
        if (args.isEmpty) {
          stderr.writeln('Error: focus requires a ref (e.g., focus w5)');
          exit(1);
        }
        final focusResult = await client.focus(args[0]);
        _printResult('focus', focusResult, jsonOutput);
        break;
      case 'doubleTap':
        if (args.isEmpty) {
          stderr
              .writeln('Error: doubleTap requires a ref (e.g., doubleTap w5)');
          exit(1);
        }
        final dtResult = await client.doubleTap(args[0]);
        _printResult('doubleTap', dtResult, jsonOutput);
        break;
      case 'longPress':
        if (args.isEmpty) {
          stderr
              .writeln('Error: longPress requires a ref (e.g., longPress w5)');
          exit(1);
        }
        final lpResult = await client.longPress(args[0]);
        _printResult('longPress', lpResult, jsonOutput);
        break;
      case 'swipe':
        if (args.isEmpty) {
          stderr.writeln('Error: swipe requires a direction (e.g., swipe up)');
          exit(1);
        }
        // Use pure VM swipe method
        final swipeResult = await client.swipe(direction: args[0]);
        _printResult('swipe', swipeResult, jsonOutput);
        break;
      case 'hover':
        if (args.isEmpty) {
          stderr.writeln('Error: hover requires a ref (e.g., hover w5)');
          exit(1);
        }
        final hoverResult = await client.hover(args[0]);
        _printResult('hover', hoverResult, jsonOutput);
        break;
      case 'drag':
        if (args.length < 2) {
          stderr.writeln(
              'Error: drag requires fromRef and toRef (e.g., drag w5 w10)');
          exit(1);
        }
        final dragResult = await client.drag(args[0], args[1]);
        _printResult('drag', dragResult, jsonOutput);
        break;
      case 'clear':
        if (args.isEmpty) {
          stderr.writeln('Error: clear requires a ref (e.g., clear w5)');
          exit(1);
        }
        // Focus first, then clear
        await client.focus(args[0]);
        final clearResult = await client.clearText();
        _printResult('clear', clearResult, jsonOutput);
        break;
      case 'typeText':
        if (args.length < 2) {
          stderr.writeln(
              'Error: typeText requires ref and text (e.g., typeText w10 "hello")');
          exit(1);
        }
        // Use pure VM typeText method - first arg is ref, rest is text
        final typeResult =
            await client.typeText(args[0], args.sublist(1).join(' '));
        _printResult('typeText', typeResult, jsonOutput);
        break;
      case 'pressKey':
        if (args.isEmpty) {
          stderr
              .writeln('Error: pressKey requires a key (e.g., pressKey enter)');
          exit(1);
        }
        // Use pure VM pressKey method
        final keyResult = await client.pressKey(args[0]);
        _printResult('pressKey', keyResult, jsonOutput);
        break;
      case 'keyDown':
        if (args.isEmpty) {
          stderr.writeln('Error: keyDown requires a key (e.g., keyDown shift)');
          exit(1);
        }
        final keyDownResult = await client.keyDown(args[0]);
        _printResult('keyDown', keyDownResult, jsonOutput);
        break;
      case 'keyUp':
        if (args.isEmpty) {
          stderr.writeln('Error: keyUp requires a key (e.g., keyUp shift)');
          exit(1);
        }
        final keyUpResult = await client.keyUp(args[0]);
        _printResult('keyUp', keyUpResult, jsonOutput);
        break;
      case 'back':
        // Use pure VM back (press escape or back key)
        final backResult = await client.pressKey('escape');
        _printResult('back', backResult, jsonOutput);
        break;
      case 'wait':
        if (args.isEmpty) {
          stderr.writeln('Error: wait requires milliseconds (e.g., wait 1000)');
          exit(1);
        }
        final ms = int.tryParse(args[0]);
        if (ms == null) {
          stderr.writeln('Error: invalid milliseconds: ${args[0]}');
          exit(1);
        }
        await Future.delayed(Duration(milliseconds: ms));
        print('✅ Waited ${ms}ms');
        break;
      case 'waitFor':
        if (args.isEmpty) {
          stderr.writeln(
              'Error: waitFor requires a pattern (e.g., waitFor "Loading")');
          exit(1);
        }
        final waitForResult = await client.waitFor(
          args[0],
          timeout: Duration(milliseconds: waitTimeout ?? 5000),
          pollInterval: Duration(milliseconds: waitPoll ?? 200),
        );
        if (jsonOutput) {
          print(const JsonEncoder.withIndent('  ').convert(waitForResult));
        } else if (waitForResult['success'] == true) {
          print(
              '✅ Found: ${waitForResult['ref']} (matched: "${waitForResult['matchedText']}")');
        } else {
          stderr.writeln('❌ ${waitForResult['error'] ?? 'Element not found'}');
        }
        break;
      case 'waitForDisappear':
        if (args.isEmpty) {
          stderr.writeln(
              'Error: waitForDisappear requires a pattern (e.g., waitForDisappear "Loading")');
          exit(1);
        }
        final waitForDisappearResult = await client.waitForDisappear(
          args[0],
          timeout: Duration(milliseconds: waitTimeout ?? 5000),
          pollInterval: Duration(milliseconds: waitPoll ?? 200),
        );
        if (jsonOutput) {
          print(const JsonEncoder.withIndent('  ')
              .convert(waitForDisappearResult));
        } else if (waitForDisappearResult['success'] == true) {
          print('✅ Element disappeared');
        } else {
          stderr.writeln(
              '❌ ${waitForDisappearResult['error'] ?? 'Element still present'}');
        }
        break;
      case 'waitForValue':
        if (args.length < 2) {
          stderr.writeln(
              'Error: waitForValue requires ref and pattern (e.g., waitForValue w10 "success")');
          exit(1);
        }
        final waitForValueResult = await client.waitForValue(
          args[0],
          args[1],
          timeout: Duration(milliseconds: waitTimeout ?? 5000),
          pollInterval: Duration(milliseconds: waitPoll ?? 200),
        );
        if (jsonOutput) {
          print(const JsonEncoder.withIndent('  ').convert(waitForValueResult));
        } else if (waitForValueResult['success'] == true) {
          print('✅ Value matched: "${waitForValueResult['matchedText']}"');
        } else {
          stderr.writeln(
              '❌ ${waitForValueResult['error'] ?? 'Value did not match'}');
        }
        break;
      case 'getText':
        if (args.isEmpty) {
          stderr.writeln('Error: getText requires a ref (e.g., getText w5)');
          exit(1);
        }
        final textResult = await client.getText(args[0]);
        _printResult('getText', textResult, jsonOutput);
        break;
      case 'find':
        if (args.isEmpty) {
          stderr.writeln('Error: find requires a ref (e.g., find w5)');
          exit(1);
        }
        if (jsonOutput) {
          // Raw JSON output
          final findResult = await client.find(args[0], json: true);
          print(const JsonEncoder.withIndent('  ').convert(findResult));
        } else {
          // Formatted output (default)
          final findResult = await client.find(args[0]);
          if (findResult['success'] == true) {
            final result = findResult['result'];
            if (result?['formatted'] == true) {
              final lines = result['lines'] as List<dynamic>? ?? [];
              _printFormattedLines(lines);
            } else {
              print('✅ Element found but no details available');
            }
          } else {
            stderr.writeln(
                '❌ find failed: ${findResult['error'] ?? 'unknown error'}');
          }
        }
        break;
      case 'screenshot':
        // Use parsed options or fallback to positional args
        final ref = screenshotRef ??
            (args.isNotEmpty && args[0].startsWith('w') ? args[0] : null);
        final path = screenshotPath ??
            (args.isNotEmpty && !args[0].startsWith('w') ? args[0] : null);
        await _screenshot(client, ref: ref, path: path);
        break;
      case 'extensions':
        await _listExtensions(client);
        break;
      case 'attach':
        await _interactiveMode(client);
        break;
      default:
        stderr.writeln('Unknown command: $command');
        exit(1);
    }
  } finally {
    await client.disconnect();
  }
}

Future<void> _snapshot(
  VmServiceClient client,
  bool jsonOutput, {
  bool compact = false,
  int? depth,
  String? fromRef,
}) async {
  try {
    if (jsonOutput) {
      // For JSON output, request raw nodes
      final result = await client.getSnapshot(
        compact: compact,
        depth: depth,
        fromRef: fromRef,
        json: true,
      );
      if (result['success'] != true) {
        stderr.writeln('Error: ${result['error']}');
        exit(1);
      }
      final nodes = result['nodes'] as List<dynamic>? ?? [];
      final data = {
        'success': true,
        'timestamp': DateTime.now().toIso8601String(),
        'nodes': nodes,
      };
      print(const JsonEncoder.withIndent('  ').convert(data));
    } else {
      // Get formatted output from server (default)
      final result = await client.getSnapshot(
        compact: compact,
        depth: depth,
        fromRef: fromRef,
      );
      if (result['success'] != true) {
        stderr.writeln('Error: ${result['error']}');
        exit(1);
      }
      // Print pre-formatted lines from server
      final lines = result['lines'] as List<dynamic>? ?? [];
      for (final line in lines) {
        print(line);
      }
    }
  } catch (e, stack) {
    stderr.writeln('Error getting snapshot: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

/// Print result from action method call.
void _printResult(
    String command, Map<String, dynamic> result, bool jsonOutput) {
  if (jsonOutput) {
    print(jsonEncode(result));
  } else if (result['success'] == true) {
    print('✅ $command succeeded');
  } else {
    stderr.writeln('❌ $command failed: ${result['error'] ?? 'unknown error'}');
  }
}

/// Print formatted lines from server response.
void _printFormattedLines(List<dynamic> lines) {
  for (final line in lines) {
    print(line);
  }
}

Future<void> _listExtensions(VmServiceClient client) async {
  final extensions = await client.listServiceExtensions();

  print('📋 Available Service Extensions:');
  print('');

  final flutterMateExts =
      extensions.where((e) => e.contains('flutter_mate')).toList();
  if (flutterMateExts.isNotEmpty) {
    print('Flutter Mate:');
    for (final ext in flutterMateExts) {
      print('  ✅ $ext');
    }
    print('');
  } else {
    print('⚠️  No flutter_mate extensions found.');
    print('   Make sure the app has FlutterMate.initialize() called.');
    print('');
  }

  final flutterExts = extensions
      .where((e) => e.startsWith('ext.flutter') && !e.contains('flutter_mate'))
      .toList();
  if (flutterExts.isNotEmpty) {
    print('Flutter Built-in:');
    for (final ext in flutterExts.take(10)) {
      print('  • $ext');
    }
    if (flutterExts.length > 10) {
      print('  ... and ${flutterExts.length - 10} more');
    }
  }
}

Future<void> _screenshot(VmServiceClient client,
    {String? ref, String? path}) async {
  final params = <String, String>{};
  if (ref != null) params['ref'] = ref;

  final result =
      await client.callExtension('ext.flutter_mate.screenshot', args: params);

  if (result['success'] != true) {
    stderr.writeln('Screenshot failed: ${result['error']}');
    return;
  }

  final data = result['result'];
  Map<String, dynamic>? parsed;
  if (data is String) {
    parsed = jsonDecode(data) as Map<String, dynamic>?;
  } else if (data is Map<String, dynamic>) {
    parsed = data;
  }

  // Support both 'data' (old) and 'image' (new) field names
  final base64Data = parsed?['image'] ?? parsed?['data'];
  if (base64Data == null) {
    stderr.writeln('Screenshot failed: no image data');
    return;
  }

  final bytes = base64Decode(base64Data as String);

  final outputPath =
      path ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
  File(outputPath).writeAsBytesSync(bytes);
  print('✅ Screenshot saved to $outputPath (${bytes.length} bytes)');
}

/// Print help for a specific command
void _printCommandHelp(String command, ArgParser parser) {
  switch (command) {
    case 'snapshot':
      print('''
snapshot - Capture UI tree with element refs

Usage: flutter_mate --uri <ws://...> snapshot [options]

Options:
${parser.commands['snapshot']!.usage}

Examples:
  # Full snapshot
  flutter_mate --uri ws://... snapshot

  # Compact mode - only widgets with text/actions
  flutter_mate --uri ws://... snapshot -c

  # Limit depth to 3 levels
  flutter_mate --uri ws://... snapshot --depth 3

  # Start from specific element (requires prior snapshot)
  flutter_mate --uri ws://... snapshot --from w6

  # Combine options
  flutter_mate --uri ws://... snapshot -c --depth 2 --from w10
''');
      break;
    case 'screenshot':
      print('''
screenshot - Capture screenshot of the Flutter app

Usage: flutter_mate --uri <ws://...> screenshot [options]

Options:
${parser.commands['screenshot']!.usage}

Examples:
  # Full screen screenshot
  flutter_mate --uri ws://... screenshot

  # Save to specific file
  flutter_mate --uri ws://... screenshot --path my_screenshot.png

  # Capture specific element only
  flutter_mate --uri ws://... screenshot --ref w10

  # Combine options
  flutter_mate --uri ws://... screenshot --ref w5 --path button.png
''');
      break;
    case 'tap':
      print('''
tap - Tap on an element

Usage: flutter_mate --uri <ws://...> tap <ref>

Arguments:
  ref    Element ref from snapshot (e.g., w5, w10)

Behavior:
  Tries semantic tap action first, falls back to gesture injection.

Examples:
  flutter_mate --uri ws://... tap w10
  flutter_mate --uri ws://... tap w25
''');
      break;
    case 'setText':
      print('''
setText - Set text field value via semantic action

Usage: flutter_mate --uri <ws://...> setText <ref> <text>

Arguments:
  ref     Text field ref from snapshot
  text    Text to set in the field

Use for widgets with (TextField) flag. For keyboard simulation, use typeText.

Examples:
  flutter_mate --uri ws://... setText w5 "hello@example.com"
  flutter_mate --uri ws://... setText w9 "my password"
''');
      break;
    case 'typeText':
      print('''
typeText - Type text using keyboard simulation

Usage: flutter_mate --uri <ws://...> typeText <ref> <text>

Arguments:
  ref     Element ref to type into
  text    Text to type character by character

Taps to focus first, then simulates keyboard input.
Use when you need to trigger onChanged callbacks during typing.

Examples:
  flutter_mate --uri ws://... typeText w10 "hello world"
''');
      break;
    case 'scroll':
      print('''
scroll - Scroll a scrollable element

Usage: flutter_mate --uri <ws://...> scroll <ref> [direction]

Arguments:
  ref         Scrollable element ref
  direction   up, down, left, right (default: down)

Examples:
  flutter_mate --uri ws://... scroll w15 down
  flutter_mate --uri ws://... scroll w20 up
''');
      break;
    case 'find':
      print('''
find - Get detailed info about an element

Usage: flutter_mate --uri <ws://...> find <ref>

Arguments:
  ref    Element ref from snapshot

Returns bounds, semantics, text content, and available actions.

Examples:
  flutter_mate --uri ws://... find w10
''');
      break;
    case 'waitFor':
      print('''
waitFor - Wait for an element to appear

Usage: flutter_mate --uri <ws://...> waitFor <pattern> [options]

Arguments:
  pattern    Regex pattern to match against element text/label/value

Options:
${parser.commands['waitFor']!.usage}

Searches (in order): textContent, semantics.label, semantics.value, semantics.hint.
Returns when an element matching the pattern is found, or times out.

Examples:
  # Wait for "Dashboard" text to appear
  flutter_mate --uri ws://... waitFor "Dashboard"

  # Wait with custom timeout (10 seconds)
  flutter_mate --uri ws://... waitFor "Loading complete" --timeout 10000

  # Faster polling for responsive checks
  flutter_mate --uri ws://... waitFor "Ready" --poll 100
''');
      break;
    case 'waitForDisappear':
      print('''
waitForDisappear - Wait for an element to disappear

Usage: flutter_mate --uri <ws://...> waitForDisappear <pattern> [options]

Arguments:
  pattern    Regex pattern to match against element text/label/value

Options:
${parser.commands['waitForDisappear']!.usage}

Waits until no element matches the pattern, or times out.
Useful for waiting for loading spinners, dialogs, or overlays to go away.

Examples:
  # Wait for loading spinner to disappear
  flutter_mate --uri ws://... waitForDisappear "Loading"

  # Wait for dialog to close
  flutter_mate --uri ws://... waitForDisappear "Are you sure" --timeout 10000
''');
      break;
    case 'waitForValue':
      print('''
waitForValue - Wait for an element's value to match a pattern

Usage: flutter_mate --uri <ws://...> waitForValue <ref> <pattern> [options]

Arguments:
  ref        Element ref to watch (e.g., w10)
  pattern    Regex pattern to match against the element's text/value

Options:
${parser.commands['waitForValue']!.usage}

Polls the specific element until its text content or semantic value matches.
Useful for waiting for form validation, async data loading, or state changes.

Examples:
  # Wait for validation message
  flutter_mate --uri ws://... waitForValue w15 "Valid email"

  # Wait for counter to reach value
  flutter_mate --uri ws://... waitForValue w20 "^10\$"

  # Wait for field to be filled
  flutter_mate --uri ws://... waitForValue w10 ".+" --timeout 3000
''');
      break;
    default:
      print('No detailed help available for: $command');
      print('Use flutter_mate --help for general usage.');
  }
}

Future<void> _interactiveMode(VmServiceClient client) async {
  print('🎮 Flutter Mate Interactive Mode');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Type "help" for commands, "quit" to exit');
  print('');

  while (true) {
    stdout.write('flutter_mate> ');
    final line = stdin.readLineSync();
    if (line == null || line.trim().toLowerCase() == 'quit') {
      print('Goodbye!');
      break;
    }

    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) continue;

    final cmd = parts[0].toLowerCase();
    final args = parts.skip(1).toList();

    try {
      switch (cmd) {
        case 'snapshot':
        case 's':
          // Check for -c flag in args
          await _snapshot(client, false, compact: args.contains('-c'));
          break;
        case 'sc': // Shortcut for compact snapshot
          await _snapshot(client, false, compact: true);
          break;
        case 'tap':
        case 't':
          if (args.isEmpty) {
            print('Usage: tap <ref>');
          } else {
            final r = await client.tap(args[0]);
            _printResult('tap', r, false);
          }
          break;
        case 'setText':
        case 'settext':
          if (args.length < 2) {
            print('Usage: setText <ref> <text>');
          } else {
            final r = await client.setText(args[0], args.skip(1).join(' '));
            _printResult('setText', r, false);
          }
          break;
        case 'scroll':
          if (args.isEmpty) {
            print('Usage: scroll <ref> [up|down|left|right]');
          } else {
            final dir = args.length > 1 ? args[1] : 'down';
            final r = await client.scroll(args[0], dir);
            _printResult('scroll', r, false);
          }
          break;
        case 'focus':
          if (args.isEmpty) {
            print('Usage: focus <ref>');
          } else {
            final r = await client.focus(args[0]);
            _printResult('focus', r, false);
          }
          break;
        case 'doubleTap':
        case 'dt':
          if (args.isEmpty) {
            print('Usage: doubleTap <ref>');
          } else {
            final r = await client.doubleTap(args[0]);
            _printResult('doubleTap', r, false);
          }
          break;
        case 'longPress':
        case 'lp':
          if (args.isEmpty) {
            print('Usage: longPress <ref>');
          } else {
            final r = await client.longPress(args[0]);
            _printResult('longPress', r, false);
          }
          break;
        case 'swipe':
          if (args.isEmpty) {
            print('Usage: swipe <up|down|left|right>');
          } else {
            final r = await client.swipe(direction: args[0]);
            _printResult('swipe', r, false);
          }
          break;
        case 'hover':
        case 'h':
          if (args.isEmpty) {
            print('Usage: hover <ref>');
          } else {
            final r = await client.hover(args[0]);
            _printResult('hover', r, false);
          }
          break;
        case 'drag':
          if (args.length < 2) {
            print('Usage: drag <fromRef> <toRef>');
          } else {
            final r = await client.drag(args[0], args[1]);
            _printResult('drag', r, false);
          }
          break;
        case 'clear':
          if (args.isEmpty) {
            print('Usage: clear <ref>');
          } else {
            await client.focus(args[0]);
            final r = await client.clearText();
            _printResult('clear', r, false);
          }
          break;
        case 'type':
        case 'typeText':
        case 'typetext':
          if (args.length < 2) {
            print('Usage: typeText <ref> <text>');
          } else {
            final r = await client.typeText(args[0], args.sublist(1).join(' '));
            _printResult('typeText', r, false);
          }
          break;
        case 'key':
          if (args.isEmpty) {
            print(
                'Usage: key <enter|tab|escape|backspace|arrowUp|arrowDown|arrowLeft|arrowRight>');
          } else {
            final r = await client.pressKey(args[0]);
            _printResult('key', r, false);
          }
          break;
        case 'keydown':
        case 'kd':
          if (args.isEmpty) {
            print('Usage: keydown <key>');
          } else {
            final r = await client.keyDown(args[0]);
            _printResult('keyDown', r, false);
          }
          break;
        case 'keyup':
        case 'ku':
          if (args.isEmpty) {
            print('Usage: keyup <key>');
          } else {
            final r = await client.keyUp(args[0]);
            _printResult('keyUp', r, false);
          }
          break;
        case 'back':
          final r = await client.pressKey('escape');
          _printResult('back', r, false);
          break;
        case 'wait':
          if (args.isEmpty) {
            print('Usage: wait <milliseconds>');
          } else {
            final ms = int.tryParse(args[0]) ?? 1000;
            await Future.delayed(Duration(milliseconds: ms));
            print('✅ Waited ${ms}ms');
          }
          break;
        case 'waitFor':
        case 'wf':
          if (args.isEmpty) {
            print('Usage: waitFor <pattern> [timeout_ms]');
          } else {
            final timeout =
                args.length > 1 ? int.tryParse(args[1]) ?? 5000 : 5000;
            final r = await client.waitFor(args[0],
                timeout: Duration(milliseconds: timeout));
            if (r['success'] == true) {
              print('✅ Found: ${r['ref']} (matched: "${r['matchedText']}")');
            } else {
              print('❌ ${r['error'] ?? 'Not found'}');
            }
          }
          break;
        case 'waitForDisappear':
        case 'wfd':
          if (args.isEmpty) {
            print('Usage: waitForDisappear <pattern> [timeout_ms]');
          } else {
            final timeout =
                args.length > 1 ? int.tryParse(args[1]) ?? 5000 : 5000;
            final r = await client.waitForDisappear(args[0],
                timeout: Duration(milliseconds: timeout));
            if (r['success'] == true) {
              print('✅ Element disappeared');
            } else {
              print('❌ ${r['error'] ?? 'Still present'}');
            }
          }
          break;
        case 'waitForValue':
        case 'wfv':
          if (args.length < 2) {
            print('Usage: waitForValue <ref> <pattern> [timeout_ms]');
          } else {
            final timeout =
                args.length > 2 ? int.tryParse(args[2]) ?? 5000 : 5000;
            final r = await client.waitForValue(args[0], args[1],
                timeout: Duration(milliseconds: timeout));
            if (r['success'] == true) {
              print('✅ Value matched: "${r['matchedText']}"');
            } else {
              print('❌ ${r['error'] ?? 'Did not match'}');
            }
          }
          break;
        case 'getText':
        case 'text':
          if (args.isEmpty) {
            print('Usage: getText <ref>');
          } else {
            final r = await client.getText(args[0]);
            _printResult('getText', r, false);
          }
          break;
        case 'find':
        case 'info':
          if (args.isEmpty) {
            print('Usage: find <ref>');
          } else {
            // Interactive mode always uses formatted output
            final r = await client.find(args[0]);
            if (r['success'] == true) {
              final result = r['result'];
              if (result?['formatted'] == true) {
                final lines = result['lines'] as List<dynamic>? ?? [];
                _printFormattedLines(lines);
              } else {
                print('✅ Element found');
              }
            } else {
              print('❌ ${r['error'] ?? 'Element not found'}');
            }
          }
          break;
        case 'screenshot':
        case 'ss':
          await _screenshot(client);
          break;
        case 'extensions':
        case 'ext':
          await _listExtensions(client);
          break;
        case 'help':
        case '?':
          print('Commands:');
          print('  snapshot, s [-c] - Get UI snapshot (-c for compact)');
          print('  sc               - Compact snapshot (shortcut)');
          print('  tap, t <ref>     - Tap element (auto: semantic or gesture)');
          print('  doubleTap, dt <ref> - Double tap element');
          print('  longPress, lp <ref> - Long press element');
          print('  hover, h <ref>   - Hover over element (trigger onHover)');
          print('  drag <from> <to> - Drag from one element to another');
          print('  setText <ref> <text> - Set text (semantic action)');
          print('  typeText <ref> <text> - Type text (keyboard simulation)');
          print('  clear <ref>      - Clear text field');
          print('  scroll <ref> [dir] - Scroll element');
          print('  swipe <dir>      - Swipe gesture');
          print('  focus <ref>      - Focus element');
          print('  key <keyName>    - Press keyboard key');
          print('  keydown, kd <key> - Press key down (hold)');
          print('  keyup, ku <key>  - Release key');
          print('  back             - Navigate back');
          print('  wait <ms>        - Wait milliseconds');
          print(
              '  waitFor, wf <pattern> [timeout] - Wait for element to appear');
          print(
              '  waitForDisappear, wfd <pattern> - Wait for element to disappear');
          print('  waitForValue, wfv <ref> <pattern> - Wait for value match');
          print('  getText, text <ref> - Get element text');
          print('  find, info <ref> - Get detailed element info');
          print('  screenshot, ss   - Take screenshot');
          print('  extensions, ext  - List extensions');
          print('  quit             - Exit');
          break;
        default:
          print('Unknown command: $cmd (type "help" for commands)');
      }
    } catch (e) {
      print('Error: $e');
    }
    print('');
  }
}

void _printUsage(ArgParser parser) {
  print('''
flutter_mate - Control Flutter apps via VM Service Protocol

Usage: flutter_mate --uri <ws://...> <command> [arguments]

Connection:
  The --uri parameter is the VM Service WebSocket URI.
  Find it in your Flutter app's console output:
  
    A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/
  
  Convert to WebSocket: ws://127.0.0.1:12345/abc=/ws

Commands:
  snapshot              Get UI snapshot (widget tree + semantics)
                        Options: --compact/-c, --depth/-d N, --from/-f wX
  find <ref>            Get detailed info about an element
  tap <ref>             Tap on element (e.g., tap w123)
  doubleTap <ref>       Double tap element
  longPress <ref>       Long press element
  hover <ref>           Hover over element (trigger onHover/onEnter)
  drag <from> <to>      Drag from one element to another
  setText <ref> <text>  Set text field via semantic action (e.g., setText w9 "text")
  typeText <ref> <text> Type text via keyboard simulation (e.g., typeText w10 "text")
  clear <ref>           Clear text field
  pressKey <key>        Press keyboard key (enter, tab, escape, etc.)
  keyDown <key>         Press key down (hold without releasing)
  keyUp <key>           Release a key
  scroll <ref> [dir]    Scroll element (dir: up, down, left, right)
  swipe <dir>           Swipe gesture
  focus <ref>           Focus on element
  back                  Navigate back
  wait <ms>             Wait milliseconds
  waitFor <pattern>     Wait for element to appear (--timeout, --poll)
  waitForDisappear <p>  Wait for element to disappear
  waitForValue <ref> <p> Wait for element value to match pattern
  getText <ref>         Get element text
  screenshot [path]     Take screenshot
  extensions            List available service extensions
  attach                Interactive mode (REPL)

Options:
${parser.usage}

Examples:
  # Get the VM Service URI from flutter run output, then:
  
  # Get UI snapshot
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
  
  # Compact mode: only widgets with info (text, actions, flags)
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws -c snapshot
  
  # Interact with elements
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws fill w5 "test@example.com"
  
  # Interactive mode
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws attach

Workflow:
  1. Run your Flutter app: flutter run
  2. Copy the VM Service URI from console
  3. flutter_mate --uri <uri> snapshot  # See UI tree
  4. flutter_mate --uri <uri> fill w5 "..."  # Fill fields
  5. flutter_mate --uri <uri> tap w10  # Tap buttons
''');
}
