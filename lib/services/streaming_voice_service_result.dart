part of 'streaming_voice_service.dart';

extension StreamingVoiceResultHandling on StreamingVoiceService {
  bool _tryHandleScrollCommand(String text) {
    if (text.contains('上一页') || text.contains('往上翻')) {
      _callback?.onCommand(VoiceCommand.scrollUp);
      return true;
    }
    if (text.contains('下一页') || text.contains('往下翻')) {
      _callback?.onCommand(VoiceCommand.scrollDown);
      return true;
    }
    if (text.contains('底') && text.contains('回')) {
      _callback?.onCommand(VoiceCommand.jumpToBottom);
      return true;
    }
    if (text.contains('顶') && text.contains('回')) {
      _callback?.onCommand(VoiceCommand.jumpToTop);
      return true;
    }
    return false;
  }

  bool _tryHandleConfirmationCommand(String text) {
    if (!_awaitingConfirmation) return false;
    
    if (text.contains('确认') || text.contains('发送') || text.contains('对')) {
      final q = _pendingQuestion;
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _submitQuestion(q);
      return true;
    } else if (text.contains('取消') || text.contains('不对') || text.contains('错') || text.contains('算了')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onConfirmationCancelled();
      speak('已取消');
      return true;
    }
    return false;
  }

  /// 收到 partial（流式、有同音字、无标点）：实时显示，不提交
  void _onPartial(String rawText) {
    final frag = (_isAwake ? _extractAfterWakeWord(rawText) : rawText).trim();
    if (frag.isEmpty) return;

    _accumulate(frag);
    final fullText = _committed + _currentSeg;

    // 哪怕正在播报TTS，也要放行纯粹的翻页控制指令
    if (_tryHandleScrollCommand(fullText)) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      return;
    }

    // 非翻页指令，如果在播报则直接忽略
    if (_isSpeaking) return;

    if (_awaitingConfirmation) {
      if (_tryHandleConfirmationCommand(fullText)) {
        return;
      }
    }

    if (_awaitingReply) return;

    // 后端返回了中间结果，立刻重置本地 VAD 静音计时
    _lastVoiceAt = DateTime.now();
    _hasSpoken = true;

    if (!_isAwake) {
      // 在纯后端推流模式下，即使处于休眠状态，也要能在 partial 阶段极速拦截翻页指令
      if (_tryHandleScrollCommand(fullText)) {
        _resetPartialBuffer();
        if (!_awaitingFinal) _sendDone();
        return;
      }

      // 未唤醒（Web/回退）：拼接文字里检测唤醒词
      if (_containsWakeWord(fullText)) {
        _resetPartialBuffer();
        _wake(after: fullText);
      } else {
        _armPrewakeCleanup();
      }
      return;
    }

