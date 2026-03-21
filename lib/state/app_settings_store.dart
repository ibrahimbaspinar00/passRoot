import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../services/pin_security_service.dart';
import '../utils/app_logger.dart';

class AppSettingsStore extends ChangeNotifier {
  static const String _storageKey = 'passroot_app_settings_v1';

  AppSettingsStore({PinSecurityService? pinSecurityService})
    : _pinSecurityService = pinSecurityService ?? PinSecurityService();

  final PinSecurityService _pinSecurityService;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  bool _pinAvailable = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;
  bool get pinAvailable => _pinAvailable;
  PinSecurityService get pinSecurityService => _pinSecurityService;

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
      } on FormatException catch (error, stackTrace) {
        AppLogger.debug(
          'AppSettingsStore',
          'Ayarlar çözümlenemedi',
          error: error,
          stackTrace: stackTrace,
        );
        _settings = const AppSettings();
      }
    }

    try {
      await _pinSecurityService.migrateLegacyPin(_settings.pinCode);
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'AppSettingsStore',
        'Legacy PIN taşıma hatası',
        error: error,
        stackTrace: stackTrace,
      );
    }

    await refreshPinAvailability(notify: false);

    _loaded = true;
    notifyListeners();
  }

  Future<void> refreshPinAvailability({bool notify = true}) async {
    bool hasPin = false;
    try {
      hasPin = await _pinSecurityService.hasPin();
    } on Exception catch (error, stackTrace) {
      AppLogger.debug(
        'AppSettingsStore',
        'PIN erişim hatası',
        error: error,
        stackTrace: stackTrace,
      );
      hasPin = false;
    }

    final shouldPersistSettings =
        _settings.pinEnabled != hasPin || (_settings.pinCode ?? '').isNotEmpty;
    _pinAvailable = hasPin;

    if (shouldPersistSettings) {
      _settings = _settings.copyWith(pinEnabled: hasPin, pinCode: null);
      await _persist();
    }
    final lockChanged = await _ensureLockConfigurationConsistency();
    if (lockChanged) {
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
    if (value) {
      await refreshPinAvailability(notify: false);
      if (!_pinAvailable) {
        return;
      }
    }
    await _update(_settings.copyWith(appLockEnabled: value));
  }

  Future<void> setLockOnAppLaunch(bool value) async {
    await _update(_settings.copyWith(lockOnAppLaunch: value));
  }

  Future<void> setLockOnAppResume(bool value) async {
    await _update(_settings.copyWith(lockOnAppResume: value));
  }

  Future<void> setPinCode(String pin) async {
    await _pinSecurityService.setPin(pin.trim());
    _pinAvailable = true;
    await _update(_settings.copyWith(pinEnabled: true, pinCode: null));
  }

  Future<void> clearPinCode() async {
    await _pinSecurityService.clearPin();
    _pinAvailable = false;
    await _update(_settings.copyWith(pinEnabled: false, pinCode: null));
  }

  Future<bool> verifyPin(String pin) async {
    final result = await _pinSecurityService.verifyPinDetailed(pin);
    return result.success;
  }

  Future<PinVerificationResult> verifyPinDetailed(String pin) {
    return _pinSecurityService.verifyPinDetailed(pin);
  }

  Future<void> setAutoLockOption(AutoLockOption value) async {
    await _update(_settings.copyWith(autoLockOption: value));
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
    await _ensureLockConfigurationConsistency();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_settings.toJson()));
  }

  Future<bool> _ensureLockConfigurationConsistency() async {
    var changed = false;
    var next = _settings;

    if (!_pinAvailable && !next.appLockEnabled) {
      next = next.copyWith(appLockEnabled: true);
      changed = true;
    }

    if (!_pinAvailable && !next.lockOnAppLaunch) {
      next = next.copyWith(lockOnAppLaunch: true);
      changed = true;
    }

    if (changed) {
      _settings = next;
    }
    return changed;
  }
}
