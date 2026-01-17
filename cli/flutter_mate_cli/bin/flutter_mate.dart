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
        abbr: 'i', negatable: false, help: 'Show only interactive elements');

  // Add subcommands
  parser.addCommand('snapshot');
  parser.addCommand('tap');
  parser.addCommand('fill');
  parser.addCommand('scroll');
  parser.addCommand('focus');
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
}) async {
  final client = VmServiceClient(wsUri);

  try {
    await client.connect();

    switch (command) {
      case 'snapshot':
        await _snapshot(client, jsonOutput, interactive);
        break;
      case 'tap':
        if (args.isEmpty) {
          stderr.writeln('Error: tap requires a ref (e.g., tap w123)');
          exit(1);
        }
        await _callExtension(client, 'ext.flutter_mate.tap',
            {'ref': args[0]}, jsonOutput);
        break;
      case 'fill':
        if (args.length < 2) {
          stderr.writeln('Error: fill requires ref and text (e.g., fill w5 "hello")');
          exit(1);
        }
        await _callExtension(client, 'ext.flutter_mate.fill',
            {'ref': args[0], 'text': args[1]}, jsonOutput);
        break;
      case 'scroll':
        if (args.isEmpty) {
          stderr.writeln('Error: scroll requires a ref (e.g., scroll w10 down)');
          exit(1);
        }
        final direction = args.length > 1 ? args[1] : 'down';
        await _callExtension(client, 'ext.flutter_mate.scroll',
            {'ref': args[0], 'direction': direction}, jsonOutput);
        break;
      case 'focus':
        if (args.isEmpty) {
          stderr.writeln('Error: focus requires a ref (e.g., focus w5)');
          exit(1);
        }
        await _callExtension(client, 'ext.flutter_mate.focus',
            {'ref': args[0]}, jsonOutput);
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
    VmServiceClient client, bool jsonOutput, bool interactive) async {
  try {
    final result = await client.callExtension(
      'ext.flutter_mate.snapshot',
      args: {'interactiveOnly': interactive.toString()},
    );

    if (result['success'] != true) {
      // FlutterMate extension not available
      stderr.writeln('FlutterMate extension not found.');
      stderr.writeln('Make sure the app has flutter_mate initialized.');

      // List available extensions as hint
      final extensions = await client.listServiceExtensions();
      final flutterMateExts =
          extensions.where((e) => e.contains('flutter_mate')).toList();
      if (flutterMateExts.isEmpty) {
        stderr.writeln('');
        stderr.writeln('Available Flutter extensions:');
        for (final ext
            in extensions.where((e) => e.startsWith('ext.flutter'))) {
          stderr.writeln('  - $ext');
        }
      }
      exit(1);
    }

    // Result can be a String (JSON) or already a Map
    final resultData = result['result'];
    Map<String, dynamic> data;
    if (resultData is String) {
      data = jsonDecode(resultData) as Map<String, dynamic>;
    } else if (resultData is Map<String, dynamic>) {
      data = resultData;
    } else {
      stderr.writeln('Unexpected result type: ${resultData.runtimeType}');
      exit(1);
    }

    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(data));
    } else {
      _printSnapshot(data);
    }
  } catch (e, stack) {
    stderr.writeln('Error getting snapshot: $e');
    stderr.writeln(stack);
    exit(1);
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
    final actions =
        (node['actions'] as List<dynamic>?)?.cast<String>() ?? [];
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

Future<void> _callExtension(
  VmServiceClient client,
  String extension,
  Map<String, String> args,
  bool jsonOutput,
) async {
  final result = await client.callExtension(extension, args: args);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(result));
    return;
  }

  if (result['success'] == true) {
    final innerResult = result['result'];
    if (innerResult is String) {
      final parsed = jsonDecode(innerResult) as Map<String, dynamic>;
      if (parsed['success'] == true) {
        print('✅ ${extension.split('.').last} succeeded');
      } else {
        print('❌ ${extension.split('.').last} failed');
      }
    } else {
      print('✅ ${extension.split('.').last} succeeded');
    }
  } else {
    print('❌ Error: ${result['error']}');
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

  final flutterExts =
      extensions.where((e) => e.startsWith('ext.flutter') && !e.contains('flutter_mate')).toList();
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

Future<void> _interactiveMode(VmServiceClient client) async {
  print('🎮 Flutter Mate Interactive Mode');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('Commands: snapshot, tap <ref>, fill <ref> <text>, scroll <ref> [dir], focus <ref>, quit');
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
          await _snapshot(client, false, true);
          break;
        case 'tap':
        case 't':
          if (args.isEmpty) {
            print('Usage: tap <ref>');
          } else {
            await _callExtension(
                client, 'ext.flutter_mate.tap', {'ref': args[0]}, false);
          }
          break;
        case 'fill':
        case 'f':
          if (args.length < 2) {
            print('Usage: fill <ref> <text>');
          } else {
            await _callExtension(client, 'ext.flutter_mate.fill',
                {'ref': args[0], 'text': args.skip(1).join(' ')}, false);
          }
          break;
        case 'scroll':
          if (args.isEmpty) {
            print('Usage: scroll <ref> [up|down|left|right]');
          } else {
            final dir = args.length > 1 ? args[1] : 'down';
            await _callExtension(client, 'ext.flutter_mate.scroll',
                {'ref': args[0], 'direction': dir}, false);
          }
          break;
        case 'focus':
          if (args.isEmpty) {
            print('Usage: focus <ref>');
          } else {
            await _callExtension(
                client, 'ext.flutter_mate.focus', {'ref': args[0]}, false);
          }
          break;
        case 'extensions':
        case 'ext':
          await _listExtensions(client);
          break;
        case 'help':
        case '?':
          print('Commands:');
          print('  snapshot, s     - Get UI snapshot');
          print('  tap, t <ref>    - Tap element');
          print('  fill, f <ref> <text> - Fill text field');
          print('  scroll <ref> [dir] - Scroll element');
          print('  focus <ref>     - Focus element');
          print('  extensions, ext - List extensions');
          print('  quit            - Exit');
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
  snapshot              Get UI tree snapshot (use -i for interactive only)
  tap <ref>             Tap on element (e.g., tap w123)
  fill <ref> <text>     Fill text field (e.g., fill w5 "hello@example.com")
  scroll <ref> [dir]    Scroll element (dir: up, down, left, right)
  focus <ref>           Focus on element
  extensions            List available service extensions
  attach                Interactive mode (REPL)

Options:
${parser.usage}

Examples:
  # Get the VM Service URI from flutter run output, then:
  
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -i
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws fill w5 "test@example.com"
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws attach  # Interactive mode

Workflow:
  1. Run your Flutter app: flutter run
  2. Copy the VM Service URI from console
  3. flutter_mate --uri <uri> snapshot -i    # See UI
  4. flutter_mate --uri <uri> fill w5 "..."  # Fill fields
  5. flutter_mate --uri <uri> tap w10        # Tap buttons
''');
}
