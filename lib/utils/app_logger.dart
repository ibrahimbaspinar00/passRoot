import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void debug(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }
    final suffix = error == null ? '' : ': $error';
    debugPrint('[$scope] $message$suffix');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace, label: '[$scope]');
    }
  }
}
