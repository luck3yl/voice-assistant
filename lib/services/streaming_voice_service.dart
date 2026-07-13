import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'asr_config.dart';
import 'voice_service.dart';
import 'wake_word_detector.dart';
import 'tts_stream_manager.dart';
part 'streaming_voice_service_vad.dart';
part 'streaming_voice_service_result.dart';

/// 实时流式语音服务（Web / Android / iOS 通用）
///
/// 工作流程：
/// 1. 连接后端 WebSocket
/// 2. 用 `record` 的 `startStream` 采集 16kHz / 16bit / 单声道 PCM 裸字节流，实时推给后端
/// 3. 后端返回：
///    - `partial`：流式模型「边听边出字」，快但有同音字、无标点 → 前端**实时显示**
///    - `final`：用户停顿后，后端主力非流式模型对整句音频纠错+加标点的完整结果
///      → 前端用它**替换**显示，并作为最终问题**提交给 AI**
/// 4. 后端自己检测停顿，前端**无需**发送 done / 也不做本地 VAD 断句
/// 5. 唤醒：原生端用本地 `speech_to_text`；Web 端回退到后端识别文字里检测唤醒词
/// 6. TTS 用本地 flutter_tts；播报时暂停推流，避免把自己的声音再传给后端
class StreamingVoiceService implements VoiceService {
  VoiceServiceCallback? _callback;
  bool _connected = false;

  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();
  late final TtsStreamManager _ttsManager;

  /// 本地唤醒词检测器（原生端待机时盯唤醒词）
  final WakeWordDetector _wakeDetector = WakeWordDetector(wakeWords);
  bool _useLocalWake = false;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  StreamSubscription<Uint8List>? _audioSub;

  bool _isSpeaking = false; // TTS 播报中
  bool _isSpeakingWakeAck = false; // 是否在播报唤醒词
  bool _isAwake = false; // 已唤醒
  bool _isListening = false; // 推流中
  bool _awaitingReply = false; // 已提交问题，正在等 AI 回复（期间暂停输入捕获）
  bool _awaitingFinal = false; // 已发 done，正在等后端 final
  bool _awaitingConfirmation = false; // 等待用户确认发送
  String _pendingQuestion = ''; // 等待确认的问题
  bool _disposed = false; // 已断开（阻止自动重连）

  Timer? _sleepTimer;
  Timer? _reconnectTimer;
  Timer? _partialSilenceTimer; // 唤醒前清理陈旧缓冲
  Timer? _vadTimer; // 本地音频 VAD 轮询（检测静音发 done）
  Timer? _finalFallbackTimer; // 发 done 后等 final 的兜底

  // === 本地 VAD 状态 ===
  bool _hasSpoken = false; // 本句是否已检测到说话
  DateTime _lastVoiceAt = DateTime.now(); // 最近一次检测到说话声的时间

  DateTime _lastRmsLogAt = DateTime.now(); // 上次打印 rms 的时间（节流）

  String _lastPartial = ''; // 当前累计的 partial 文字
  String _committed = ''; // 已确认的前面若干段
  String _currentSeg = ''; // 当前正在被修正的这一段
  String _wsUrl = AsrConfig.wsEndpoint;
  /// 音频门控：在此时刻之前的音频 chunk 全部丢弃（避免噪声/回声）
  DateTime _audioGateUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // === 响应速度统计 ===
  DateTime? _lastRecvAt;
  DateTime _respAnchorAt = DateTime.now();
  bool _firstRecvLogged = false;

  /// 唤醒词同音变体
  static const List<String> wakeWords = [
    '小智', '小志', '小知', '小制', '小至', '小治', '晓智', '晓志', '小芝', '校智',
    '下一个问题', '下个问题',
  ];

  /// 唤醒后的应答语
  static const String wakeAck = '请说';

  VoiceTimbre _timbre = VoiceTimbre.female;
  double _speechRate = 1.0;

  /// 唤醒后无操作自动休眠时长
  static const Duration _awakeTimeout = Duration(seconds: 300);

  /// 唤醒前 partial 停更多久清空缓冲
  static const Duration _partialSilence =
      Duration(milliseconds: AsrConfig.partialSilenceMs);

  void _log(String msg) {
    if (AsrConfig.debug) debugPrint('[ASR] $msg');
  }

  void _logRecvLatency() {
    if (!AsrConfig.debug) return;
    final now = DateTime.now();
    if (!_firstRecvLogged) {
      _firstRecvLogged = true;
      _log('⏱ 首条响应延迟: ${now.difference(_respAnchorAt).inMilliseconds}ms');
    }
    if (_lastRecvAt != null) {
      _log('⏱ 距上一条: ${now.difference(_lastRecvAt!).inMilliseconds}ms');
    }
    _lastRecvAt = now;
  }

