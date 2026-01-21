import 'dart:ui' show Offset;

/// A combined snapshot of the widget tree with semantics information
///
/// This provides both structural context (widget types, hierarchy) from the
/// Element tree and interaction capabilities (actions, labels, values) from
/// the Semantics tree.
///
/// ```dart
/// final snapshot = await FlutterMate.snapshot();
///
/// // Access by ref
/// final node = snapshot['w5'];
///
/// // Get nodes with semantics
/// final interactive = snapshot.withSemantics;
///
/// // Pretty print
/// print(snapshot);
/// ```
class CombinedSnapshot {
  final bool success;
  final String? error;
  final DateTime timestamp;
  final List<CombinedNode> nodes;
  final Map<String, CombinedNode> _nodesByRef;

  CombinedSnapshot({
    required this.success,
    this.error,
    required this.timestamp,
    required this.nodes,
  }) : _nodesByRef = {for (final n in nodes) n.ref: n};

  /// Get a node by its ref (e.g., 'w5')
  CombinedNode? operator [](String ref) => _nodesByRef[ref];

  /// Get only nodes that have semantics attached
  List<CombinedNode> get withSemantics =>
      nodes.where((n) => n.semantics != null).toList();

  /// Get root nodes (nodes with no parent)
  List<CombinedNode> get roots => nodes.where((n) => n.depth == 0).toList();

  /// Get a collapsed view of the tree
  ///
  /// Collapses chains of single-child nodes with same bounds.
  /// Semantics widgets are never collapsed (they need their own ref).
  /// Zero-area nodes (SizedBox, spacers) are hidden.
  List<CollapsedNode> get collapsed {
    final result = <CollapsedNode>[];
    final visited = <String>{};

    void processNode(CombinedNode node, int displayDepth) {
      if (visited.contains(node.ref)) return;

      // Skip zero-area spacers
      if (_isHiddenSpacer(node)) {
        visited.add(node.ref);
        return;
      }

      // Start a chain with this node
      final chain = <({String ref, String widget})>[];
      var current = node;
      SemanticsInfo? aggregatedSemantics;
      String? aggregatedText;
      final aggregatedFlags = <String>{};

      while (true) {
        visited.add(current.ref);
        chain.add((ref: current.ref, widget: current.widget));

        // Aggregate semantics
        if (current.semantics != null) {
          aggregatedSemantics ??= current.semantics;
          aggregatedFlags.addAll(current.semantics!.flags);
        }

        // Aggregate text content
        if (current.textContent != null && current.textContent!.isNotEmpty) {
          aggregatedText ??= current.textContent;
        }

        // Stop conditions:
        // 1. No children
        // 2. Multiple children
        // 3. Child has different bounds
        // 4. Current is a Semantics widget (keep it separate)
        // 5. Child is a Semantics widget (don't collapse into it)
        if (current.children.isEmpty) break;
        if (current.children.length > 1) break;
        if (current.widget == 'Semantics') break;

        final childRef = current.children.first;
        final child = _nodesByRef[childRef];
        if (child == null) break;

        // Skip hidden spacers in children
        if (_isHiddenSpacer(child)) {
          visited.add(child.ref);
          // Continue to next sibling if any... but we only have one child here
          break;
        }

        // Don't collapse into Semantics widgets
        if (child.widget == 'Semantics') break;

        // Always collapse layout wrappers (regardless of bounds)
        if (CollapsedNode._layoutWrappers.contains(current.widget)) {
          current = child;
          continue;
        }

        // Check bounds - collapse if same bounds
        if (current.bounds != null &&
            child.bounds != null &&
            current.bounds!.sameBoundsAs(child.bounds!)) {
          current = child;
          continue;
        }

        // Different bounds, stop collapsing
        break;
      }

      // Create collapsed node
      result.add(CollapsedNode(
        chain: chain,
        depth: displayDepth,
        bounds: current.bounds,
        children: current.children,
        semantics: aggregatedSemantics,
        textContent: aggregatedText,
        flags: aggregatedFlags,
      ));

      // Process children
      for (final childRef in current.children) {
        final child = _nodesByRef[childRef];
        if (child != null && !visited.contains(childRef)) {
          processNode(child, displayDepth + 1);
        }
      }
    }

    // Start from roots
    for (final root in roots) {
      processNode(root, 0);
    }

    return result;
  }

