/// Snapshot types shared between Flutter Mate SDK and CLI.
///
/// These types represent the widget tree snapshot with semantics information.
/// They are pure Dart with no Flutter dependencies.

/// A combined snapshot of the widget tree with semantics information.
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

  /// Create from JSON
  factory CombinedSnapshot.fromJson(Map<String, dynamic> json) {
    return CombinedSnapshot(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      nodes: (json['nodes'] as List<dynamic>?)
              ?.map((n) => CombinedNode.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'success': success,
        if (error != null) 'error': error,
        'timestamp': timestamp.toIso8601String(),
        'nodeCount': nodes.length,
        'nodesWithSemantics': withSemantics.length,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };
}

/// A node in the combined widget tree.
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

  /// Text content for informative widgets
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
  ({double x, double y})? get center => bounds?.center;

  /// Create from JSON
  factory CombinedNode.fromJson(Map<String, dynamic> json) {
    return CombinedNode(
      ref: json['ref'] as String? ?? '',
      widget: json['widget'] as String? ?? '?',
      depth: json['depth'] as int? ?? 0,
      bounds: json['bounds'] != null
          ? CombinedRect.fromJson(json['bounds'] as Map<String, dynamic>)
          : null,
      children: (json['children'] as List<dynamic>?)?.cast<String>() ?? [],
      semantics: json['semantics'] != null
          ? SemanticsInfo.fromJson(json['semantics'] as Map<String, dynamic>)
          : null,
      textContent: json['textContent'] as String?,
    );
  }

  /// Convert to JSON
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

/// Semantics information extracted from a SemanticsNode.
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

  /// Start of text selection
  final int? textSelectionBase;

  /// End of text selection
  final int? textSelectionExtent;

  /// Maximum allowed value length
  final int? maxValueLength;

  /// Current value length
  final int? currentValueLength;

  /// Total number of scrollable children
  final int? scrollChildCount;

  /// Index of first visible semantic child
  final int? scrollIndex;

  /// Current scroll position in logical pixels
  final double? scrollPosition;

  /// Maximum scroll extent
  final double? scrollExtentMax;

  /// Minimum scroll extent
  final double? scrollExtentMin;

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

  /// Create from JSON
  factory SemanticsInfo.fromJson(Map<String, dynamic> json) {
    return SemanticsInfo(
      id: json['id'] as int? ?? 0,
      identifier: json['identifier'] as String?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      hint: json['hint'] as String?,
      tooltip: json['tooltip'] as String?,
      increasedValue: json['increasedValue'] as String?,
      decreasedValue: json['decreasedValue'] as String?,
      flags: (json['flags'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
      actions:
          (json['actions'] as List<dynamic>?)?.cast<String>().toSet() ?? {},
      textDirection: json['textDirection'] as String?,
      textSelectionBase: json['textSelectionBase'] as int?,
      textSelectionExtent: json['textSelectionExtent'] as int?,
      maxValueLength: json['maxValueLength'] as int?,
      currentValueLength: json['currentValueLength'] as int?,
      scrollChildCount: json['scrollChildCount'] as int?,
      scrollIndex: json['scrollIndex'] as int?,
      scrollPosition: (json['scrollPosition'] as num?)?.toDouble(),
      scrollExtentMax: (json['scrollExtentMax'] as num?)?.toDouble(),
      scrollExtentMin: (json['scrollExtentMin'] as num?)?.toDouble(),
      headingLevel: json['headingLevel'] as int?,
      linkUrl: json['linkUrl'] as String?,
      role: json['role'] as String?,
      inputType: json['inputType'] as String?,
      validationResult: json['validationResult'] as String?,
      platformViewId: json['platformViewId'] as int?,
      controlsNodes:
          (json['controlsNodes'] as List<dynamic>?)?.cast<String>().toSet(),
    );
  }

  /// Convert to JSON
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

/// Simple rect class for node bounds.
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
  ({double x, double y}) get center => (
        x: x + width / 2,
        y: y + height / 2,
      );

  /// Check if this rect has the same bounds as another (within tolerance)
  bool sameBoundsAs(CombinedRect other, {double tolerance = 1.0}) {
    return (x - other.x).abs() <= tolerance &&
        (y - other.y).abs() <= tolerance &&
        (width - other.width).abs() <= tolerance &&
        (height - other.height).abs() <= tolerance;
  }

  /// Check if this is a zero-area rect
  bool get isZeroArea => width <= 0 || height <= 0;

  /// Create from JSON
  factory CombinedRect.fromJson(Map<String, dynamic> json) {
    return CombinedRect(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, double> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}