  @override
  bool get isConnected => _connected;

  @override
  void setCallback(VoiceServiceCallback callback) => _callback = callback;

  @override
  Future<void> connect(String serverUrl) async {
    _disposed = false;
    if (serverUrl.startsWith('ws://') || serverUrl.startsWith('wss://')) {
      _wsUrl = serverUrl;
    }

    await _initTts();

    _wakeDetector.setOnWake(_onWakeDetected);
    _wakeDetector.setOnError((msg) => _log('wake detector: $msg'));
    _wakeDetector.setOnCommand((cmd) {
      if (cmd == 'scrollUp') {
        _callback?.onCommand(VoiceCommand.scrollUp);
      } else if (cmd == 'scrollDown') {
        _callback?.onCommand(VoiceCommand.scrollDown);
      } else if (cmd == 'jumpToBottom') {
        _callback?.onCommand(VoiceCommand.jumpToBottom);
      } else if (cmd == 'jumpToTop') {
        _callback?.onCommand(VoiceCommand.jumpToTop);
      } else if (cmd == 'confirm') {
        if (_awaitingConfirmation) {
          final q = _pendingQuestion;
          _awaitingConfirmation = false;
          _pendingQuestion = '';
          _submitQuestion(q);
        }
      } else if (cmd == 'cancel') {
        if (_awaitingConfirmation) {
          _awaitingConfirmation = false;
          _pendingQuestion = '';
          _callback?.onConfirmationCancelled();
          speak('已取消');
        } else if (_awaitingReply || _isSpeaking) {
          // 在非确认态下（思考/播报中），“取消”等同于“停止”
          _awaitingReply = false;
          stopSpeaking();
          _callback?.onCommand(VoiceCommand.stopSpeaking);
        }
      }
    });

    // 坚决执行指令：绝不使用后端做唤醒，完全死守前端本地引擎！
    _useLocalWake = await _wakeDetector.initialize();
    _log('local wake supported: $_useLocalWake');

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      _connected = false;
      _callback?.onConnectionChanged(false);
      _callback?.onError('麦克风权限未授予');
      return;
    }

    await _openSocket();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _applyTimbre();
    