  /// Check if a node should be hidden (zero-area spacer)
  bool _isHiddenSpacer(CombinedNode node) {
    // Hide SizedBox and Spacer with zero area
    if (node.widget == 'SizedBox' || node.widget == 'Spacer') {
      if (node.bounds == null) return true;
      if (node.bounds!.isZeroArea) return true;
      // Also hide very small spacers (< 2px in either dimension)
      if (node.bounds!.width < 2 || node.bounds!.height < 2) return true;
    }
    return false;
  }

  /// Convert to JSON for LLM consumption
  Map<String, dynamic> toJson() => {
        'success': success,
        if (error != null) 'error': error,
        'timestamp': timestamp.toIso8601String(),
        'nodeCount': nodes.length,
        'nodesWithSemantics': withSemantics.length,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

  /// Pretty print with tree structure
  @override
  String toString() {
    if (!success) return 'CombinedSnapshot failed: $error';

    final buffer = StringBuffer();
    buffer.writeln('📱 Flutter Mate Combined Snapshot');
    buffer.writeln('━' * 50);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('Total nodes: ${nodes.length}');
    buffer.writeln('With semantics: ${withSemantics.length}');
    buffer.writeln('');

    // Build tree structure for display
    for (final node in nodes) {
      final indent = '  ' * node.depth;
      final hasSemantics = node.semantics != null;
      final semanticsMarker = hasSemantics ? ' [s${node.semantics!.id}]' : '';
      final sem = node.semantics;

      final parts = <String>[];
      if (sem?.label != null) {
        parts.add('"${sem!.label}"');
      }
      if (sem?.value != null && sem!.value!.isNotEmpty) {
        parts.add('= "${sem.value}"');
      }
      // Validation indicator
      if (sem?.validationResult == 'invalid') {
        parts.add('⚠️');
      } else if (sem?.validationResult == 'valid') {
        parts.add('✓');
      }
      // Tooltip
      if (sem?.tooltip != null && sem!.tooltip!.isNotEmpty) {
        parts.add('💬"${sem.tooltip}"');
      }
      // Heading level
      if (sem?.headingLevel != null && sem!.headingLevel! > 0) {
        parts.add('H${sem.headingLevel}');
      }
      // Link
      if (sem?.linkUrl != null && sem!.linkUrl!.isNotEmpty) {
        parts.add('🔗');
      }
      // Input type or role
      if (sem?.inputType != null && sem!.inputType != 'none' && sem.inputType != 'text') {
        parts.add('<${sem.inputType}>');
      } else if (sem?.role != null && sem!.role != 'none') {
        parts.add('<${sem.role}>');
      }
      // Actions
      if (sem?.actions.isNotEmpty == true) {
        parts.add('[${sem!.actions.join(', ')}]');
      }

      final info = parts.isNotEmpty ? ' ${parts.join(' ')}' : '';
      buffer.writeln('$indent${node.ref}: ${node.widget}$semanticsMarker$info');
    }

    buffer.writeln('');
    buffer.writeln('💡 Use refs: FlutterMate.tap("w5")');
    buffer.writeln('   Nodes with [sN] have semantics support');
    return buffer.toString();
  }
}

/// A node in the combined widget tree
///
/// Contains widget information from the Element tree and optionally
/// semantics information if the widget has accessibility annotations.
class CombinedNode {
  /// Unique reference for this node (e.g., 'w0', 'w1')
  final String ref;

  /// Widget type name (e.g., 'TextField', 'ElevatedButton')
  final String widget;

  /// Depth in the tree (0 = root)
  final int depth;

  /// Bounding box on screen
  final CombinedRect? bounds;

  /// Child node refs
  final List<String> children;

  /// Semantics information (null if widget has no semantics)
  final SemanticsInfo? semantics;

  /// Text content for informative widgets (Text, Icon, tooltip labels, etc.)
  /// Extracted from the widget's description or actual content.
  final String? textContent;

  CombinedNode({
    required this.ref,
    required this.widget,
    required this.depth,
    this.bounds,
    required this.children,
    this.semantics,
    this.textContent,
  });

