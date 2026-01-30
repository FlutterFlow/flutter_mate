import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_mate_cli/client/commands.dart';
import 'package:flutter_mate_cli/client/connection.dart';
import 'package:flutter_mate_cli/daemon/protocol.dart';

const String version = '0.1.0';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version')
    ..addOption('session',
        abbr: 's', defaultsTo: 'default', help: 'Session name')
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON');

  // ══════════════════════════════════════════════════════════════════════════
  // APP LIFECYCLE COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final runParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for run');
  parser.addCommand('run', runParser);

  final connectParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for connect');
  parser.addCommand('connect', connectParser);

  final closeParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for close');
  parser.addCommand('close', closeParser);

  final statusParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for status');
  parser.addCommand('status', statusParser);

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  final sessionParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for session');
  parser.addCommand('session', sessionParser);

  // ══════════════════════════════════════════════════════════════════════════
  // INTROSPECTION COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

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

  final findParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for find');
  parser.addCommand('find', findParser);

  // ══════════════════════════════════════════════════════════════════════════
  // INTERACTION COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final tapParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for tap');
  parser.addCommand('tap', tapParser);

  final doubleTapParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for doubleTap');
  parser.addCommand('doubleTap', doubleTapParser);

  final longPressParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for longPress');
  parser.addCommand('longPress', longPressParser);

  final hoverParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for hover');
  parser.addCommand('hover', hoverParser);

  final dragParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for drag');
  parser.addCommand('drag', dragParser);

  final focusParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for focus');
  parser.addCommand('focus', focusParser);

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT INPUT COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final setTextParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for setText');
  parser.addCommand('setText', setTextParser);

  final typeTextParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for typeText');
  parser.addCommand('typeText', typeTextParser);

  final clearParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for clear');
  parser.addCommand('clear', clearParser);

  final getTextParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for getText');
  parser.addCommand('getText', getTextParser);

  // ══════════════════════════════════════════════════════════════════════════
  // SCROLL COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final scrollParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for scroll');
  parser.addCommand('scroll', scrollParser);

  final swipeParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for swipe');
  parser.addCommand('swipe', swipeParser);

  // ══════════════════════════════════════════════════════════════════════════
  // KEYBOARD COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final pressKeyParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for pressKey');
  parser.addCommand('pressKey', pressKeyParser);

  final keyDownParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show help for keyDown');
  parser.addCommand('keyDown', keyDownParser);

  final keyUpParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for keyUp');
  parser.addCommand('keyUp', keyUpParser);

  // ══════════════════════════════════════════════════════════════════════════
  // WAIT COMMANDS
  // ══════════════════════════════════════════════════════════════════════════

  final waitParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for wait');
  parser.addCommand('wait', waitParser);

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

    final session = results['session'] as String;
    final jsonOutput = results['json'] as bool;

    // Determine command
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

    await _executeCommand(
      command: command,
      args: cmdArgs,
      cmdResults: cmdResults,
      session: session,
      jsonOutput: jsonOutput,
      parser: parser,
    );

    // Ensure clean exit after command completes
    exit(0);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

