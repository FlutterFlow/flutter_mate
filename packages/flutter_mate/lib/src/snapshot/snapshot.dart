import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/flutter_mate.dart';
import '../core/semantics_utils.dart';
import 'combined_snapshot.dart';

/// Service for capturing UI snapshots
///
/// Uses Flutter's WidgetInspectorService for the summary tree (same as DevTools)
/// then attaches semantics info for AI/automation interactions.
class SnapshotService {
  /// Get a snapshot of the current UI
  ///
  /// Returns a [CombinedSnapshot] containing the widget tree with semantics.
  /// Each node has a ref (w0, w1, w2...) that can be used for interactions.
  ///
  /// Uses Flutter's WidgetInspectorService to get the same tree that DevTools
  /// shows - only user-created widgets, not framework internals.
  ///
  /// ```dart
  /// final snapshot = await SnapshotService.snapshot();
  /// print(snapshot);
  /// ```
  static Future<CombinedSnapshot> snapshot() async {
    FlutterMate.ensureInitialized();

    // Wait for first frame if needed
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      await FlutterMate.waitForFirstFrame();
    }

    if (WidgetsBinding.instance.rootElement == null) {
      return CombinedSnapshot(
        success: false,
        error: 'No root element found. Is the UI rendered?',
        timestamp: DateTime.now(),
        nodes: [],
      );
    }

    try {
      // Use Flutter's WidgetInspectorService to get the summary tree
      // This is the same tree that DevTools shows - only user widgets
      final service = WidgetInspectorService.instance;
      const groupName = 'flutter_mate_snapshot';

      final jsonStr = service.getRootWidgetSummaryTree(groupName);

      final treeJson = jsonDecode(jsonStr) as Map<String, dynamic>?;
      if (treeJson == null) {
        return CombinedSnapshot(
          success: false,
          error: 'Failed to get widget tree from inspector',
          timestamp: DateTime.now(),
          nodes: [],
        );
      }

      // Clear cached elements for fresh snapshot
      FlutterMate.cachedElements.clear();

      // Parse the inspector tree and attach semantics using toObject
      final nodes = <CombinedNode>[];
      int refCounter = 0;

      void walkInspectorNode(Map<String, dynamic> node, int depth) {
        final description = node['description'] as String? ?? '';
        final widgetType = _extractWidgetType(description);
        final valueId = node['valueId'] as String?;
        final childrenJson = node['children'] as List<dynamic>? ?? [];

        final ref = 'w${refCounter++}';

        CombinedRect? bounds;
        SemanticsInfo? semantics;
        String? textContent;

        // Use toObject to get the actual Element from valueId
        if (valueId != null) {
          try {
            // ignore: invalid_use_of_protected_member
            final obj = service.toObject(valueId, groupName);
            if (obj is Element) {
              // Cache the Element for ref lookup (used by typeText, etc.)
              FlutterMate.cachedElements[ref] = obj;

              // Extract text content from widget
              textContent = _extractWidgetContent(obj.widget);
              // Find the RenderObject
              RenderObject? ro;
              if (obj is RenderObjectElement) {
                ro = obj.renderObject;
              } else {
                // Walk down to find first RenderObjectElement
                void findRenderObject(Element el) {
                  if (ro != null) return;
                  if (el is RenderObjectElement) {
                    ro = el.renderObject;
                    return;
                  }
                  el.visitChildren(findRenderObject);
                }

                findRenderObject(obj);
              }

              if (ro != null) {
                // Get bounds if it's a RenderBox
                if (ro is RenderBox) {
                  final box = ro as RenderBox;
                  if (box.hasSize) {
                    try {
                      final topLeft = box.localToGlobal(Offset.zero);
                      bounds = CombinedRect(
                        x: topLeft.dx,
                        y: topLeft.dy,
                        width: box.size.width,
                        height: box.size.height,
                      );
                    } catch (_) {
                      // localToGlobal can fail if not attached
                    }
                  }
                }

                // Only attach semantics to Semantics widgets
                // Other widgets just get bounds - actions figure out semantics at runtime
                if (widgetType == 'Semantics') {
                  SemanticsNode? sn = ro!.debugSemantics;
                  if (sn != null) {
                    // For Semantics widget, find the child semantics with actions
                    // The Semantics widget annotates its child, so walk down to find actionable node
                    SemanticsNode nodeWithActions = sn;

                    void findActionableNode(SemanticsNode node) {
                      final data = node.getSemanticsData();
                      if (data.actions != 0) {
                        nodeWithActions = node;
                        return;
                      }
                      node.visitChildren((child) {
                        findActionableNode(child);
                        return true;
                      });
                    }

                    if (sn.getSemanticsData().actions == 0) {
                      findActionableNode(sn);
                    }

                    semantics = _extractSemanticsInfo(nodeWithActions);
                  }
                }
              }
            }
          } catch (e) {
            // toObject can fail for some elements, continue without semantics
            debugPrint('FlutterMate: toObject failed for $valueId: $e');
          }
        }

        // Collect children refs
        final childRefs = <String>[];
        final childStartRef = refCounter;

        for (final childJson in childrenJson) {
          if (childJson is Map<String, dynamic>) {
            final beforeCount = refCounter;
            walkInspectorNode(childJson, depth + 1);
            if (refCounter > beforeCount) {
              childRefs.add('w$beforeCount');
            }
          }
        }

        // Insert this node at the correct position (before its children)
        final nodeIndex = nodes.length - (refCounter - childStartRef);
        nodes.insert(
          nodeIndex < 0 ? 0 : nodeIndex,
          CombinedNode(
            ref: ref,
            widget: widgetType,
            depth: depth,
            bounds: bounds,
            children: childRefs,
            semantics: semantics,
            textContent: textContent,
          ),
        );
      }

      walkInspectorNode(treeJson, 0);

      // Reorder nodes to be in depth-first order (parents before children)
      nodes.sort((a, b) {
        final refA = int.parse(a.ref.substring(1));
        final refB = int.parse(b.ref.substring(1));
        return refA.compareTo(refB);
      });

      final snapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: nodes,
      );

