import 'package:flutter/rendering.dart';

/// Utility functions for extracting semantics information
///
/// These are used by both the snapshot system and the service extensions
/// for debugging.

/// Extract action names from SemanticsData
List<String> getActionsFromData(SemanticsData data) {
  final actions = <String>[];
  if (data.hasAction(SemanticsAction.tap)) actions.add('tap');
  if (data.hasAction(SemanticsAction.longPress)) actions.add('longPress');
  if (data.hasAction(SemanticsAction.scrollLeft)) actions.add('scrollLeft');
  if (data.hasAction(SemanticsAction.scrollRight)) actions.add('scrollRight');
  if (data.hasAction(SemanticsAction.scrollUp)) actions.add('scrollUp');
  if (data.hasAction(SemanticsAction.scrollDown)) actions.add('scrollDown');
  if (data.hasAction(SemanticsAction.focus)) actions.add('focus');
  if (data.hasAction(SemanticsAction.setText)) actions.add('setText');
  if (data.hasAction(SemanticsAction.increase)) actions.add('increase');
  if (data.hasAction(SemanticsAction.decrease)) actions.add('decrease');
  if (data.hasAction(SemanticsAction.copy)) actions.add('copy');
  if (data.hasAction(SemanticsAction.cut)) actions.add('cut');
  if (data.hasAction(SemanticsAction.paste)) actions.add('paste');
  return actions;
}

/// Extract flag names from SemanticsData
List<String> getFlagsFromData(SemanticsData data) {
  final flags = <String>[];

  void checkFlag(SemanticsFlag flag, String name) {
    // ignore: deprecated_member_use
    if (data.hasFlag(flag)) flags.add(name);
  }

  checkFlag(SemanticsFlag.isButton, 'isButton');
  checkFlag(SemanticsFlag.isTextField, 'isTextField');
  checkFlag(SemanticsFlag.isLink, 'isLink');
  checkFlag(SemanticsFlag.isFocusable, 'isFocusable');
  checkFlag(SemanticsFlag.isFocused, 'isFocused');
  checkFlag(SemanticsFlag.isEnabled, 'isEnabled');
  checkFlag(SemanticsFlag.isChecked, 'isChecked');
  checkFlag(SemanticsFlag.isSelected, 'isSelected');
  checkFlag(SemanticsFlag.isToggled, 'isToggled');
  checkFlag(SemanticsFlag.isHeader, 'isHeader');
  checkFlag(SemanticsFlag.isSlider, 'isSlider');
  checkFlag(SemanticsFlag.isImage, 'isImage');
  checkFlag(SemanticsFlag.isObscured, 'isObscured');
  checkFlag(SemanticsFlag.isReadOnly, 'isReadOnly');
  checkFlag(SemanticsFlag.isMultiline, 'isMultiline');

  return flags;
}

/// Get the root semantics node from the current render tree
SemanticsNode? getRootSemanticsNode() {
  for (final view in RendererBinding.instance.renderViews) {
    if (view.owner?.semanticsOwner?.rootSemanticsNode != null) {
      return view.owner!.semanticsOwner!.rootSemanticsNode;
    }
  }
  return null;
}

/// Search for a semantics node by ID in the tree
SemanticsNode? searchSemanticsNodeById(int nodeId) {
  final rootNode = getRootSemanticsNode();
  if (rootNode == null) return null;
  return _searchNode(rootNode, nodeId);
}

SemanticsNode? _searchNode(SemanticsNode node, int targetId) {
  if (node.id == targetId) return node;

  SemanticsNode? found;
  node.visitChildren((child) {
    final result = _searchNode(child, targetId);
    if (result != null) {
      found = result;
      return false;
    }
    return true;
  });
  return found;
}
