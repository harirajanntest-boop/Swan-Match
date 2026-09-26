import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug-mode NDJSON logger for agent sessions (adb logcat: AGENT_DEBUG).
void agentDebugLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  final payload = <String, dynamic>{
    'sessionId': 'c1ab8f',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data ?? <String, dynamic>{},
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  // #region agent log
  debugPrint('AGENT_DEBUG|c1ab8f|${jsonEncode(payload)}');
  // #endregion
}
