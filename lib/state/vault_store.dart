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

  int importFromCsvString(String raw) {
    final rows = _CsvTableParser.parse(raw);
    if (rows.isEmpty) {
      throw const FormatException('CSV dosyasi bos.');
    }

    final headers = rows.first.map(_normalizeCsvHeader).toList(growable: false);
    final urlIndex = _findHeaderIndex(headers, const <String>[
      'url',
      'website',
      'site',
      'origin',
      'loginuri',
    ]);
    final usernameIndex = _findHeaderIndex(headers, const <String>[
      'username',
      'user',
      'login',
      'email',
    ]);
    final passwordIndex = _findHeaderIndex(headers, const <String>[
      'password',
      'pass',
      'sifre',
    ]);
    final nameIndex = _findHeaderIndex(headers, const <String>[
      'name',
      'title',
      'sitename',
      'accountname',
    ]);
    final noteIndex = _findHeaderIndex(headers, const <String>[
      'note',
      'notes',
      'comment',
      'aciklama',
    ]);

    if (passwordIndex == -1) {
      throw const FormatException(
        'CSV basligi desteklenmiyor. Beklenen kolon: password.',
      );
    }

    final now = DateTime.now();
    final parsed = <VaultRecord>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rawUrl = _csvValue(row, urlIndex);
      final username = _csvValue(row, usernameIndex);
      final password = _csvValue(row, passwordIndex);
      final rawName = _csvValue(row, nameIndex);
      final rawNote = _csvValue(row, noteIndex);

      if (rawUrl.isEmpty && username.isEmpty && password.isEmpty && rawName.isEmpty) {
        continue;
      }
      if (password.isEmpty) {
        continue;
      }

      final normalizedUrl = _normalizeImportedUrl(rawUrl);
      final platform = _platformFromUrl(normalizedUrl);
      final title = _resolveImportedTitle(
        name: rawName,
        url: normalizedUrl,
        username: username,
        index: parsed.length + 1,
      );
      final note = _mergeImportedNote(rawNote);
      final category = normalizedUrl.isNotEmpty
          ? RecordCategory.website
          : RecordCategory.other;

      parsed.add(
        VaultRecord(
          id: '${now.microsecondsSinceEpoch}_${rowIndex}_${parsed.length}',
          title: title,
          category: category,
          platform: platform.isEmpty ? title : platform,
          accountName: username,
          password: password,
          note: note,
          websiteOrDescription: normalizedUrl,
          isFavorite: false,
          securityNote: '',
          securityTag: '',
          tags: const <String>[],
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (parsed.isEmpty) {
      throw const FormatException(
        'CSV dosyasinda aktarilacak parola kaydi bulunamadi.',
      );
    }

    replaceAllRecords(parsed);
    return parsed.length;
  }

  int _findHeaderIndex(List<String> headers, List<String> aliases) {
    final normalizedAliases = aliases
        .map(_normalizeCsvHeader)
        .toSet();
    for (var i = 0; i < headers.length; i++) {
      if (normalizedAliases.contains(headers[i])) {
        return i;
      }
    }
    return -1;
  }

  String _normalizeCsvHeader(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1);
    }
    normalized = normalized.replaceAll('"', '');
    normalized = normalized.replaceAll(RegExp(r'[\s_-]+'), '');
    return normalized;
  }

  String _csvValue(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  String _normalizeImportedUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return '';
    }
    final candidate = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return raw;
    }
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      return uri.toString();
    }
    return raw;
  }

  String _platformFromUrl(String url) {
    if (url.trim().isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.trim().isEmpty) {
      return '';
    }
    final host = uri.host.toLowerCase();
    if (host.startsWith('www.')) {
      return host.substring(4);
    }
    return host;
  }

  String _resolveImportedTitle({
    required String name,
    required String url,
    required String username,
    required int index,
  }) {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    final host = _platformFromUrl(url);
    if (host.isNotEmpty) {
      return host;
    }
    if (username.trim().isNotEmpty) {
      return username.trim();
    }
    return 'Imported Record $index';
  }

  String _mergeImportedNote(String rawNote) {
    final sourceTag = '[Imported from Google Password Manager CSV]';
    final trimmed = rawNote.trim();
    if (trimmed.isEmpty) {
      return sourceTag;
    }
    return '$trimmed\n\n$sourceTag';
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

class _CsvTableParser {
  static List<List<String>> parse(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();

    var inQuotes = false;
    var i = 0;
    while (i < input.length) {
      final char = input[i];
      if (char == '"') {
        final nextIsQuote = i + 1 < input.length && input[i + 1] == '"';
        if (inQuotes && nextIsQuote) {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = !inQuotes;
        i++;
        continue;
      }

      if (!inQuotes && char == ',') {
        row.add(cell.toString());
        cell.clear();
        i++;
        continue;
      }

      if (!inQuotes && (char == '\n' || char == '\r')) {
        row.add(cell.toString());
        cell.clear();
        rows.add(List<String>.from(row));
        row.clear();

        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i += 2;
        } else {
          i++;
        }
        continue;
      }

      cell.write(char);
      i++;
    }

    final hasTailData = cell.isNotEmpty || row.isNotEmpty;
    if (hasTailData) {
      row.add(cell.toString());
      rows.add(List<String>.from(row));
    }

    return rows
        .where((r) => r.any((value) => value.trim().isNotEmpty))
        .toList(growable: false);
  }
}