Future<void> _executeCommand({
  required String command,
  required List<String> args,
  required ArgResults? cmdResults,
  required String session,
  required bool jsonOutput,
  required ArgParser parser,
}) async {
  switch (command) {
    // ════════════════════════════════════════════════════════════════════════
    // APP LIFECYCLE
    // ════════════════════════════════════════════════════════════════════════

    case 'run':
      await _handleRun(args, session, jsonOutput);
      break;

    case 'connect':
      if (args.isEmpty) {
        stderr.writeln('Error: connect requires a URI');
        stderr.writeln(
            'Usage: flutter_mate connect ws://127.0.0.1:12345/abc=/ws');
        exit(1);
      }
      await _handleConnect(args[0], session, jsonOutput);
      break;

    case 'close':
      await _handleClose(session, jsonOutput);
      break;

    case 'status':
      await _handleStatus(session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // SESSION MANAGEMENT
    // ════════════════════════════════════════════════════════════════════════

    case 'session':
      final subCmd = args.isNotEmpty ? args[0] : 'list';
      if (subCmd == 'list') {
        await _handleSessionList(jsonOutput);
      } else {
        stderr.writeln('Unknown session subcommand: $subCmd');
        stderr.writeln('Available: list');
        exit(1);
      }
      break;

    // ════════════════════════════════════════════════════════════════════════
    // INTROSPECTION
    // ════════════════════════════════════════════════════════════════════════

    case 'snapshot':
      final compact = cmdResults?['compact'] as bool? ?? false;
      final depthStr = cmdResults?['depth'] as String?;
      final depth = depthStr != null ? int.tryParse(depthStr) : null;
      final fromRef = cmdResults?['from'] as String?;
      await _handleSnapshot(session, jsonOutput,
          compact: compact, depth: depth, fromRef: fromRef);
      break;

    case 'find':
      if (args.isEmpty) {
        stderr.writeln('Error: find requires a ref (e.g., find w5)');
        exit(1);
      }
      await _handleFind(args[0], session, jsonOutput);
      break;

    case 'screenshot':
      final ref = cmdResults?['ref'] as String? ??
          (args.isNotEmpty && args[0].startsWith('w') ? args[0] : null);
      final path = cmdResults?['path'] as String? ??
          (args.isNotEmpty && !args[0].startsWith('w') ? args[0] : null);
      await _handleScreenshot(session, ref: ref, path: path);
      break;

    case 'getText':
      if (args.isEmpty) {
        stderr.writeln('Error: getText requires a ref (e.g., getText w5)');
        exit(1);
      }
      await _handleGetText(args[0], session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // INTERACTIONS
    // ════════════════════════════════════════════════════════════════════════

    case 'tap':
      if (args.isEmpty) {
        stderr.writeln('Error: tap requires a ref (e.g., tap w123)');
        exit(1);
      }
      await _handleTap(args[0], session, jsonOutput);
      break;

    case 'doubleTap':
      if (args.isEmpty) {
        stderr.writeln('Error: doubleTap requires a ref (e.g., doubleTap w5)');
        exit(1);
      }
      await _handleDoubleTap(args[0], session, jsonOutput);
      break;

    case 'longPress':
      if (args.isEmpty) {
        stderr.writeln('Error: longPress requires a ref (e.g., longPress w5)');
        exit(1);
      }
      await _handleLongPress(args[0], session, jsonOutput);
      break;

    case 'hover':
      if (args.isEmpty) {
        stderr.writeln('Error: hover requires a ref (e.g., hover w5)');
        exit(1);
      }
      await _handleHover(args[0], session, jsonOutput);
      break;

    case 'drag':
      if (args.length < 2) {
        stderr.writeln(
            'Error: drag requires fromRef and toRef (e.g., drag w5 w10)');
        exit(1);
      }
      await _handleDrag(args[0], args[1], session, jsonOutput);
      break;

    case 'focus':
      if (args.isEmpty) {
        stderr.writeln('Error: focus requires a ref (e.g., focus w5)');
        exit(1);
      }
      await _handleFocus(args[0], session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // TEXT INPUT
    // ════════════════════════════════════════════════════════════════════════

    case 'setText':
      if (args.length < 2) {
        stderr.writeln(
            'Error: setText requires ref and text (e.g., setText w5 "hello")');
        exit(1);
      }
      await _handleSetText(
          args[0], args.sublist(1).join(' '), session, jsonOutput);
      break;

    case 'typeText':
      if (args.length < 2) {
        stderr.writeln(
            'Error: typeText requires ref and text (e.g., typeText w10 "hello")');
        exit(1);
      }
      await _handleTypeText(
          args[0], args.sublist(1).join(' '), session, jsonOutput);
      break;

    case 'clear':
      if (args.isEmpty) {
        stderr.writeln('Error: clear requires a ref (e.g., clear w5)');
        exit(1);
      }
      await _handleClear(args[0], session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // SCROLLING
    // ════════════════════════════════════════════════════════════════════════

    case 'scroll':
      if (args.isEmpty) {
        stderr.writeln('Error: scroll requires a ref (e.g., scroll w10 down)');
        exit(1);
      }
      final direction = args.length > 1 ? args[1] : 'down';
      await _handleScroll(args[0], direction, session, jsonOutput);
      break;

    case 'swipe':
      if (args.isEmpty) {
        stderr.writeln('Error: swipe requires a direction (e.g., swipe up)');
        exit(1);
      }
      await _handleSwipe(args[0], session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // KEYBOARD
    // ════════════════════════════════════════════════════════════════════════

    case 'pressKey':
      if (args.isEmpty) {
        stderr.writeln('Error: pressKey requires a key (e.g., pressKey enter)');
        exit(1);
      }
      await _handlePressKey(args[0], session, jsonOutput);
      break;

    case 'keyDown':
      if (args.isEmpty) {
        stderr.writeln('Error: keyDown requires a key (e.g., keyDown shift)');
        exit(1);
      }
      await _handleKeyDown(args[0], session, jsonOutput);
      break;

    case 'keyUp':
      if (args.isEmpty) {
        stderr.writeln('Error: keyUp requires a key (e.g., keyUp shift)');
        exit(1);
      }
      await _handleKeyUp(args[0], session, jsonOutput);
      break;

    // ════════════════════════════════════════════════════════════════════════
    // WAITING
    // ════════════════════════════════════════════════════════════════════════

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
      await _handleWait(ms, session, jsonOutput);
      break;

    case 'waitFor':
      if (args.isEmpty) {
        stderr.writeln(
            'Error: waitFor requires a pattern (e.g., waitFor "Loading")');
        exit(1);
      }
      final timeoutStr = cmdResults?['timeout'] as String?;
      final pollStr = cmdResults?['poll'] as String?;
      final timeout = timeoutStr != null ? int.tryParse(timeoutStr) : null;
      final poll = pollStr != null ? int.tryParse(pollStr) : null;
      await _handleWaitFor(args[0], session, jsonOutput,
          timeout: timeout, poll: poll);
      break;

    case 'waitForDisappear':
      if (args.isEmpty) {
        stderr.writeln(
            'Error: waitForDisappear requires a pattern (e.g., waitForDisappear "Loading")');
        exit(1);
      }
      final timeoutStr = cmdResults?['timeout'] as String?;
      final pollStr = cmdResults?['poll'] as String?;
      final timeout = timeoutStr != null ? int.tryParse(timeoutStr) : null;
      final poll = pollStr != null ? int.tryParse(pollStr) : null;
      await _handleWaitForDisappear(args[0], session, jsonOutput,
          timeout: timeout, poll: poll);
      break;

    case 'waitForValue':
      if (args.length < 2) {
        stderr.writeln(
            'Error: waitForValue requires ref and pattern (e.g., waitForValue w10 "success")');
        exit(1);
      }
      final timeoutStr = cmdResults?['timeout'] as String?;
      final pollStr = cmdResults?['poll'] as String?;
      final timeout = timeoutStr != null ? int.tryParse(timeoutStr) : null;
      final poll = pollStr != null ? int.tryParse(pollStr) : null;
      await _handleWaitForValue(args[0], args[1], session, jsonOutput,
          timeout: timeout, poll: poll);
      break;

    default:
      stderr.writeln('Unknown command: $command');
      exit(1);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// APP LIFECYCLE HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleRun(
    List<String> flutterArgs, String session, bool jsonOutput) async {
  await ensureDaemon(session);

  final request = buildRunCommand(flutterArgs);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('✅ App launched');
    if (data?['uri'] != null) {
      print('   VM Service: ${data!['uri']}');
    }
  } else {
    stderr.writeln('❌ Failed to launch: ${response.error}');
    exit(1);
  }
}

Future<void> _handleConnect(String uri, String session, bool jsonOutput) async {
  await ensureDaemon(session);

  final request = buildConnectCommand(uri);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('✅ Connected to ${data?['uri'] ?? uri}');
  } else {
    stderr.writeln('❌ Failed to connect: ${response.error}');
    exit(1);
  }
}

Future<void> _handleClose(String session, bool jsonOutput) async {
  if (!isDaemonRunning(session)) {
    if (jsonOutput) {
      print(jsonEncode({'success': true, 'message': 'No daemon running'}));
    } else {
      print('✅ No daemon running for session "$session"');
    }
    return;
  }

  final request = buildCloseCommand();
  try {
    final response = await sendCommand(request, session);
    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
    } else if (response.success) {
      print('✅ Session "$session" closed');
    } else {
      stderr.writeln('❌ Close failed: ${response.error}');
    }
  } catch (e) {
    // Daemon may have already shut down
    if (jsonOutput) {
      print(jsonEncode({'success': true, 'message': 'Session closed'}));
    } else {
      print('✅ Session "$session" closed');
    }
  }
}

Future<void> _handleStatus(String session, bool jsonOutput) async {
  if (!isDaemonRunning(session)) {
    if (jsonOutput) {
      print(jsonEncode({
        'session': session,
        'running': false,
      }));
    } else {
      print('Session "$session": not running');
    }
    return;
  }

  final request = buildStatusCommand();
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('Session "$session":');
    print('  Connected: ${data?['connected'] ?? false}');
    print('  Launched: ${data?['launched'] ?? false}');
    if (data?['uri'] != null) {
      print('  URI: ${data!['uri']}');
    }
    print('  Can hot reload: ${data?['canHotReload'] ?? false}');
  } else {
    stderr.writeln('❌ Status failed: ${response.error}');
  }
}

Future<void> _handleSessionList(bool jsonOutput) async {
  final sessions = listSessions();

  if (jsonOutput) {
    final sessionData = <Map<String, dynamic>>[];
    for (final name in sessions) {
      final status = await getSessionStatus(name);
      sessionData.add({
        'name': name,
        ...?status,
      });
    }
    print(const JsonEncoder.withIndent('  ').convert(sessionData));
  } else if (sessions.isEmpty) {
    print('No active sessions');
  } else {
    print('Active sessions:');
    for (final name in sessions) {
      final status = await getSessionStatus(name);
      final connected = status?['connected'] == true;
      final uri = status?['uri'];
      print(
          '  $name: ${connected ? 'connected' : 'not connected'}${uri != null ? ' ($uri)' : ''}');
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// INTROSPECTION HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleSnapshot(
  String session,
  bool jsonOutput, {
  bool compact = false,
  int? depth,
  String? fromRef,
}) async {
  await _ensureConnected(session);

  final request = buildSnapshotCommand(
    compact: compact,
    depth: depth,
    fromRef: fromRef,
  );
  final response = await sendCommand(request, session);

  if (!response.success) {
    stderr.writeln('❌ Snapshot failed: ${response.error}');
    exit(1);
  }

  final data = response.data as Map<String, dynamic>?;
  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(data));
  } else {
    final lines = data?['lines'] as List<dynamic>? ?? [];
    for (final line in lines) {
      print(line);
    }
  }
}

Future<void> _handleFind(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildFindCommand(ref);
  final response = await sendCommand(request, session);

  if (!response.success) {
    stderr.writeln('❌ Find failed: ${response.error}');
    exit(1);
  }

  final data = response.data;
  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(data));
  } else if (data is Map && data['formatted'] == true) {
    final lines = data['lines'] as List<dynamic>? ?? [];
    for (final line in lines) {
      print(line);
    }
  } else {
    print('✅ Element found');
  }
}

