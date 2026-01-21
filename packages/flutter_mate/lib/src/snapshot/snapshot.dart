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

      // Track used semantics node IDs to avoid duplication
      final usedSemanticsIds = <int>{};

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

              // Extract text content from the widget itself
              textContent = _extractWidgetContent(obj.widget);

              // If no direct text, collect ALL text from element subtree.
              // Since _extractWidgetContent only returns text from Text/RichText,
              // we won't capture noise like widget type names.
              if (textContent == null) {
                final allTexts = _collectAllTextInSubtree(obj);
                if (allTexts.isNotEmpty) {
                  textContent = allTexts.join(' | ');
                }
              }
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

                // Try to find semantics for ANY widget (not just Semantics widgets)
                // This allows TextField, Button, etc. to show their semantics
                if (ro != null) {
                  SemanticsNode? sn = _findSemanticsInRenderTree(ro!);
                  if (sn != null && !usedSemanticsIds.contains(sn.id)) {
                    // Mark this semantics ID as used to avoid duplication
                    usedSemanticsIds.add(sn.id);
                    semantics = _extractSemanticsInfo(sn);
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

  /// Extract content from widget using toString()
  /// Only extracts quoted strings - actual text content, not debug properties.
  static String? _extractWidgetContent(Widget widget) {
    try {
      final str = widget.toString();
      final typeName = widget.runtimeType.toString();

      // Only extract from actual text display widgets
      // This prevents extracting widget names like "EditableText" or "Semantics"
      if (!typeName.contains('Text') && !typeName.contains('RichText')) {
        return null;
      }

      // Extract content in quotes: Text("Hello") → "Hello"
      final quoteMatch = RegExp(r'"([^"]*)"').firstMatch(str);
      if (quoteMatch != null) {
        final content = quoteMatch.group(1)?.trim();
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    } catch (_) {
      // toString can fail for some widgets
    }
    return null;
  }

  /// Find the best semantics node in the render tree
  /// Traverses down to find a node with actions or meaningful content
  static SemanticsNode? _findSemanticsInRenderTree(RenderObject ro) {
    // First check if this render object has direct semantics
    SemanticsNode? best = ro.debugSemantics;

    // If no direct semantics or it has no actions/value, traverse down
    if (best == null || !_hasMeaningfulSemantics(best)) {
      void visitRenderObject(RenderObject child) {
        final sn = child.debugSemantics;
        if (sn != null && _hasMeaningfulSemantics(sn)) {
          best = sn;
          return; // Found one, stop
        }
        // Continue traversing if no semantics found
        child.visitChildren(visitRenderObject);
      }

      ro.visitChildren(visitRenderObject);
    }

    return best;
  }

  /// Check if a semantics node has meaningful content (actions, label, or value)
  static bool _hasMeaningfulSemantics(SemanticsNode node) {
    final data = node.getSemanticsData();
    return data.actions != 0 || data.label.isNotEmpty || data.value.isNotEmpty;
  }

  /// Collect ALL text content from an element subtree
  /// Returns all text found, not just the first
  static List<String> _collectAllTextInSubtree(Element element) {
    final texts = <String>[];
    final seen = <String>{}; // Avoid duplicates

    void visit(Element child) {
      // Try to extract text from this widget
      final content = _extractWidgetContent(child.widget);
      if (content != null && content.isNotEmpty && !seen.contains(content)) {
        seen.add(content);
        texts.add(content);
      }

      // Continue to ALL children (don't stop on first find)
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    return texts;
  }

  /// Extract semantics info from a SemanticsNode
  /// Includes all fields from SemanticsData for completeness.
  static SemanticsInfo _extractSemanticsInfo(SemanticsNode node) {
    final data = node.getSemanticsData();

    // Extract text selection if present
    int? textSelectionBase;
    int? textSelectionExtent;
    if (data.textSelection != null) {
      textSelectionBase = data.textSelection!.baseOffset;
      textSelectionExtent = data.textSelection!.extentOffset;
    }

    return SemanticsInfo(
      id: node.id,
      identifier: data.identifier.isNotEmpty ? data.identifier : null,
      label: data.label.isNotEmpty ? data.label : null,
      value: data.value.isNotEmpty ? data.value : null,
      hint: data.hint.isNotEmpty ? data.hint : null,
      tooltip: data.tooltip.isNotEmpty ? data.tooltip : null,
      increasedValue:
          data.increasedValue.isNotEmpty ? data.increasedValue : null,
      decreasedValue:
          data.decreasedValue.isNotEmpty ? data.decreasedValue : null,
      flags: getFlagsFromData(data).toSet(),
      actions: getActionsFromData(data).toSet(),
      // Text direction
      textDirection: data.textDirection?.name,
      // Text selection
      textSelectionBase: textSelectionBase,
      textSelectionExtent: textSelectionExtent,
      // Value length (for text fields)
      maxValueLength: data.maxValueLength,
      currentValueLength: data.currentValueLength,
      // Scroll properties
      scrollChildCount: data.scrollChildCount,
      scrollIndex: data.scrollIndex,
      scrollPosition: data.scrollPosition,
      scrollExtentMax: data.scrollExtentMax,
      scrollExtentMin: data.scrollExtentMin,
      // Additional properties
      headingLevel: data.headingLevel > 0 ? data.headingLevel : null,
      linkUrl: data.linkUrl?.toString(),
      role: data.role.name != 'none' ? data.role.name : null,
      inputType: data.inputType.name != 'none' ? data.inputType.name : null,
      validationResult: data.validationResult.name != 'none'
          ? data.validationResult.name
          : null,
      platformViewId: data.platformViewId != -1 ? data.platformViewId : null,
      controlsNodes: data.controlsNodes,
    );
  }
}
