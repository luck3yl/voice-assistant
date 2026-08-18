
import 'package:flutter_tts/flutter_tts.dart';

class TtsStreamManager {
  final FlutterTts tts;
  final Function onTtsStart;
  final Function onTtsEnd;
  /// 即将朗读某句话时的回调（传入原始未净化文本）
  final void Function(String sentence)? onSentencePlaying;
  String _buffer = '';
  final RegExp _sentenceEndRegex = RegExp(r'[。！？，；,!;?\n]+');
  
  bool _isPlaying = false;
  final List<String> _ttsQueue = [];
  final List<String> _rawQueue = []; // 与 _ttsQueue 同步的原始文本队列（用于音画同步）
  bool _isMuted = false;
  
  bool _thoughtSpoken = false;
  int _toolSpokenCount = 0;


  TtsStreamManager(this.tts, this.onTtsStart, this.onTtsEnd, {this.onSentencePlaying}) {
    tts.setStartHandler(() {
      onTtsStart();
    });
    tts.setCompletionHandler(() {
      _isPlaying = false;
      if (_ttsQueue.isEmpty) {
        onTtsEnd();
      }
      _playNext();
    });
    tts.setErrorHandler((_) {
      _isPlaying = false;
      if (_ttsQueue.isEmpty) {
        onTtsEnd();
      }
      _playNext();
    });
  }

  void feedChunk(String chunk) {
    _buffer += chunk;
    _checkMuteState();
    if (!_isMuted) {
      _processBuffer();
    }
  }

  void flush() {
    if (!_isMuted && _buffer.trim().isNotEmpty) {
      _enqueueAndPlay(_buffer);
      _buffer = '';
    }
  }

  void stopAndClear() {
    _buffer = '';
    _ttsQueue.clear();
    _rawQueue.clear();
    _isPlaying = false;
    _isMuted = false;
    _thoughtSpoken = false;
    _toolSpokenCount = 0;

    tts.stop();
  }

  void _checkMuteState() {
    if (!_isMuted) {
      final match = RegExp(
        r'THOUGHT|\[TOOL\]|EVALUATION|---|</?think>|</?response>|\bresponse\b|知识检索|我先|轮检索|技能',
        caseSensitive: false,
      ).firstMatch(_buffer);
      if (match != null) {
        _enqueueAndPlay(_buffer.substring(0, match.start));
        _isMuted = true;
        _buffer = _buffer.substring(match.start);
      }
    }

    if (_isMuted) {
      if (RegExp(r'THOUGHT', caseSensitive: false).hasMatch(_buffer)) {
        if (!_thoughtSpoken) {
          _ttsQueue.add("已收到您的问题，正在为您查询相关领域的专业知识，请稍等...");
          _rawQueue.add(''); // 系统插入语，无需高亮
          _playNext();
          _thoughtSpoken = true;
        }
        _buffer = _buffer.replaceAll(RegExp(r'THOUGHT', caseSensitive: false), '_spoke_thought');
      }

      if (RegExp(r'\[TOOL\]', caseSensitive: false).hasMatch(_buffer)) {
        if (_toolSpokenCount == 0) {
          // _ttsQueue.add("正在为您分析核心要点，马上为您呈现...");
        } else if (_toolSpokenCount == 1) {
          _ttsQueue.add("正在补充查询更多细节数据...");
          _rawQueue.add(''); // 系统插入语，无需高亮
        }
        _playNext();
        _toolSpokenCount++;
        _buffer = _buffer.replaceAll(RegExp(r'\[TOOL\]', caseSensitive: false), '_spoke_tool');
      }

      final docMatch = RegExp(r'本次检索到[\s\n\*]*(\d+)[\s\n\*]*篇[\s\n\*]*文档').firstMatch(_buffer);
      if (docMatch != null) {
        String count = docMatch.group(1)!;
        _ttsQueue.add("搜索到 $count 篇相关资料，正在为您快速筛选整合...");
        _rawQueue.add(''); // 系统插入语，无需高亮
        _playNext();
        _buffer = _buffer.replaceRange(docMatch.start, docMatch.end, '');
      }

      final loopMatch = RegExp(r'经过[\s\n\*]*(\d+)[\s\n\*]*次检索').firstMatch(_buffer);
      if (loopMatch != null) {
        String count = loopMatch.group(1)!;
        _ttsQueue.add("经过 $count 轮深度筛选与验证，马上为您解答。");
        _rawQueue.add(''); // 系统插入语，无需高亮
        _playNext();
        _buffer = _buffer.replaceRange(loopMatch.start, loopMatch.end, '');
      }

      int u1 = _buffer.indexOf('### '); // 更宽泛的匹配
      int u2 = _buffer.indexOf('---');
      int u3 = _buffer.indexOf('**一、');
      int u4 = _buffer.indexOf('**1.');
      int u5 = _buffer.indexOf('检索分析总结');
      int u6 = _buffer.indexOf('深度解析答案');
      
      final respMatch = RegExp(r'(?:\n|^)\s*(?:</?think>|</?response>|\bresponse\b)\s*(?:\n|$)', caseSensitive: false).firstMatch(_buffer);
      int u7 = respMatch != null ? respMatch.start : -1;
      
      int unmuteIdx = _getEarliest([u1, u2, u3, u4, u5, u6, u7]);
      if (unmuteIdx != -1) {
        _isMuted = false;
        _buffer = _buffer.substring(unmuteIdx);
      } else {
        // 增加缓冲保留长度，避免跨 chunk 的正则匹配被拦腰截断
        if (_buffer.length > 500) {
          _buffer = _buffer.substring(_buffer.length - 500);
        }
      }
    }
  }