Future<void> _handleScreenshot(
  String session, {
  String? ref,
  String? path,
}) async {
  await _ensureConnected(session);

  final request = buildScreenshotCommand(ref: ref);
  final response = await sendCommand(request, session);

  if (!response.success) {
    stderr.writeln('❌ Screenshot failed: ${response.error}');
    exit(1);
  }

  final data = response.data;
  Map<String, dynamic>? parsed;
  if (data is String) {
    parsed = jsonDecode(data) as Map<String, dynamic>?;
  } else if (data is Map<String, dynamic>) {
    parsed = data;
  }

  final base64Data = parsed?['image'] ?? parsed?['data'];
  if (base64Data == null) {
    stderr.writeln('❌ Screenshot failed: no image data');
    exit(1);
  }

  final bytes = base64Decode(base64Data as String);
  final outputPath =
      path ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
  File(outputPath).writeAsBytesSync(bytes);
  print('✅ Screenshot saved to $outputPath (${bytes.length} bytes)');
}

Future<void> _handleGetText(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildGetTextCommand(ref);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('✅ getText: "${data?['text'] ?? ''}"');
  } else {
    stderr.writeln('❌ getText failed: ${response.error}');
  }
}

// ════════════════════════════════════════════════════════════════════════════
// INTERACTION HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleTap(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildTapCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('tap', response, jsonOutput);
}