    _ttsManager = TtsStreamManager(_tts, () {
      _isSpeaking = true;
      if (!_isSpeakingWakeAck) _callback?.onTtsStart();
    }, () {
      _isSpeaking = false;
      // TTS 刚结束，丢弃前几百毫秒音频，防止回声被识别为错误文字
      _audioGateUntil = DateTime.now().add(
        const Duration(milliseconds: AsrConfig.audioLeadInMs),
      );
      _log('audio gate: TTS结束，丢弃前 ${AsrConfig.audioLeadInMs}ms 音频');
      if (!_isSpeakingWakeAck) _callback?.onTtsEnd();
      _isSpeakingWakeAck = false;
      _resumeAfterTts();
    }, onSentencePlaying: (sentence) {
      if (!_isSpeakingWakeAck) _callback?.onSentencePlaying(sentence);
    });
  }

  // === WebSocket ===
  Future<void> _openSocket() async {
    try {
      _log('connecting to $_wsUrl ...');
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await channel.ready;
      _channel = channel;
      _connected = true;
      _callback?.onConnectionChanged(true);
      _log('connected.');

      _wsSub = channel.stream.listen(
        _onWsMessage,
        onError: (e) => _handleSocketClosed('WebSocket 错误：$e'),
        onDone: () => _handleSocketClosed(null),
        cancelOnError: true,
      );
    } catch (e) {
      _connected = false;
      _callback?.onConnectionChanged(false);
      _callback?.onError('无法连接语音服务：$e');
      _log('connect FAILED: $e');
      _scheduleReconnect();
    }
  }

  void _handleSocketClosed(String? error) {
    _connected = false;
    _callback?.onConnectionChanged(false);
    if (error != null) _callback?.onError(error);
    _wsSub = null;
    _channel = null;
    
    // 只有在等待 final 的时候断开，才视作会话中断。
    // 千万不能在 _awaitingConfirmation 的时候退出，因为后端发完 final 后本身就可能会断开连接！
    if (_awaitingFinal) {
      _log('后端断开连接，放弃等待 final，退回休眠');
      _awaitingFinal = false;
      _resetPartialBuffer();
      _enterIdle();
    }
    
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_disposed || _connected) return;
      final wasListening = _isListening;
      final wasAwake = _isAwake;
      await _openSocket();
      if (_connected && wasListening) {
        if (wasAwake) {
          await _enterAwakeStreaming();
        } else {
          await _enterIdle();
        }
      }
    });
  }

  void _onWsMessage(dynamic data) {
    _logRecvLatency();
    // _log('recv(${data.runtimeType}): $data');
    if (data is! String) return;
    final event = AsrEvent.parse(data);
    // _log('parsed: ${event.type} "${event.text}" (awake=$_isAwake)');
    switch (event.type) {
      case AsrEventType.partial:
        _onPartial(event.text);
        break;
      case AsrEventType.finalResult:
        _onFinal(event.text);
        break;
      case AsrEventType.wake:
        _wake(after: event.text);
        break;
      case AsrEventType.speechStart:
        if (_isAwake) _callback?.onSpeechStart();
        break;
      case AsrEventType.speechEnd:
        break;
      case AsrEventType.aiReply:
        if (event.text == '[DONE]') {
          if (AsrConfig.ttsEnabled) _ttsManager.flush();
        } else if (event.text.isNotEmpty) {
          _callback?.onAiReply(event.text);
          if (AsrConfig.ttsEnabled) _ttsManager.feedChunk(event.text);
        }
        break;
      case AsrEventType.error:
        _callback?.onError('识别错误：${event.text}');
        break;
      case AsrEventType.unknown:
        break;
    }
  }

  // === 录音推流 ===
  @override
  Future<void> startContinuousListening() async {
    if (!_connected) return;
    await _enterIdle();
  }

  /// 进入待机态：等待唤醒
  Future<void> _enterIdle() async {
    _isAwake = false;
    _awaitingReply = false;
    _awaitingFinal = false;
    _awaitingConfirmation = false;
    _pendingQuestion = '';
    _hasSpoken = false;
    _finalFallbackTimer?.cancel();
    _resetPartialBuffer();
    if (_useLocalWake) {
      await _stopStreaming();
      await _wakeDetector.safeRestart();
      _log('idle: local wake listening');
    } else {
      // Web/回退：持续推流，靠后端识别文字里的唤醒词
      if (!_isListening && !_isSpeaking) await _startStreaming();
    }
  }

  /// 唤醒态推流：停本地唤醒识别，开始把音频推给后端识别问题
  Future<void> _enterAwakeStreaming() async {
    if (_useLocalWake) {
      await _wakeDetector.stop();
      // 极大缩短引擎切换带来的交接真空期，避免吞字
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _respAnchorAt = DateTime.now();
    _firstRecvLogged = false;
    if (!_isListening && !_isSpeaking) {
      await _startStreaming();
    }
  }

  void _onWakeDetected(String afterWake) {
    if (_isAwake || _isSpeaking) return;
    _log('local WAKE detected, afterWake: "$afterWake"');
    _awaitingReply = false; // 允许打断当前的 AI 回答
    _wake(after: afterWake);
  }

  Future<void> _startStreaming() async {
    try {
      _log('startStream: pcm16 ${AsrConfig.sampleRate}Hz x${AsrConfig.numChannels}');
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AsrConfig.sampleRate,
          numChannels: AsrConfig.numChannels,
          // 关闭自动增益：避免静音被放大，保证本地 VAD 能量判断可靠
          echoCancel: true,
          noiseSuppress: true,
          autoGain: false,
        ),
      );
      _isListening = true;
      // 录音刚启动，丢弃前几百毫秒音频，避免麦克风激活噪声
      _audioGateUntil = DateTime.now().add(
        const Duration(milliseconds: AsrConfig.audioLeadInMs),
      );
      _log('audio gate: 录音启动，丢弃前 ${AsrConfig.audioLeadInMs}ms 音频');

      var firstChunkLogged = false;
      _audioSub = stream.listen(
        (chunk) {
          // 播报中 / 等待 final 期间 不推流（允许在等回复期间推流以响应翻页指令）
          if (_isSpeaking || !_connected || _awaitingFinal) return;
          // 录音启动 / TTS 结束后的前几百毫秒丢弃，避免噪声/回声污染识别
          if (DateTime.now().isBefore(_audioGateUntil)) return;
          _channel?.sink.add(chunk);
          _feedVad(chunk);
          if (!firstChunkLogged) {
            firstChunkLogged = true;
            _log('audio streaming: first chunk sent (${chunk.length} bytes)');
          }
        },
        onError: (e) => _callback?.onError('录音流错误：$e'),
        cancelOnError: false,
      );
      // 本地 VAD 轮询：静音 2 秒后给后端发 done
      _vadTimer?.cancel();
      _vadTimer = Timer.periodic(
        const Duration(milliseconds: 150),
        (_) => _vadTick(),
      );
      _log('streaming started');
    } catch (e) {
      _isListening = false;
      _callback?.onError('录音启动失败：$e');
      _log('startStream FAILED: $e');
    }
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    await _stopStreaming();
  }

  // === 本地 VAD：检测静音 → 给后端发 done ===


  @override
  Future<void> speak(String text) async {
    _awaitingReply = false; // AI 回复已到
    _awaitingFinal = false;
    _hasSpoken = false;
    _finalFallbackTimer?.cancel();

    _isSpeakingWakeAck = (text == wakeAck);

    if (!AsrConfig.ttsEnabled) {
      if (!_isSpeakingWakeAck) _callback?.onTtsStart();
      _isSpeaking = false;
      if (!_isSpeakingWakeAck) _callback?.onTtsEnd();
      _isSpeakingWakeAck = false;
      _resumeAfterTts();
      return;
    }
    _isSpeaking = true;
    _resetPartialBuffer();
    _ttsManager.stopAndClear();
    _ttsManager.feedChunk(text);
    _ttsManager.flush();
  }

  void _resumeAfterTts() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_disposed || _isSpeaking || !_connected) return;
      if (_isAwake) {
        _enterAwakeStreaming();
      } else {
        _enterIdle();
      }
    });
  }

  @override
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _audioGateUntil = DateTime.now().add(
      const Duration(milliseconds: AsrConfig.audioLeadInMs),
    );
    if (!_isSpeakingWakeAck) _callback?.onTtsEnd();
    _isSpeakingWakeAck = false;
    _resumeAfterTts();
  }

  /// AI \u56de\u590d\u5b8c\u6210\u4e14\u4e0d\u4f7f\u7528 TTS \u65f6\uff0c\u89e3\u9501 _awaitingReply \u5e76\u6062\u590d\u63a8\u6d41
  @override
  Future<void> resumeListening() async {
    _awaitingReply = false;
    _awaitingFinal = false;
    _awaitingConfirmation = false;
    _pendingQuestion = '';
    _hasSpoken = false;
    _isAwake = false; // 回答完毕后自动进入休眠，必须使用唤醒词或"下一个问题"来开启新一轮
    _finalFallbackTimer?.cancel();
    _resetPartialBuffer();
    _resumeAfterTts();
  }

  @override
  void feedTtsChunk(String chunk) {
    if (AsrConfig.ttsEnabled) {
      _ttsManager.feedChunk(chunk);
    }
  }

  @override
  void flushTts() {
    if (AsrConfig.ttsEnabled) {
      _ttsManager.flush();
    }
  }

  @override
  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sleepTimer?.cancel();
    _partialSilenceTimer?.cancel();
    await stopListening();
    await _wakeDetector.stop();
    _wakeDetector.dispose();
    await _tts.stop();
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
    _callback?.onConnectionChanged(false);
  }

  // === 音色 / 语速 ===
  @override
  Future<void> setVoiceTimbre(VoiceTimbre timbre) async {
    _timbre = timbre;
    await _applyTimbre();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _tts.setSpeechRate(_speechRate);
  }

  Future<void> _applyTimbre() async {
    await _tts.setPitch(_timbre == VoiceTimbre.female ? 1.1 : 0.7);
    final voice = await _pickVoice(_timbre);
    if (voice != null) {
      try {
        await _tts.setVoice(voice);
      } catch (_) {}
    }
  }

  Future<Map<String, String>?> _pickVoice(VoiceTimbre timbre) async {
    List<dynamic> voices;
    try {
      voices = (await _tts.getVoices) as List<dynamic>;
    } catch (_) {
      return null;
    }

    final femaleKeys = ['female', 'huihui', 'yaoyao', 'xiaoxiao', 'xiaoyi', '女'];
    final maleKeys = ['male', 'kangkang', 'yunyang', 'yunxi', 'yunjian', '男'];
    final wantKeys = timbre == VoiceTimbre.female ? femaleKeys : maleKeys;

    Map<String, String>? firstZh;
    for (final v in voices) {
      final map = Map<String, dynamic>.from(v as Map);
      final name = (map['name'] ?? '').toString();
      final locale = (map['locale'] ?? '').toString();
      if (!locale.toLowerCase().startsWith('zh')) continue;

      final entry = {'name': name, 'locale': locale};
      firstZh ??= entry;

      final lower = name.toLowerCase();
      if (wantKeys.any((k) => lower.contains(k))) {
        return entry;
      }
    }
    return firstZh;
  }
}