      // Cache for ref -> semantics ID translation in actions
      FlutterMate.lastSnapshot = snapshot;

      return snapshot;
    } catch (e, stack) {
      debugPrint('FlutterMate: snapshot error: $e\n$stack');
      return CombinedSnapshot(
        success: false,
        error: 'Failed to get snapshot: $e',
        timestamp: DateTime.now(),
        nodes: [],
      );
    }
  }

  /// Extract widget type from inspector description
  static String _extractWidgetType(String description) {
    // Description can be like "Text" or "Padding(padding: EdgeInsets...)"
    final parenIndex = description.indexOf('(');
    if (parenIndex > 0) {
      return description.substring(0, parenIndex);
    }
    return description;
  }

  /// Extract content from widget using its diagnostic description
  /// This is a general solution that works for any widget type.
  static String? _extractWidgetContent(Widget widget) {
    try {
      // Use toStringShort() which includes key properties for most widgets
      // e.g., Text("Hello") returns 'Text("Hello")'
      // e.g., Icon(IconData(U+E88A)) returns 'Icon'
      final shortString = widget.toStringShort();

      // Extract content between quotes if present
      final quoteMatch = RegExp(r'"([^"]*)"').firstMatch(shortString);
      if (quoteMatch != null) {
        return quoteMatch.group(1);
      }

      // For widgets without quoted content, try toDiagnosticsNode
      final diagNode = widget.toDiagnosticsNode();
      final props = diagNode.getProperties();
      for (final prop in props) {
        // Look for 'data', 'label', 'text', 'title' properties
        final name = prop.name?.toLowerCase();
        if (name == 'data' ||
            name == 'label' ||
            name == 'text' ||
            name == 'title') {
          final value = prop.value;
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {
      // Diagnostics can fail for some widgets
    }
    return null;
  }

  /// Extract semantics info from a SemanticsNode
  static SemanticsInfo _extractSemanticsInfo(SemanticsNode node) {
    final data = node.getSemanticsData();

    return SemanticsInfo(
      id: node.id,
      label: data.label.isNotEmpty ? data.label : null,
      value: data.value.isNotEmpty ? data.value : null,
      hint: data.hint.isNotEmpty ? data.hint : null,
      increasedValue:
          data.increasedValue.isNotEmpty ? data.increasedValue : null,
      decreasedValue:
          data.decreasedValue.isNotEmpty ? data.decreasedValue : null,
      flags: getFlagsFromData(data).toSet(),
      actions: getActionsFromData(data).toSet(),
      // Scroll properties
      scrollChildCount: data.scrollChildCount,
      scrollIndex: data.scrollIndex,
      scrollPosition: data.scrollPosition,
      scrollExtentMax: data.scrollExtentMax,
      scrollExtentMin: data.scrollExtentMin,
    );
  }
}
