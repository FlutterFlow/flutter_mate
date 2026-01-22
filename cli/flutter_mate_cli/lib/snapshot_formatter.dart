/// Shared snapshot formatting utilities for CLI and MCP server.
///
/// Provides functions to parse, collapse, and format snapshot data
/// for human-readable output. Uses types from flutter_mate_types
/// for type-safe snapshot handling.
library snapshot_formatter;

import 'package:flutter_mate_types/flutter_mate_types.dart';

// Re-export types for convenience
export 'package:flutter_mate_types/flutter_mate_types.dart';

// ============================================================================
// Constants
// ============================================================================

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

// ============================================================================
// Collapsed entry for display
// ============================================================================

/// A chain item in a collapsed entry (ref + widget name).
class ChainItem {
  final String ref;
  final String widget;

  const ChainItem({required this.ref, required this.widget});
}

/// A collapsed entry for display (chain of widgets + aggregated info).
class CollapsedEntry {
  final List<ChainItem> chain;
  final int depth;
  final SemanticsInfo? semantics;
  final String? textContent;
  final List<String> children;

  const CollapsedEntry({
    required this.chain,
    required this.depth,
    this.semantics,
    this.textContent,
    this.children = const [],
  });
}

// ============================================================================
// Collapsing logic
// ============================================================================

/// Parse raw JSON nodes into typed [CombinedNode] objects.
Map<String, CombinedNode> parseNodes(List<dynamic> rawNodes) {
  final nodeMap = <String, CombinedNode>{};
  for (final raw in rawNodes) {
    final node = CombinedNode.fromJson(raw as Map<String, dynamic>);
    nodeMap[node.ref] = node;
  }
  return nodeMap;
}

/// Check if a node is a hidden spacer (zero-area).
bool _isHiddenSpacer(CombinedNode node) {
  if (node.widget != 'SizedBox' && node.widget != 'Spacer') return false;
  return node.bounds?.isZeroArea ?? true;
}

/// Collapse nodes with same bounds into chains for cleaner display.
List<CollapsedEntry> collapseNodes(Map<String, CombinedNode> nodeMap) {
  final result = <CollapsedEntry>[];
  final visited = <String>{};

  void processNode(CombinedNode node, int displayDepth) {
    if (visited.contains(node.ref)) return;

    // Skip zero-area spacers
    if (_isHiddenSpacer(node)) {
      visited.add(node.ref);
      return;
    }

    // Start a chain with this node
    final chain = <ChainItem>[];
    var current = node;
    SemanticsInfo? aggregatedSemantics;
    String? aggregatedText;

    while (true) {
      visited.add(current.ref);
      chain.add(ChainItem(ref: current.ref, widget: current.widget));

      // Aggregate semantics (first one wins)
      aggregatedSemantics ??= current.semantics;

      // Aggregate text content (first one wins)
      if (current.textContent?.isNotEmpty == true) {
        aggregatedText ??= current.textContent;
      }

      // Stop conditions
      if (current.children.isEmpty) break;
      if (current.children.length > 1) break;

      // Don't collapse past Semantics widgets
      if (current.widget == 'Semantics') break;

      final childRef = current.children.first;
      final child = nodeMap[childRef];
      if (child == null) break;

      // Skip hidden spacers
      if (_isHiddenSpacer(child)) {
        visited.add(childRef);
        break;
      }

      // Don't collapse into Semantics widgets
      if (child.widget == 'Semantics') break;

      // Always collapse layout wrappers (regardless of bounds)
      if (layoutWrappers.contains(current.widget)) {
        current = child;
        continue;
      }

      // Check bounds - collapse if same
      if (current.bounds != null &&
          child.bounds != null &&
          current.bounds!.sameBoundsAs(child.bounds!)) {
        current = child;
        continue;
      }

      break;
    }

    // Create collapsed entry
    result.add(CollapsedEntry(
      chain: chain,
      depth: displayDepth,
      semantics: aggregatedSemantics,
      textContent: aggregatedText,
      children: current.children,
    ));

    // Process children - skip spacers when there are multiple siblings
    final hasMultipleSiblings = current.children.length > 1;

    for (final childRef in current.children) {
      final child = nodeMap[childRef];
      if (child == null || visited.contains(childRef)) continue;

      // Skip spacer widgets between siblings (only if they have no children)
      if (hasMultipleSiblings &&
          siblingSpacers.contains(child.widget) &&
          child.children.isEmpty) {
        visited.add(childRef);
        continue;
      }

      processNode(child, displayDepth + 1);
    }
  }

  // Find and process root nodes (depth 0)
  for (final node in nodeMap.values) {
    if (node.depth == 0) {
      processNode(node, 0);
    }
  }

  return result;
}

