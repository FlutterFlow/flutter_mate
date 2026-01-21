import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_mate_cli/vm_service_client.dart';

const String version = '0.1.0';

/// Layout wrapper widgets to hide from display (purely structural)
const _layoutWrappers = {
  // Spacing/sizing
  'Padding',
  'SizedBox',
  'ConstrainedBox',
  'LimitedBox',
  'OverflowBox',
  'FractionallySizedBox',
  'IntrinsicHeight',
  'IntrinsicWidth',
  // Alignment
  'Center',
  'Align',
  // Flex children
  'Expanded',
  'Flexible',
  'Positioned',
  'Spacer',
  // Decoration/styling
  'Container',
  'DecoratedBox',
  'ColoredBox',
  // Transforms
  'Transform',
  'RotatedBox',
  'FittedBox',
  'AspectRatio',
  // Clipping
  'ClipRect',
  'ClipRRect',
  'ClipOval',
  'ClipPath',
  // Other structural
  'Opacity',
  'Offstage',
  'Visibility',
  'IgnorePointer',
  'AbsorbPointer',
  'MetaData',
  'KeyedSubtree',
  'RepaintBoundary',
  'Builder',
  'StatefulBuilder',
};

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version')
    ..addOption('uri', abbr: 'u', help: 'VM Service WebSocket URI (ws://...)')
    ..addFlag('json', abbr: 'j', negatable: false, help: 'Output as JSON');

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
}) async {
  final client = VmServiceClient(wsUri);

  try {
    await client.connect();

    switch (command) {
      case 'snapshot':
        await _snapshot(client, jsonOutput);
        break;
      case 'debug-trees':
        await _debugTrees(client, jsonOutput);
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
      case 'fill': // deprecated alias
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

Future<void> _snapshot(VmServiceClient client, bool jsonOutput) async {
  try {
    // Get snapshot via FlutterMate service extension
    final result = await client.getSnapshot();
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
      _printSnapshot(data);
    }
  } catch (e, stack) {
    stderr.writeln('Error getting snapshot: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

/// Debug: Get both inspector tree and semantics tree for comparison
Future<void> _debugTrees(VmServiceClient client, bool jsonOutput) async {
  try {
    final result = await client.callExtension(
      'ext.flutter_mate.debugTrees',
      args: {},
    );

    if (jsonOutput) {
      print(const JsonEncoder.withIndent('  ').convert(result));
      return;
    }

    // Print inspector tree
    print('\n${'=' * 60}');
    print('📱 INSPECTOR TREE (DevTools structure)');
    print('=' * 60);

    final inspectorTree = result['inspectorTree'] as Map<String, dynamic>?;
    if (inspectorTree != null) {
      void printInspectorNode(Map<String, dynamic> node, int depth) {
        final indent = '  ' * depth;
        final description = node['description'] as String? ?? '';
        final valueId = node['valueId'] as String?;
        final widgetRuntimeType = node['widgetRuntimeType'] as String?;

        print('$indent• $description');
        if (valueId != null) print('$indent  valueId: $valueId');
        if (widgetRuntimeType != null) {
          print('$indent  widgetRuntimeType: $widgetRuntimeType');
        }

        final children = node['children'] as List<dynamic>? ?? [];
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            printInspectorNode(child, depth + 1);
          }
        }
      }

      printInspectorNode(inspectorTree, 0);
    }

    // Print semantics tree
    print('\n${'=' * 60}');
    print('🔤 SEMANTICS TREE (Interactive elements)');
    print('=' * 60);

    final semanticsNodes = result['semanticsNodes'] as List<dynamic>? ?? [];
    for (final node in semanticsNodes) {
      final nodeMap = node as Map<String, dynamic>;
      final id = nodeMap['id'];
      final depth = nodeMap['depth'] as int? ?? 0;
      final label = nodeMap['label'] as String?;
      final value = nodeMap['value'] as String?;
      final rect = nodeMap['rect'] as Map<String, dynamic>?;
      final actions =
          (nodeMap['actions'] as List<dynamic>?)?.cast<String>() ?? [];
      final flags = (nodeMap['flags'] as List<dynamic>?)?.cast<String>() ?? [];

      final indent = '  ' * depth;
      final displayLabel = label ?? value ?? '(no label)';
      final actionsStr = actions.isNotEmpty ? ' [${actions.join(', ')}]' : '';
      final flagsStr = flags.where((f) => f.startsWith('is')).join(', ');

      print('$indent• s$id: $displayLabel$actionsStr');
      if (rect != null) {
        print(
            '$indent  bounds: (${rect['x']?.toStringAsFixed(0)}, ${rect['y']?.toStringAsFixed(0)}) ${rect['width']?.toStringAsFixed(0)}x${rect['height']?.toStringAsFixed(0)}');
      }
      if (flagsStr.isNotEmpty) print('$indent  flags: $flagsStr');
    }

    print('\n${'-' * 60}');
    print(
        'Inspector nodes: ${_countInspectorNodes(inspectorTree)}, Semantics nodes: ${semanticsNodes.length}');
  } catch (e, stack) {
    stderr.writeln('Error getting debug trees: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

int _countInspectorNodes(Map<String, dynamic>? node) {
  if (node == null) return 0;
  int count = 1;
  final children = node['children'] as List<dynamic>? ?? [];
  for (final child in children) {
    if (child is Map<String, dynamic>) {
      count += _countInspectorNodes(child);
    }
  }
  return count;
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

  // Build node map for quick lookup
  final nodeMap = <String, Map<String, dynamic>>{};
  for (final node in nodes) {
    nodeMap[node['ref'] as String] = node as Map<String, dynamic>;
  }

  // Collapse nodes with same bounds
  final collapsed = _collapseNodes(nodes, nodeMap);

  for (final entry in collapsed) {
    final chain = entry['chain'] as List<Map<String, dynamic>>;
    final depth = entry['depth'] as int;
    final semantics = entry['semantics'] as Map<String, dynamic>?;
    final textContent = entry['textContent'] as String?;

    final indent = '  ' * depth;

    // Build chain string: [w0] Widget1 → [w1] Widget2
    // Filter out layout wrappers, but keep at least one widget
    final meaningful = chain
        .where((item) => !_layoutWrappers.contains(item['widget'] as String))
        .toList();
    final display = meaningful.isNotEmpty ? meaningful : [chain.first];
    final chainParts = <String>[];
    for (final item in display) {
      final ref = item['ref'] as String;
      final widget = item['widget'] as String;
      chainParts.add('[$ref] $widget');
    }
    final chainStr = chainParts.join(' → ');

    // Build info parts
    final parts = <String>[];

    // Collect all text from textContent and semantics label, deduplicate
    final allTexts = <String>[];
    final seenTexts = <String>{}; // Track by trimmed lowercase for dedup

    void addText(String? text) {
      if (text == null || text.trim().isEmpty) return;
      // Skip single-character icon glyphs (Private Use Area)
      if (text.length == 1 && text.codeUnitAt(0) >= 0xE000) return;
      final key = text.trim().toLowerCase();
      if (!seenTexts.contains(key)) {
        seenTexts.add(key);
        allTexts.add(text.trim());
      }
    }

    // Add textContent parts (split by |)
    if (textContent != null) {
      for (final t in textContent.split(' | ')) {
        addText(t);
      }
    }

    // Add semantics label
    final label = semantics?['label'] as String?;
    addText(label);

    // Add semantic value FIRST (e.g., current text in a text field)
    final value = semantics?['value'] as String?;
    if (value != null &&
        value.isNotEmpty &&
        !seenTexts.contains(value.trim().toLowerCase())) {
      parts.add('value = "$value"');
    }

    // Then add text content list
    if (allTexts.isNotEmpty) {
      parts.add('(${allTexts.join(', ')})');
    }

    // Build extra semantic info in {key: value, ...} format
    final extraParts = <String>[];

    final validationResult = semantics?['validationResult'] as String?;
    if (validationResult == 'invalid') {
      extraParts.add('invalid');
    } else if (validationResult == 'valid') {
      extraParts.add('valid');
    }

    final tooltip = semantics?['tooltip'] as String?;
    if (tooltip != null && tooltip.isNotEmpty) {
      extraParts.add('tooltip: "$tooltip"');
    }

    final headingLevel = semantics?['headingLevel'] as int?;
    if (headingLevel != null && headingLevel > 0) {
      extraParts.add('heading: $headingLevel');
    }

    final linkUrl = semantics?['linkUrl'] as String?;
    if (linkUrl != null && linkUrl.isNotEmpty) {
      extraParts.add('link');
    }

    final role = semantics?['role'] as String?;
    final inputType = semantics?['inputType'] as String?;
    if (inputType != null && inputType != 'none' && inputType != 'text') {
      extraParts.add('type: $inputType');
    } else if (role != null && role != 'none') {
      extraParts.add('role: $role');
    }

    if (extraParts.isNotEmpty) {
      parts.add('{${extraParts.join(', ')}}');
    }

    // Add actions
    final actions =
        (semantics?['actions'] as List<dynamic>?)?.cast<String>() ?? [];
    if (actions.isNotEmpty) {
      parts.add('[${actions.join(', ')}]');
    }

    // Add flags
    final flags = (semantics?['flags'] as List<dynamic>?)?.cast<String>() ?? [];
    final flagsStr = flags
        .where((f) => f.startsWith('is'))
        .map((f) => f.substring(2))
        .join(', ');
    if (flagsStr.isNotEmpty) parts.add('($flagsStr)');

    // Add scroll info
    final scrollPosition = semantics?['scrollPosition'] as num?;
    final scrollExtentMax = semantics?['scrollExtentMax'] as num?;
    if (scrollPosition != null) {
      final pos = scrollPosition.toStringAsFixed(0);
      final max = scrollExtentMax?.toStringAsFixed(0) ?? '?';
      parts.add('{scroll: $pos/$max}');
    }

    final info = parts.isNotEmpty ? ' ${parts.join(' ')}' : '';
    print('$indent• $chainStr$info');
  }
}

/// Collapse nodes with same bounds into chains
List<Map<String, dynamic>> _collapseNodes(
    List<dynamic> nodes, Map<String, Map<String, dynamic>> nodeMap) {
  final result = <Map<String, dynamic>>[];
  final visited = <String>{};

  void processNode(Map<String, dynamic> node, int displayDepth) {
    final ref = node['ref'] as String;
    if (visited.contains(ref)) return;

    // Skip zero-area spacers
    if (_isHiddenSpacer(node)) {
      visited.add(ref);
      return;
    }

    // Start a chain with this node
    final chain = <Map<String, dynamic>>[];
    var current = node;
    Map<String, dynamic>? aggregatedSemantics;
    String? aggregatedText;

    while (true) {
      final currentRef = current['ref'] as String;
      visited.add(currentRef);
      chain.add({
        'ref': currentRef,
        'widget': current['widget'] as String? ?? '?',
      });

      // Aggregate semantics
      final sem = current['semantics'] as Map<String, dynamic>?;
      if (sem != null) {
        aggregatedSemantics ??= sem;
      }

      // Aggregate text content
      final text = current['textContent'] as String?;
      if (text != null && text.isNotEmpty) {
        aggregatedText ??= text;
      }

      // Stop conditions
      final children = current['children'] as List<dynamic>? ?? [];
      if (children.isEmpty) break;
      if (children.length > 1) break;

      // Don't collapse past Semantics widgets
      final widgetType = current['widget'] as String? ?? '';
      if (widgetType == 'Semantics') break;

      final childRef = children.first as String;
      final child = nodeMap[childRef];
      if (child == null) break;

      // Skip hidden spacers
      if (_isHiddenSpacer(child)) {
        visited.add(childRef);
        break;
      }

      // Don't collapse into Semantics widgets
      final childWidget = child['widget'] as String? ?? '';
      if (childWidget == 'Semantics') break;

      // Always collapse layout wrappers (regardless of bounds)
      if (_layoutWrappers.contains(widgetType)) {
        current = child;
        continue;
      }

      // Check bounds - collapse if same
      if (_sameBounds(current, child)) {
        current = child;
        continue;
      }

      break;
    }

    // Create collapsed entry
    result.add({
      'chain': chain,
      'depth': displayDepth,
      'semantics': aggregatedSemantics,
      'textContent': aggregatedText,
      'children': current['children'] as List<dynamic>? ?? [],
    });

    // Process children
    final children = current['children'] as List<dynamic>? ?? [];
    for (final childRef in children) {
      final child = nodeMap[childRef as String];
      if (child != null && !visited.contains(childRef)) {
        processNode(child, displayDepth + 1);
      }
    }
  }

  // Find and process root nodes
  for (final node in nodes) {
    final nodeData = node as Map<String, dynamic>;
    final depth = nodeData['depth'] as int? ?? 0;
    if (depth == 0) {
      processNode(nodeData, 0);
    }
  }

  return result;
}

/// Check if a node should be hidden (zero-area spacer)
bool _isHiddenSpacer(Map<String, dynamic> node) {
  final widget = node['widget'] as String? ?? '';
  if (widget != 'SizedBox' && widget != 'Spacer') return false;

  final bounds = node['bounds'] as Map<String, dynamic>?;
  if (bounds == null) return true;

  final width = (bounds['width'] as num?)?.toDouble() ?? 0;
  final height = (bounds['height'] as num?)?.toDouble() ?? 0;

  return width < 2 || height < 2;
}

/// Check if two nodes have the same bounds
bool _sameBounds(Map<String, dynamic> a, Map<String, dynamic> b) {
  final boundsA = a['bounds'] as Map<String, dynamic>?;
  final boundsB = b['bounds'] as Map<String, dynamic>?;

  if (boundsA == null || boundsB == null) return false;

  const tolerance = 1.0;

  final xDiff = ((boundsA['x'] as num?) ?? 0) - ((boundsB['x'] as num?) ?? 0);
  final yDiff = ((boundsA['y'] as num?) ?? 0) - ((boundsB['y'] as num?) ?? 0);
  final wDiff =
      ((boundsA['width'] as num?) ?? 0) - ((boundsB['width'] as num?) ?? 0);
  final hDiff =
      ((boundsA['height'] as num?) ?? 0) - ((boundsB['height'] as num?) ?? 0);

  return xDiff.abs() <= tolerance &&
      yDiff.abs() <= tolerance &&
      wDiff.abs() <= tolerance &&
      hDiff.abs() <= tolerance;
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
          await _snapshot(client, false);
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
        case 'fill': // deprecated alias
        case 'f':
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
          print('  snapshot, s      - Get UI snapshot');
          print('  tap, t <ref>     - Tap element (auto: semantic or gesture)');
          print('  doubleTap, dt <ref> - Double tap element');
          print('  longPress, lp <ref> - Long press element');
          print('  setText, f <ref> <text> - Set text (semantic action)');
          print('  typeText <ref> <text> - Type text (keyboard simulation)');
          print('  clear <ref>      - Clear text field');
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
  snapshot              Get UI snapshot (widget tree + semantics)
  tap <ref>             Tap on element (e.g., tap w123)
  doubleTap <ref>       Double tap element
  longPress <ref>       Long press element
  fill <ref> <text>     Fill text field via semantic setText (e.g., fill w9 "text")
  typeText <ref> <text> Type text via keyboard simulation (e.g., typeText w10 "text")
  clear <ref>           Clear text field
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
  
  # Get UI snapshot
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot
  
  # Interactive elements only
  flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -i
  
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
