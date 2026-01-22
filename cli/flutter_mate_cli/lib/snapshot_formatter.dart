/// Shared snapshot formatting utilities for CLI and MCP server.
///
/// Extracts common logic for collapsing widget nodes and formatting
/// the snapshot output.

/// Layout wrapper widgets to hide from display (purely structural)
const layoutWrappers = {
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
  'DefaultTextStyle',
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
  // Visual effects
  'Opacity',
  'ImageFiltered',
  'BackdropFilter',
  'ShaderMask',
  'ColorFiltered',
  // Animations (structural, no semantic meaning)
  'AnimatedBuilder',
  'AnimatedContainer',
  'AnimatedDefaultTextStyle',
  'AnimatedOpacity',
  'AnimatedPositioned',
  'AnimatedSize',
  'AnimatedSwitcher',
  'TweenAnimationBuilder',
  'SlideTransition',
  'FadeTransition',
  'ScaleTransition',
  'RotationTransition',
  'SizeTransition',
  'DecoratedBoxTransition',
  'PositionedTransition',
  'RelativePositionedTransition',
  'AnimatedModalBarrier',
  // Builders (reactive wrappers)
  'ValueListenableBuilder',
  'StreamBuilder',
  'FutureBuilder',
  'LayoutBuilder',
  'OrientationBuilder',
  // Other structural
  'MetaData',
  'KeyedSubtree',
  'RepaintBoundary',
  'Builder',
  'StatefulBuilder',
  'NotificationListener',
  'MediaQuery',
  'Theme',
  'DefaultTextEditingShortcuts',
};

/// Widgets to skip when they appear as siblings (spacers between items).
const siblingSpacers = {
  'SizedBox',
  'Spacer',
  'Divider',
  'VerticalDivider',
  'Gap',
};

/// Collapse nodes with same bounds into chains for cleaner display.
List<Map<String, dynamic>> collapseNodes(
    List<dynamic> nodes, Map<String, Map<String, dynamic>> nodeMap) {
  final result = <Map<String, dynamic>>[];
  final visited = <String>{};

  void processNode(Map<String, dynamic> node, int displayDepth) {
    final ref = node['ref'] as String;
    if (visited.contains(ref)) return;

    // Skip zero-area spacers
    if (isHiddenSpacer(node)) {
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
      if (isHiddenSpacer(child)) {
        visited.add(childRef);
        break;
      }

      // Don't collapse into Semantics widgets
      final childWidget = child['widget'] as String? ?? '';
      if (childWidget == 'Semantics') break;

      // Always collapse layout wrappers (regardless of bounds)
      if (layoutWrappers.contains(widgetType)) {
        current = child;
        continue;
      }

      // Check bounds - collapse if same
      if (sameBounds(current, child)) {
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

    // Process children - skip meaningless spacers when there are multiple siblings
    final children = current['children'] as List<dynamic>? ?? [];
    final hasMultipleSiblings = children.length > 1;

    for (final childRef in children) {
      final ref = childRef as String;
      final child = nodeMap[ref];
      if (child == null || visited.contains(ref)) continue;

      // Skip spacer widgets between siblings
      final widgetType = child['widget'] as String? ?? '';
      if (hasMultipleSiblings && siblingSpacers.contains(widgetType)) {
        visited.add(ref);
        continue;
      }

      processNode(child, displayDepth + 1);
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
bool isHiddenSpacer(Map<String, dynamic> node) {
  final widget = node['widget'] as String? ?? '';
  if (widget != 'SizedBox' && widget != 'Spacer') return false;

  final bounds = node['bounds'] as Map<String, dynamic>?;
  if (bounds == null) return true;

  final width = (bounds['width'] as num?)?.toDouble() ?? 0;
  final height = (bounds['height'] as num?)?.toDouble() ?? 0;

  return width < 2 || height < 2;
}

/// Check if two nodes have the same bounds
bool sameBounds(Map<String, dynamic> a, Map<String, dynamic> b) {
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

/// Format a single collapsed entry for display.
/// Returns a formatted string like:
/// `• [w0] Widget (text) {info} [actions] (Flags)`
String formatCollapsedEntry(Map<String, dynamic> entry) {
  final chain = entry['chain'] as List<Map<String, dynamic>>;
  final depth = entry['depth'] as int;
  final semantics = entry['semantics'] as Map<String, dynamic>?;
  final textContent = entry['textContent'] as String?;

  final indent = '  ' * depth;

  // Filter layout wrappers from display chain
  final meaningful = chain
      .where((item) => !layoutWrappers.contains(item['widget'] as String))
      .toList();
  final display = meaningful.isNotEmpty ? meaningful : [chain.first];
  final chainStr =
      display.map((e) => '[${e['ref']}] ${e['widget']}').join(' → ');

  // Build info parts
  final parts = <String>[];

  // Collect all text from textContent and semantics label
  // SDK already deduplicates these, so just combine them for display
  final allTexts = <String>[];

  // Helper to add non-empty, non-icon text
  void addText(String? text) {
    if (text == null || text.trim().isEmpty) return;
    // Skip single-character icon glyphs (Private Use Area)
    if (text.length == 1 && text.codeUnitAt(0) >= 0xE000) return;
    allTexts.add(text.trim());
  }

  // Add textContent parts (split by |)
  if (textContent != null) {
    for (final t in textContent.split(' | ')) {
      addText(t);
    }
  }

  // Add semantics label (SDK already deduplicates this)
  final label = semantics?['label'] as String?;
  addText(label);

  // Add semantic value FIRST (e.g., current text in a text field)
  final value = semantics?['value'] as String?;
  if (value != null && value.isNotEmpty) {
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

  final partsStr = parts.isEmpty ? '' : ' ${parts.join(' ')}';
  return '$indent• $chainStr$partsStr';
}

/// Format an entire snapshot for display.
/// Returns a list of formatted lines.
List<String> formatSnapshot(List<dynamic> nodes) {
  // Build node map
  final nodeMap = <String, Map<String, dynamic>>{};
  for (final node in nodes) {
    nodeMap[node['ref'] as String] = node as Map<String, dynamic>;
  }

  // Collapse nodes
  final collapsed = collapseNodes(nodes, nodeMap);

  // Format each entry
  return collapsed.map((entry) => formatCollapsedEntry(entry)).toList();
}