// ============================================================================
// Utilities
// ============================================================================

/// Escape special characters in a string for display.
String escapeString(String s, {bool escapeDollar = true}) {
  final escapedString = s
      .replaceAll('\\', r'\\')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', '')
      .replaceAll('\t', r'\t')
      .replaceAll('\'', r"\'")
      .replaceAll('"', r'\"');
  return escapeDollar ? escapedString.replaceAll(r'$', r'\$') : escapedString;
}

// ============================================================================
// Formatting
// ============================================================================

/// Format a single collapsed entry for display.
String formatCollapsedEntry(CollapsedEntry entry) {
  final indent = '  ' * entry.depth;

  // Filter layout wrappers from display chain
  final meaningful =
      entry.chain.where((item) => !layoutWrappers.contains(item.widget));
  final display = meaningful.isNotEmpty ? meaningful : [entry.chain.first];
  final chainStr = display.map((e) => '[${e.ref}] ${e.widget}').join(' → ');

  // Build info parts
  final parts = <String>[];

  // Collect all text from textContent and semantics label
  final allTexts = <String>[];

  void addText(String? text) {
    if (text == null || text.trim().isEmpty) return;
    // Skip single-character icon glyphs (Private Use Area)
    if (text.length == 1 && text.codeUnitAt(0) >= 0xE000) return;
    // Escape special characters for cleaner display
    allTexts.add(escapeString(text.trim(), escapeDollar: false));
  }

  // Add textContent parts (split by |)
  if (entry.textContent != null) {
    for (final t in entry.textContent!.split(' | ')) {
      addText(t);
    }
  }

  // Add semantics label
  addText(entry.semantics?.label);

  // Add semantic value FIRST (e.g., current text in a text field)
  final value = entry.semantics?.value;
  if (value != null && value.isNotEmpty) {
    parts.add('value = "$value"');
  }

  // Then add text content list
  if (allTexts.isNotEmpty) {
    parts.add('(${allTexts.join(', ')})');
  }

  // Build extra semantic info in {key: value, ...} format
  final extraParts = <String>[];
  final sem = entry.semantics;

  if (sem != null) {
    if (sem.validationResult == 'invalid') {
      extraParts.add('invalid');
    } else if (sem.validationResult == 'valid') {
      extraParts.add('valid');
    }

    if (sem.tooltip?.isNotEmpty == true) {
      extraParts.add('tooltip: "${sem.tooltip}"');
    }

    if (sem.headingLevel != null && sem.headingLevel! > 0) {
      extraParts.add('heading: ${sem.headingLevel}');
    }

    if (sem.linkUrl?.isNotEmpty == true) {
      extraParts.add('link');
    }

    if (sem.inputType != null &&
        sem.inputType != 'none' &&
        sem.inputType != 'text') {
      extraParts.add('type: ${sem.inputType}');
    } else if (sem.role != null && sem.role != 'none') {
      extraParts.add('role: ${sem.role}');
    }
  }

  if (extraParts.isNotEmpty) {
    parts.add('{${extraParts.join(', ')}}');
  }

  // Add actions
  if (sem != null && sem.actions.isNotEmpty) {
    parts.add('[${sem.actions.join(', ')}]');
  }

  // Add flags
  if (sem != null && sem.flags.isNotEmpty) {
    final flagsStr = sem.flags
        .where((f) => f.startsWith('is'))
        .map((f) => f.substring(2))
        .join(', ');
    if (flagsStr.isNotEmpty) parts.add('($flagsStr)');
  }

  // Add scroll info
  if (sem?.scrollPosition != null) {
    final pos = sem!.scrollPosition!.toStringAsFixed(0);
    final max = sem.scrollExtentMax?.toStringAsFixed(0) ?? '?';
    parts.add('{scroll: $pos/$max}');
  }

  final partsStr = parts.isEmpty ? '' : ' ${parts.join(' ')}';
  return '$indent• $chainStr$partsStr';
}

/// Format an entire snapshot for display.
/// Returns a list of formatted lines.
List<String> formatSnapshot(List<dynamic> rawNodes) {
  final nodeMap = parseNodes(rawNodes);
  final collapsed = collapseNodes(nodeMap);
  return collapsed.map(formatCollapsedEntry).toList();
}
