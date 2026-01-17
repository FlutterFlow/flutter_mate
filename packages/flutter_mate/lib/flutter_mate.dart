/// Flutter Mate — Automation SDK for Flutter apps
///
/// Build in-app AI agents or control apps externally via VM Service.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_mate/flutter_mate.dart';
///
/// // Initialize at app startup
/// await FlutterMate.initialize();
///
/// // Get UI snapshot
/// final snapshot = await FlutterMate.snapshot(interactiveOnly: true);
/// print(snapshot);
///
/// // Interact with elements using refs
/// await FlutterMate.fill('w5', 'hello@example.com');
/// await FlutterMate.tap('w10');
/// ```
///
/// ## External Control via CLI
///
/// ```bash
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws snapshot -i
/// flutter_mate --uri ws://127.0.0.1:12345/abc=/ws tap w10
/// ```
///
/// See the README for more examples and API documentation.
library flutter_mate;

export 'src/flutter_mate.dart' show FlutterMate, ScrollDirection;
export 'src/snapshot.dart' show Snapshot, SnapshotNode, Rect;
