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
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON')
    ..addFlag('interactive',
        abbr: 'i', negatable: false, help: 'Show only interactive elements')
    ..addOption('mode',
        abbr: 'm',
        defaultsTo: 'semantics',
        allowed: ['semantics', 'combined'],
        help: 'Snapshot mode: semantics (flat) or combined (widget tree)');

  // Add subcommands
  parser.addCommand('snapshot');
  parser.addCommand('tap');
  parser.addCommand('fill');
  parser.addCommand('scroll');
  parser.addCommand('focus');
  parser.addCommand('doubleTap');
  parser.addCommand('longPress');
  parser.addCommand('swipe');
  parser.addCommand('clear');
  parser.addCommand('typeText');
  parser.addCommand('pressKey');
  parser.addCommand('back');
  parser.addCommand('wait');
  parser.addCommand('getText');
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
    final interactive = results['interactive'] as bool;
    final mode = results['mode'] as String;

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
      interactive: interactive,
      mode: mode,
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
  required bool interactive,
  required String mode,
}) async {
  final client = VmServiceClient(wsUri);

  try {
    await client.connect();

    switch (command) {
      case 'snapshot':
        await _snapshot(client, jsonOutput, interactive, mode);
        break;
      case 'tap':
        if (args.isEmpty) {
          stderr.writeln('Error: tap requires a ref (e.g., tap w123)');
          exit(1);
        }
        final tapResult = await client.tap(args[0]);
        _printResult('tap', tapResult, jsonOutput);
        break;
      case 'fill':
        if (args.length < 2) {
          stderr.writeln(
              'Error: fill requires ref and text (e.g., fill w5 "hello")');
          exit(1);
        }
        final fillResult = await client.fill(args[0], args[1]);
        _printResult('fill', fillResult, jsonOutput);
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
        if (args.isEmpty) {
          stderr.writeln(
              'Error: typeText requires text (e.g., typeText "hello")');
          exit(1);
        }
        // Use pure VM typeText method
        final typeResult = await client.typeText(args.join(' '));
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

Future<void> _snapshot(VmServiceClient client, bool jsonOutput,
    bool interactive, String mode) async {
  try {
    Map<String, dynamic> data;

    if (mode == 'combined') {
      // Use pure VM method - works on ANY Flutter debug app!
      // summaryOnly: false to get text previews
      final result = await client.getCombinedSnapshot(summaryOnly: false);
      if (result['success'] != true) {
        stderr.writeln('Error: ${result['error']}');
        exit(1);
      }
      data = result;
    } else {
      // Pure VM semantics - no FlutterMate extension needed!
      final semanticsResult = await client.getSemanticsTree();
      if (semanticsResult['success'] != true) {
        stderr.writeln('Error: ${semanticsResult['error']}');
        exit(1);
      }

      final nodes = semanticsResult['nodes'] as List<dynamic>? ?? [];

      // Filter to interactive only if requested
      final filteredNodes = interactive
          ? nodes.where((n) {
              final node = n as Map<String, dynamic>;
              final label = node['label'] as String?;
              final actions = node['actions'] as List<dynamic>?;
              return (label != null && label.isNotEmpty) ||
                  (actions != null && actions.isNotEmpty);
            }).toList()
          : nodes;

      data = {
        'success': true,
        'timestamp': DateTime.now().toIso8601String(),
        'nodes': filteredNodes,
      };
    }

    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(data));
    } else if (mode == 'combined') {
      _printCombinedSnapshotPure(data);
    } else {
      _printSnapshot(data);
    }
  } catch (e, stack) {
    stderr.writeln('Error getting snapshot: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

/// Print result from pure VM method call
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

void _printSnapshot(Map<String, dynamic> data) {
  if (data['success'] != true) {
    stderr.writeln('Error: ${data['error']}');
    return;
  }

  final nodes = data['nodes'] as List<dynamic>;
  print('📱 Flutter Mate Snapshot (via VM Service)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Timestamp: ${data['timestamp']}');
  print('Total nodes: ${nodes.length}');
  print('');

  for (final node in nodes) {
    final ref = node['ref'] as String;
    final label = node['label'] as String?;
    final value = node['value'] as String?;
    final actions = (node['actions'] as List<dynamic>?)?.cast<String>() ?? [];
    final flags = (node['flags'] as List<dynamic>?)?.cast<String>() ?? [];
    final depth = node['depth'] as int? ?? 0;
    final isInteractive = node['isInteractive'] as bool? ?? false;

    if (!isInteractive && label == null && value == null) continue;

    final indent = '  ' * depth;
    final typeIcon = _getTypeIcon(flags);
    final displayText = label ?? value ?? '(no label)';
    final actionsStr = actions.isNotEmpty ? ' [${actions.join(', ')}]' : '';
    final flagsStr = flags
        .where((f) => f.startsWith('is'))
        .map((f) => f.substring(2))
        .join(', ');

    print(
        '$indent$typeIcon $ref: "$displayText"$actionsStr${flagsStr.isNotEmpty ? ' ($flagsStr)' : ''}');
  }

  print('');
  print('💡 Use refs to interact: flutter_mate --uri <ws://...> tap w123');
}

/// Print combined snapshot from pure VM method
void _printCombinedSnapshotPure(Map<String, dynamic> data) {
  final nodes = data['nodes'] as List<dynamic>;
  final widgetCount = data['widgetCount'] as int? ?? nodes.length;
  final semanticsCount = data['semanticsCount'] as int? ?? 0;
  final semanticsNodes = data['semanticsNodes'] as List<dynamic>? ?? [];

  print('📱 Flutter Mate Combined Snapshot (Pure VM)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Timestamp: ${data['timestamp']}');
  print('');

  // Section 1: Widget Tree (structure)
  print('📦 WIDGET TREE ($widgetCount widgets)');
  print('─────────────────────────────────');

  for (final node in nodes) {
    final id = node['id'] as String;
    final type = node['type'] as String;
    final depth = node['depth'] as int? ?? 0;
    final indent = '  ' * depth;
    final icon = _getTypeIconForWidget(type);
    print('$indent$icon $id: $type');
  }

  print('');

  // Section 2: Interactive Elements (semantics)
  print('🎯 INTERACTIVE ELEMENTS ($semanticsCount items)');
  print('──────────────────────────────────────');

  if (semanticsNodes.isNotEmpty) {
    for (final sem in semanticsNodes) {
      final ref = sem['ref'] as String? ?? '?';
      final label = sem['label'] as String? ?? '';
      final actions = (sem['actions'] as List<dynamic>?)?.cast<String>() ?? [];

      if (label.isEmpty && actions.isEmpty) continue;

      final actionsStr = actions.isNotEmpty ? ' [${actions.join(', ')}]' : '';
      print('  $ref: "$label"$actionsStr');
    }
  } else {
    print('  (No semantics extracted - use regular snapshot for interactions)');
  }

  print('');
  print('💡 For interactions, use: flutter_mate tap <ref>');
}

String _getTypeIconForWidget(String type) {
  if (type.contains('Button')) return '🔘';
  if (type.contains('TextField')) return '📝';
  if (type.contains('Text')) return '📄';
  if (type.contains('Icon')) return '🎨';
  if (type.contains('Image')) return '🖼️';
  if (type.contains('Scaffold')) return '📱';
  if (type.contains('AppBar')) return '📲';
  if (type.contains('Column') || type.contains('Row')) return '📐';
  return '  ';
}

String _getTypeIcon(List<String> flags) {
  if (flags.contains('isButton')) return '🔘';
  if (flags.contains('isTextField')) return '📝';
  if (flags.contains('isLink')) return '🔗';
  if (flags.contains('isHeader')) return '📌';
  if (flags.contains('isImage')) return '🖼️';
  if (flags.contains('isSlider')) return '🎚️';
  if (flags.contains('isChecked')) return '☑️';
  if (flags.contains('isFocusable')) return '👆';
  return '•';
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

Future<void> _screenshot(VmServiceClient client, String? path) async {
  final result = await client.callExtension('ext.flutter_mate.screenshot');

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

  if (parsed == null || parsed['data'] == null) {
    stderr.writeln('Screenshot failed: no image data');
    return;
  }

  final base64Data = parsed['data'] as String;
  final bytes = base64Decode(base64Data);

  final outputPath =
      path ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
  File(outputPath).writeAsBytesSync(bytes);
  print('✅ Screenshot saved to $outputPath');
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
          final mode = args.isNotEmpty && args[0] == 'combined'
              ? 'combined'
              : 'semantics';
          await _snapshot(client, false, true, mode);
          break;
        case 'combined':
        case 'c':
          await _snapshot(client, false, true, 'combined');
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
        case 'fill':
        case 'f':
          if (args.length < 2) {
            print('Usage: fill <ref> <text>');
          } else {
            final r = await client.fill(args[0], args.skip(1).join(' '));
            _printResult('fill', r, false);
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
          if (args.isEmpty) {
            print('Usage: type <text>');
          } else {
            final r = await client.typeText(args.join(' '));
            _printResult('type', r, false);
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
          print('  snapshot, s      - Get semantics snapshot');
          print('  combined, c      - Get combined widget tree + semantics');
          print('  tap, t <ref>     - Tap element');
          print('  doubleTap, dt <ref> - Double tap element');
          print('  longPress, lp <ref> - Long press element');
          print('  fill, f <ref> <text> - Fill text field');
          print('  clear <ref>      - Clear text field');
          print('  type <text>      - Type text (to focused field)');
          print('  scroll <ref> [dir] - Scroll element');
          print('  swipe <dir>      - Swipe gesture');
          print('  focus <ref>      - Focus element');
          print('  key <keyName>    - Press keyboard key');
          print('  back             - Navigate back');
          print('  wait <ms>        - Wait milliseconds');
          print('  getText, text <ref> - Get element text');
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
  snapshot              Get UI tree snapshot
                        -i: interactive elements only
                        -m combined: widget tree + semantics
  tap <ref>             Tap on element (e.g., tap w123)
  doubleTap <ref>       Double tap element
  longPress <ref>       Long press element
  fill <ref> <text>     Fill text field (e.g., fill w5 "hello@example.com")
  clear <ref>           Clear text field
  typeText <text>       Type text character by character
  pressKey <key>        Press keyboard key (enter, tab, escape, etc.)
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
  
  # Semantics snapshot (flat, accessibility info)
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -i
  
  # Combined snapshot (widget tree + semantics)
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -m combined
  
  # Interact with elements
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws fill w5 "test@example.com"
  
  # Interactive mode
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws attach

Workflow:
  1. Run your Flutter app: flutter run
  2. Copy the VM Service URI from console
  3. flutter_mate --uri <uri> snapshot -m combined  # See widget tree
  4. flutter_mate --uri <uri> fill w5 "..."         # Fill fields
  5. flutter_mate --uri <uri> tap w10               # Tap buttons
''');
}
