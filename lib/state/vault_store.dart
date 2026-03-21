import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/vault_record.dart';
import '../services/encrypted_vault_storage_service.dart';
import '../services/vault_transfer_service.dart';
import '../utils/app_logger.dart';
import '../utils/password_utils.dart';

class VaultStore extends ChangeNotifier {
  VaultStore({
    List<VaultRecord>? seed,
    EncryptedVaultStorageService? storageService,
  }) : _records = List<VaultRecord>.from(seed ?? const <VaultRecord>[]),
       _storageService = storageService ?? EncryptedVaultStorageService() {
    unawaited(_loadFromStorage());
  }

  final List<VaultRecord> _records;
  final EncryptedVaultStorageService _storageService;
  bool _isLoading = true;
  VaultStorageIssue? _storageIssue;
  final Map<String, _DerivedPasswordData> _derivedPasswordCache =
      <String, _DerivedPasswordData>{};
  final Map<RecordCategory, UnmodifiableListView<VaultRecord>>
  _categoryViewCache = <RecordCategory, UnmodifiableListView<VaultRecord>>{};
  List<VaultRecord> _sortedCache = const <VaultRecord>[];
  UnmodifiableListView<VaultRecord> _sortedView =
      UnmodifiableListView<VaultRecord>(const <VaultRecord>[]);
  UnmodifiableListView<VaultRecord> _strongView =
      UnmodifiableListView<VaultRecord>(const <VaultRecord>[]);
  UnmodifiableListView<VaultRecord> _weakView =
      UnmodifiableListView<VaultRecord>(const <VaultRecord>[]);
  Map<String, List<VaultRecord>> _repeatedGroupsCache =
      const <String, List<VaultRecord>>{};
  int _repeatedRecordCountCache = 0;
  int _repeatedGroupCountCache = 0;
  bool _sortedCacheDirty = true;
  bool _categoryCacheDirty = true;
  bool _securitySummaryDirty = true;

  bool get isLoading => _isLoading;
  VaultStorageIssue? get storageIssue => _storageIssue;
  bool get hasStorageIssue => _storageIssue != null;

  Future<void> retryLoadFromStorage() {
    return _loadFromStorage(forceReload: true);
  }

  Future<void> clearCorruptedStorage() async {
    try {
      await _storageService.clear();
      _records.clear();
      _markCachesDirty(clearDerivedCache: true);
      _clearStorageIssue();
      notifyListeners();
    } on EncryptedVaultStorageException catch (error, stackTrace) {
      _logStorageError('clear', error, stackTrace);
      _setStorageIssue(_issueFromStorageException(error));
      throw VaultStoreException(
        'Bozuk kasa verisi temizlenemedi. LÃ¼tfen tekrar deneyin.',
      );
    } on Exception catch (error, stackTrace) {
      _logStorageError('clear', error, stackTrace);
      _setStorageIssue(
        VaultStorageIssue(
          title: 'Kasa temizlenemedi',
          message:
              'Kasa verisi temizlenemedi. Cihaz depolama iznini ve boÅŸ alanÄ± kontrol edin.',
          code: 'vault_clear_failed',
          type: VaultStorageIssueType.writeFailure,
        ),
      );
      throw VaultStoreException(
        'Kasa verisi temizlenemedi. LÃ¼tfen depolama alanÄ±nÄ± kontrol edin.',
      );
    }
  }

