import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/passroot_app.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureGlobalErrorLogging();

  try {
    await Firebase.initializeApp();
  } on Exception catch (error, stackTrace) {
    AppLogger.warning(
      'main',
      'Firebase initializeApp failed; app will continue with optional Google features disabled.',
      error: error,
      stackTrace: stackTrace,
      context: const <String, Object?>{
        'surface': 'startup',
        'feature': 'firebase_init',
      },
    );
  }

  runApp(const PassRootApp());
}

void _configureGlobalErrorLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'FlutterError',
      'Unhandled framework exception',
      error: details.exception,
      stackTrace: details.stack,
      context: <String, Object?>{
        'library': details.library ?? 'unknown',
        'context': details.context?.toDescription() ?? 'none',
      },
    );

    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppLogger.error(
      'PlatformDispatcher',
      'Unhandled async error',
      error: error,
      stackTrace: stackTrace,
      context: const <String, Object?>{'surface': 'platform_dispatcher'},
    );
    return true;
  };
}