  int _getEarliest(List<int> indices) {
    int min = -1;
    for (int idx in indices) {
      if (idx != -1 && (min == -1 || idx < min)) {
        min = idx;
      }
    }
    return min;
  }

  void _processBuffer() {
    while (true) {
      final match = _sentenceEndRegex.firstMatch(_buffer);
      if (match == null) break;

      final endIndex = match.end;
      final sentence = _buffer.substring(0, endIndex);
      _buffer = _buffer.substring(endIndex);
      
      _enqueueAndPlay(sentence);
    }
  }

  void _enqueueAndPlay(String rawSentence) {
    final cleanText = _purifyText(rawSentence);
    if (cleanText.isEmpty) return;
    // 队列存储 [cleanText, rawSentence] 对，供音画同步使用
    _ttsQueue.add(cleanText);
    _rawQueue.add(rawSentence);
    _playNext();
  }

  void _playNext() async {
    if (_isPlaying || _ttsQueue.isEmpty) return;
    
    _isPlaying = true;
    final textToSpeak = _ttsQueue.removeAt(0);
    final rawSentence = _rawQueue.isNotEmpty ? _rawQueue.removeAt(0) : textToSpeak;
    // 音画同步：通知外界当前将要朗读的句子（传原始文本用于在消息内容中定位）
    onSentencePlaying?.call(rawSentence);
    try {
      await tts.speak(textToSpeak);
    } catch (_) {}
  }

  String _purifyText(String raw) {
    String t = raw;

    t = t.replaceAll(RegExp(r'</?think>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'</?response>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'(?:\n|^)\s*\bresponse\b\s*(?:\n|$)', caseSensitive: false), ' ');

    t = t.replaceAll(RegExp(r'###\s*.*检索分析总结.*'), '核实完毕，为您总结如下：');
    t = t.replaceAll(RegExp(r'###\s*.*深度解析答案.*'), '具体要求是：');
    t = t.replaceAll(RegExp(r'###\s*.*'), '内容如下：');
    t = t.replaceAll(RegExp(r'🔗?\s*文档来源'), '以上标准参考了：');
    
    t = t.replaceAll('|', '，');

    t = t.replaceAll(RegExp(r'\.[a-zA-Z0-9]{3,4}'), '');

    t = t.replaceAll(RegExp(r'[\*#>`\-]'), '');
    t = t.replaceAll(RegExp(r'\\[nr]'), ''); 
    t = t.replaceAll('/n', '');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll('\r', ' ');

    t = t.trim();
    if (t.replaceAll(RegExp(r'[，。！？]'), '').trim().isEmpty) return '';

    return t;
  }
}
