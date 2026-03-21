import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_start_gate.dart';
import 'app_theme.dart';
import '../models/app_settings.dart';
import '../screens/splash_screen.dart';
import '../state/app_settings_store.dart';

class PassRootApp extends StatefulWidget {
  const PassRootApp({super.key});

  @override
  State<PassRootApp> createState() => _PassRootAppState();
}

class _PassRootAppState extends State<PassRootApp> {
  late final AppSettingsStore _settingsStore;

  @override
  void initState() {
    super.initState();
    _settingsStore = AppSettingsStore();
    _settingsStore.load();
  }

  @override
  void dispose() {
    _settingsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsStore,
      builder: (context, _) {
        if (!_settingsStore.loaded) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashScreen(),
          );
        }

        return MaterialApp(
          title: 'PassRoot Vault',
          debugShowCheckedModeBanner: false,
          locale: _settingsStore.settings.language.locale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: _settingsStore.settings.darkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: AppTheme.light(accent: _settingsStore.settings.themeAccent),
          darkTheme: AppTheme.dark(accent: _settingsStore.settings.themeAccent),
          home: AppStartGate(settingsStore: _settingsStore),
        );
      },
    );
  }
}
