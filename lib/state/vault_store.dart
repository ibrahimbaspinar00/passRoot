import 'dart:collection';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fake_records.dart';
import '../models/vault_record.dart';
import '../utils/password_utils.dart';

class VaultStore extends ChangeNotifier {
  VaultStore({List<VaultRecord>? seed})
    : _records = List<VaultRecord>.from(seed ?? fakeRecords) {
    unawaited(_loadFromStorage());
  }

  static const String _storageKey = 'passroot_vault_records_v2';

  final List<VaultRecord> _records;
  final Map<String, _DerivedPasswordData> _derivedPasswordCache =
      <String, _DerivedPasswordData>{};
  List<VaultRecord> _sortedCache = const <VaultRecord>[];
  UnmodifiableListView<VaultRecord> _sortedView =
      UnmodifiableListView<VaultRecord>(const <VaultRecord>[]);
  bool _sortedCacheDirty = true;

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final loaded = <VaultRecord>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loaded.add(VaultRecord.fromJson(item));
        } else if (item is Map) {
          loaded.add(VaultRecord.fromJson(item.cast<String, dynamic>()));
        }
      }
      if (loaded.isEmpty) return;
      _records
        ..clear()
        ..addAll(loaded);
      _sortedCacheDirty = true;
      notifyListeners();
    } catch (_) {
      // Keep in-memory seed when persisted data cannot be parsed.
    }
  }

  Future<void> _persistToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _records.map((record) => record.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {
      // Ignore persistence errors and keep app usable.
    }
  }

  void _persistAsync() {
    unawaited(_persistToStorage());
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
    }
    return _sortedView;
  }

  List<VaultRecord> recordsForCategory(RecordCategory category) {
    return sortedRecords
        .where((record) => record.category == category)
        .toList();
  }

  void replaceAllRecords(List<VaultRecord> records) {
    _records
      ..clear()
      ..addAll(records);
    _sortedCacheDirty = true;
    _derivedPasswordCache.clear();
    notifyListeners();
    _persistAsync();
  }

  void clearAllRecords() {
    _records.clear();
    _sortedCacheDirty = true;
    _derivedPasswordCache.clear();
    notifyListeners();
    _persistAsync();
  }

  void addRecord(VaultRecord record) {
    _records.add(record);
    _sortedCacheDirty = true;
    _derivedPasswordCache.remove(record.id);
    notifyListeners();
    _persistAsync();
  }

  void updateRecord(VaultRecord updated) {
    final index = _records.indexWhere((record) => record.id == updated.id);
    if (index == -1) return;
    _records[index] = updated;
    _sortedCacheDirty = true;
    _derivedPasswordCache.remove(updated.id);
    notifyListeners();
    _persistAsync();
  }

  void deleteRecord(String id) {
    _records.removeWhere((record) => record.id == id);
    _sortedCacheDirty = true;
    _derivedPasswordCache.remove(id);
    notifyListeners();
    _persistAsync();
  }

  void toggleFavorite(String id) {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) return;
    _records[index] = _records[index].copyWith(
      isFavorite: !_records[index].isFavorite,
      updatedAt: DateTime.now(),
    );
    _sortedCacheDirty = true;
    notifyListeners();
    _persistAsync();
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
    return sortedRecords
        .where(
          (record) =>
              analyzePassword(record.password).strength ==
              PasswordStrength.strong,
        )
        .toList();
  }

  List<VaultRecord> get weakRecords {
    return sortedRecords
        .where(
          (record) =>
              analyzePassword(record.password).strength ==
              PasswordStrength.weak,
        )
        .toList();
  }

  Map<String, List<VaultRecord>> get repeatedPasswordGroups {
    final map = <String, List<VaultRecord>>{};
    for (final record in sortedRecords) {
      if (record.password.trim().isEmpty) continue;
      map.putIfAbsent(record.password, () => <VaultRecord>[]).add(record);
    }
    map.removeWhere((key, value) => value.length < 2);
    return map;
  }

  int get repeatedRecordCount {
    return repeatedPasswordGroups.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
  }

  int get repeatedGroupCount => repeatedPasswordGroups.length;

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

  int importFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Gecersiz dosya yapisi.');
    }

    final data = decoded['records'];
    if (data is! List) {
      throw const FormatException('Kayit listesi bulunamadi.');
    }

    final parsed = <VaultRecord>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        parsed.add(VaultRecord.fromJson(item));
      } else if (item is Map) {
        parsed.add(VaultRecord.fromJson(item.cast<String, dynamic>()));
      }
    }
    replaceAllRecords(parsed);
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
