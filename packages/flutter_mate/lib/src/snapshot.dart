import 'dart:ui' show Offset;

/// A snapshot of the current UI state
///
/// Contains all semantics nodes from the UI tree, each with a unique
/// ref (like 'w5') that can be used to interact with the element.
///
/// ```dart
/// final snapshot = await FlutterMate.snapshot();
///
/// // Access by ref
/// final node = snapshot['w5'];
///
/// // Get only interactive elements
/// final buttons = snapshot.interactive;
///
/// // Convert to JSON (for LLMs)
/// final json = snapshot.toJson();
///
/// // Pretty print
/// print(snapshot);
/// ```
class Snapshot {
  final bool success;
  final String? error;
  final DateTime timestamp;
  final List<SnapshotNode> nodes;
  final Map<String, SnapshotNode> refs;

  Snapshot({
    required this.success,
    this.error,
    required this.timestamp,
    required this.nodes,
    required this.refs,
  });

  /// Get a node by its ref (e.g., 'w5' or '@w5')
  SnapshotNode? operator [](String ref) {
    final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;
    return refs[cleanRef];
  }

  /// Get only interactive nodes
  List<SnapshotNode> get interactive =>
      nodes.where((n) => n.isInteractive).toList();

  /// Convert to JSON for LLM consumption
  Map<String, dynamic> toJson() => {
        'success': success,
        'error': error,
        'timestamp': timestamp.toIso8601String(),
        'nodeCount': nodes.length,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };

  /// Pretty print for human consumption
  @override
  String toString() {
    if (!success) return 'Snapshot failed: $error';

    final buffer = StringBuffer();
    buffer.writeln('📱 Flutter Mate Snapshot');
    buffer.writeln('━' * 50);
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('Total nodes: ${nodes.length}');
    buffer.writeln('');

    for (final node in nodes.where((n) => n.isInteractive || n.label != null)) {
      final indent = '  ' * node.depth;
      final icon = node.typeIcon;
      final actionsStr =
          node.actions.isNotEmpty ? ' [${node.actions.join(', ')}]' : '';
      final flagsStr = node.flags
          .where((f) => f.startsWith('is'))
          .map((f) => f.substring(2))
          .join(', ');

      buffer.writeln(
          '$indent$icon ${node.ref}: "${node.label ?? node.value ?? '(no label)'}"$actionsStr${flagsStr.isNotEmpty ? ' ($flagsStr)' : ''}');
    }

    buffer.writeln('');
    buffer.writeln('💡 Use refs to interact: FlutterMate.tap("w5")');
    return buffer.toString();
  }
}

/// A single element in the UI tree
///
/// Each node has:
/// - [ref] — Unique identifier (e.g., 'w5') for interacting with this element
/// - [label] — Accessibility label (e.g., 'Email', 'Submit')
/// - [value] — Current value (e.g., text field contents)
/// - [actions] — Available actions ('tap', 'focus', 'setText', etc.)
/// - [flags] — Element type flags ('isButton', 'isTextField', etc.)
/// - [rect] — Position and size on screen
class SnapshotNode {
  final String ref;
  final int id;
  final int depth;
  final String? label;
  final String? value;
  final String? hint;
  final List<String> actions;
  final List<String> flags;
  final Rect rect;
  final bool isInteractive;

  SnapshotNode({
    required this.ref,
    required this.id,
    required this.depth,
    this.label,
    this.value,
    this.hint,
    required this.actions,
    required this.flags,
    required this.rect,
    required this.isInteractive,
  });

  /// Check if this node supports a specific action
  bool hasAction(String action) => actions.contains(action);

  /// Check if this node has a specific flag
  bool hasFlag(String flag) => flags.contains(flag);

  /// Get an icon representing the node type
  String get typeIcon {
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

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'id': id,
        'depth': depth,
        if (label != null) 'label': label,
        if (value != null) 'value': value,
        if (hint != null) 'hint': hint,
        'actions': actions,
        'flags': flags,
        'rect': rect.toJson(),
        'isInteractive': isInteractive,
      };
}

/// Simple rect class for node bounds
class Rect {
  final int x;
  final int y;
  final int width;
  final int height;

  Rect({
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

  Map<String, int> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
