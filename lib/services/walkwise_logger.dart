import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class WalkWiseLogger {
  static final WalkWiseLogger _instance = WalkWiseLogger._internal();
  factory WalkWiseLogger() => _instance;
  WalkWiseLogger._internal();

  File? _logFile;

  Future<File> _getLogFile() async {
    if (_logFile != null) return _logFile!;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/walkwise.log');
    _logFile = file;
    return file;
  }

  Future<void> log(String type, String details) async {
    final file = await _getLogFile();
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-ddTHH:mm:ss.SSSZ').format(now);
    final entry = '${type.toUpperCase()} $details [$timestamp]\n';
    await file.writeAsString(entry, mode: FileMode.append);
  }

  Future<List<String>> getLogTail({int lines = 50}) async {
    final file = await _getLogFile();
    if (!await file.exists()) return [];
    final allLines = await file.readAsLines();
    return allLines.length > lines ? allLines.sublist(allLines.length - lines) : allLines;
  }

  Future<void> clearLog() async {
    final file = await _getLogFile();
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }
} 