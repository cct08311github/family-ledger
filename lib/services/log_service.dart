import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { debug, info, warning, error }

enum LogTag { APP, AUTH, SYNC, DB, STORAGE }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogTag tag;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formatted {
    final time = DateFormat('HH:mm:ss').format(timestamp);
    final lvl = level.name.toUpperCase();
    final base = '[$time] [$lvl] [${tag.name}] $message';
    if (error != null) return '$base\n  Error: $error';
    return base;
  }
}

class LogService {
  LogService._();
  static final LogService _instance = LogService._();
  static LogService get instance => _instance;

  static const int _maxEntries = 500;
  final List<LogEntry> _entries = [];
  final _controller = StreamController<List<LogEntry>>.broadcast();

  Stream<List<LogEntry>> get stream => _controller.stream;
  List<LogEntry> get entries => List.unmodifiable(_entries);

  void _add(LogLevel level, LogTag tag, String message,
      [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }

    // Console output
    final line = entry.formatted;
    if (level == LogLevel.error || level == LogLevel.warning) {
      developer.log(line, name: tag.name, level: level == LogLevel.error ? 1000 : 900);
    } else if (kDebugMode) {
      debugPrint(line);
    }

    _controller.add(List.unmodifiable(_entries));
  }

  static void debug(LogTag tag, String message) =>
      _instance._add(LogLevel.debug, tag, message);

  static void info(LogTag tag, String message) =>
      _instance._add(LogLevel.info, tag, message);

  static void warning(LogTag tag, String message, [Object? error]) =>
      _instance._add(LogLevel.warning, tag, message, error);

  static void error(LogTag tag, String message,
      [Object? error, StackTrace? stackTrace]) =>
      _instance._add(LogLevel.error, tag, message, error, stackTrace);

  void clear() {
    _entries.clear();
    _controller.add(List.unmodifiable(_entries));
  }

  String exportAll() {
    return _entries.map((e) => e.formatted).join('\n');
  }
}