    // 已唤醒：实时刷新显示（等 final 才提交）
    final full = fullText.trim();
    if (full != _lastPartial) {
      _lastPartial = full;
      _callback?.onPartialResult(full);
    }
    _resetSleepTimer();
  }

  /// 收到 final（带标点、已纠错的完整句）：替换显示 + 作为问题提交
  void _onFinal(String rawText) {
    final text = rawText.trim();

    // 无论是否休眠、是否在等回答、是否在播报，都优先响应翻页指令
    if (_tryHandleScrollCommand(text)) {
      _awaitingFinal = false;
      _finalFallbackTimer?.cancel();
      _resetPartialBuffer();
      return;
    }

    if (_isSpeaking) return;

    if (_awaitingReply) return;
    
    if (text == '[DONE]') {
      if (AsrConfig.ttsEnabled) _ttsManager.flush();
      return;
    }

    _awaitingFinal = false;
    _finalFallbackTimer?.cancel();

    if (text.isEmpty) return;

    if (!_isAwake) {
      // 休眠状态下，允许直接使用翻页指令
      if (_tryHandleScrollCommand(text)) {
        _resetPartialBuffer();
        return;
      }

      // 未唤醒：final 里检测唤醒词
      if (_containsWakeWord(text)) {
        _wake(after: text);
      }
      _resetPartialBuffer();
      return;
    }

    _resetSleepTimer();
    final question = _extractAfterWakeWord(text);
    _resetPartialBuffer();

    if (question.isEmpty) {
      // 纯唤醒词，根据具体词语给不同应答
      speak(text.contains('下一个问题') ? '请说' : '我在');
      return;
    }

    _handleRecognizedText(question);
  }

  /// 处理识别出的文字，根据是否处于确认态决定下一步
  void _handleRecognizedText(String text) {
    // 全局拦截控制指令，绕过确认流，直接执行！
    if (text.contains('下一页') || text.contains('往下翻')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      _callback?.onCommand(VoiceCommand.scrollDown);
      _resumeAfterTts(); // 重置状态
      return;
    }
    if (text.contains('上一页') || text.contains('往上翻')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      _callback?.onCommand(VoiceCommand.scrollUp);
      _resumeAfterTts(); // 重置状态
      return;
    }
    if (text.contains('底') && text.contains('回')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      _callback?.onCommand(VoiceCommand.jumpToBottom);
      _resumeAfterTts(); // 重置状态
      return;
    }
    if (text.contains('顶') && text.contains('回')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      _callback?.onCommand(VoiceCommand.jumpToTop);
      _resumeAfterTts(); // 重置状态
      return;
    }
    if (text.contains('返回') || text.contains('后退')) {
      _awaitingConfirmation = false;
      _pendingQuestion = '';
      _callback?.onCommand(VoiceCommand.goBack);
      _resumeAfterTts(); // 重置状态
      return;
    }

    if (_awaitingConfirmation) {
      // 正在等待确认，判断用户的回答
      if (!_tryHandleConfirmationCommand(text)) {
        // 如果后端发来的只是刚才 partial 结果的 final 确认，文字没变，直接忽略，防止打断前端引擎
        if (text == _pendingQuestion) return;

        // 说的是其他内容，当作新的问题覆盖并重新要求确认
        _pendingQuestion = text;
        _callback?.onConfirmationNeeded(text);
        if (_useLocalWake) {
          _stopStreaming().then((_) {
            if (_awaitingConfirmation) _wakeDetector.safeRestart();
          });
        }
      }
    } else {
      // 常规问题，进入确认流程
      _awaitingConfirmation = true;
      _pendingQuestion = text;
      _callback?.onConfirmationNeeded(text);
      if (_useLocalWake) {
        _stopStreaming().then((_) {
          if (_awaitingConfirmation) _wakeDetector.safeRestart();
        });
      }
    }
  }

  /// 提交问题：交给上层处理（指令/AI）
  void _submitQuestion(String question) {
    _callback?.onFinalResult(question);
    _processCommand(question);
    
    // 提交问题后，进入等待回复状态，并同时进入休眠监听（启用前端识别）
    _awaitingReply = true;
    _awaitingFinal = false;
    _isAwake = false;
    _log('等待回复... (问题: "$question")');

    if (_useLocalWake) {
      // 停止后端推流，启动前端本地唤醒引擎，专门听翻页和下一个问题
      _stopStreaming().then((_) {
        if (!_isAwake) _wakeDetector.safeRestart();
      });
    }
  }

  void _accumulate(String frag) {
    if (_currentSeg.isEmpty) {
      _currentSeg = frag;
    } else if (_overlaps(frag, _currentSeg)) {
      _currentSeg = frag.length >= _currentSeg.length ? frag : _currentSeg;
    } else {
      _committed += _currentSeg;
      _currentSeg = frag;
    }
  }

  void _armPrewakeCleanup() {
    _partialSilenceTimer?.cancel();
    _partialSilenceTimer = Timer(StreamingVoiceService._partialSilence, _resetPartialBuffer);
  }

  bool _overlaps(String a, String b) =>
      a.startsWith(b) || b.startsWith(a) || a.contains(b) || b.contains(a);

  void _resetPartialBuffer() {
    _partialSilenceTimer?.cancel();
    _lastPartial = '';
    _committed = '';
    _currentSeg = '';
  }

  /// 进入唤醒态
  void _wake({String after = ''}) {
    if (_isAwake) return;
    _isAwake = true;
    _awaitingReply = false; // 允许打断
    _enterAwakeStreaming();
    _callback?.onWakeUp();
    
    _log('WAKE triggered, after="$after"');
    final question = _extractAfterWakeWord(after).trim();

    _startSleepTimer();

    if (question.isNotEmpty) {
      _handleRecognizedText(question);
    } else {
      speak(after.contains('下一个问题') ? '请说' : '我在');
    }
  }

  void _processCommand(String text) {
    _resetSleepTimer();

    if (text.contains('停止') || text.contains('别说了')) {
      _awaitingReply = false;
      stopSpeaking();
      _callback?.onCommand(VoiceCommand.stopSpeaking);
      return;
    }
    if (text.contains('返回') || text.contains('后退')) {
      _awaitingReply = false;
      _callback?.onCommand(VoiceCommand.goBack);
      return;
    }
    if (text.contains('再说一遍') || text.contains('重复')) {
      _awaitingReply = false;
      _callback?.onCommand(VoiceCommand.repeatLast);
      return;
    }

    // 普通问题 → 交给 AI，进入"等回复"，暂停捕获新输入
    _awaitingReply = true;
    _callback?.onAiReply(text);
  }

  bool _containsWakeWord(String text) =>
      StreamingVoiceService.wakeWords.any((w) => text.contains(w));

  String _extractAfterWakeWord(String text) {
    var result = text;
    for (final w in StreamingVoiceService.wakeWords) {
      result = result.replaceAll(w, '');
    }
    result = result.replaceAll(RegExp(r'^[，,。.、!！?？\s]+'), '');
    return result.trim();
  }

  void _startSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(StreamingVoiceService._awakeTimeout, () {
      if (_awaitingReply || _isSpeaking) {
        _startSleepTimer();
        return;
      }
      _log('awake timeout -> idle');
      _enterIdle();
    });
  }

  void _resetSleepTimer() {
    if (_isAwake) _startSleepTimer();
  }
}
