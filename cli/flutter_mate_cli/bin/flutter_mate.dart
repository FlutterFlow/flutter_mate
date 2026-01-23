import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_mate_cli/snapshot_formatter.dart';
import 'package:flutter_mate_cli/vm_service_client.dart';

const String version = '0.1.0';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version')
    ..addOption('uri', abbr: 'u', help: 'VM Service WebSocket URI (ws://...)')
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON')
    ..addFlag('compact',
        abbr: 'c',
        negatable: false,
        help: 'Compact mode: only show widgets with info (text, actions, etc)');

  // Add subcommands
  parser.addCommand('snapshot');
  parser.addCommand('tap');
  parser.addCommand('fill');
  parser.addCommand('scroll');
  parser.addCommand('focus');
  parser.addCommand('doubleTap');
  parser.addCommand('longPress');
  parser.addCommand('swipe');
  parser.addCommand('hover');
  parser.addCommand('drag');
  parser.addCommand('clear');
  parser.addCommand('typeText');
  parser.addCommand('pressKey');
  parser.addCommand('keyDown');
  parser.addCommand('keyUp');
  parser.addCommand('back');
  parser.addCommand('wait');
  parser.addCommand('getText');
  parser.addCommand('find');
  parser.addCommand('screenshot');
  parser.addCommand('extensions'); // List available extensions
  parser.addCommand('attach'); // Interactive mode

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
    final compact = results['compact'] as bool;

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

    // Determine command
    String command;
    List<String> args;

    if (results.command != null) {
      command = results.command!.name!;
      args = results.command!.rest;
    } else if (results.rest.isNotEmpty) {
      command = results.rest[0];
      args = results.rest.skip(1).toList();
    } else {
      _printUsage(parser);
      return;
    }

    await _executeCommand(
      command: command,
      args: args,
      wsUri: uri,
      jsonOutput: jsonOutput,
      compact: compact,
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
}) async {
  final client = VmServiceClient(wsUri);

  try {
    await client.connect();

    switch (command) {
      case 'snapshot':
        await _snapshot(client, jsonOutput, compact: compact);
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
        final findResult = await client.find(args[0]);
        if (jsonOutput) {
          print(const JsonEncoder.withIndent('  ').convert(findResult));
        } else if (findResult['success'] == true) {
          final element = findResult['result']?['element'] as Map?;
          if (element != null) {
            _printElementDetails(element);
          } else {
            print('✅ Element found but no details available');
          }
        } else {
          stderr.writeln(
              '❌ find failed: ${findResult['error'] ?? 'unknown error'}');
        }
        break;
      case 'screenshot':
        // Screenshots require special handling - not pure VM
        stderr.writeln('Note: screenshot requires FlutterMate extension');
        await _screenshot(client, args.isNotEmpty ? args[0] : null);
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
}) async {
  try {
    // Get snapshot via FlutterMate service extension
    // Pass compact to SDK for server-side filtering (much faster for large UIs)
    final result = await client.getSnapshot(compact: compact);
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

    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(data));
    } else {
      _printSnapshot(data, compact: compact);
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

void _printSnapshot(Map<String, dynamic> data, {bool compact = false}) {
  if (data['success'] != true) {
    stderr.writeln('Error: ${data['error']}');
    return;
  }

  final nodes = data['nodes'] as List<dynamic>;
  final lines = formatSnapshot(nodes, compact: compact);
  for (final line in lines) {
    print(line);
  }
}

/// Print detailed info about an element using shared formatter
void _printElementDetails(Map element) {
  final lines = formatElementDetails(Map<String, dynamic>.from(element));
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

Future<void> _screenshot(VmServiceClient client, String? refOrPath) async {
  // If arg looks like a ref (starts with 'w'), pass it as ref
  // Otherwise treat it as output path
  String? ref;
  String? path;
  if (refOrPath != null) {
    if (refOrPath.startsWith('w') && RegExp(r'^w\d+$').hasMatch(refOrPath)) {
      ref = refOrPath;
    } else {
      path = refOrPath;
    }
  }

  final params = <String, String>{};
  if (ref != null) params['ref'] = ref;

  final result = await client.callExtension('ext.flutter_mate.screenshot', args: params);

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
            final r = await client.find(args[0]);
            if (r['success'] == true) {
              final element = r['result']?['element'] as Map?;
              if (element != null) {
                _printElementDetails(element);
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
          await _screenshot(client, null);
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
