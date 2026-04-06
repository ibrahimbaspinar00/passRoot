import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_profile.dart';
import '../security/secure_storage_service.dart';

class AccountStore extends ChangeNotifier {
  static const String _storageKey = 'passroot_account_state_v1';

  // Sensitive credential material must stay in secure storage.
  static const String _passwordHashKey = 'passroot_account_password_hash_v1';
  static const String _passwordSaltKey = 'passroot_account_password_salt_v1';
  static const String _passwordIterationsKey =
      'passroot_account_password_iter_v1';

  static const int _defaultIterations = 210000;
  static const int _minimumIterations = 100000;

  // Legacy SharedPreferences keys from older insecure account model.
  static const List<String> _legacyHashPrefKeys = <String>[
    _passwordHashKey,
    'passroot_account_password_hash',
    'account_password_hash',
  ];
  static const List<String> _legacySaltPrefKeys = <String>[
    _passwordSaltKey,
    'passroot_account_password_salt',
    'account_password_salt',
  ];
  static const List<String> _legacyIterationPrefKeys = <String>[
    _passwordIterationsKey,
    'passroot_account_password_iter',
    'account_password_iter',
  ];

  static const List<String> _legacySensitiveJsonKeys = <String>[
    'passwordHash',
    'passwordSalt',
    'passwordIterations',
    'passwordHashB64',
    'passwordSaltB64',
    'passwordIter',
    'credentials',
  ];

  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  AccountStore({SecureStorageService? secureStorageService})
    : _secureStorageService = secureStorageService ?? SecureStorageService();

  final SecureStorageService _secureStorageService;

  bool _loaded = false;
  bool _signedIn = false;
  AccountProfile? _profile;
  String? _passwordHashB64;
  String? _passwordSaltB64;
  int _iterations = _defaultIterations;

  bool get loaded => _loaded;
  bool get isSignedIn => _signedIn && hasRegisteredAccount;
  bool get isGuest => !isSignedIn;
  bool get hasRegisteredAccount => _profile != null;
  AccountProfile? get profile => _profile;

  String get accountStatusLabel {
    if (!hasRegisteredAccount) return 'Misafir Kullanici';
    return isSignedIn
        ? 'Kayitli Kullanici - Oturum Acik'
        : 'Kayitli Kullanici - Oturum Kapali';
  }

  bool get supportsUnauthenticatedPasswordReset => false;

