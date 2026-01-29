import 'package:flutter/rendering.dart';

import '../core/flutter_mate.dart';
import '../core/semantics_utils.dart';
import '../snapshot/snapshot.dart';

/// Find a semantics node by ref
///
/// Looks up the semantics ID from the cached snapshot and searches
/// the semantics tree for the matching node.
SemanticsNode? findSemanticsNode(String ref) {
  // Clean ref: '@w5' -> 'w5'
  final cleanRef = ref.startsWith('@') ? ref.substring(1) : ref;
  if (!cleanRef.startsWith('w')) return null;

  // Look up semantics ID from cached snapshot
  final lastSnapshot = FlutterMate.lastSnapshot;
  if (lastSnapshot != null) {
    final node = lastSnapshot[cleanRef];
    if (node?.semantics != null) {
      final semanticsId = node!.semantics!.id;
      return searchSemanticsNodeById(semanticsId);
    }
  }

  // Fallback: try parsing ref as semantics ID directly (backwards compat)
  final nodeId = int.tryParse(cleanRef.substring(1));
  if (nodeId == null) return null;
  return searchSemanticsNodeById(nodeId);
}

/// Find element ref by text content or semantic label.
///
/// Searches the current snapshot for an element whose text contains
/// the given string (case-insensitive).
///
/// Searches (in order):
/// - `textContent` (from Text/RichText widgets)
/// - `semantics.label`
/// - `semantics.value`
/// - `semantics.hint`
///
/// ```dart
/// final ref = await findByLabel('Email');
/// if (ref != null) {
///   await FlutterMate.setText(ref, 'test@example.com');
/// }
/// ```
Future<String?> findByLabel(String label) async {
  FlutterMate.ensureInitialized();

  final snap = SnapshotService.snapshot();
  final lowerLabel = label.toLowerCase();

  for (final node in snap.nodes) {
    // Check textContent first
    final textContent = node.textContent;
    if (textContent != null && textContent.toLowerCase().contains(lowerLabel)) {
      return node.ref;
    }

    // Check semantics fields
    final nodeLabel = node.semantics?.label;
    if (nodeLabel != null && nodeLabel.toLowerCase().contains(lowerLabel)) {
      return node.ref;
    }

    final nodeValue = node.semantics?.value;
    if (nodeValue != null && nodeValue.toLowerCase().contains(lowerLabel)) {
      return node.ref;
    }

    final nodeHint = node.semantics?.hint;
    if (nodeHint != null && nodeHint.toLowerCase().contains(lowerLabel)) {
      return node.ref;
    }
  }

  return null;
}

/// Find all element refs matching a text pattern.
///
/// Returns all refs whose text matches the pattern (regex, case-insensitive).
///
/// Searches:
/// - `textContent` (from Text/RichText widgets)
/// - `semantics.label`
/// - `semantics.value`
/// - `semantics.hint`
///
/// ```dart
/// final refs = await findAllByLabel('Item');
/// for (final ref in refs) {
///   await FlutterMate.tap(ref);
/// }
/// ```
Future<List<String>> findAllByLabel(String labelPattern) async {
  FlutterMate.ensureInitialized();

  final snap = SnapshotService.snapshot();
  final pattern = RegExp(labelPattern, caseSensitive: false);
  final refs = <String>[];

  for (final node in snap.nodes) {
    bool matched = false;

    // Check textContent first
    final textContent = node.textContent;
    if (textContent != null && pattern.hasMatch(textContent)) {
      matched = true;
    }

    // Check semantics fields
    if (!matched) {
      final label = node.semantics?.label;
      if (label != null && pattern.hasMatch(label)) {
        matched = true;
      }
    }

    if (!matched) {
      final value = node.semantics?.value;
      if (value != null && pattern.hasMatch(value)) {
        matched = true;
      }
    }

    if (!matched) {
      final hint = node.semantics?.hint;
      if (hint != null && pattern.hasMatch(hint)) {
        matched = true;
      }
    }

    if (matched) {
      refs.add(node.ref);
    }
  }

  return refs;
}

/// Wait for an element with matching text to appear.
///
/// Polls the snapshot until an element with text matching the pattern
/// is found, or timeout is reached.
///
/// Searches (in order):
/// - `textContent` (from Text/RichText widgets)
/// - `semantics.label`
/// - `semantics.value`
/// - `semantics.hint`
///
/// Returns the element's ref if found, null if timeout.
Future<String?> waitFor(
  String labelPattern, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  FlutterMate.ensureInitialized();

  final pattern = RegExp(labelPattern, caseSensitive: false);
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    final snap = SnapshotService.snapshot();
    for (final node in snap.nodes) {
      // Check textContent first (from Text/RichText widgets)
      final textContent = node.textContent;
      if (textContent != null && pattern.hasMatch(textContent)) {
        return node.ref;
      }

      // Check semantics fields
      final label = node.semantics?.label;
      if (label != null && pattern.hasMatch(label)) {
        return node.ref;
      }

      final value = node.semantics?.value;
      if (value != null && pattern.hasMatch(value)) {
        return node.ref;
      }

      final hint = node.semantics?.hint;
      if (hint != null && pattern.hasMatch(hint)) {
        return node.ref;
      }
    }
    await FlutterMate.delay(pollInterval);
  }

  return null;
}