Future<void> _handleDoubleTap(
    String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildDoubleTapCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('doubleTap', response, jsonOutput);
}

Future<void> _handleLongPress(
    String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildLongPressCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('longPress', response, jsonOutput);
}

Future<void> _handleHover(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildHoverCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('hover', response, jsonOutput);
}

Future<void> _handleDrag(
    String fromRef, String toRef, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildDragCommand(fromRef, toRef);
  final response = await sendCommand(request, session);

  _printActionResult('drag', response, jsonOutput);
}

Future<void> _handleFocus(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildFocusCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('focus', response, jsonOutput);
}

// ════════════════════════════════════════════════════════════════════════════
// TEXT INPUT HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleSetText(
    String ref, String text, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildSetTextCommand(ref, text);
  final response = await sendCommand(request, session);

  _printActionResult('setText', response, jsonOutput);
}

Future<void> _handleTypeText(
    String ref, String text, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildTypeTextCommand(ref, text);
  final response = await sendCommand(request, session);

  _printActionResult('typeText', response, jsonOutput);
}

Future<void> _handleClear(String ref, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildClearCommand(ref);
  final response = await sendCommand(request, session);

  _printActionResult('clear', response, jsonOutput);
}

// ════════════════════════════════════════════════════════════════════════════
// SCROLL HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleScroll(
    String ref, String direction, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildScrollCommand(ref, direction);
  final response = await sendCommand(request, session);

  _printActionResult('scroll', response, jsonOutput);
}

