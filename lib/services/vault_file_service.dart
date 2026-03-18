import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultFileService {
  static const String _lastImportPathKey = 'passroot_last_import_path_v1';

  static Future<String?> pickImportFilePath({
    List<String> allowedExtensions = const <String>['json', 'csv'],
    String? initialDirectory,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      initialDirectory: initialDirectory,
    );
    return result?.files.single.path;
  }

  static Future<String?> pickExportFilePath({
    String fileName = 'passroot_export.json',
  }) async {
    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: 'Kayitlari nereye kaydetmek istersiniz?',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<File> writeExportFile({
    required String content,
    String? path,
  }) async {
    if (path != null && path.trim().isNotEmpty) {
      final file = File(path);
      await file.parent.create(recursive: true);
      return file.writeAsString(content, flush: true);
    }

    final docs = await getApplicationDocumentsDirectory();
    final now = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${docs.path}/passroot_export_$now.json');
    return file.writeAsString(content, flush: true);
  }

  static Future<String> readFile(String path) async {
    return File(path).readAsString();
  }

  static Future<bool> exists(String path) async {
    return File(path).exists();
  }

  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return false;
      }
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveLastImportPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastImportPathKey, path.trim());
  }

  static Future<String?> lastImportPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_lastImportPathKey)?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  static Future<void> clearLastImportPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastImportPathKey);
  }

  static Future<File> createBackup(String content) async {
    final directory = await _backupDirectory();
    final now = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/backup_$now.json');
    return file.writeAsString(content, flush: true);
  }

  static Future<List<File>> listBackups() async {
    final directory = await _backupDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.json'))
        .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  static Future<Directory> _backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory('${docs.path}/passroot_backups');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
