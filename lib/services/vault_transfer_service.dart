import 'dart:convert';
import 'dart:isolate';

class VaultTransferService {
  const VaultTransferService._();

  static Future<String> buildExportJson({
    required List<Map<String, dynamic>> records,
    bool pretty = false,
  }) {
    final normalized = records
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    return Isolate.run<String>(
      () => _buildExportJsonSync(records: normalized, pretty: pretty),
    );
  }

  static Future<List<Map<String, dynamic>>> parseVaultJsonRecords(String raw) {
    return Isolate.run<List<Map<String, dynamic>>>(
      () => _parseVaultJsonRecordsSync(raw),
    );
  }

  static Future<List<Map<String, dynamic>>> parseVaultCsvRecords(String raw) {
    return Isolate.run<List<Map<String, dynamic>>>(
      () => _parseVaultCsvRecordsSync(raw),
    );
  }
}

String _buildExportJsonSync({
  required List<Map<String, dynamic>> records,
  required bool pretty,
}) {
  final payload = <String, dynamic>{
    'formatVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'records': records,
  };
  return pretty
      ? const JsonEncoder.withIndent('  ').convert(payload)
      : jsonEncode(payload);
}

List<Map<String, dynamic>> _parseVaultJsonRecordsSync(String raw) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('Dosya icerigi JSON olarak okunamadi.');
  }

  List<dynamic> recordItems;
  if (decoded is Map<String, dynamic>) {
    final records = decoded['records'];
    if (records is! List) {
      throw const FormatException('Kayit listesi bulunamadi.');
    }
    recordItems = records;
  } else if (decoded is Map) {
    final records = decoded['records'];
    if (records is! List) {
      throw const FormatException('Kayit listesi bulunamadi.');
    }
    recordItems = records;
  } else if (decoded is List) {
    // Legacy plain JSON support.
    recordItems = decoded;
  } else {
    throw const FormatException('Desteklenmeyen JSON yapi formati.');
  }

  final now = DateTime.now();
  final parsed = <Map<String, dynamic>>[];
  for (var i = 0; i < recordItems.length; i++) {
    final item = recordItems[i];
    if (item is Map<String, dynamic>) {
      parsed.add(_normalizeRecordMap(item, index: i + 1, fallbackTime: now));
      continue;
    }
    if (item is Map) {
      parsed.add(
        _normalizeRecordMap(
          item.cast<String, dynamic>(),
          index: i + 1,
          fallbackTime: now,
        ),
      );
    }
  }

  if (parsed.isEmpty) {
    throw const FormatException('Icerikte ice aktarilacak kayit bulunamadi.');
  }
  return parsed;
}

List<Map<String, dynamic>> _parseVaultCsvRecordsSync(String raw) {
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
  final parsed = <Map<String, dynamic>>[];
  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final rawUrl = _csvValue(row, urlIndex);
    final username = _csvValue(row, usernameIndex);
    final password = _csvValue(row, passwordIndex);
    final rawName = _csvValue(row, nameIndex);
    final rawNote = _csvValue(row, noteIndex);

    if (rawUrl.isEmpty &&
        username.isEmpty &&
        password.isEmpty &&
        rawName.isEmpty) {
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
    final category = normalizedUrl.isNotEmpty ? 'website' : 'other';

    parsed.add(
      _normalizeRecordMap(
        <String, dynamic>{
          'id': '${now.microsecondsSinceEpoch}_${rowIndex}_${parsed.length}',
          'title': title,
          'category': category,
          'platform': platform.isEmpty ? title : platform,
          'accountName': username,
          'password': password,
          'note': _mergeImportedNote(rawNote),
          'websiteOrDescription': normalizedUrl,
          'isFavorite': false,
          'securityNote': '',
          'securityTag': '',
          'tags': const <String>[],
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
        index: parsed.length + 1,
        fallbackTime: now,
      ),
    );
  }

  if (parsed.isEmpty) {
    throw const FormatException('CSV dosyasinda aktarilacak kayit bulunamadi.');
  }

  return parsed;
}

Map<String, dynamic> _normalizeRecordMap(
  Map<String, dynamic> source, {
  required int index,
  required DateTime fallbackTime,
}) {
  final nowIso = fallbackTime.toIso8601String();

  final tags = <String>[];
  final rawTags = source['tags'];
  if (rawTags is List) {
    for (final item in rawTags) {
      final tag = item is String ? item.trim() : '';
      if (tag.isNotEmpty) {
        tags.add(tag);
      }
    }
  }

  final createdAt = _normalizeIsoDate(source['createdAt'], fallback: nowIso);
  final updatedAt = _normalizeIsoDate(source['updatedAt'], fallback: nowIso);

  final id = _readString(source['id']);
  final title = _readString(source['title']);
  final category = _readString(source['category']);
  final platform = _readString(source['platform']);
  final accountName = _readString(source['accountName']);
  final password = _readString(source['password']);
  final note = _readString(source['note']);
  final websiteOrDescription = _readString(source['websiteOrDescription']);
  final securityNote = _readString(source['securityNote']);
  final securityTag = _readString(source['securityTag']);

  return <String, dynamic>{
    'id': id.isNotEmpty ? id : '${fallbackTime.microsecondsSinceEpoch}_$index',
    'title': title,
    'category': category.isNotEmpty ? category : 'other',
    'platform': platform,
    'accountName': accountName,
    'password': password,
    'note': note,
    'websiteOrDescription': websiteOrDescription,
    'isFavorite': source['isFavorite'] == true,
    'securityNote': securityNote,
    'securityTag': securityTag,
    'tags': tags,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

String _normalizeIsoDate(dynamic raw, {required String fallback}) {
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed.toIso8601String();
      }
    }
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw).toIso8601String();
  }
  return fallback;
}

String _readString(dynamic value) {
  if (value is String) {
    return value.trim();
  }
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

int _findHeaderIndex(List<String> headers, List<String> aliases) {
  final normalizedAliases = aliases.map(_normalizeCsvHeader).toSet();
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
  const sourceTag = '[Imported from CSV]';
  final trimmed = rawNote.trim();
  if (trimmed.isEmpty) {
    return sourceTag;
  }
  return '$trimmed\n\n$sourceTag';
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
