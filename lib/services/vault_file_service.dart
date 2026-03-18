import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class VaultFileService {
  static Future<String?> pickImportFilePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      allowMultiple: false,
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
