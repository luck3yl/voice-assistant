import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// 本地唤醒词检测器（Web / Android / iOS 一致）
///
/// 用 `speech_to_text` 调用平台本地语音识别，专门盯唤醒词。
/// 对「小智」这类短词，本地识别比后端流式 ASR 更准、更快。
///
/// 注意：检测期间占用麦克风，调用方需在唤醒后 `stop()`，再启动 PCM 推流，
/// 避免与录音推流抢麦克风。
class WakeWordDetector {
  WakeWordDetector(this.wakeWords);

  /// 唤醒词及其同音变体
  final List<String> wakeWords;

  SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool _initTried = false;
  bool _running = false; // 期望保持监听
  bool _listening = false; // 当前 listen 会话进行中
  bool _triggered = false; // 本轮是否已触发唤醒
  Timer? _restartTimer;

  void Function(String afterWake)? _onWake;
  void Function(String message)? _onError;

  /// 当前平台是否支持本地唤醒检测
  bool get supported => _available;

  void setOnWake(void Function(String afterWake) cb) => _onWake = cb;
  void setOnError(void Function(String message) cb) => _onError = cb;

  /// 初始化（只会真正执行一次）
  Future<bool> initialize() async {
    if (_initTried && _available) return _available;
    _initTried = true;
    try {
      _available = await _speech.initialize(
        onStatus: _onStatus,
        // Web 端的 speech_to_text 插件在报错时存在 JSON 序列化 Bug，因此不传递 onError，通过 onStatus == 'done' 兜底重启
        onError: kIsWeb ? null : (e) {
          _onError?.call(e.errorMsg);
          _scheduleRestart();
        },
      );
    } catch (e) {
      _available = false;
      _onError?.call('唤醒识别初始化失败：$e');
    }
    return _available;
  }

  /// 开始监听唤醒词（持续，内部会自动重启会话）
  Future<void> start() async {
    if (!_available) {
      await initialize();
      if (!_available) return;
    }
    _running = true;
    _triggered = false;
    _beginListen();
  }

  void _beginListen() {
    if (!_running || _listening || _triggered) return;
    if (_speech.isListening) return;
    _listening = true;
    _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 7),
        pauseFor: const Duration(seconds: 7),
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  void Function(String command)? _onCommand;

  void setOnCommand(void Function(String command) cb) => _onCommand = cb;

  void _onResult(SpeechRecognitionResult result) {
    if (_triggered) return;
    final text = result.recognizedWords;
    if (text.isNotEmpty) {
      debugPrint('[前端识别] 识别到内容: "$text"');
    }
    if (text.isEmpty) return;

    if (text.contains('上一页') || text.contains('往上翻')) {
      _triggered = true;
      _onCommand?.call('scrollUp');
      stop().then((_) {
        safeRestart();
      });
      return;
    }
    if (text.contains('下一页') || text.contains('往下翻')) {
      _triggered = true;
      _onCommand?.call('scrollDown');
      stop().then((_) {
        safeRestart();
      });
      return;
    }
    if (text.contains('最后一页') || text.contains('最后一夜')) {
      _triggered = true;
      _onCommand?.call('jumpToBottom');
      stop().then((_) {
        safeRestart();
      });
      return;
    }
    if (text.contains('第一页')) {
      _triggered = true;
      _onCommand?.call('jumpToTop');
      stop().then((_) {
        safeRestart();
      });
      return;
    }
    if (text.contains('确认') || text.contains('发送') || text.contains('确认发送')) {
      _triggered = true;
      _onCommand?.call('confirm');
      stop();
      return;
    }
    if (text.contains('取消') || text.contains('不对') || text.contains('错了') || text.contains('算了')) {
      _triggered = true;
      _onCommand?.call('cancel');
      stop().then((_) {
        safeRestart();
      });
      return;
    }

    if (wakeWords.any((w) => text.contains(w))) {
      _triggered = true;
      stop().then((_) {
        _onWake?.call(text);
      });
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _listening = true;
      debugPrint('[前端识别] 开始监听');
    } else if (status == 'notListening' || status == 'done') {
      _listening = false;
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_running || _triggered) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 300), () {
      if (_running && !_triggered) _beginListen();
    });
  }


  /// 安全重启机制，自动处理正在停止中的冲突
  Future<void> safeRestart() async {
    _triggered = false;
    _running = true;
    try {
      await _speech.cancel();
      _listening = false;
    } catch (_) {}

    // 给浏览器一点喘息时间，确保上一个实例彻底销毁
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_speech.isListening) {
      // 幽灵占用：浏览器底层状态卡死，没有触发 onend，导致 package 状态永久死锁
      // 暴力破局：直接废弃旧引擎，重新孵化一个新引擎
      _speech = SpeechToText();
      _initTried = false;
      await initialize();
    }
    
    if (_available && !_listening) {
      _beginListen();
    }
  }

  /// 停止监听（唤醒后调用，释放麦克风给录音推流）
  Future<void> stop() async {
    _running = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    try {
      await _speech.cancel();
      _listening = false;
    } catch (_) {}
  }

  void dispose() {
    _restartTimer?.cancel();
    try {
      _speech.cancel();
    } catch (_) {}
  }
}
