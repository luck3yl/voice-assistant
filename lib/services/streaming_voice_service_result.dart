part of 'streaming_voice_service.dart';

extension StreamingVoiceResultHandling on StreamingVoiceService {
  /// 全局控制指令优先拦截器（严格与 UI 页面显示的指令对齐）
  /// 包含：停止、上一页、下一页、第一页、最后一页、下一个问题、返回、再说一遍、发送、取消
  bool _tryHandleControlCommand(String text) {
    if (text.isEmpty) return false;
    final cleanText = text.trim();

    // 1. 停止播报（UI 显示：停止）
    if (cleanText.contains('停止')) {
      stopSpeaking();
      _awaitingReply = false;
      _awaitingFinal = false;
      _finalFallbackTimer?.cancel();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.stopSpeaking);
      _log('[指令拦截] 停止播报');
      return true;
    }

    // 2. 翻页/滚动指令（UI 显示：上一页、下一页、第一页、最后一页）
    if (cleanText.contains('上一页')) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.scrollUp);
      _log('[指令拦截] 上一页');
      return true;
    }
    if (cleanText.contains('下一页')) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.scrollDown);
      _log('[指令拦截] 下一页');
      return true;
    }
    if (cleanText.contains('最后一页')) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.jumpToBottom);
      _log('[指令拦截] 最后一页');
      return true;
    }
    if (cleanText.contains('第一页')) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.jumpToTop);
      _log('[指令拦截] 第一页');
      return true;
    }

    // 3. 页面导航（UI 显示：返回 / 退出 / 返回首页）
    if (cleanText.contains('返回') || cleanText.contains('退出')) {
      _awaitingReply = false;
      _awaitingFinal = false;
      _finalFallbackTimer?.cancel();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.goBack);
      speak('已返回首页');
      _log('[指令拦截] 返回首页');
      return true;
    }


    // 4. 重复播放（UI 显示：再说一遍）
    if (cleanText.contains('再说一遍')) {
      _awaitingReply = false;
      _awaitingFinal = false;
      _finalFallbackTimer?.cancel();
      _resetPartialBuffer();
      _callback?.onCommand(VoiceCommand.repeatLast);
      _log('[指令拦截] 再说一遍');
      return true;
    }

    // 5. 开启新提问（UI 显示：下一个问题）
    if (cleanText.contains('下一个问题') || cleanText.contains('下个问题')) {
      _resetPartialBuffer();
      _isAwake = true; // 保持唤醒状态，保留历史记录，准备接收下一个新问题！
      _awaitingReply = false;
      _awaitingFinal = false;
      _callback?.onCommand(VoiceCommand.nextQuestion);
      speak('请说');
      _startSleepTimer();
      _log('[指令拦截] 下一个问题 (保留历史，保持唤醒)');
      return true;
    }

    // 6. 取消指令（UI 显示：取消）
    final trailingClean = cleanText.replaceAll(RegExp(r'[，。！？,\.\!\?\s]+$'), '');
    if (trailingClean.endsWith('取消') || cleanText.contains('取消')) {
      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();
      _callback?.onConfirmationCancelled();
      _callback?.onPartialResult('');
      speak('已取消');
      _log('[指令拦截] 已取消');
      return true;
    }

    // 7. 确认发送指令（UI 显示：发送 / 确认发送 / 确认）
    if (cleanText.contains('发送') || cleanText.contains('确认')) {
      // 优先从已固化的 _committed 或 _lastPartial 中提取提问正文（避免被"发送嗯"覆盖）
      String realQuestion = _committed.trim();
      if (realQuestion.isEmpty) {
        realQuestion = _lastPartial.trim();
      }
      if (realQuestion.isEmpty) {
        realQuestion = cleanText.trim();
      }

      // 剥离结尾的"发送"、"确认发送"、"发送嗯"、"发送啊"等指令字词与标点
      realQuestion = realQuestion
          .replaceAll(RegExp(r'(发送|确认发送|确认|发送嗯|发送啊|发送吧|确认发送嗯|确认嗯)[，。！？,\.\!\?\s]*$'), '')
          .trim();
      realQuestion = realQuestion.replaceAll(RegExp(r'[，。！？,\.\!\?\s]+$'), '');

      if (!_awaitingFinal) _sendDone();
      _resetPartialBuffer();

      if (realQuestion.isNotEmpty) {
        _submitQuestion(realQuestion);
      } else {
        _enterIdle();
      }
      _log('[指令拦截] 确认发送: "$realQuestion"');
      return true;
    }


    return false;
  }


  /// 收到 partial（流式、有同音字、无标点）：实时显示，不提交
  void _onPartial(String rawText) {
    final frag = (_isAwake ? _extractAfterWakeWord(rawText) : rawText).trim();
    if (frag.isEmpty) return;

    // 先检测控制指令！如果命中控制指令（如"下一个问题"、"取消"、"发送"），直接拦截返回，绝不推给 UI 展现或拼接！
    if (_tryHandleControlCommand(frag) || _tryHandleControlCommand(rawText)) {
      return;
    }

    _accumulatePartial(frag);
    final fullText = _committed + _currentSeg;

    if (_tryHandleControlCommand(fullText)) {
      return;
    }


    // 如果未命中控制指令，且当前正在播报TTS或正在等待回复，则忽略普通文字输入（防止自我监听回声）
    if (_isSpeaking || _awaitingReply) return;

    // 后端返回了中间结果，立刻重置本地 VAD 静音计时
    _lastVoiceAt = DateTime.now();
    _hasSpoken = true;

    if (!_isAwake) {
      // 未唤醒（Web/后端推流）：拼接文字里检测唤醒词
      if (_containsWakeWord(fullText)) {
        _wake(after: fullText);
      } else {
        _armPrewakeCleanup();
      }
      return;
    }

    // 已唤醒：实时刷新显示（等待明确说出"发送"或点击[发送]按钮）
    final full = fullText.trim();
    if (full != _lastPartial) {
      _lastPartial = full;
      _callback?.onPartialResult(full);
    }
    _resetSleepTimer();
  }

  /// 收到 confirm（长句停顿后的局部非流式纠错）：替换/固化到 _committed 中，清空 _currentSeg
  void _onConfirm(String rawText) {
    final frag = (_isAwake ? _extractAfterWakeWord(rawText) : rawText).trim();
    if (frag.isEmpty) {
      _lastPartial = '';
      _committed = '';
      _currentSeg = '';
      _callback?.onPartialResult('');
      return;
    }


    // 先检测控制指令（如"下一个问题"、"取消"、"发送"），命中即拦截，防止指令字词被写入 _committed
    if (_tryHandleControlCommand(frag) || _tryHandleControlCommand(rawText)) {
      return;
    }

    // confirm 是长句停顿后的分句纠错包：顺延拼接固化到 _committed
    _committed += frag;
    _currentSeg = '';

    final fullText = _committed;

    if (_tryHandleControlCommand(fullText)) {
      return;
    }


    if (_isSpeaking || _awaitingReply) return;

    _lastVoiceAt = DateTime.now();
    _hasSpoken = true;

    if (!_isAwake) {
      if (_containsWakeWord(fullText)) {
        _wake(after: fullText);
      } else {
        _armPrewakeCleanup();
      }
      return;
    }


    final full = fullText.trim();
    if (full != _lastPartial) {
      _lastPartial = full;
      _callback?.onPartialResult(full);
    }
    _resetSleepTimer();
  }



  /// 收到 final（带标点、已纠错的完整句）：替换显示，只有命中发送指令才提交
  void _onFinal(String rawText) {
    final text = rawText.trim();

    // 先做全局控制指令拦截
    if (_tryHandleControlCommand(text)) {
      _awaitingFinal = false;
      _finalFallbackTimer?.cancel();
      return;
    }

    if (text == '[DONE]') {
      if (AsrConfig.ttsEnabled) _ttsManager.flush();
      return;
    }

    _awaitingFinal = false;
    _finalFallbackTimer?.cancel();

    if (text.isEmpty) return;

    // 根据 text 包含了全量还是增量决定拼接逻辑
    String fullFinalText = text;
    if (_committed.isNotEmpty) {
      if (text.startsWith(_committed)) {
        fullFinalText = text;
      } else {
        fullFinalText = _committed + text;
      }
    }

    // 再次对全量 final 文本做控制指令拦截
    if (_tryHandleControlCommand(fullFinalText)) {
      return;
    }

    if (_isSpeaking || _awaitingReply) return;

    _submitFinalText(fullFinalText);
  }

  void _submitFinalText(String fullFinalText) {
    if (fullFinalText.trim().isEmpty) return;

    if (!_isAwake) {
      // 未唤醒：检测唤醒词
      if (_containsWakeWord(fullFinalText)) {
        _wake(after: fullFinalText);
      }
      _resetPartialBuffer();
      return;
    }

    _resetSleepTimer();
    final question = _extractAfterWakeWord(fullFinalText);


    if (question.isEmpty) {
      speak((fullFinalText.contains('下一个问题') || fullFinalText.contains('下个问题')) ? '请说' : '我在');
      _resetPartialBuffer();
      return;
    }

    _handleRecognizedText(question);
  }

  /// 处理识别出的文字（更新界面实时显示，等待明确说"发送"或点击[发送]按钮）
  void _handleRecognizedText(String text) {
    // 再次兜底检查控制指令（包含发送、取消、翻页等）
    if (_tryHandleControlCommand(text)) {
      _resumeAfterTts(); // 重置状态
      return;
    }

    // 更新界面实时识别文字 preview，等待用户口述"发送"或点击屏幕上的【发送】按钮
    final full = text.trim();
    if (full.isNotEmpty && full != _lastPartial) {
      _lastPartial = full;
      _callback?.onPartialResult(full);
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

  void _accumulatePartial(String frag) {
    if (frag.isEmpty) return;
    if (_currentSeg.isEmpty) {
      _currentSeg = frag;
      return;
    }

    // 1. 如果新片段已全量覆盖旧片段
    if (frag.startsWith(_currentSeg) || frag.contains(_currentSeg)) {
      _currentSeg = frag;
      return;
    }
    // 2. 如果旧片段已包含新片段，无需重复追加
    if (_currentSeg.startsWith(frag) || _currentSeg.contains(frag)) {
      return;
    }

    // 3. 计算末端与首端的最长公共重叠字数（例如 "楼操" 与 "操作" 组合成 "楼操作"，消除重复的"操"字）
    int overlapLen = 0;
    final maxCheck = _currentSeg.length < frag.length ? _currentSeg.length : frag.length;
    for (int i = maxCheck; i >= 1; i--) {
      if (_currentSeg.endsWith(frag.substring(0, i))) {
        overlapLen = i;
        break;
      }
    }

    if (overlapLen > 0) {
      _currentSeg += frag.substring(overlapLen);
    } else {
      _currentSeg += frag;
    }
  }

  void _armPrewakeCleanup() {
    _partialSilenceTimer?.cancel();
    _partialSilenceTimer = Timer(StreamingVoiceService._partialSilence, _resetPartialBuffer);
  }


  void _resetPartialBuffer() {
    _partialSilenceTimer?.cancel();
    _lastPartial = '';
    _committed = '';
    _currentSeg = '';
    _callback?.onPartialResult('');
  }


  /// 进入唤醒态
  void _wake({String after = ''}) {
    if (_isAwake) return;
    _isAwake = true;
    _awaitingReply = false; // 允许打断
    _enterAwakeStreaming();
    _callback?.onWakeUp();

    // 唤醒瞬间清空残留的唤醒字词（如"小"）
    _lastPartial = '';
    _committed = '';
    _currentSeg = '';
    _callback?.onPartialResult('');
    
    _log('WAKE triggered, after="$after"');
    final question = _extractAfterWakeWord(after).trim();




    _startSleepTimer();


    if (question.isNotEmpty) {
      _handleRecognizedText(question);
    } else {
      speak((after.contains('下一个问题') || after.contains('下个问题')) ? '请说' : '我在');
    }
  }



  void _processCommand(String text) {
    _resetSleepTimer();

    if (text.contains('停止') || text.contains('别说了') || text.contains('闭嘴') || text == '停') {
      _awaitingReply = false;
      stopSpeaking();
      _callback?.onCommand(VoiceCommand.stopSpeaking);
      return;
    }
    if (text.contains('返回') || text.contains('后退') || text.contains('回去')) {
      _awaitingReply = false;
      _callback?.onCommand(VoiceCommand.goBack);
      return;
    }
    if (text.contains('再说一遍') || text.contains('重复') || text.contains('再说一次')) {
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
    if (text.isEmpty) return '';
    var result = text.trim();

    // 1. 匹配并保留最后一个唤醒词之后的内容，彻底丢弃唤醒词之前的所有环境杂音废话
    for (final w in StreamingVoiceService.wakeWords) {
      final idx = result.lastIndexOf(w);
      if (idx >= 0) {
        result = result.substring(idx + w.length);
      }
    }

    // 2. 彻底剥离开头残留的同音唤醒字词（防止"小"、"智"、"志"、"小智"、"小志"残留在提问正文里）
    result = result.replaceAll(RegExp(r'^(小智|小志|小只|小直|小质|小致|小智小|小志小|小智请|小志请|小智小智请|小志小志请|小|智|志)[，,。.、!！?？\s]*'), '');

    result = result.replaceAll(RegExp(r'^[，,。.、!！?？\s]+'), '').trim();
    return result;
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
