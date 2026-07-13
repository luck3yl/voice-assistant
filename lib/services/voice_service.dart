/// 语音服务 - 纯 WebSocket 流式方案
///
/// 架构设计：
/// 前端（头盔）只负责：
///   1. 麦克风录音 → 音频流
///   2. 通过 WebSocket 将音频流发送到后端
///   3. 接收后端返回的：识别文字、AI回复文字、TTS音频流
///   4. 播放 TTS 音频
///
/// 后端负责：
///   - ASR（语音识别）
///   - VAD（语音活动检测 / 端点检测）
///   - 唤醒词检测
///   - 大模型推理
///   - TTS（语音合成）
///
/// 这样前端完全不需要任何语音SDK，只需要：
///   - 麦克风录音能力（Flutter 原生支持）
///   - WebSocket 通信
///   - 音频播放
library;

/// WebSocket 消息类型定义
enum WsMessageType {
  // 前端 -> 后端
  audioData,      // 音频数据帧
  controlStart,   // 开始录音通知
  controlStop,    // 停止录音通知

  // 后端 -> 前端
  wakeUp,         // 唤醒词被触发
  speechStart,    // 检测到说话开始（VAD）
  speechEnd,      // 检测到说话结束（VAD）
  partialResult,  // ASR 中间结果
  finalResult,    // ASR 最终结果
  aiReply,        // AI 回复文字
  ttsAudio,       // TTS 音频数据
  ttsEnd,         // TTS 播放完毕
  error,          // 错误信息
  command,        // 语音指令（导航等）
}

/// 播报音色
enum VoiceTimbre {
  female, // 女声
  male,   // 男声
}

/// 语音指令类型
enum VoiceCommand {
  goBack,           // "返回"

  stopSpeaking,     // "停止" / "别说了"
  repeatLast,       // "再说一遍"
  clearChat,        // "清空对话"
  scrollUp,         // "往上翻"
  scrollDown,       // "往下翻"
  jumpToBottom,     // "最后一页"
  jumpToTop,        // "第一页"
}

/// 语音服务回调接口
abstract class VoiceServiceCallback {
  void onWakeUp();
  void onSpeechStart();
  void onPartialResult(String text);
  void onFinalResult(String text);
  void onAiReply(String text);
  void onTtsStart();
  void onTtsEnd();
  /// TTS 即将朗读的句子（用于音画同步）
  void onSentencePlaying(String sentence) {}
  /// 识别完成，等待用户确认发送
  void onConfirmationNeeded(String text) {}
  /// 用户取消了发送
  void onConfirmationCancelled() {}
  void onCommand(VoiceCommand command);
  void onError(String message);
  void onConnectionChanged(bool connected);
}

/// 语音服务接口
abstract class VoiceService {
  /// 连接到后端语音服务
  Future<void> connect(String serverUrl);

  /// 断开连接
  Future<void> disconnect();

  /// 开始持续录音（连接后即开始，音频流持续发送到后端）
  Future<void> startContinuousListening();

  /// 停止录音
  Future<void> stopListening();

  /// TTS 语音播报
  Future<void> speak(String text);

  /// 停止播报
  Future<void> stopSpeaking();

  /// 喂入流式 TTS 文本片段
  void feedTtsChunk(String chunk);

  /// 刷新 TTS 缓冲区（流式接收结束时调用）
  void flushTts();

  /// 当 AI 回复完成且不需要 TTS 时，通知服务恢复监听（解锁 _awaitingReply）
  Future<void> resumeListening();

  /// 设置播报音色（女声 / 男声）
  Future<void> setVoiceTimbre(VoiceTimbre timbre);

  /// 设置语速（0.5 ~ 2.0，1.0 为正常）
  Future<void> setSpeechRate(double rate);

  /// 注册回调
  void setCallback(VoiceServiceCallback callback);

  /// 是否已连接
  bool get isConnected;
}

/// 模拟语音服务（开发/测试用）
class MockVoiceService implements VoiceService {
  VoiceServiceCallback? _callback;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void setCallback(VoiceServiceCallback callback) {
    _callback = callback;
  }

  @override
  Future<void> connect(String serverUrl) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _connected = true;
    _callback?.onConnectionChanged(true);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _callback?.onConnectionChanged(false);
  }

  @override
  Future<void> startContinuousListening() async {
    // 模拟：2秒后唤醒
    Future.delayed(const Duration(seconds: 2), () {
      _callback?.onWakeUp();
    });
  }

  @override
  Future<void> stopListening() async {
    // 停止录音
  }

  @override
  Future<void> speak(String text) async {
    _callback?.onTtsStart();
    await Future.delayed(Duration(milliseconds: text.length * 40));
    _callback?.onTtsEnd();
  }

  @override
  Future<void> stopSpeaking() async {
    _callback?.onTtsEnd();
  }

  @override
  void feedTtsChunk(String chunk) {}

  @override
  void flushTts() {}

  @override
  Future<void> setVoiceTimbre(VoiceTimbre timbre) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> resumeListening() async {
    // Mock: 无需操作
  }

  /// 模拟一次完整的语音交互流程
  Future<void> simulateInteraction(String question, String answer) async {
    _callback?.onSpeechStart();
    await Future.delayed(const Duration(milliseconds: 300));

    // 模拟中间结果
    final words = question.split('');
    for (int i = 0; i < words.length; i += 3) {
      await Future.delayed(const Duration(milliseconds: 100));
      _callback?.onPartialResult(question.substring(0, i + 3));
    }

    _callback?.onFinalResult(question);
    await Future.delayed(const Duration(milliseconds: 800));

    _callback?.onAiReply(answer);
    _callback?.onTtsStart();
    await Future.delayed(Duration(milliseconds: answer.length * 40));
    _callback?.onTtsEnd();
  }
}
