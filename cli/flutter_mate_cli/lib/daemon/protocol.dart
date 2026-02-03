import 'dart:convert';

/// Protocol for communication between CLI client and daemon.
///
/// Uses newline-delimited JSON (NDJSON) over Unix socket.
/// Each message is a single line of JSON terminated by '\n'.

// ════════════════════════════════════════════════════════════════════════════
// REQUEST
// ════════════════════════════════════════════════════════════════════════════

/// Base request structure sent from CLI to daemon.
class Request {
  final String id;
  final String action;
  final Map<String, dynamic> args;

  Request({
    required this.id,
    required this.action,
    this.args = const {},
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final action = json['action'] as String? ?? '';
    final args = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('action');
    return Request(id: id, action: action, args: args);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        ...args,
      };

  String serialize() => jsonEncode(toJson());

  @override
  String toString() => 'Request($action, id=$id, args=$args)';
}

/// Parse a JSON string into a Request.
/// Returns null if parsing fails.
Request? parseRequest(String input) {
  try {
    final json = jsonDecode(input.trim());
    if (json is! Map<String, dynamic>) return null;
    return Request.fromJson(json);
  } catch (_) {
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RESPONSE
// ════════════════════════════════════════════════════════════════════════════

/// Response sent from daemon to CLI.
class Response {
  final String id;
  final bool success;
  final dynamic data;
  final String? error;

  Response({
    required this.id,
    required this.success,
    this.data,
    this.error,
  });

  factory Response.success(String id, [dynamic data]) => Response(
        id: id,
        success: true,
        data: data,
      );

  factory Response.error(String id, String error) => Response(
        id: id,
        success: false,
        error: error,
      );

  factory Response.fromJson(Map<String, dynamic> json) => Response(
        id: json['id'] as String? ?? '',
        success: json['success'] as bool? ?? false,
        data: json['data'],
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'success': success,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      };

  String serialize() => jsonEncode(toJson());

  @override
  String toString() =>
      success ? 'Response.success($id, $data)' : 'Response.error($id, $error)';
}

/// Parse a JSON string into a Response.
/// Returns null if parsing fails.
Response? parseResponse(String input) {
  try {
    final json = jsonDecode(input.trim());
    if (json is! Map<String, dynamic>) return null;
    return Response.fromJson(json);
  } catch (_) {
    return null;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ACTIONS
// ════════════════════════════════════════════════════════════════════════════

/// All supported daemon actions.
abstract class Actions {
  // App lifecycle
  static const connect = 'connect';
  static const close = 'close';
  static const status = 'status';

  // Introspection
  static const snapshot = 'snapshot';
  static const find = 'find';
  static const screenshot = 'screenshot';
  static const getText = 'getText';

  // Interactions
  static const tap = 'tap';
  static const doubleTap = 'doubleTap';
  static const longPress = 'longPress';
  static const hover = 'hover';
  static const drag = 'drag';
  static const focus = 'focus';

  // Text input
  static const setText = 'setText';
  static const typeText = 'typeText';
  static const clear = 'clear';

  // Scrolling
  static const scroll = 'scroll';
  static const swipe = 'swipe';

  // Keyboard
  static const pressKey = 'pressKey';
  static const keyDown = 'keyDown';
  static const keyUp = 'keyUp';

  // Waiting
  static const wait = 'wait';
  static const waitFor = 'waitFor';
  static const waitForDisappear = 'waitForDisappear';
  static const waitForValue = 'waitForValue';
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Generate a unique request ID.
String generateRequestId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = now.hashCode.abs() % 10000;
  return '${now.toRadixString(36)}_${random.toRadixString(36)}';
}
