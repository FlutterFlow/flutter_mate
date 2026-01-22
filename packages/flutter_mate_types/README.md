# flutter_mate_types

Shared type definitions for Flutter Mate SDK and CLI.

## Overview

This package contains pure Dart types with no Flutter dependencies, making them usable by both:

- **flutter_mate** (Flutter SDK) - uses types for snapshot generation
- **flutter_mate_cli** (CLI/MCP server) - uses types for parsing and formatting

## Types

### CombinedSnapshot

Container for the full UI snapshot with nodes, timestamp, and metadata.

```dart
final snapshot = CombinedSnapshot.fromJson(jsonData);
print('${snapshot.nodes.length} elements');
final node = snapshot['w5']; // Access by ref
```

### CombinedNode

A single node in the widget tree with ref, widget type, bounds, semantics, and text content.

```dart
final node = CombinedNode.fromJson(nodeData);
print('[${node.ref}] ${node.widget}');
if (node.hasAdditionalInfo) {
  // Node has meaningful content beyond just widget type
}
```

### SemanticsInfo

Comprehensive semantics data extracted from Flutter's SemanticsNode.

Includes:
- `label`, `value`, `hint`, `tooltip` - text content
- `actions` - available semantic actions (tap, focus, scroll, etc.)
- `flags` - semantic flags (isButton, isTextField, isFocusable, etc.)
- `validationResult` - form field validation state
- `scrollPosition`, `scrollExtentMax` - scroll info
- And more...

### CombinedRect

Simple bounds rectangle with helper methods.

```dart
final center = rect.center; // ({double x, double y})
final isZero = rect.isZeroArea;
final same = rect.sameBoundsAs(other);
```

## Usage

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_mate_types:
    path: ../flutter_mate_types
```

Import:

```dart
import 'package:flutter_mate_types/flutter_mate_types.dart';
```
