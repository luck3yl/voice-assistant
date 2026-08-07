import 'package:flutter/foundation.dart';

/// 语音状态
enum VoiceState {
  idle,        // 待命，等待唤醒
  awake,       // 已唤醒，准备接收指令
  listening,   // 正在听用户说话
  confirming,  // 识别完成，等待用户确认发送
  processing,  // 识别/AI 处理中
  speaking,    // 正在播报回复
  error,       // 错误
}

/// 语音交互状态管理（纯语音免手操模式）
///
/// 交互流程：
/// idle -> (唤醒词触发) -> awake -> (检测到说话) -> listening
/// -> (VAD静音检测/说话结束) -> processing -> (回复生成)
/// -> speaking -> (播报完毕) -> awake -> (超时无操作) -> idle
class VoiceProvider extends ChangeNotifier {
  VoiceState _state = VoiceState.idle;
  String _recognizedText = '';
  String _pendingQuestion = '';
  String _errorMessage = '';
  double _volumeLevel = 0.0;
  bool _isConnected = false;
  bool _hasEverWokenUp = false;


  // 唤醒后的自动休眠倒计时（秒）
  static const int awakeTimeoutSeconds = 30;

  VoiceState get state => _state;
  String get recognizedText => _recognizedText;
  String get pendingQuestion => _pendingQuestion;
  String get errorMessage => _errorMessage;
  double get volumeLevel => _volumeLevel;
  bool get isConnected => _isConnected;
  bool get hasEverWokenUp => _hasEverWokenUp;


  bool get isIdle => _state == VoiceState.idle;
  bool get isAwake => _state == VoiceState.awake;
  bool get isListening => _state == VoiceState.listening;
  bool get isConfirming => _state == VoiceState.confirming;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;

  bool _isWaitingForNextQuestion = false;
  bool get isWaitingForNextQuestion => _isWaitingForNextQuestion;

  /// 用户点击或口述“下一个问题”：开启专属新一页等待输入
  void prepareNextQuestion() {
    _isWaitingForNextQuestion = true;
    _state = VoiceState.awake;
    _recognizedText = '';
    notifyListeners();
  }

  void resetNextQuestionFlag() {
    _isWaitingForNextQuestion = false;
    notifyListeners();
  }

  /// 唤醒词被触发
  void onWakeUp() {
    _state = VoiceState.awake;
    _isWaitingForNextQuestion = true;
    _recognizedText = '';
    _errorMessage = '';
    _hasEverWokenUp = true;
    notifyListeners();
  }


  /// 检测到用户开始说话（VAD 触发）
  void onSpeechStart() {
    if (_state == VoiceState.confirming) {
      // 确认模式下保持状态，只清空识别缓冲
      _recognizedText = '';
      notifyListeners();
      return;
    }
    if (_isWaitingForNextQuestion) {
      _state = VoiceState.listening;
      _recognizedText = '';
      notifyListeners();
    }
  }

  /// 实时更新识别中间结果（边说边显示）
  void updatePartialResult(String text) {
    // 只有在开口/点击了“下一个问题”或唤醒之后（_isWaitingForNextQuestion == true），才允许触发识别模式！
    if (!_isWaitingForNextQuestion && _state != VoiceState.listening) {
      return;
    }
    _recognizedText = text;
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      if (_state == VoiceState.awake || _state == VoiceState.listening) {
        _state = VoiceState.listening;
      }
    } else {
      if (_state == VoiceState.listening) {
        _state = VoiceState.awake;
      }
    }
    notifyListeners();
  }



  /// 用户说话结束，进入处理阶段
  void onSpeechEnd(String finalText) {
    _state = VoiceState.processing;
    _isWaitingForNextQuestion = false;
    // 识别文字已成为正式的对话消息，清空实时识别缓冲，避免残留在"正在识别"气泡里
    _recognizedText = '';
    notifyListeners();
  }


  /// AI 回复开始播报
  void onSpeakingStart() {
    _state = VoiceState.speaking;
    notifyListeners();
  }

  /// 回复完成，回到唤醒待命状态
  void onSpeakingEnd() {
    _state = VoiceState.awake;
    notifyListeners();
  }

  /// 进入确认模式：显示识别结果，等用户说"确认发送"或"取消"
  void onConfirmationNeeded(String question) {
    _state = VoiceState.confirming;
    _pendingQuestion = question;
    _recognizedText = '';
    notifyListeners();
  }

  /// 用户取消了发送
  void onConfirmationCancelled() {
    _state = VoiceState.awake;
    _pendingQuestion = '';
    _recognizedText = '';
    notifyListeners();
  }

  /// 超时无操作或点击返回，完全复位回到待机首页
  void onTimeout() {
    _state = VoiceState.idle;
    _hasEverWokenUp = false;
    _isWaitingForNextQuestion = false;
    _recognizedText = '';
    _pendingQuestion = '';
    notifyListeners();
  }


  /// 更新音量
  void updateVolume(double level) {
    _volumeLevel = level;
    notifyListeners();
  }

  /// 连接状态变更
  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  /// 错误状态
  void setError(String message) {
    _state = VoiceState.error;
    _errorMessage = message;
    notifyListeners();

    // 3秒后自动恢复到待命
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == VoiceState.error) {
        _state = VoiceState.idle;
        notifyListeners();
      }
    });
  }

  /// 重置
  void reset() {
    _state = VoiceState.idle;
    _recognizedText = '';
    _errorMessage = '';
    _volumeLevel = 0.0;
    notifyListeners();
  }
}