  /// Whether this node has semantics attached
  bool get hasSemantics => semantics != null;

  /// Whether this node can be interacted with
  bool get isInteractive => semantics?.actions.isNotEmpty == true;

  /// Get center point for gesture interactions
  Offset? get center => bounds?.center;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'widget': widget,
        'depth': depth,
        if (bounds != null) 'bounds': bounds!.toJson(),
        'children': children,
        if (semantics != null) 'semantics': semantics!.toJson(),
        if (textContent != null) 'textContent': textContent,
      };
}

/// Semantics information extracted from a SemanticsNode
/// Includes all fields from Flutter's SemanticsData class.
class SemanticsInfo {
  /// Semantics node ID
  final int id;

  /// Unique identifier for this semantics node
  final String? identifier;

  /// Accessibility label (e.g., 'Email', 'Submit button')
  final String? label;

  /// Current value (e.g., text field contents, slider position)
  final String? value;

  /// Accessibility hint (e.g., 'Double tap to activate')
  final String? hint;

  /// Tooltip text
  final String? tooltip;

  /// For sliders: the value after increasing
  final String? increasedValue;

  /// For sliders: the value after decreasing
  final String? decreasedValue;

  /// Semantic flags (e.g., 'isButton', 'isTextField', 'isFocusable')
  final Set<String> flags;

  /// Available actions (e.g., 'tap', 'focus', 'setText')
  final Set<String> actions;

  /// Text direction (ltr, rtl)
  final String? textDirection;

  // ── Text selection ──

  /// Start of text selection
  final int? textSelectionBase;

  /// End of text selection
  final int? textSelectionExtent;

  // ── Value length (for text fields) ──

  /// Maximum allowed value length
  final int? maxValueLength;

  /// Current value length
  final int? currentValueLength;

  // ── Scroll properties ──

  /// Total number of scrollable children (null if unknown/unbounded)
  final int? scrollChildCount;

  /// Index of first visible semantic child
  final int? scrollIndex;

  /// Current scroll position in logical pixels
  final double? scrollPosition;

  /// Maximum scroll extent (may be infinity if unbounded)
  final double? scrollExtentMax;

  /// Minimum scroll extent (usually 0)
  final double? scrollExtentMin;

  // ── Additional properties ──

  /// Heading level (1-6, 0 if not a heading)
  final int? headingLevel;

  /// Link URL if this is a link
  final String? linkUrl;

  /// Semantic role (e.g., 'button', 'textField', 'slider')
  final String? role;

  /// Input type for text fields (e.g., 'text', 'number', 'email')
  final String? inputType;

  /// Validation result for form fields (none, valid, invalid)
  final String? validationResult;

  /// Platform view ID if this is a platform view
  final int? platformViewId;

  /// IDs of nodes this node controls
  final Set<String>? controlsNodes;

  SemanticsInfo({
    required this.id,
    this.identifier,
    this.label,
    this.value,
    this.hint,
    this.tooltip,
    this.increasedValue,
    this.decreasedValue,
    required this.flags,
    required this.actions,
    this.textDirection,
    this.textSelectionBase,
    this.textSelectionExtent,
    this.maxValueLength,
    this.currentValueLength,
    this.scrollChildCount,
    this.scrollIndex,
    this.scrollPosition,
    this.scrollExtentMax,
    this.scrollExtentMin,
    this.headingLevel,
    this.linkUrl,
    this.role,
    this.inputType,
    this.validationResult,
    this.platformViewId,
    this.controlsNodes,
  });

  /// Check if this has a specific action
  bool hasAction(String action) => actions.contains(action);

  /// Check if this has a specific flag
  bool hasFlag(String flag) => flags.contains(flag);

  /// Check if this element is scrollable
  bool get isScrollable =>
      actions.contains('scrollUp') ||
      actions.contains('scrollDown') ||
      actions.contains('scrollLeft') ||
      actions.contains('scrollRight');

  /// Check if this is a form field with validation error
  bool get hasValidationError => validationResult == 'invalid';

  /// Check if this is a form field that passed validation
  bool get isValid => validationResult == 'valid';

