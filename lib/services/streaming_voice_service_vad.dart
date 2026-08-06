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
    // 老板要求：不再根据静音时长自动结束识别，用户想停顿多久都可以。
    // 直到用户明确说出“发送”等指令时才会停止。
  }

  void _sendDone() {
    _hasSpoken = false;
    _awaitingFinal = true;
    try {
      _channel?.sink.add(AsrConfig.doneMessage);
      _log('sent done (后端不再返回 final，等待 500ms 后前端主动提交...)');
    } catch (e) {
      _log('send done error: $e');
    }
    
    // 后端不再返回 final。我们在发完 done 后，稍等 500ms（让可能在途的最后一个 confirm 收完），然后直接前端自己提交。
    _finalFallbackTimer?.cancel();
    _finalFallbackTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        if (!_awaitingFinal) return;
        _awaitingFinal = false;
        
        final text = (_committed + _currentSeg).trim();
        if (text.isEmpty) {
          _log('主动提交：内容为空，退回休眠');
          _enterIdle();
          return;
        }
        
        _log('主动提交：$text');
        _submitFinalText(text);
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
