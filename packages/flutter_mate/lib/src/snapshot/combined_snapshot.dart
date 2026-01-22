/// Re-export shared snapshot types from flutter_mate_types.
///
/// This file provides the core snapshot types used throughout Flutter Mate:
/// - [CombinedSnapshot] - Container for the full UI snapshot
/// - [CombinedNode] - A single node in the widget tree
/// - [SemanticsInfo] - Comprehensive semantics data
/// - [CombinedRect] - Bounding rectangle for nodes
///
/// These types are pure Dart with no Flutter dependencies, enabling
/// sharing between the Flutter SDK and CLI/MCP tools.
library;

export 'package:flutter_mate_types/flutter_mate_types.dart';
