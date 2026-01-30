import 'package:flutter_mate_cli/daemon/protocol.dart';

/// Helper functions for building and parsing CLI commands.

// ════════════════════════════════════════════════════════════════════════════
// COMMAND BUILDERS
// ════════════════════════════════════════════════════════════════════════════

/// Build a 'run' command request.
Request buildRunCommand(List<String> flutterArgs) {
  return Request(
    id: generateRequestId(),
    action: Actions.run,
    args: {'args': flutterArgs},
  );
}

/// Build a 'connect' command request.
Request buildConnectCommand(String uri) {
  return Request(
    id: generateRequestId(),
    action: Actions.connect,
    args: {'uri': uri},
  );
}

/// Build a 'close' command request.
Request buildCloseCommand() {
  return Request(
    id: generateRequestId(),
    action: Actions.close,
  );
}

/// Build a 'status' command request.
Request buildStatusCommand() {
  return Request(
    id: generateRequestId(),
    action: Actions.status,
  );
}

/// Build a 'snapshot' command request.
Request buildSnapshotCommand({
  bool compact = false,
  int? depth,
  String? fromRef,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.snapshot,
    args: {
      if (compact) 'compact': true,
      if (depth != null) 'depth': depth,
      if (fromRef != null) 'from': fromRef,
    },
  );
}

/// Build a 'find' command request.
Request buildFindCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.find,
    args: {'ref': ref},
  );
}

/// Build a 'screenshot' command request.
Request buildScreenshotCommand({String? ref}) {
  return Request(
    id: generateRequestId(),
    action: Actions.screenshot,
    args: {
      if (ref != null) 'ref': ref,
    },
  );
}

/// Build a 'getText' command request.
Request buildGetTextCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.getText,
    args: {'ref': ref},
  );
}

/// Build a 'tap' command request.
Request buildTapCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.tap,
    args: {'ref': ref},
  );
}

/// Build a 'doubleTap' command request.
Request buildDoubleTapCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.doubleTap,
    args: {'ref': ref},
  );
}

/// Build a 'longPress' command request.
Request buildLongPressCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.longPress,
    args: {'ref': ref},
  );
}

/// Build a 'hover' command request.
Request buildHoverCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.hover,
    args: {'ref': ref},
  );
}

/// Build a 'drag' command request.
Request buildDragCommand(String fromRef, String toRef) {
  return Request(
    id: generateRequestId(),
    action: Actions.drag,
    args: {'from': fromRef, 'to': toRef},
  );
}

/// Build a 'focus' command request.
Request buildFocusCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.focus,
    args: {'ref': ref},
  );
}

/// Build a 'setText' command request.
Request buildSetTextCommand(String ref, String text) {
  return Request(
    id: generateRequestId(),
    action: Actions.setText,
    args: {'ref': ref, 'text': text},
  );
}

/// Build a 'typeText' command request.
Request buildTypeTextCommand(String ref, String text) {
  return Request(
    id: generateRequestId(),
    action: Actions.typeText,
    args: {'ref': ref, 'text': text},
  );
}

/// Build a 'clear' command request.
Request buildClearCommand(String ref) {
  return Request(
    id: generateRequestId(),
    action: Actions.clear,
    args: {'ref': ref},
  );
}

/// Build a 'scroll' command request.
Request buildScrollCommand(String ref, String direction) {
  return Request(
    id: generateRequestId(),
    action: Actions.scroll,
    args: {'ref': ref, 'direction': direction},
  );
}

/// Build a 'swipe' command request.
Request buildSwipeCommand(String direction) {
  return Request(
    id: generateRequestId(),
    action: Actions.swipe,
    args: {'direction': direction},
  );
}

/// Build a 'pressKey' command request.
Request buildPressKeyCommand(String key) {
  return Request(
    id: generateRequestId(),
    action: Actions.pressKey,
    args: {'key': key},
  );
}

/// Build a 'keyDown' command request.
Request buildKeyDownCommand(
  String key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
  bool command = false,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.keyDown,
    args: {
      'key': key,
      if (control) 'control': true,
      if (shift) 'shift': true,
      if (alt) 'alt': true,
      if (command) 'command': true,
    },
  );
}

/// Build a 'keyUp' command request.
Request buildKeyUpCommand(
  String key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
  bool command = false,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.keyUp,
    args: {
      'key': key,
      if (control) 'control': true,
      if (shift) 'shift': true,
      if (alt) 'alt': true,
      if (command) 'command': true,
    },
  );
}

/// Build a 'wait' command request.
Request buildWaitCommand(int ms) {
  return Request(
    id: generateRequestId(),
    action: Actions.wait,
    args: {'ms': ms},
  );
}

/// Build a 'waitFor' command request.
Request buildWaitForCommand(
  String pattern, {
  int? timeout,
  int? poll,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.waitFor,
    args: {
      'pattern': pattern,
      if (timeout != null) 'timeout': timeout,
      if (poll != null) 'poll': poll,
    },
  );
}

/// Build a 'waitForDisappear' command request.
Request buildWaitForDisappearCommand(
  String pattern, {
  int? timeout,
  int? poll,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.waitForDisappear,
    args: {
      'pattern': pattern,
      if (timeout != null) 'timeout': timeout,
      if (poll != null) 'poll': poll,
    },
  );
}

/// Build a 'waitForValue' command request.
Request buildWaitForValueCommand(
  String ref,
  String pattern, {
  int? timeout,
  int? poll,
}) {
  return Request(
    id: generateRequestId(),
    action: Actions.waitForValue,
    args: {
      'ref': ref,
      'pattern': pattern,
      if (timeout != null) 'timeout': timeout,
      if (poll != null) 'poll': poll,
    },
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ARGUMENT PARSING HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Extract the ref argument from command args.
String? extractRef(List<String> args) {
  if (args.isEmpty) return null;
  return args[0];
}

/// Extract ref and text arguments from command args.
(String?, String?) extractRefAndText(List<String> args) {
  if (args.isEmpty) return (null, null);
  if (args.length == 1) return (args[0], null);
  return (args[0], args.sublist(1).join(' '));
}

/// Extract from and to refs from command args.
(String?, String?) extractFromTo(List<String> args) {
  if (args.length < 2) return (null, null);
  return (args[0], args[1]);
}

/// Parse an integer from a string, returning null if invalid.
int? parseIntArg(String? value) {
  if (value == null) return null;
  return int.tryParse(value);
}
