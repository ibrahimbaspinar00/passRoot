import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_start_gate.dart';
import 'app_theme.dart';
import '../models/app_settings.dart';
import '../screens/splash_screen.dart';
import '../state/account_store.dart';
import '../state/app_settings_store.dart';
import '../state/google_auth_store.dart';

class PassRootApp extends StatefulWidget {
  const PassRootApp({super.key});

  @override
  State<PassRootApp> createState() => _PassRootAppState();
}

class _PassRootAppState extends State<PassRootApp> {
  late final AppSettingsStore _settingsStore;
  late final AccountStore _accountStore;
  late final GoogleAuthStore _googleAuthStore;

  bool _settingsLoaded = false;
  bool _bootstrapReady = false;
  late Locale _locale;
  late ThemeMode _themeMode;
  late AppThemeAccent _themeAccent;

  @override
  void initState() {
    super.initState();
    _settingsStore = AppSettingsStore();
    _accountStore = AccountStore();
    _googleAuthStore = GoogleAuthStore();
    _settingsStore.addListener(_onSettingsChanged);
    _accountStore.addListener(_onBootstrapStoresChanged);
    _googleAuthStore.addListener(_onBootstrapStoresChanged);

    final initialSettings = _settingsStore.settings;
    _locale = initialSettings.language.locale;
    _themeMode = initialSettings.darkMode ? ThemeMode.dark : ThemeMode.light;
    _themeAccent = initialSettings.themeAccent;

    _settingsStore.load();
    _accountStore.load();
    _googleAuthStore.load();
  }

  @override
  void dispose() {
    _settingsStore.removeListener(_onSettingsChanged);
    _accountStore.removeListener(_onBootstrapStoresChanged);
    _googleAuthStore.removeListener(_onBootstrapStoresChanged);
    _settingsStore.dispose();
    _accountStore.dispose();
    _googleAuthStore.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final settings = _settingsStore.settings;
    final nextLoaded = _settingsStore.loaded;
    final nextLocale = settings.language.locale;
    final nextThemeMode = settings.darkMode ? ThemeMode.dark : ThemeMode.light;
    final nextThemeAccent = settings.themeAccent;

    final changed =
        _settingsLoaded != nextLoaded ||
        _locale != nextLocale ||
        _themeMode != nextThemeMode ||
        _themeAccent != nextThemeAccent;
    if (!changed) {
      return;
    }

    setState(() {
      _settingsLoaded = nextLoaded;
      _locale = nextLocale;
      _themeMode = nextThemeMode;
      _themeAccent = nextThemeAccent;
    });
  }

  void _onBootstrapStoresChanged() {
    if (!mounted) return;
    final nextReady = _accountStore.loaded && _googleAuthStore.loaded;
    if (_bootstrapReady == nextReady) {
      return;
    }
    setState(() {
      _bootstrapReady = nextReady;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    return MaterialApp(
      title: 'PassRoot Vault',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: AppTheme.light(accent: _themeAccent),
      darkTheme: AppTheme.dark(accent: _themeAccent),
      home: _bootstrapReady
          ? AppStartGate(
              settingsStore: _settingsStore,
              accountStore: _accountStore,
              googleAuthStore: _googleAuthStore,
            )
          : const SplashScreen(),
    );
  }
}
