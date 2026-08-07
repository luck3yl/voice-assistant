import 'dart:async';
import 'package:flutter/foundation.dart';

/// 全局运行调试日志服务（专为跨远程/异地设备排查日志设计）
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  final List<String> _logs = [];
  final StreamController<List<String>> _controller = StreamController<List<String>>.broadcast();

  List<String> get logs => List.unmodifiable(_logs);
  Stream<List<String>> get logStream => _controller.stream;

  void log(String message) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";
    final entry = "[$timeStr] $message";

    _logs.add(entry);
    if (_logs.length > 250) {
      _logs.removeAt(0);
    }
    debugPrint(entry);
    _controller.add(List.unmodifiable(_logs));
  }

  void clear() {
    _logs.clear();
    _controller.add([]);
  }
}
