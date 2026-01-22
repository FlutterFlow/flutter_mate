import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  /// If [compact] is true, filters to only nodes with meaningful info
  /// (text, semantics, actions, flags). This reduces output size significantly.
  ///
  /// ```dart
  /// final snapshot = await SnapshotService.snapshot();
  /// print(snapshot);
  ///
  /// // Compact mode - only nodes with info
  /// final compact = await SnapshotService.snapshot(compact: true);
  /// ```
  static Future<CombinedSnapshot> snapshot({bool compact = false}) async {
    FlutterMate.ensureInitialized();

    // Clear caches for fresh detection
    _offstageCache.clear();
    _onstageCache.clear();

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

      // Track claimed text for deduplication (children claim first)
      // Key: normalized text, Value: true (we only need to know if claimed)
      final claimedText = <String>{};

      // Normalize text for comparison
      String normalizeText(String s) {
        return s
            .toLowerCase()
            .replaceAll(RegExp(r'[\ufffc\ufffd]'), '')
            .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

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
        RenderObject? ro;

        // Use toObject to get the actual Element from valueId
        if (valueId != null) {
          try {
            // ignore: invalid_use_of_protected_member
            final obj = service.toObject(valueId, groupName);
            if (obj is Element) {
              // Check if this element is offstage (not being painted)
              // This catches widgets from previous routes, Offstage widgets, etc.
              if (_isElementOffstage(obj)) {
                // Skip offstage elements entirely (don't process children either)
                return;
              }

              // Cache the Element for ref lookup
              FlutterMate.cachedElements[ref] = obj;

              // Extract text content from the widget itself
              try {
                textContent = _extractWidgetContent(obj.widget);

                // If no direct text, collect ALL text from element subtree
                if (textContent == null) {
                  final allTexts = _collectAllTextInSubtree(obj);
                  if (allTexts.isNotEmpty) {
                    textContent = allTexts.join(' | ');
                  }
                }
              } catch (_) {
                // Text extraction can fail during navigation transitions
              }

              // Find the RenderObject
              if (obj is RenderObjectElement) {
                ro = obj.renderObject;
              } else {
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

              if (ro != null && ro is RenderBox) {
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
                  } catch (_) {}
                }
              }
            }
          } catch (e) {
            debugPrint('FlutterMate: toObject failed for $valueId: $e');
          }
        }

        // Process children FIRST - they claim their text and semantics
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

        // NOW deduplicate text - children have already claimed theirs
        // Filter out text that was already claimed by children
        if (textContent != null && textContent.isNotEmpty) {
          final texts = textContent.split(' | ');
          final newTexts = <String>[];
          for (final t in texts) {
            final key = normalizeText(t);
            if (key.isNotEmpty && !claimedText.contains(key)) {
              claimedText.add(key); // Claim this text
              newTexts.add(t);
            }
          }
          textContent = newTexts.isEmpty ? null : newTexts.join(' | ');
        }

        // NOW extract semantics - children have already claimed theirs
        if (ro != null) {
          final sn = _findSemanticsInRenderTree(ro!);
          if (sn != null && !usedSemanticsIds.contains(sn.id)) {
            usedSemanticsIds.add(sn.id);
            var sem = _extractSemanticsInfo(sn);

            // Also deduplicate semantics.label against claimed text
            if (sem.label != null) {
              final labelKey = normalizeText(sem.label!);
              if (labelKey.isNotEmpty && claimedText.contains(labelKey)) {
                // Label was claimed by a child - clear it
                sem = SemanticsInfo(
                  id: sem.id,
                  identifier: sem.identifier,
                  label: null,
                  value: sem.value,
                  hint: sem.hint,
                  tooltip: sem.tooltip,
                  increasedValue: sem.increasedValue,
                  decreasedValue: sem.decreasedValue,
                  textDirection: sem.textDirection,
                  textSelectionBase: sem.textSelectionBase,
                  textSelectionExtent: sem.textSelectionExtent,
                  maxValueLength: sem.maxValueLength,
                  currentValueLength: sem.currentValueLength,
                  headingLevel: sem.headingLevel,
                  linkUrl: sem.linkUrl,
                  role: sem.role,
                  inputType: sem.inputType,
                  validationResult: sem.validationResult,
                  platformViewId: sem.platformViewId,
                  controlsNodes: sem.controlsNodes,
                  flags: sem.flags,
                  actions: sem.actions,
                  scrollChildCount: sem.scrollChildCount,
                  scrollIndex: sem.scrollIndex,
                  scrollPosition: sem.scrollPosition,
                  scrollExtentMax: sem.scrollExtentMax,
                  scrollExtentMin: sem.scrollExtentMin,
                );
              } else if (labelKey.isNotEmpty) {
                claimedText.add(labelKey); // Claim this label
              }
            }
            semantics = sem;
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

      // Filter nodes in compact mode (keep meaningful nodes + their ancestors)
      List<CombinedNode> filteredNodes;
      if (compact) {
        // Find all meaningful nodes
        final meaningfulRefs = <String>{};
        for (final node in nodes) {
          if (node.hasAdditionalInfo) {
            meaningfulRefs.add(node.ref);
          }
        }

        // Build parent map (child -> parent)
        final parentMap = <String, String>{};
        for (final node in nodes) {
          for (final childRef in node.children) {
            parentMap[childRef] = node.ref;
          }
        }

        // For each meaningful node, add all ancestors to keep set
        final keepRefs = <String>{...meaningfulRefs};
        for (final ref in meaningfulRefs) {
          var current = ref;
          while (parentMap.containsKey(current)) {
            final parent = parentMap[current]!;
            keepRefs.add(parent);
            current = parent;
          }
        }

        // Filter but keep ancestors (preserves tree structure)
        filteredNodes = nodes.where((n) => keepRefs.contains(n.ref)).toList();
      } else {
        filteredNodes = nodes;
      }

      final snapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: filteredNodes,
      );

      // Cache full snapshot for ref -> semantics ID translation in actions
      // (even in compact mode, we need full data for interactions)
      FlutterMate.lastSnapshot = CombinedSnapshot(
        success: true,
        timestamp: DateTime.now(),
        nodes: nodes,
      );

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

  /// Extract text content from a widget using Flutter's diagnostics system.
  ///
  /// Uses DiagnosticsNode to find text in ANY widget's properties,
  /// without needing to know specific widget types or property names.
  /// Also extracts icon information for Icon widgets.
  static String? _extractWidgetContent(Widget widget) {
    try {
      final node = widget.toDiagnosticsNode();
      final properties = node.getProperties();

      // First pass: look for string properties (most common for text)
      for (final prop in properties) {
        if (prop is StringProperty) {
          final value = prop.value;
          if (value != null && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }

      // Second pass: look for InlineSpan properties (TextSpan, etc.)
      for (final prop in properties) {
        if (prop is DiagnosticsProperty) {
          final value = prop.value;
          if (value is InlineSpan) {
            final text = _extractTextFromSpan(value);
            if (text.isNotEmpty) return text;
          }
        }
      }
    } catch (_) {
      // Diagnostics can fail for some widgets
    }
    return null;
  }

  /// Extract plain text from an InlineSpan tree (TextSpan, WidgetSpan, etc.)
  static String _extractTextFromSpan(InlineSpan span) {
    final buffer = StringBuffer();

    void visit(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) {
          buffer.write(s.text);
        }
        s.children?.forEach(visit);
      }
      // WidgetSpan and other spans don't have extractable text
    }

    visit(span);
    return buffer.toString().trim();
  }

  /// Find semantics in the render tree, searching down if needed
  /// This finds semantics in internal widgets (like _InkResponse inside ElevatedButton)
  /// that are not in the inspector tree. Already-used IDs are skipped by the caller.
  static SemanticsNode? _findSemanticsInRenderTree(RenderObject ro) {
    // First check if this render object has direct semantics
    SemanticsNode? best = ro.debugSemantics;

    // If no direct semantics or it has no meaningful content, search children
    if (best == null || !_hasMeaningfulSemantics(best)) {
      void visitRenderObject(RenderObject child) {
        if (best != null && _hasMeaningfulSemantics(best!)) return;
        final sn = child.debugSemantics;
        if (sn != null && _hasMeaningfulSemantics(sn)) {
          best = sn;
          return;
        }
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

  /// Cache of known offstage RenderObjects for O(1) lookup
  /// Cleared at the start of each snapshot
  static final Set<RenderObject> _offstageCache = {};

  /// Cache of known onstage RenderObjects to avoid re-checking
  static final Set<RenderObject> _onstageCache = {};

  /// Check if an element is offstage (not being painted)
  ///
  /// Uses caching to achieve O(1) amortized complexity for both
  /// offstage AND onstage elements.
  ///
  /// This detects:
  /// - Widgets from previous routes (after navigation)
  /// - Offstage widgets
  /// - Unattached render objects
  static bool _isElementOffstage(Element element) {
    try {
      // Get the render object directly if available
      RenderObject? ro;
      if (element is RenderObjectElement) {
        ro = element.renderObject;
      }

      // No render object = can't determine, assume onstage
      if (ro == null) return false;

      // Check if unattached
      if (!ro.attached) return true;

      // Fast path: check caches first (O(1))
      if (_offstageCache.contains(ro)) return true;
      if (_onstageCache.contains(ro)) return false;

      // Check ancestors in cache (usually hits within 1-2 levels)
      RenderObject? current = ro.parent;
      while (current != null) {
        if (_offstageCache.contains(current)) {
          _offstageCache.add(ro); // Cache this one too
          return true;
        }
        if (_onstageCache.contains(current)) {
          _onstageCache.add(ro); // Cache this one too
          return false;
        }
        current = current.parent;
      }

      // Slow path: check for Offstage widget specifically
      // This is much cheaper than debugDescribeChildren()
      current = ro;
      while (current != null) {
        // Check for RenderOffstage (the actual Offstage widget's render object)
        if (current.runtimeType.toString() == 'RenderOffstage') {
          // ignore: invalid_use_of_protected_member
          final offstage = (current as dynamic).offstage as bool?;
          if (offstage == true) {
            _offstageCache.add(ro);
            return true;
          }
        }
        current = current.parent;
      }

      // No offstage ancestor found - cache as onstage
      _onstageCache.add(ro);
      return false;
    } catch (_) {
      // If we can't determine, assume it's onstage
      return false;
    }
  }

  /// Collect ALL text content from an element subtree
  /// Returns all text found, not just the first
  static List<String> _collectAllTextInSubtree(Element element) {
    final texts = <String>[];
    final seen = <String>{}; // Avoid duplicates

    void visit(Element child) {
      try {
        // Skip offstage elements (previous routes, Offstage widgets, etc.)
        if (_isElementOffstage(child)) {
          return;
        }

        // Try to extract text from this widget
        final content = _extractWidgetContent(child.widget);
        if (content != null && content.isNotEmpty && !seen.contains(content)) {
          seen.add(content);
          texts.add(content);
        }

        // Continue to ALL children (don't stop on first find)
        child.visitChildren(visit);
      } catch (_) {
        // Element may become invalid during navigation - skip it
      }
    }

    try {
      element.visitChildren(visit);
    } catch (_) {
      // Parent element may be invalid
    }
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
