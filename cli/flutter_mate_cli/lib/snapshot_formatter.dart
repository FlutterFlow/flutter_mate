/// Shared snapshot formatting utilities for CLI and MCP server.
///
/// Extracts common logic for collapsing widget nodes and formatting
/// the snapshot output.

// ============================================================================
// Typed classes for snapshot data
// ============================================================================

/// Bounds of a widget in the UI.
class NodeBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const NodeBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory NodeBounds.fromJson(Map<String, dynamic> json) {
    return NodeBounds(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }

  bool sameBoundsAs(NodeBounds other, {double tolerance = 1.0}) {
    return (x - other.x).abs() <= tolerance &&
        (y - other.y).abs() <= tolerance &&
        (width - other.width).abs() <= tolerance &&
        (height - other.height).abs() <= tolerance;
  }

  bool get isZeroArea => width < 2 || height < 2;
}

/// Semantics information for a widget.
class NodeSemantics {
  final int? id;
  final String? label;
  final String? value;
  final String? hint;
  final String? tooltip;
  final String? validationResult;
  final int? headingLevel;
  final String? linkUrl;
  final String? role;
  final String? inputType;
  final double? scrollPosition;
  final double? scrollExtentMax;
  final List<String> actions;
  final List<String> flags;

  const NodeSemantics({
    this.id,
    this.label,
    this.value,
    this.hint,
    this.tooltip,
    this.validationResult,
    this.headingLevel,
    this.linkUrl,
    this.role,
    this.inputType,
    this.scrollPosition,
    this.scrollExtentMax,
    this.actions = const [],
    this.flags = const [],
  });

  factory NodeSemantics.fromJson(Map<String, dynamic> json) {
    return NodeSemantics(
      id: json['id'] as int?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      hint: json['hint'] as String?,
      tooltip: json['tooltip'] as String?,
      validationResult: json['validationResult'] as String?,
      headingLevel: json['headingLevel'] as int?,
      linkUrl: json['linkUrl'] as String?,
      role: json['role'] as String?,
      inputType: json['inputType'] as String?,
      scrollPosition: (json['scrollPosition'] as num?)?.toDouble(),
      scrollExtentMax: (json['scrollExtentMax'] as num?)?.toDouble(),
      actions: (json['actions'] as List<dynamic>?)?.cast<String>() ?? [],
      flags: (json['flags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (label != null) 'label': label,
        if (value != null) 'value': value,
        if (hint != null) 'hint': hint,
        if (tooltip != null) 'tooltip': tooltip,
        if (validationResult != null) 'validationResult': validationResult,
        if (headingLevel != null) 'headingLevel': headingLevel,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (role != null) 'role': role,
        if (inputType != null) 'inputType': inputType,
        if (scrollPosition != null) 'scrollPosition': scrollPosition,
        if (scrollExtentMax != null) 'scrollExtentMax': scrollExtentMax,
        if (actions.isNotEmpty) 'actions': actions,
        if (flags.isNotEmpty) 'flags': flags,
      };
}

/// A node in the snapshot tree.
class SnapshotNode {
  final String ref;
  final String widget;
  final int depth;
  final NodeBounds? bounds;
  final NodeSemantics? semantics;
  final String? textContent;
  final List<String> children;

  const SnapshotNode({
    required this.ref,
    required this.widget,
    required this.depth,
    this.bounds,
    this.semantics,
    this.textContent,
    this.children = const [],
  });

  factory SnapshotNode.fromJson(Map<String, dynamic> json) {
    return SnapshotNode(
      ref: json['ref'] as String? ?? '',
      widget: json['widget'] as String? ?? '?',
      depth: json['depth'] as int? ?? 0,
      bounds: json['bounds'] != null
          ? NodeBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      semantics: json['semantics'] != null
          ? NodeSemantics.fromJson(json['semantics'] as Map<String, dynamic>)
          : null,
      textContent: json['textContent'] as String?,
      children: (json['children'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  bool get isHiddenSpacer {
    if (widget != 'SizedBox' && widget != 'Spacer') return false;
    return bounds?.isZeroArea ?? true;
  }

  bool get isSiblingSpacerCandidate {
    return siblingSpacers.contains(widget) && children.isEmpty;
  }
}

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
  final NodeSemantics? semantics;
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
// Collapsing logic
// ============================================================================

/// Parse raw JSON nodes into typed [SnapshotNode] objects.
Map<String, SnapshotNode> parseNodes(List<dynamic> rawNodes) {
  final nodeMap = <String, SnapshotNode>{};
  for (final raw in rawNodes) {
    final node = SnapshotNode.fromJson(raw as Map<String, dynamic>);
    nodeMap[node.ref] = node;
  }
  return nodeMap;
}

/// Collapse nodes with same bounds into chains for cleaner display.
List<CollapsedEntry> collapseNodes(Map<String, SnapshotNode> nodeMap) {
  final result = <CollapsedEntry>[];
  final visited = <String>{};

  void processNode(SnapshotNode node, int displayDepth) {
    if (visited.contains(node.ref)) return;

    // Skip zero-area spacers
    if (node.isHiddenSpacer) {
      visited.add(node.ref);
      return;
    }

    // Start a chain with this node
    final chain = <ChainItem>[];
    var current = node;
    NodeSemantics? aggregatedSemantics;
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
      if (child.isHiddenSpacer) {
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
      if (hasMultipleSiblings && child.isSiblingSpacerCandidate) {
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
    allTexts.add(text.trim());
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
