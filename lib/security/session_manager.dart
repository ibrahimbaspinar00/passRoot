import 'package:flutter/foundation.dart';

enum SessionPhase { booting, pinSetupRequired, locked, unlocked }

class SessionManager extends ChangeNotifier {
  SessionPhase _phase = SessionPhase.booting;
  bool _isAuthenticating = false;
  bool _isPinSetupBusy = false;
  String? _errorText;

  SessionPhase get phase => _phase;
  bool get isBooting => _phase == SessionPhase.booting;
  bool get needsPinSetup => _phase == SessionPhase.pinSetupRequired;
  bool get isLocked => _phase == SessionPhase.locked;
  bool get isUnlocked => _phase == SessionPhase.unlocked;
  bool get isAuthenticating => _isAuthenticating;
  bool get isPinSetupBusy => _isPinSetupBusy;
  String? get errorText => _errorText;

  void startBooting() {
    _phase = SessionPhase.booting;
    _isAuthenticating = false;
    _isPinSetupBusy = false;
    _errorText = null;
    notifyListeners();
  }

  void requirePinSetup({String? errorText}) {
    _phase = SessionPhase.pinSetupRequired;
    _isAuthenticating = false;
    _isPinSetupBusy = false;
    _errorText = errorText;
    notifyListeners();
  }

  void lock({String? errorText}) {
    _phase = SessionPhase.locked;
    _isAuthenticating = false;
    _isPinSetupBusy = false;
    _errorText = errorText;
    notifyListeners();
  }

  void unlock() {
    _phase = SessionPhase.unlocked;
    _isAuthenticating = false;
    _isPinSetupBusy = false;
    _errorText = null;
    notifyListeners();
  }

  bool beginAuthentication() {
    if (_phase != SessionPhase.locked || _isAuthenticating) {
      return false;
    }
    _isAuthenticating = true;
    _errorText = null;
    notifyListeners();
    return true;
  }

  void endAuthentication({String? errorText}) {
    _isAuthenticating = false;
    _errorText = errorText;
    notifyListeners();
  }

  bool beginPinSetup() {
    if (_phase != SessionPhase.pinSetupRequired || _isPinSetupBusy) {
      return false;
    }
    _isPinSetupBusy = true;
    _errorText = null;
    notifyListeners();
    return true;
  }

  void endPinSetupWithError(String message) {
    _isPinSetupBusy = false;
    _errorText = message;
    notifyListeners();
  }
}
