// Re-export shared types from flutter_mate_types
export 'package:flutter_mate_types/flutter_mate_types.dart';

import 'package:flutter_mate_types/flutter_mate_types.dart';

/// Extension on CombinedSnapshot for Flutter-specific functionality
extension CombinedSnapshotExtension on CombinedSnapshot {
  /// Get a collapsed view of the tree
  ///
  /// Collapses chains of single-child nodes with same bounds.
  /// Semantics widgets are never collapsed (they need their own ref).
  /// Zero-area nodes (SizedBox, spacers) are hidden.
  List<CollapsedNode> get collapsed {
    final result = <CollapsedNode>[];
    final visited = <String>{};
    final nodesByRef = {for (final n in nodes) n.ref: n};

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

        // Stop conditions
        if (current.children.isEmpty) break;
        if (current.children.length > 1) break;
        if (current.widget == 'Semantics') break;

        final childRef = current.children.first;
        final child = nodesByRef[childRef];
        if (child == null) break;

        // Skip hidden spacers in children
        if (_isHiddenSpacer(child)) {
          visited.add(child.ref);
          break;
        }

        // Don't collapse into Semantics widgets
        if (child.widget == 'Semantics') break;

        // Always collapse layout wrappers (regardless of bounds)
        if (CollapsedNode.layoutWrappers.contains(current.widget)) {
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
        final child = nodesByRef[childRef];
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
    if (node.widget == 'SizedBox' || node.widget == 'Spacer') {
      if (node.bounds == null) return true;
      if (node.bounds!.isZeroArea) return true;
      if (node.bounds!.width < 2 || node.bounds!.height < 2) return true;
    }
    return false;
  }
}

/// A collapsed node representing a chain of widgets with same bounds
class CollapsedNode {
  /// Layout wrapper widgets to hide from display (purely structural)
  static const layoutWrappers = {
    'Padding',
    'SizedBox',
    'ConstrainedBox',
    'LimitedBox',
    'OverflowBox',
    'FractionallySizedBox',
    'IntrinsicHeight',
    'IntrinsicWidth',
    'Center',
    'Align',
    'Expanded',
    'Flexible',
    'Positioned',
    'Spacer',
    'Container',
    'DecoratedBox',
    'ColoredBox',
    'Transform',
    'RotatedBox',
    'FittedBox',
    'AspectRatio',
    'ClipRect',
    'ClipRRect',
    'ClipOval',
    'ClipPath',
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
  String get chainString {
    final meaningful =
        chain.where((e) => !layoutWrappers.contains(e.widget)).toList();
    final display = meaningful.isNotEmpty ? meaningful : [chain.first];
    return display.map((e) => '[${e.ref}] ${e.widget}').join(' → ');
  }

  /// Whether this node has semantics
  bool get hasSemantics => semantics != null;

  /// Whether this is a Semantics widget
  bool get isSemanticsWidget => chain.any((e) => e.widget == 'Semantics');
}
