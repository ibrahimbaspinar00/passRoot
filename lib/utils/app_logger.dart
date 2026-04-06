import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger._();

  static final RegExp _emailPattern = RegExp(
    r'\b([A-Za-z0-9._%+\-]{1,64})@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})\b',
  );
  static final RegExp _bearerPattern = RegExp(
    r'\b(bearer)\s+([A-Za-z0-9\-._~+/]+=*)',
    caseSensitive: false,
  );
  static final RegExp _jwtPattern = RegExp(
    r'\b([A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,})\b',
  );
  static final RegExp _secretAssignmentPattern = RegExp(
    r'\b(password|pass|pin|token|idToken|accessToken|refreshToken|secret|vault)\b\s*[:=]\s*([^\s,;]+)',
    caseSensitive: false,
  );
  static final RegExp _longTokenPattern = RegExp(r'\b[A-Za-z0-9+/_=-]{32,}\b');

  static void debug(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _emit(
      AppLogLevel.debug,
      scope,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void info(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _emit(
      AppLogLevel.info,
      scope,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void warning(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _emit(
      AppLogLevel.warning,
      scope,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void error(
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _emit(
      AppLogLevel.error,
      scope,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _emit(
    AppLogLevel level,
    String scope,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    if (_skipForCurrentBuild(level)) {
      return;
    }

    final safeScope = sanitize(scope);
    final safeMessage = sanitize(message);
    final safeError = error == null ? null : sanitize(error.toString());
    final safeContext = _sanitizeContext(context);
    final safeContextSuffix = safeContext.isEmpty
        ? ''
        : ' context=${jsonEncode(safeContext)}';
    final levelLabel = level.name.toUpperCase();
    final errorSuffix = safeError == null ? '' : ' error=$safeError';

    debugPrint(
      '[$levelLabel][$safeScope] $safeMessage$errorSuffix$safeContextSuffix',
    );

    if (!kReleaseMode && stackTrace != null) {
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[$levelLabel][$safeScope]',
      );
    }
  }

  static bool _skipForCurrentBuild(AppLogLevel level) {
    if (kReleaseMode) {
      return level == AppLogLevel.debug || level == AppLogLevel.info;
    }
    return false;
  }

  static Map<String, String> _sanitizeContext(Map<String, Object?>? context) {
    if (context == null || context.isEmpty) {
      return const <String, String>{};
    }
    final safe = <String, String>{};
    context.forEach((key, value) {
      safe[sanitize(key)] = sanitize('${value ?? 'null'}');
    });
    return safe;
  }

  static String sanitize(String raw) {
    if (raw.isEmpty) {
      return raw;
    }
    var value = raw;
    value = value.replaceAllMapped(_emailPattern, (match) {
      final localPart = match.group(1) ?? '';
      final domain = match.group(2) ?? '';
      final maskedLocal = _maskLocalPart(localPart);
      return '$maskedLocal@$domain';
    });
    value = value.replaceAllMapped(
      _bearerPattern,
      (match) => '${match.group(1)} <redacted-token>',
    );
    value = value.replaceAllMapped(_jwtPattern, (_) => '<redacted-jwt>');
    value = value.replaceAllMapped(
      _secretAssignmentPattern,
      (match) => '${match.group(1)}=<redacted>',
    );
    value = value.replaceAllMapped(_longTokenPattern, _redactTokenLike);
    return value;
  }

  static String _maskLocalPart(String localPart) {
    if (localPart.isEmpty) {
      return '***';
    }
    if (localPart.length == 1) {
      return '*';
    }
    if (localPart.length == 2) {
      return '${localPart[0]}*';
    }
    final middle = List<String>.filled(localPart.length - 2, '*').join();
    return '${localPart[0]}$middle${localPart[localPart.length - 1]}';
  }

  static String _redactTokenLike(Match match) {
    final token = match.group(0) ?? '';
    if (token.length < 32) {
      return token;
    }
    final lower = token.toLowerCase();
    if (lower.contains('http')) {
      return token;
    }
    return '<redacted>';
  }
}
