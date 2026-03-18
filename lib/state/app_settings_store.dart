import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsStore extends ChangeNotifier {
  static const String _storageKey = 'passroot_app_settings_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  bool _biometricSupported = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;
  bool get biometricSupported => _biometricSupported;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _settings = AppSettings.fromJson(decoded);
        } else if (decoded is Map) {
          _settings = AppSettings.fromJson(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        _settings = const AppSettings();
      }
    }

    _loaded = true;
    notifyListeners();
    unawaited(refreshBiometricCapability());
  }

  Future<void> refreshBiometricCapability({bool notify = true}) async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final biometrics = await _localAuth.getAvailableBiometrics();
      _biometricSupported = supported && canCheck && biometrics.isNotEmpty;
    } catch (_) {
      _biometricSupported = false;
    }

    if (!_biometricSupported && _settings.biometricEnabled) {
      _settings = _settings.copyWith(biometricEnabled: false);
      await _persist();
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool value) async {
    await _update(_settings.copyWith(darkMode: value));
  }

  Future<void> setThemeAccent(AppThemeAccent value) async {
    await _update(_settings.copyWith(themeAccent: value));
  }

  Future<void> setRecordCardStyle(RecordCardStyle value) async {
    await _update(_settings.copyWith(cardStyle: value));
  }

  Future<void> setAppLockEnabled(bool value) async {
    final next = value
        ? _settings
        : _settings.copyWith(biometricEnabled: false);
    await _update(next.copyWith(appLockEnabled: value));
  }

  Future<void> setPinCode(String pin) async {
    await _update(_settings.copyWith(pinCode: pin.trim()));
  }

  Future<void> clearPinCode() async {
    await _update(_settings.copyWith(pinCode: null));
  }

  Future<void> setBiometricEnabled(bool value) async {
    if (value) {
      await refreshBiometricCapability();
      if (!_biometricSupported) return;
    }
    await _update(_settings.copyWith(biometricEnabled: value));
  }

  Future<void> setAutoLockOption(AutoLockOption value) async {
    await _update(_settings.copyWith(autoLockOption: value));
  }

  Future<void> setFirebaseSessionTimeoutEnabled(bool value) async {
    await _update(_settings.copyWith(firebaseSessionTimeoutEnabled: value));
  }

  Future<void> setFirebaseSessionTimeoutOption(
    FirebaseSessionTimeoutOption value,
  ) async {
    await _update(_settings.copyWith(firebaseSessionTimeoutOption: value));
  }

  Future<void> setLanguage(AppLanguage language) async {
    await _update(_settings.copyWith(language: language));
  }

  Future<void> setPasswordGeneratorSettings(
    PasswordGeneratorSettings value,
  ) async {
    await _update(_settings.copyWith(passwordGenerator: value));
  }

  Future<void> setNotificationSettings(
    SecurityNotificationSettings value,
  ) async {
    await _update(_settings.copyWith(notifications: value));
  }

  Future<void> setLastBackupNow() async {
    await _update(
      _settings.copyWith(lastBackupIso: DateTime.now().toIso8601String()),
    );
  }

  Future<void> _update(AppSettings value) async {
    _settings = value;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
  }
}