  Future<void> load() async {
    _clearInMemoryState();
    _loaded = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      _CredentialMaterial? embeddedLegacyCredential;

      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            embeddedLegacyCredential = _extractLegacyCredentialFromState(
              decoded,
            );
            _hydrateFromMap(decoded);
          } else if (decoded is Map) {
            final asMap = decoded.cast<String, dynamic>();
            embeddedLegacyCredential = _extractLegacyCredentialFromState(asMap);
            _hydrateFromMap(asMap);
          }
        } on FormatException {
          _clearInMemoryState();
        }
      }

      await _loadCredentialMaterial(
        prefs: prefs,
        embeddedLegacyCredential: embeddedLegacyCredential,
      );

      if (!_isCredentialMaterialValid()) {
        _signedIn = false;
      }

      await _removeSensitiveMaterialFromPrefs(prefs);
    } on Exception {
      _clearInMemoryState();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? photoUrl,
  }) async {
    _ensureLoaded();
    if (hasRegisteredAccount) {
      throw const AccountOperationException(
        'Bu cihazda zaten kayitli bir hesap var. Giris yapabilir veya hesabi silebilirsiniz.',
      );
    }

    final normalizedName = _normalizeUsername(username);
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhoto = _normalizePhoto(photoUrl);
    final normalizedPassword = _normalizePassword(password);

    await _mutateAndPersist(() async {
      final salt = _randomBytes(16);
      final hash = await _hashPassword(
        normalizedPassword,
        salt,
        iterations: _defaultIterations,
      );
      final now = DateTime.now().toIso8601String();
      _profile = AccountProfile(
        username: normalizedName,
        email: normalizedEmail,
        photoUrl: normalizedPhoto,
        createdAtIso: now,
        updatedAtIso: now,
        lastLoginAtIso: now,
      );
      _passwordHashB64 = base64Encode(hash);
      _passwordSaltB64 = base64Encode(salt);
      _iterations = _defaultIterations;
      _signedIn = true;
    });

    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _ensureLoaded();
    final profile = _profile;
    if (profile == null || !_isCredentialMaterialValid()) {
      throw const AccountOperationException(
        'Kayitli hesap bulunamadi. Once kayit olmaniz gerekir.',
      );
    }

    final normalizedEmail = _normalizeEmail(email);
    final normalizedPassword = _normalizePassword(password);
    if (normalizedEmail != profile.email) {
      throw const AccountOperationException(
        'E-posta veya sifre hatali. Lutfen tekrar deneyin.',
      );
    }

    final verified = await _verifyPassword(normalizedPassword);
    if (!verified) {
      throw const AccountOperationException(
        'E-posta veya sifre hatali. Lutfen tekrar deneyin.',
      );
    }

    await _mutateAndPersist(() async {
      final now = DateTime.now().toIso8601String();
      _profile = profile.copyWith(lastLoginAtIso: now, updatedAtIso: now);
      _signedIn = true;
    });

    notifyListeners();
  }

  Future<void> signOut() async {
    _ensureLoaded();
    if (!hasRegisteredAccount || !_signedIn) {
      return;
    }

    await _mutateAndPersist(() async {
      _signedIn = false;
    });

    notifyListeners();
  }

  Future<void> updateProfile({
    required String username,
    String? photoUrl,
  }) async {
    _ensureSignedIn();
    final profile = _profile!;
    final normalizedName = _normalizeUsername(username);
    final normalizedPhoto = _normalizePhoto(photoUrl);

    await _mutateAndPersist(() async {
      final now = DateTime.now().toIso8601String();
      _profile = profile.copyWith(
        username: normalizedName,
        photoUrl: normalizedPhoto,
        updatedAtIso: now,
      );
    });

    notifyListeners();
  }

  Future<void> updatePhoto(String? photoUrl) async {
    _ensureSignedIn();
    final profile = _profile!;
    final normalizedPhoto = _normalizePhoto(photoUrl);

    await _mutateAndPersist(() async {
      final now = DateTime.now().toIso8601String();
      _profile = profile.copyWith(photoUrl: normalizedPhoto, updatedAtIso: now);
    });

    notifyListeners();
  }

  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    _ensureSignedIn();
    final profile = _profile!;
    final normalizedEmail = _normalizeEmail(newEmail);
    final normalizedPassword = _normalizePassword(currentPassword);
    if (normalizedEmail == profile.email) {
      throw const AccountOperationException(
        'Yeni e-posta mevcut e-posta ile ayni olamaz.',
      );
    }

    final verified = await _verifyPassword(normalizedPassword);
    if (!verified) {
      throw const AccountOperationException('Mevcut sifre dogrulanamadi.');
    }

    await _mutateAndPersist(() async {
      final now = DateTime.now().toIso8601String();
      _profile = profile.copyWith(email: normalizedEmail, updatedAtIso: now);
    });

    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _ensureSignedIn();
    final normalizedCurrent = _normalizePassword(currentPassword);
    final normalizedNext = _normalizePassword(newPassword);
    if (normalizedCurrent == normalizedNext) {
      throw const AccountOperationException(
        'Yeni sifre mevcut sifreden farkli olmalidir.',
      );
    }

    final verified = await _verifyPassword(normalizedCurrent);
    if (!verified) {
      throw const AccountOperationException('Mevcut sifre dogrulanamadi.');
    }

    await _mutateAndPersist(() async {
      final salt = _randomBytes(16);
      final hash = await _hashPassword(
        normalizedNext,
        salt,
        iterations: _defaultIterations,
      );
      _passwordHashB64 = base64Encode(hash);
      _passwordSaltB64 = base64Encode(salt);
      _iterations = _defaultIterations;
      final now = DateTime.now().toIso8601String();
      _profile = _profile?.copyWith(updatedAtIso: now);
    });

    notifyListeners();
  }

  Future<void> resetPasswordWithEmail({
    required String email,
    required String newPassword,
  }) async {
    // Keep signature for backward compatibility with older callers, but do not
    // allow unauthenticated reset in local-only security model.
    _normalizeEmail(email);
    _normalizePassword(newPassword);
    throw const AccountOperationException(
      'Sifre sifirlama devre disidir. Passroot yerel guvenlik modeli nedeniyle e-posta eslesmesiyle reset yapmaz; sifre degisikligi yalnizca mevcut sifre dogrulandiginda yapilir.',
    );
  }

  Future<void> deleteAccount({required String currentPassword}) async {
    _ensureSignedIn();
    final normalizedPassword = _normalizePassword(currentPassword);
    final verified = await _verifyPassword(normalizedPassword);
    if (!verified) {
      throw const AccountOperationException(
        'Sifre dogrulanamadi. Hesap silinmedi.',
      );
    }

    await _mutateAndPersist(() async {
      _clearInMemoryState();
    });

    notifyListeners();
  }

  Future<void> _mutateAndPersist(Future<void> Function() mutation) async {
    final snapshot = _snapshot();
    try {
      await mutation();
      await _persist();
    } on AccountOperationException {
      _restoreFromSnapshot(snapshot);
      rethrow;
    } on Exception {
      _restoreFromSnapshot(snapshot);
      throw const AccountOperationException(
        'Hesap verisi kaydedilemedi. Lutfen tekrar deneyin.',
      );
    }
  }

  Future<void> _persist() async {
    final prefs = await _prefsOrThrow();
    await _persistCredentialMaterial();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
    await _removeSensitiveMaterialFromPrefs(prefs);
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'profile': _profile?.toJson(),
      'signedIn': _signedIn,
      'schemaVersion': 2,
    };
  }

  void _hydrateFromMap(Map<String, dynamic> json) {
    final profileMap = json['profile'];
    if (profileMap is Map<String, dynamic>) {
      _profile = AccountProfile.fromJson(profileMap);
    } else if (profileMap is Map) {
      _profile = AccountProfile.fromJson(profileMap.cast<String, dynamic>());
    } else {
      _profile = null;
    }

    _signedIn = json['signedIn'] == true;
  }

  _CredentialMaterial? _extractLegacyCredentialFromState(
    Map<String, dynamic> json,
  ) {
    final credentialsNode = json['credentials'];
    Map<String, dynamic>? credentialsMap;
    if (credentialsNode is Map<String, dynamic>) {
      credentialsMap = credentialsNode;
    } else if (credentialsNode is Map) {
      credentialsMap = credentialsNode.cast<String, dynamic>();
    }

    final hash =
        _readNonEmptyString(credentialsMap?['passwordHash']) ??
        _readNonEmptyString(credentialsMap?['hash']) ??
        _readNonEmptyString(json['passwordHashB64']) ??
        _readNonEmptyString(json['passwordHash']);
    final salt =
        _readNonEmptyString(credentialsMap?['passwordSalt']) ??
        _readNonEmptyString(credentialsMap?['salt']) ??
        _readNonEmptyString(json['passwordSaltB64']) ??
        _readNonEmptyString(json['passwordSalt']);
    final iterationsRaw =
        _readNonEmptyString(credentialsMap?['passwordIterations']) ??
        _readNonEmptyString(credentialsMap?['iter']) ??
        _readNonEmptyString(json['passwordIterations']) ??
        _readNonEmptyString(json['passwordIter']);
    final iterations = _parseIterations(iterationsRaw);

    if ((hash ?? '').isEmpty || (salt ?? '').isEmpty) {
      return null;
    }

    return _CredentialMaterial(
      hashB64: hash!,
      saltB64: salt!,
      iterations: iterations,
    );
  }

  Future<void> _loadCredentialMaterial({
    required SharedPreferences prefs,
    _CredentialMaterial? embeddedLegacyCredential,
  }) async {
    _passwordHashB64 = await _tryReadSecure(_passwordHashKey);
    _passwordSaltB64 = await _tryReadSecure(_passwordSaltKey);
    final iterationRaw = await _tryReadSecure(_passwordIterationsKey);
    _iterations = _parseIterations(iterationRaw);

    if (_isCredentialMaterialValid()) {
      return;
    }

    final migrated = await _migrateLegacyCredentialMaterial(
      prefs: prefs,
      embeddedLegacyCredential: embeddedLegacyCredential,
    );
    if (migrated == null) {
      _passwordHashB64 = null;
      _passwordSaltB64 = null;
      _iterations = _defaultIterations;
      return;
    }

    _passwordHashB64 = migrated.hashB64;
    _passwordSaltB64 = migrated.saltB64;
    _iterations = migrated.iterations;
  }

  Future<_CredentialMaterial?> _migrateLegacyCredentialMaterial({
    required SharedPreferences prefs,
    _CredentialMaterial? embeddedLegacyCredential,
  }) async {
    final fromPrefs =
        embeddedLegacyCredential ?? _readLegacyCredentialFromPrefs(prefs);
    if (fromPrefs == null) {
      return null;
    }

    if (!_isCredentialPayloadWellFormed(fromPrefs)) {
      await _clearLegacyCredentialPrefs(prefs);
      await _removeSensitiveMaterialFromPrefs(prefs);
      return null;
    }

    final wrote = await _writeCredentialMaterialToSecure(fromPrefs);
    if (!wrote) {
      return null;
    }

    await _clearLegacyCredentialPrefs(prefs);
    await _removeSensitiveMaterialFromPrefs(prefs);
    return fromPrefs;
  }

  _CredentialMaterial? _readLegacyCredentialFromPrefs(SharedPreferences prefs) {
    final hash = _firstNonEmptyString(_legacyHashPrefKeys.map(prefs.getString));
    final salt = _firstNonEmptyString(_legacySaltPrefKeys.map(prefs.getString));
    final iterationRaw = _firstNonEmptyString(
      _legacyIterationPrefKeys.map(prefs.getString),
    );

    if ((hash ?? '').isEmpty || (salt ?? '').isEmpty) {
      return null;
    }

    return _CredentialMaterial(
      hashB64: hash!,
      saltB64: salt!,
      iterations: _parseIterations(iterationRaw),
    );
  }

  Future<void> _removeSensitiveMaterialFromPrefs(
    SharedPreferences prefs,
  ) async {
    await _clearLegacyCredentialPrefs(prefs);

    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    Map<String, dynamic>? decoded;
    try {
      final object = jsonDecode(raw);
      if (object is Map<String, dynamic>) {
        decoded = Map<String, dynamic>.from(object);
      } else if (object is Map) {
        decoded = Map<String, dynamic>.from(object.cast<String, dynamic>());
      }
    } on FormatException {
      return;
    }
    if (decoded == null) {
      return;
    }

    var changed = false;
    for (final key in _legacySensitiveJsonKeys) {
      changed = decoded.remove(key) != null || changed;
    }

    final credentialsNode = decoded['credentials'];
    if (credentialsNode is Map || credentialsNode is Map<String, dynamic>) {
      decoded.remove('credentials');
      changed = true;
    }

    if (!changed) {
      return;
    }
    await prefs.setString(_storageKey, jsonEncode(decoded));
  }

  Future<void> _clearLegacyCredentialPrefs(SharedPreferences prefs) async {
    for (final key in <String>[
      ..._legacyHashPrefKeys,
      ..._legacySaltPrefKeys,
      ..._legacyIterationPrefKeys,
    ]) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }

  String? _readNonEmptyString(Object? value) {
    final raw = value is String ? value.trim() : '';
    return raw.isEmpty ? null : raw;
  }

  String? _firstNonEmptyString(Iterable<String?> values) {
    for (final value in values) {
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  bool _isCredentialPayloadWellFormed(_CredentialMaterial material) {
    try {
      final hash = base64Decode(material.hashB64);
      final salt = base64Decode(material.saltB64);
      return hash.isNotEmpty && salt.isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  int _parseIterations(String? raw) {
    final parsed = int.tryParse((raw ?? '').trim());
    if (parsed == null || parsed < _minimumIterations) {
      return _defaultIterations;
    }
    return parsed;
  }

  Future<String?> _tryReadSecure(String key) async {
    try {
      return (await _secureStorageService.read(key))?.trim();
    } on Exception {
      return null;
    }
  }

  Future<bool> _writeCredentialMaterialToSecure(
    _CredentialMaterial material,
  ) async {
    try {
      await _secureStorageService.write(
        key: _passwordHashKey,
        value: material.hashB64,
      );
      await _secureStorageService.write(
        key: _passwordSaltKey,
        value: material.saltB64,
      );
      await _secureStorageService.write(
        key: _passwordIterationsKey,
        value: '${material.iterations}',
      );
      return true;
    } on Exception {
      return false;
    }
  }

  void _clearInMemoryState() {
    _profile = null;
    _passwordHashB64 = null;
    _passwordSaltB64 = null;
    _iterations = _defaultIterations;
    _signedIn = false;
  }

  _AccountSnapshot _snapshot() {
    return _AccountSnapshot(
      profile: _profile,
      signedIn: _signedIn,
      passwordHashB64: _passwordHashB64,
      passwordSaltB64: _passwordSaltB64,
      iterations: _iterations,
    );
  }

  void _restoreFromSnapshot(_AccountSnapshot snapshot) {
    _profile = snapshot.profile;
    _signedIn = snapshot.signedIn;
    _passwordHashB64 = snapshot.passwordHashB64;
    _passwordSaltB64 = snapshot.passwordSaltB64;
    _iterations = snapshot.iterations;
  }

  Future<SharedPreferences> _prefsOrThrow() async {
    try {
      return await SharedPreferences.getInstance();
    } on Exception {
      throw const AccountOperationException(
        'Hesap tercih depolamasina erisilemedi.',
      );
    }
  }

  void _ensureLoaded() {
    if (!_loaded) {
      throw const AccountOperationException(
        'Hesap servisi henuz hazir degil. Lutfen tekrar deneyin.',
      );
    }
  }

  void _ensureSignedIn() {
    _ensureLoaded();
    if (!isSignedIn || _profile == null) {
      throw const AccountOperationException(
        'Bu islem icin once giris yapmaniz gerekiyor.',
      );
    }
  }

  String _normalizeUsername(String value) {
    final normalized = value.trim();
    if (normalized.length < 2) {
      throw const AccountOperationException(
        'Kullanici adi en az 2 karakter olmali.',
      );
    }
    if (normalized.length > 40) {
      throw const AccountOperationException(
        'Kullanici adi 40 karakterden uzun olamaz.',
      );
    }
    return normalized;
  }

  String _normalizeEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      throw const AccountOperationException(
        'Gecerli bir e-posta adresi girin.',
      );
    }
    return normalized;
  }

  String _normalizePassword(String value) {
    final normalized = value.trim();
    if (normalized.length < 8) {
      throw const AccountOperationException('Sifre en az 8 karakter olmali.');
    }
    return normalized;
  }

  String? _normalizePhoto(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw const AccountOperationException(
        'Profil fotografi icin gecerli bir URL girin.',
      );
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const AccountOperationException(
        'Profil fotografi URL semasi http veya https olmali.',
      );
    }
    return normalized;
  }

  bool _isCredentialMaterialValid() {
    return (_passwordHashB64 ?? '').isNotEmpty &&
        (_passwordSaltB64 ?? '').isNotEmpty;
  }

  Future<void> _persistCredentialMaterial() async {
    if (!_isCredentialMaterialValid()) {
      await _clearCredentialMaterial();
      return;
    }
    try {
      await _secureStorageService.write(
        key: _passwordHashKey,
        value: _passwordHashB64!,
      );
      await _secureStorageService.write(
        key: _passwordSaltKey,
        value: _passwordSaltB64!,
      );
      await _secureStorageService.write(
        key: _passwordIterationsKey,
        value: '$_iterations',
      );
    } on Exception {
      throw const AccountOperationException(
        'Hesap kimlik materyali guvenli depoya yazilamadi.',
      );
    }
  }

  Future<void> _clearCredentialMaterial() async {
    try {
      await _secureStorageService.delete(_passwordHashKey);
      await _secureStorageService.delete(_passwordSaltKey);
      await _secureStorageService.delete(_passwordIterationsKey);
    } on Exception {
      throw const AccountOperationException(
        'Hesap kimlik materyali guvenli depodan temizlenemedi.',
      );
    }
  }

  Future<bool> _verifyPassword(String value) async {
    if (!_isCredentialMaterialValid()) {
      return false;
    }
    try {
      final hash = base64Decode(_passwordHashB64!);
      final salt = base64Decode(_passwordSaltB64!);
      final current = await _hashPassword(value, salt, iterations: _iterations);
      return _constantTimeEquals(hash, current);
    } on FormatException {
      return false;
    }
  }

  Future<List<int>> _hashPassword(
    String password,
    List<int> salt, {
    required int iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < left.length; i++) {
      result |= left[i] ^ right[i];
    }
    return result == 0;
  }
}

class AccountOperationException implements Exception {
  const AccountOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _CredentialMaterial {
  const _CredentialMaterial({
    required this.hashB64,
    required this.saltB64,
    required this.iterations,
  });

  final String hashB64;
  final String saltB64;
  final int iterations;
}

class _AccountSnapshot {
  const _AccountSnapshot({
    required this.profile,
    required this.signedIn,
    required this.passwordHashB64,
    required this.passwordSaltB64,
    required this.iterations,
  });

  final AccountProfile? profile;
  final bool signedIn;
  final String? passwordHashB64;
  final String? passwordSaltB64;
  final int iterations;
}
