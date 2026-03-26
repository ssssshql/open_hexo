import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志服务 - 单例模式
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  bool _initialized = false;
  static const int _maxLogSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5;

  /// 初始化日志服务
  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(appDir.path, 'open_hexo_logs'));
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File(p.join(logDir.path, 'log_$today.txt'));
      
      // 检查日志文件大小，如果过大则轮转
      if (await _logFile!.exists()) {
        final size = await _logFile!.length();
        if (size > _maxLogSize) {
          await _rotateLogs(logDir);
        }
      }

      _initialized = true;
      info('Logger', '日志服务已初始化');
    } catch (e) {
      // 初始化失败，仅打印到控制台
      print('Logger init failed: $e');
    }
  }

  /// 轮转日志文件
  Future<void> _rotateLogs(Directory logDir) async {
    try {
      final files = await logDir.list()
          .where((f) => f.path.endsWith('.txt'))
          .toList();
      
      files.sort((a, b) => b.path.compareTo(a.path));
      
      // 删除旧日志
      while (files.length >= _maxLogFiles) {
        final oldest = files.removeLast();
        await oldest.delete();
      }

      // 重命名当前日志
      if (_logFile != null && await _logFile!.exists()) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final newPath = _logFile!.path.replaceAll('.txt', '_$timestamp.txt');
        await _logFile!.rename(newPath);
        
        // 创建新的日志文件
        _logFile = File(_logFile!.path);
      }
    } catch (e) {
      print('Log rotation failed: $e');
    }
  }

  /// 写入日志
  Future<void> _writeLog(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final levelStr = level.name.toUpperCase().padRight(7);
    final logLine = '[$timestamp] [$levelStr] [$tag] $message';
    
    // 打印到控制台（带颜色）
    final colorCode = _getColorCode(level);
    print('\x1B[${colorCode}m$logLine\x1B[0m');
    
    if (error != null) {
      print('\x1B[${colorCode}m  Error: $error\x1B[0m');
    }
    if (stackTrace != null) {
      print('\x1B[${colorCode}m  StackTrace: $stackTrace\x1B[0m');
    }

    // 写入文件（不带颜色代码）
    if (_initialized && _logFile != null) {
      try {
        final buffer = StringBuffer();
        buffer.writeln(logLine);
        if (error != null) {
          // 过滤无效 UTF-8 字符
          final errorStr = _sanitizeString(error.toString());
          buffer.writeln('  Error: $errorStr');
        }
        if (stackTrace != null) {
          final stackStr = _sanitizeString(stackTrace.toString());
          buffer.writeln('  StackTrace: $stackStr');
        }
        
        // 使用 UTF-8 编码写入
        final bytes = utf8.encode(buffer.toString());
        await _logFile!.writeAsBytes(bytes, mode: FileMode.append);
      } catch (e) {
        print('Failed to write log: $e');
      }
    }
  }

  /// 清理字符串中的无效字符
  String _sanitizeString(String input) {
    return input.replaceAll(RegExp(r'[^\x00-\x7F\u4e00-\u9fff]'), '?');
  }

  String _getColorCode(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '90'; // 灰色
      case LogLevel.info:
        return '34'; // 蓝色
      case LogLevel.warning:
        return '33'; // 黄色
      case LogLevel.error:
        return '31'; // 红色
    }
  }

  /// 调试日志
  void debug(String tag, String message) {
    _writeLog(LogLevel.debug, tag, message);
  }

  /// 信息日志
  void info(String tag, String message) {
    _writeLog(LogLevel.info, tag, message);
  }

  /// 警告日志
  void warning(String tag, String message, [Object? error]) {
    _writeLog(LogLevel.warning, tag, message, error);
  }

  /// 错误日志
  void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _writeLog(LogLevel.error, tag, message, error, stackTrace);
  }

  /// 获取日志文件路径
  String? get logFilePath => _logFile?.path;

  /// 读取日志内容
  Future<String> readLogs({int lines = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return '暂无日志';
    }

    try {
      // 使用 bytes 方式读取，并处理编码错误
      final bytes = await _logFile!.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final allLines = content.split('\n').where((l) => l.isNotEmpty).toList();
      
      if (allLines.isEmpty) {
        return '日志文件为空';
      }
      
      if (allLines.length <= lines) {
        return content;
      }
      
      return '... 省略 ${allLines.length - lines} 行 ...\n\n'
          '${allLines.sublist(allLines.length - lines).join('\n')}';
    } catch (e) {
      return '读取日志失败: $e';
    }
  }

  /// 清空日志
  Future<void> clearLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
