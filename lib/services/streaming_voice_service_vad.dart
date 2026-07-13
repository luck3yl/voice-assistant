part of 'streaming_voice_service.dart';

extension StreamingVoiceVAD on StreamingVoiceService {
  void _feedVad(Uint8List chunk) {
    if (!_isAwake || _awaitingFinal) return;
    final rms = _rms(chunk);
    // 节流打印实时能量，便于校准阈值
    if (AsrConfig.debug) {
      final now = DateTime.now();
      if (now.difference(_lastRmsLogAt).inMilliseconds >= 500) {
        _lastRmsLogAt = now;
        _log('rms=${rms.toStringAsFixed(4)} (阈值 ${AsrConfig.vadRmsThreshold})');
      }
    }
    if (rms > AsrConfig.vadRmsThreshold) {
      _lastVoiceAt = DateTime.now();
      if (!_hasSpoken) {
        _hasSpoken = true;

        _callback?.onSpeechStart();
        _log('VAD speech start (rms=${rms.toStringAsFixed(4)})');
      }
    }
  }

  double _rms(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    if (n == 0) return 0;
    final data = ByteData.sublistView(bytes);
    double sumSq = 0;
    for (var i = 0; i < n; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += s * s;
    }
    return math.sqrt(sumSq / n);
  }

  /// 静音 2 秒 → 发 done，等后端 final
  void _vadTick() {
    // 如果没有在使用本地唤醒，并且处于待机推流状态，也允许触发 done 来截断唤醒词
    final canTrigger = _isAwake || (!_useLocalWake && _isListening);
    if (!canTrigger ||
        _isSpeaking ||
        _awaitingReply ||
        _awaitingFinal ||
        !_hasSpoken) {
      return;
    }
    final silenceMs = DateTime.now().difference(_lastVoiceAt).inMilliseconds;
    if (silenceMs >= AsrConfig.vadSilenceMs) {
      _log('VAD: 静音 ${silenceMs}ms (>=${AsrConfig.vadSilenceMs}) → 发 done');
      _sendDone();
    }
  }

  void _sendDone() {
    _hasSpoken = false;
    _awaitingFinal = true;
    try {
      _channel?.sink.add(AsrConfig.doneMessage);
      _log('sent done (等后端 final...)');
    } catch (e) {
      _log('send done error: $e');
    }
    // 兜底：后端迟迟不返回 final，视为无效会话直接退回休眠
    _finalFallbackTimer?.cancel();
    _finalFallbackTimer = Timer(
      const Duration(milliseconds: AsrConfig.finalTimeoutMs),
      () {
        if (!_awaitingFinal) return;
        _log('final 超时，放弃提交并退回休眠');
        _enterIdle();
      },
    );
  }

  Future<void> _stopStreaming({bool keepAwaitFinal = false}) async {
    _isListening = false;
    _vadTimer?.cancel();
    _vadTimer = null;
    
    if (!keepAwaitFinal) {
      _finalFallbackTimer?.cancel();
      _finalFallbackTimer = null;
      _awaitingFinal = false;
    }
    
    _hasSpoken = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
  }

}