Future<void> _handleSwipe(
    String direction, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildSwipeCommand(direction);
  final response = await sendCommand(request, session);

  _printActionResult('swipe', response, jsonOutput);
}

// ════════════════════════════════════════════════════════════════════════════
// KEYBOARD HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handlePressKey(
    String key, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildPressKeyCommand(key);
  final response = await sendCommand(request, session);

  _printActionResult('pressKey', response, jsonOutput);
}

Future<void> _handleKeyDown(String key, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildKeyDownCommand(key);
  final response = await sendCommand(request, session);

  _printActionResult('keyDown', response, jsonOutput);
}

Future<void> _handleKeyUp(String key, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildKeyUpCommand(key);
  final response = await sendCommand(request, session);

  _printActionResult('keyUp', response, jsonOutput);
}

// ════════════════════════════════════════════════════════════════════════════
// WAIT HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _handleWait(int ms, String session, bool jsonOutput) async {
  await _ensureConnected(session);

  final request = buildWaitCommand(ms);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    print('✅ Waited ${ms}ms');
  } else {
    stderr.writeln('❌ Wait failed: ${response.error}');
  }
}

Future<void> _handleWaitFor(
  String pattern,
  String session,
  bool jsonOutput, {
  int? timeout,
  int? poll,
}) async {
  await _ensureConnected(session);

  final request = buildWaitForCommand(pattern, timeout: timeout, poll: poll);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('✅ Found: ${data?['ref']} (matched: "${data?['matchedText']}")');
  } else {
    stderr.writeln('❌ ${response.error ?? 'Element not found'}');
  }
}

