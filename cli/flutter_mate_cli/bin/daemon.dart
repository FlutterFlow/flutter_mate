import 'dart:io';

import 'package:flutter_mate_cli/daemon/daemon.dart';

/// Daemon entry point.
///
/// This is spawned by the CLI client when a daemon isn't running.
/// The session name is passed via FLUTTER_MATE_SESSION environment variable.
void main(List<String> args) async {
  final session = Platform.environment['FLUTTER_MATE_SESSION'] ?? 'default';

  try {
    await startDaemon(session);
  } catch (e) {
    stderr.writeln('Daemon error: $e');
    exit(1);
  }
}
