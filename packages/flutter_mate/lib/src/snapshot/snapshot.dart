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
    _offstageStatusCache.clear();
    _parentChildOffstageMap.clear();

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

      // Returns the set of claimed text from this subtree (for parent deduplication)
      Set<String> walkInspectorNode(Map<String, dynamic> node, int depth) {
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
                return <String>{};
              }

              // Cache the Element for ref lookup
              FlutterMate.cachedElements[ref] = obj;

              // Find the RenderObject first (needed for text extraction and bounds)
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

              // Extract text content from the render tree (only actual rendered text)
              try {
                textContent = _extractTextFromRenderObject(ro);

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
        // Collect all text claimed by descendants (for THIS node's deduplication only)
        final childRefs = <String>[];
        final childStartRef = refCounter;
        final descendantClaims = <String>{};

        for (final childJson in childrenJson) {
          if (childJson is Map<String, dynamic>) {
            final beforeCount = refCounter;
            final childClaims = walkInspectorNode(childJson, depth + 1);
            descendantClaims.addAll(childClaims);
            if (refCounter > beforeCount) {
              childRefs.add('w$beforeCount');
            }
          }
        }

        // This node's own claims (text it displays that wasn't claimed by children)
        final myClaims = <String>{};

        // NOW deduplicate text - only against MY children's claims, not siblings'
        if (textContent != null && textContent.isNotEmpty) {
          final texts = textContent.split(' | ');
          final newTexts = <String>[];
          for (final t in texts) {
            final key = normalizeText(t);
            if (key.isNotEmpty && !descendantClaims.contains(key)) {
              myClaims.add(key); // Claim this text
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

            // Also deduplicate semantics.label against MY children's claims only
            if (sem.label != null) {
              final labelKey = normalizeText(sem.label!);
              if (labelKey.isNotEmpty && descendantClaims.contains(labelKey)) {
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
                myClaims.add(labelKey); // Claim this label
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

        // Return all claims from this subtree (my claims + descendants' claims)
        return myClaims..addAll(descendantClaims);
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

  /// Extract text content from a RenderObject using the render tree.
  ///
  /// This extracts ONLY actually rendered text by checking:
  /// - RenderParagraph: The render object for Text/RichText widgets
  /// - RenderEditable: The render object for TextField content
  ///
  /// This is more accurate than diagnostics-based extraction because it
  /// only returns text that is actually painted to screen.
  static String? _extractTextFromRenderObject(RenderObject? ro) {
    if (ro == null) return null;

    try {
      // RenderParagraph is what paints Text/RichText widgets
      if (ro is RenderParagraph) {
        final text = _extractTextFromSpan(ro.text);
        if (text.isNotEmpty) return text;
      }

      // RenderEditable is what paints TextField/TextFormField content
      if (ro is RenderEditable) {
        final text = ro.text?.toPlainText();
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    } catch (_) {
      // Render object may be in invalid state
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

  /// Cache of RenderObjects whose parent marks them as offstage
  /// Key: child RenderObject, Value: true if offstage
  static final Map<RenderObject, bool> _offstageStatusCache = {};

  /// Cache of parent -> children diagnostics to avoid repeated calls
  /// This is the expensive call we want to minimize
  static final Map<RenderObject, Map<RenderObject, bool>>
      _parentChildOffstageMap = {};

  /// Check if an element is offstage (not being painted)
  ///
  /// Uses two-level caching:
  /// 1. Direct cache: O(1) lookup for previously checked RenderObjects
  /// 2. Parent cache: Reuses parent's children diagnostics for siblings
  ///
  /// This detects widgets from previous routes, Offstage widgets, etc.
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

      // Fast path: check direct cache (O(1))
      if (_offstageStatusCache.containsKey(ro)) {
        return _offstageStatusCache[ro]!;
      }

      // Check if any ancestor is cached as offstage
      RenderObject? current = ro.parent;
      while (current != null) {
        if (_offstageStatusCache[current] == true) {
          _offstageStatusCache[ro] = true;
          return true;
        }
        current = current.parent;
      }

      // Check parent's children diagnostics (cached per parent)
      final parent = ro.parent;
      if (parent != null) {
        // Get or build the parent's child offstage map
        if (!_parentChildOffstageMap.containsKey(parent)) {
          final childMap = <RenderObject, bool>{};
          try {
            // This is the expensive call - but only once per unique parent
            final children = parent.debugDescribeChildren();
            for (final child in children) {
              if (child.value is RenderObject) {
                childMap[child.value as RenderObject] =
                    child.style == DiagnosticsTreeStyle.offstage;
              }
            }
          } catch (_) {}
          _parentChildOffstageMap[parent] = childMap;
        }

        // Check if this child is marked offstage by its parent
        final isOffstage = _parentChildOffstageMap[parent]?[ro] ?? false;
        _offstageStatusCache[ro] = isOffstage;
        return isOffstage;
      }

      // No parent = root, not offstage
      _offstageStatusCache[ro] = false;
      return false;
    } catch (_) {
      // If we can't determine, assume it's onstage
      return false;
    }
  }

  /// Collect ALL text content from an element subtree using the render tree.
  /// Returns all text found, not just the first.
  /// Only extracts actually rendered text (RenderParagraph, RenderEditable).
  static List<String> _collectAllTextInSubtree(Element element) {
    final texts = <String>[];
    final seen = <String>{}; // Avoid duplicates

    void visit(Element child) {
      try {
        // Skip offstage elements (previous routes, Offstage widgets, etc.)
        if (_isElementOffstage(child)) {
          return;
        }

        // Try to extract text from the render object (not widget diagnostics)
        if (child is RenderObjectElement) {
          final content = _extractTextFromRenderObject(child.renderObject);
          if (content != null &&
              content.isNotEmpty &&
              !seen.contains(content)) {
            seen.add(content);
            texts.add(content);
          }
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