  Future<void> _loadFromStorage({bool forceReload = false}) async {
    _isLoading = true;
    if (forceReload) {
      notifyListeners();
    }
    try {
      final raw = await _storageService.loadJsonPayload();
      if (raw == null || raw.trim().isEmpty) {
        _records.clear();
        _markCachesDirty(clearDerivedCache: true);
        _clearStorageIssue(notify: false);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Kasa verisi beklenen listede deÄŸil.');
      }

      final loaded = <VaultRecord>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loaded.add(VaultRecord.fromJson(item));
        } else if (item is Map) {
          loaded.add(VaultRecord.fromJson(item.cast<String, dynamic>()));
        }
      }
      _records
        ..clear()
        ..addAll(loaded);
      _markCachesDirty(clearDerivedCache: true);
      _clearStorageIssue(notify: false);
    } on EncryptedVaultStorageException catch (error, stackTrace) {
      _logStorageError('load', error, stackTrace);
      _setStorageIssue(_issueFromStorageException(error), notify: false);
    } on FormatException catch (error, stackTrace) {
      _logStorageError('decode', error, stackTrace);
      _setStorageIssue(
        VaultStorageIssue(
          title: 'Kasa verisi bozuk',
          message:
              'Kasa verisi okunamadÄ±. Åifreli iÃ§erik bozulmuÅŸ olabilir. LÃ¼tfen yedekten geri yÃ¼klemeyi deneyin.',
          code: 'vault_payload_corrupted',
          type: VaultStorageIssueType.corruptedPayload,
        ),
        notify: false,
      );
    } on Exception catch (error, stackTrace) {
      _logStorageError('load', error, stackTrace);
      _setStorageIssue(
        VaultStorageIssue(
          title: 'Kasa verisi okunamadÄ±',
          message:
              'Kasa verisi ÅŸu anda okunamÄ±yor. Tekrar deneyin veya yedekten geri yÃ¼kleyin.',
          code: 'vault_read_failed',
          type: VaultStorageIssueType.readFailure,
        ),
        notify: false,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _commitRecords(
    List<VaultRecord> nextRecords, {
    required String operation,
  }) async {
    final payload = nextRecords.map((record) => record.toJson()).toList();
    try {
      await _storageService.saveJsonPayload(jsonEncode(payload));
    } on EncryptedVaultStorageException catch (error, stackTrace) {
      _logStorageError(operation, error, stackTrace);
      _setStorageIssue(_issueFromStorageException(error));
      throw VaultStoreException(
        'Veri cihaza kaydedilemedi. LÃ¼tfen tekrar deneyin.',
      );
    } on Exception catch (error, stackTrace) {
      _logStorageError(operation, error, stackTrace);
      _setStorageIssue(
        VaultStorageIssue(
          title: 'Kasa kaydedilemedi',
          message:
              'DeÄŸiÅŸiklikler cihaza yazÄ±lamadÄ±. Depolama alanÄ±nÄ± kontrol edip tekrar deneyin.',
          code: 'vault_write_failed',
          type: VaultStorageIssueType.writeFailure,
        ),
      );
      throw VaultStoreException(
        'DeÄŸiÅŸiklikler cihaza kaydedilemedi. LÃ¼tfen tekrar deneyin.',
      );
    }

    _records
      ..clear()
      ..addAll(nextRecords);
    _markCachesDirty(clearDerivedCache: true);
    _clearStorageIssue(notify: false);
    notifyListeners();
  }

  void _markCachesDirty({bool clearDerivedCache = false}) {
    _sortedCacheDirty = true;
    _categoryCacheDirty = true;
    _securitySummaryDirty = true;
    if (clearDerivedCache) {
      _derivedPasswordCache.clear();
    }
  }

  void _logStorageError(String stage, Object error, StackTrace stackTrace) {
    AppLogger.debug(
      'VaultStore/$stage',
      'Storage operation failed',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _setStorageIssue(VaultStorageIssue issue, {bool notify = true}) {
    _storageIssue = issue;
    if (notify) {
      notifyListeners();
    }
  }

  void _clearStorageIssue({bool notify = false}) {
    if (_storageIssue == null) {
      return;
    }
    _storageIssue = null;
    if (notify) {
      notifyListeners();
    }
  }

  VaultStorageIssue _issueFromStorageException(
    EncryptedVaultStorageException error,
  ) {
    switch (error.code) {
      case EncryptedVaultStorageErrorCode.decryptionFailed:
      case EncryptedVaultStorageErrorCode.invalidPayload:
        return VaultStorageIssue(
          title: 'Kasa verisi Ã§Ã¶zÃ¼mlenemedi',
          message:
              'Kasa verisi aÃ§Ä±lamadÄ±. Åifreleme verisi bozulmuÅŸ olabilir. Yedekten geri yÃ¼klemeyi deneyin.',
          code: 'vault_decrypt_failed',
          type: VaultStorageIssueType.corruptedPayload,
        );
      case EncryptedVaultStorageErrorCode.readFailed:
      case EncryptedVaultStorageErrorCode.secureStorageUnavailable:
        return VaultStorageIssue(
          title: 'Kasa verisine eriÅŸilemiyor',
          message:
              'Depolama alanÄ±na eriÅŸilemedi. UygulamayÄ± yeniden baÅŸlatÄ±p tekrar deneyin.',
          code: 'vault_read_failed',
          type: VaultStorageIssueType.readFailure,
        );
      case EncryptedVaultStorageErrorCode.writeFailed:
        return VaultStorageIssue(
          title: 'Kasa kaydedilemedi',
          message:
              'DeÄŸiÅŸiklikler cihaza kaydedilemedi. Depolama alanÄ±nÄ± kontrol edip tekrar deneyin.',
          code: 'vault_write_failed',
          type: VaultStorageIssueType.writeFailure,
        );
    }
  }

  UnmodifiableListView<VaultRecord> get records =>
      UnmodifiableListView<VaultRecord>(_records);

  List<VaultRecord> get sortedRecords {
    if (_sortedCacheDirty) {
      _sortedCache = List<VaultRecord>.from(_records)
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });
      _sortedView = UnmodifiableListView<VaultRecord>(_sortedCache);
      _sortedCacheDirty = false;
      _categoryCacheDirty = true;
    }
    return _sortedView;
  }

  List<VaultRecord> recordsForCategory(RecordCategory category) {
    if (_categoryCacheDirty) {
      _rebuildCategoryCache();
    }
    return _categoryViewCache[category] ??
        UnmodifiableListView<VaultRecord>(const <VaultRecord>[]);
  }

  Future<void> replaceAllRecords(List<VaultRecord> records) {
    return _commitRecords(
      List<VaultRecord>.from(records),
      operation: 'replace_all_records',
    );
  }

  Future<void> clearAllRecords() {
    return _commitRecords(
      const <VaultRecord>[],
      operation: 'clear_all_records',
    );
  }

  Future<void> addRecord(VaultRecord record) {
    final next = List<VaultRecord>.from(_records)..add(record);
    return _commitRecords(next, operation: 'add_record');
  }

  Future<void> updateRecord(VaultRecord updated) {
    final index = _records.indexWhere((record) => record.id == updated.id);
    if (index == -1) {
      return Future<void>.value();
    }
    final next = List<VaultRecord>.from(_records)..[index] = updated;
    return _commitRecords(next, operation: 'update_record');
  }

  Future<void> deleteRecord(String id) {
    final next = List<VaultRecord>.from(_records)
      ..removeWhere((record) => record.id == id);
    return _commitRecords(next, operation: 'delete_record');
  }

  Future<void> toggleFavorite(String id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return Future<void>.value();
    }
    final next = List<VaultRecord>.from(_records);
    next[index] = next[index].copyWith(
      isFavorite: !_records[index].isFavorite,
      updatedAt: DateTime.now(),
    );
    return _commitRecords(next, operation: 'toggle_favorite');
  }

  void _rebuildCategoryCache() {
    // Performance: cache filtered category lists to avoid repeated where/toList in UI rebuilds.
    final buckets = <RecordCategory, List<VaultRecord>>{
      for (final category in RecordCategory.values) category: <VaultRecord>[],
    };
    for (final record in sortedRecords) {
      buckets[record.category]!.add(record);
    }
    _categoryViewCache
      ..clear()
      ..addEntries(
        buckets.entries.map(
          (entry) =>
              MapEntry<RecordCategory, UnmodifiableListView<VaultRecord>>(
                entry.key,
                UnmodifiableListView<VaultRecord>(entry.value),
              ),
        ),
      );
    _categoryCacheDirty = false;
  }

  PasswordAnalysis analysisForRecord(VaultRecord record) {
    return _derivePasswordData(record).analysis;
  }

  String maskedPasswordForRecord(VaultRecord record) {
    return _derivePasswordData(record).maskedPassword;
  }

  _DerivedPasswordData _derivePasswordData(VaultRecord record) {
    final cached = _derivedPasswordCache[record.id];
    if (cached != null && cached.rawPassword == record.password) {
      return cached;
    }

    final next = _DerivedPasswordData(
      rawPassword: record.password,
      analysis: analyzePassword(record.password),
      maskedPassword: _maskPassword(record.password),
    );
    _derivedPasswordCache[record.id] = next;
    return next;
  }

  String _maskPassword(String password) {
    if (password.length <= 3) return '***';
    final hiddenLength = password.length - 3;
    return '${List.filled(hiddenLength, '*').join()}${password.substring(hiddenLength)}';
  }

  int get totalCount => _records.length;

  int get favoriteCount => _records.where((record) => record.isFavorite).length;

  List<VaultRecord> get strongRecords {
    _ensureSecuritySummaryCache();
    return _strongView;
  }

  List<VaultRecord> get weakRecords {
    _ensureSecuritySummaryCache();
    return _weakView;
  }

  Map<String, List<VaultRecord>> get repeatedPasswordGroups {
    _ensureSecuritySummaryCache();
    return _repeatedGroupsCache;
  }

  int get repeatedRecordCount {
    _ensureSecuritySummaryCache();
    return _repeatedRecordCountCache;
  }

  int get repeatedGroupCount {
    _ensureSecuritySummaryCache();
    return _repeatedGroupCountCache;
  }

  void _ensureSecuritySummaryCache() {
    if (!_securitySummaryDirty) {
      return;
    }

    final strong = <VaultRecord>[];
    final weak = <VaultRecord>[];
    final repeatedMap = <String, List<VaultRecord>>{};

    for (final record in sortedRecords) {
      final analysis = _derivePasswordData(record).analysis;
      if (analysis.strength == PasswordStrength.strong) {
        strong.add(record);
      } else if (analysis.strength == PasswordStrength.weak) {
        weak.add(record);
      }

      final normalizedPassword = record.password.trim();
      if (normalizedPassword.isEmpty) {
        continue;
      }
      repeatedMap
          .putIfAbsent(record.password, () => <VaultRecord>[])
          .add(record);
    }

    repeatedMap.removeWhere((_, value) => value.length < 2);
    _strongView = UnmodifiableListView<VaultRecord>(strong);
    _weakView = UnmodifiableListView<VaultRecord>(weak);
    _repeatedGroupsCache = Map<String, List<VaultRecord>>.unmodifiable(
      repeatedMap.map(
        (key, value) => MapEntry<String, List<VaultRecord>>(
          key,
          List<VaultRecord>.unmodifiable(value),
        ),
      ),
    );
    _repeatedRecordCountCache = _repeatedGroupsCache.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    _repeatedGroupCountCache = _repeatedGroupsCache.length;
    _securitySummaryDirty = false;
  }

  List<Map<String, dynamic>> toJsonList() {
    return _records.map((record) => record.toJson()).toList();
  }

  String encodeJson({bool pretty = true}) {
    final payload = <String, dynamic>{
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'records': toJsonList(),
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(payload)
        : jsonEncode(payload);
  }

  Future<String> encodeJsonInBackground({bool pretty = false}) async {
    final recordsPayload = toJsonList();
    return VaultTransferService.buildExportJson(
      records: recordsPayload,
      pretty: pretty,
    );
  }

  Future<int> importFromJsonString(String raw) async {
    final payload = await VaultTransferService.parseVaultJsonRecords(raw);
    final parsed = payload
        .map((item) => VaultRecord.fromJson(item))
        .toList(growable: false);
    await replaceAllRecords(parsed);
    return parsed.length;
  }

  Future<int> importFromCsvString(String raw) async {
    final payload = await VaultTransferService.parseVaultCsvRecords(raw);
    final parsed = payload
        .map((item) => VaultRecord.fromJson(item))
        .toList(growable: false);
    await replaceAllRecords(parsed);
    return parsed.length;
  }

  Map<RecordCategory, int> get categoryCount {
    final map = <RecordCategory, int>{};
    for (final record in _records) {
      map[record.category] = (map[record.category] ?? 0) + 1;
    }
    return map;
  }

  List<MapEntry<RecordCategory, int>> topCategories({int limit = 3}) {
    final list = categoryCount.entries.toList();
    list.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) return countCompare;
      return a.key.label.compareTo(b.key.label);
    });
    return list.take(limit).toList();
  }

  Color strengthColor(PasswordStrength strength) {
    return switch (strength) {
      PasswordStrength.strong => const Color(0xFF1D8F62),
      PasswordStrength.medium => const Color(0xFFCA8A04),
      PasswordStrength.weak => const Color(0xFFDC2626),
    };
  }
}

class _DerivedPasswordData {
  const _DerivedPasswordData({
    required this.rawPassword,
    required this.analysis,
    required this.maskedPassword,
  });

  final String rawPassword;
  final PasswordAnalysis analysis;
  final String maskedPassword;
}

enum VaultStorageIssueType { corruptedPayload, readFailure, writeFailure }

@immutable
class VaultStorageIssue {
  const VaultStorageIssue({
    required this.title,
    required this.message,
    required this.code,
    required this.type,
  });

  final String title;
  final String message;
  final String code;
  final VaultStorageIssueType type;
}

class VaultStoreException implements Exception {
  const VaultStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
