import 'dart:ui' show Offset;

/// A combined snapshot of the widget tree with semantics information
///
/// This provides both structural context (widget types, hierarchy) from the
/// Element tree and interaction capabilities (actions, labels, values) from
/// the Semantics tree.
///
/// ```dart
/// final snapshot = await FlutterMate.snapshotCombined();
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
  List<CombinedNode> get roots =>
      nodes.where((n) => n.depth == 0).toList();

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
      
      final parts = <String>[];
      if (node.semantics?.label != null) {
        parts.add('"${node.semantics!.label}"');
      }
      if (node.semantics?.value != null && node.semantics!.value!.isNotEmpty) {
        parts.add('= "${node.semantics!.value}"');
      }
      if (node.semantics?.actions.isNotEmpty == true) {
        parts.add('[${node.semantics!.actions.join(', ')}]');
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

  CombinedNode({
    required this.ref,
    required this.widget,
    required this.depth,
    this.bounds,
    required this.children,
    this.semantics,
  });

  /// Whether this node has semantics attached
  bool get hasSemantics => semantics != null;

  /// Whether this node can be interacted with
  bool get isInteractive =>
      semantics?.actions.isNotEmpty == true;

  /// Get center point for gesture interactions
  Offset? get center => bounds?.center;

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'widget': widget,
        'depth': depth,
        if (bounds != null) 'bounds': bounds!.toJson(),
        'children': children,
        if (semantics != null) 'semantics': semantics!.toJson(),
      };
}

/// Semantics information extracted from a SemanticsNode
class SemanticsInfo {
  /// Semantics node ID
  final int id;

  /// Accessibility label (e.g., 'Email', 'Submit button')
  final String? label;

  /// Current value (e.g., text field contents, slider position)
  final String? value;

  /// Accessibility hint (e.g., 'Double tap to activate')
  final String? hint;

  /// For sliders: the value after increasing
  final String? increasedValue;

  /// For sliders: the value after decreasing
  final String? decreasedValue;

  /// Semantic flags (e.g., 'isButton', 'isTextField', 'isFocusable')
  final Set<String> flags;

  /// Available actions (e.g., 'tap', 'focus', 'setText')
  final Set<String> actions;

  SemanticsInfo({
    required this.id,
    this.label,
    this.value,
    this.hint,
    this.increasedValue,
    this.decreasedValue,
    required this.flags,
    required this.actions,
  });

  /// Check if this has a specific action
  bool hasAction(String action) => actions.contains(action);

  /// Check if this has a specific flag
  bool hasFlag(String flag) => flags.contains(flag);

  Map<String, dynamic> toJson() => {
        'id': id,
        if (label != null) 'label': label,
        if (value != null && value!.isNotEmpty) 'value': value,
        if (hint != null) 'hint': hint,
        if (increasedValue != null) 'increasedValue': increasedValue,
        if (decreasedValue != null) 'decreasedValue': decreasedValue,
        'flags': flags.toList(),
        'actions': actions.toList(),
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

  Map<String, double> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