  Map<String, dynamic> toJson() => {
        'id': id,
        if (identifier != null) 'identifier': identifier,
        if (label != null) 'label': label,
        if (value != null && value!.isNotEmpty) 'value': value,
        if (hint != null) 'hint': hint,
        if (tooltip != null) 'tooltip': tooltip,
        if (increasedValue != null) 'increasedValue': increasedValue,
        if (decreasedValue != null) 'decreasedValue': decreasedValue,
        'flags': flags.toList(),
        'actions': actions.toList(),
        if (textDirection != null) 'textDirection': textDirection,
        if (textSelectionBase != null) 'textSelectionBase': textSelectionBase,
        if (textSelectionExtent != null)
          'textSelectionExtent': textSelectionExtent,
        if (maxValueLength != null) 'maxValueLength': maxValueLength,
        if (currentValueLength != null)
          'currentValueLength': currentValueLength,
        if (scrollChildCount != null) 'scrollChildCount': scrollChildCount,
        if (scrollIndex != null) 'scrollIndex': scrollIndex,
        if (scrollPosition != null) 'scrollPosition': scrollPosition,
        if (scrollExtentMax != null && scrollExtentMax!.isFinite)
          'scrollExtentMax': scrollExtentMax,
        if (scrollExtentMin != null) 'scrollExtentMin': scrollExtentMin,
        if (headingLevel != null && headingLevel! > 0)
          'headingLevel': headingLevel,
        if (linkUrl != null) 'linkUrl': linkUrl,
        if (role != null && role != 'none') 'role': role,
        if (inputType != null && inputType != 'none') 'inputType': inputType,
        if (validationResult != null && validationResult != 'none')
          'validationResult': validationResult,
        if (platformViewId != null) 'platformViewId': platformViewId,
        if (controlsNodes != null && controlsNodes!.isNotEmpty)
          'controlsNodes': controlsNodes!.toList(),
      };
}

/// Simple rect class for node bounds
class CombinedRect {
  final double x;
  final double y;
  final double width;
  final double height;

  CombinedRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Center point of the rect
  Offset get center => Offset(
        x + width / 2,
        y + height / 2,
      );

  /// Check if this rect has the same bounds as another (within tolerance)
  bool sameBoundsAs(CombinedRect other, {double tolerance = 1.0}) {
    return (x - other.x).abs() <= tolerance &&
        (y - other.y).abs() <= tolerance &&
        (width - other.width).abs() <= tolerance &&
        (height - other.height).abs() <= tolerance;
  }

  /// Check if this is a zero-area rect (spacer/divider)
  bool get isZeroArea => width <= 0 || height <= 0;

  Map<String, double> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

/// A collapsed node representing a chain of widgets with same bounds
class CollapsedNode {
  /// Layout wrapper widgets to hide from display (purely structural)
  static const _layoutWrappers = {
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

  /// Chain of (ref, widget) pairs that were collapsed
  final List<({String ref, String widget})> chain;

  /// The effective depth for display
  final int depth;

  /// Bounds (same for all nodes in chain)
  final CombinedRect? bounds;

  /// Children refs (from the last node in chain)
  final List<String> children;

  /// Aggregated semantics from all nodes in chain
  final SemanticsInfo? semantics;

  /// Aggregated text content from all nodes in chain
  final String? textContent;

  /// Aggregated semantic flags from all nodes
  final Set<String> flags;

  CollapsedNode({
    required this.chain,
    required this.depth,
    this.bounds,
    required this.children,
    this.semantics,
    this.textContent,
    this.flags = const {},
  });

  /// First ref in the chain (for interactions)
  String get primaryRef => chain.first.ref;

  /// Format as "[w0] Widget1 → [w1] Widget2 → ..."
  /// Filters out layout wrapper widgets for cleaner display.
  String get chainString {
    // Filter out layout wrappers, but keep at least one widget
    final meaningful =
        chain.where((e) => !_layoutWrappers.contains(e.widget)).toList();
    final display = meaningful.isNotEmpty ? meaningful : [chain.first];
    return display.map((e) => '[${e.ref}] ${e.widget}').join(' → ');
  }

  /// Whether this node has semantics
  bool get hasSemantics => semantics != null;

  /// Whether this is a Semantics widget (should not be collapsed into)
  bool get isSemanticsWidget => chain.any((e) => e.widget == 'Semantics');
}