Future<void> _handleWaitForDisappear(
  String pattern,
  String session,
  bool jsonOutput, {
  int? timeout,
  int? poll,
}) async {
  await _ensureConnected(session);

  final request =
      buildWaitForDisappearCommand(pattern, timeout: timeout, poll: poll);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    print('✅ Element disappeared');
  } else {
    stderr.writeln('❌ ${response.error ?? 'Element still present'}');
  }
}

Future<void> _handleWaitForValue(
  String ref,
  String pattern,
  String session,
  bool jsonOutput, {
  int? timeout,
  int? poll,
}) async {
  await _ensureConnected(session);

  final request =
      buildWaitForValueCommand(ref, pattern, timeout: timeout, poll: poll);
  final response = await sendCommand(request, session);

  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    print('✅ Value matched: "${data?['matchedText']}"');
  } else {
    stderr.writeln('❌ ${response.error ?? 'Value did not match'}');
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

Future<void> _ensureConnected(String session) async {
  await ensureDaemon(session);

  // Check if we're connected
  final request = buildStatusCommand();
  final response = await sendCommand(request, session);

  if (response.success) {
    final data = response.data as Map<String, dynamic>?;
    if (data?['connected'] != true) {
      stderr.writeln('Error: Not connected to a Flutter app');
      stderr.writeln('');
      stderr.writeln('Use one of:');
      stderr.writeln('  flutter_mate run -d chrome    # Launch a new app');
      stderr
          .writeln('  flutter_mate connect <uri>    # Connect to existing app');
      exit(1);
    }
  }
}

void _printActionResult(String action, Response response, bool jsonOutput) {
  if (jsonOutput) {
    print(const JsonEncoder.withIndent('  ').convert(response.toJson()));
  } else if (response.success) {
    print('✅ $action succeeded');
  } else {
    stderr.writeln('❌ $action failed: ${response.error ?? 'unknown error'}');
  }
}

void _printCommandHelp(String command, ArgParser parser) {
  switch (command) {
    case 'run':
      print('''
run - Launch a Flutter app and connect to it

Usage: flutter_mate run [flutter-run-args...]

All arguments after 'run' are passed directly to 'flutter run'.

Examples:
  # Run on macOS
  flutter_mate run -d macos

  # Run on Chrome (headless)
  flutter_mate run -d chrome --web-browser-flag="--headless"

  # Run with dart defines
  flutter_mate run -d chrome --dart-define=API_URL=http://localhost

  # Run specific flavor
  flutter_mate run --flavor production
''');
      break;
    case 'connect':
      print('''
connect - Connect to an existing Flutter app

Usage: flutter_mate connect <uri>

The URI is the VM Service WebSocket URI from flutter run output:
  "A Dart VM Service on macOS is available at: http://127.0.0.1:12345/abc=/"

The URI will be automatically normalized (http→ws, adds /ws suffix).

Examples:
  flutter_mate connect ws://127.0.0.1:12345/abc=/ws
  flutter_mate connect http://127.0.0.1:12345/abc=/
''');
      break;
    case 'snapshot':
      print('''
snapshot - Capture UI tree with element refs

Usage: flutter_mate snapshot [options]

Options:
${parser.commands['snapshot']!.usage}

Examples:
  # Full snapshot
  flutter_mate snapshot

  # Compact mode - only widgets with text/actions
  flutter_mate snapshot -c

  # Limit depth to 3 levels
  flutter_mate snapshot --depth 3

  # Start from specific element (requires prior snapshot)
  flutter_mate snapshot --from w6

  # Combine options
  flutter_mate snapshot -c --depth 2 --from w10
''');
      break;
    case 'screenshot':
      print('''
screenshot - Capture screenshot of the Flutter app

Usage: flutter_mate screenshot [options]

Options:
${parser.commands['screenshot']!.usage}

Examples:
  # Full screen screenshot
  flutter_mate screenshot

  # Save to specific file
  flutter_mate screenshot --path my_screenshot.png

  # Capture specific element only
  flutter_mate screenshot --ref w10
''');
      break;
    case 'waitFor':
      print('''
waitFor - Wait for an element to appear

Usage: flutter_mate waitFor <pattern> [options]

Arguments:
  pattern    Regex pattern to match against element text/label/value

Options:
${parser.commands['waitFor']!.usage}

Examples:
  flutter_mate waitFor "Dashboard"
  flutter_mate waitFor "Loading complete" --timeout 10000
''');
      break;
    case 'waitForDisappear':
      print('''
waitForDisappear - Wait for an element to disappear

Usage: flutter_mate waitForDisappear <pattern> [options]

Options:
${parser.commands['waitForDisappear']!.usage}

Examples:
  flutter_mate waitForDisappear "Loading"
  flutter_mate waitForDisappear "Are you sure" --timeout 10000
''');
      break;
    case 'waitForValue':
      print('''
waitForValue - Wait for an element's value to match a pattern

Usage: flutter_mate waitForValue <ref> <pattern> [options]

Options:
${parser.commands['waitForValue']!.usage}

Examples:
  flutter_mate waitForValue w15 "Valid email"
  flutter_mate waitForValue w20 "^10\$"
''');
      break;
    default:
      print('No detailed help available for: $command');
      print('Use flutter_mate --help for general usage.');
  }
}

void _printUsage(ArgParser parser) {
  print('''
flutter_mate - Control Flutter apps via daemon

Usage: flutter_mate [-s session] <command> [arguments]

App Lifecycle:
  run [flutter-args...]   Launch app (all flutter run args supported)
  connect <uri>           Connect to existing app via VM Service URI
  close                   Close app and stop daemon
  status                  Show connection status

Session Management:
  session list            List active sessions

Introspection:
  snapshot                Get UI snapshot (widget tree + semantics)
                          Options: --compact/-c, --depth/-d N, --from/-f wX
  find <ref>              Get detailed info about an element
  screenshot [path]       Take screenshot
                          Options: --ref/-r wX, --path/-p file.png
  getText <ref>           Get element text

Interactions:
  tap <ref>               Tap on element
  doubleTap <ref>         Double tap element
  longPress <ref>         Long press element
  hover <ref>             Hover over element
  drag <from> <to>        Drag from one element to another
  focus <ref>             Focus on element

Text Input:
  setText <ref> <text>    Set text field via semantic action
  typeText <ref> <text>   Type text via keyboard simulation
  clear <ref>             Clear text field

Scrolling:
  scroll <ref> [dir]      Scroll element (dir: up, down, left, right)
  swipe <dir>             Swipe gesture

Keyboard:
  pressKey <key>          Press keyboard key (enter, tab, escape, etc.)
  keyDown <key>           Press key down (hold)
  keyUp <key>             Release key

Waiting:
  wait <ms>               Wait milliseconds
  waitFor <pattern>       Wait for element to appear
  waitForDisappear <p>    Wait for element to disappear
  waitForValue <ref> <p>  Wait for element value to match

Options:
${parser.usage}

Examples:
  # Launch app and run commands
  flutter_mate run -d chrome --web-browser-flag="--headless"
  flutter_mate snapshot
  flutter_mate tap w10
  flutter_mate screenshot
  flutter_mate close

  # Connect to existing app
  flutter_mate connect ws://127.0.0.1:12345/abc=/ws
  flutter_mate snapshot -c
  flutter_mate tap w5

  # Multiple sessions
  flutter_mate -s staging run -d chrome
  flutter_mate -s staging snapshot
  flutter_mate session list
''');
}
