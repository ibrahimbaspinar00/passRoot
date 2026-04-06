import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/google_user_profile.dart';
import '../services/google_auth_service.dart';
import '../utils/app_logger.dart';

enum CloudSyncStatus { disconnected, unavailable, active, error }

class GoogleAuthStore extends ChangeNotifier {
  GoogleAuthStore({GoogleAuthService? service})
    : _service = service ?? GoogleAuthService();

  final GoogleAuthService _service;
  StreamSubscription<User?>? _authStateSubscription;

  bool _loaded = false;
  bool _busy = false;
  GoogleUserProfile? _user;
  String? _lastErrorMessage;

  bool get loaded => _loaded;
  bool get isBusy => _busy;
  bool get isSignedIn => _user != null;
  GoogleUserProfile? get user => _user;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get cloudSyncSupported => false;

  CloudSyncStatus get cloudSyncStatus {
    final hasError = (_lastErrorMessage ?? '').trim().isNotEmpty;
    if (hasError) {
      return CloudSyncStatus.error;
    }
    if (!isSignedIn) {
      return CloudSyncStatus.disconnected;
    }
    if (cloudSyncSupported) {
      return CloudSyncStatus.active;
    }
    return CloudSyncStatus.unavailable;
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    try {
      await _service.initialize();
      _authStateSubscription ??= _service.authStateChanges.listen(
        _onAuthStateChanged,
        onError: _onAuthStateError,
      );

      final restored = await _service.restoreSession();
      if (restored != null) {
        _user = _fromFirebaseUser(restored);
      } else {
        final current = _service.currentUser;
        _user = current == null ? null : _fromFirebaseUser(current);
      }
      _lastErrorMessage = null;
    } on GoogleAuthException catch (error, stackTrace) {
      AppLogger.warning(
        'GoogleAuthStore',
        'load failed',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'load'},
      );
      _lastErrorMessage = error.message;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GoogleAuthStore',
        'load failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
        context: const <String, Object?>{'operation': 'load'},
      );
      _lastErrorMessage =
          'Google giris durumu kontrol edilirken bir hata olustu.';
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    await _ensureLoaded();
    await _withBusy(() async {
      final firebaseUser = await _service.signIn();
      _user = _fromFirebaseUser(firebaseUser);
      _lastErrorMessage = null;
    });
  }

  Future<void> signOut() async {
    await _ensureLoaded();
    await _withBusy(() async {
      await _service.signOut();
      _user = null;
      _lastErrorMessage = null;
    });
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    await load();
  }

  void _onAuthStateChanged(User? firebaseUser) {
    _user = firebaseUser == null ? null : _fromFirebaseUser(firebaseUser);
    _lastErrorMessage = null;
    if (_loaded) {
      notifyListeners();
    }
  }

  void _onAuthStateError(Object error, StackTrace stackTrace) {
    AppLogger.warning(
      'GoogleAuthStore',
      'authStateChanges error',
      error: error,
      stackTrace: stackTrace,
      context: const <String, Object?>{'operation': 'auth_state_changes'},
    );
    _lastErrorMessage = error is GoogleAuthException
        ? error.message
        : 'Google oturum olayi islenirken bir hata olustu.';
    if (_loaded) {
      notifyListeners();
    }
  }

  GoogleUserProfile _fromFirebaseUser(User user) {
    final email = user.email?.trim() ?? '';
    final displayName = (user.displayName ?? '').trim();
    final fallbackName = email.contains('@')
        ? email.split('@').first.trim()
        : email;
    final safeName = displayName.isNotEmpty ? displayName : fallbackName;
    final photoUrl = (user.photoURL ?? '').trim();

    return GoogleUserProfile(
      id: user.uid,
      email: email,
      displayName: safeName.isNotEmpty ? safeName : 'Google User',
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    );
  }

  @override
  void dispose() {
    unawaited(_authStateSubscription?.cancel());
    _authStateSubscription = null;
    super.dispose();
  }
}
