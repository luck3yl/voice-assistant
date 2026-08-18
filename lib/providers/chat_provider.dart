import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/chat_api.dart';

/// 聊天状态管理
class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isRetrieving = false;
  bool _isThinkingState = false;

  bool _hasEverChatted = false;

  /// 自增序号，保证每条消息 id 唯一（避免同毫秒创建导致 id 冲突）
  int _seq = 0;

  /// 本次会话 id（用于后端多轮上下文）
  final String _conversationId =
      'conv-${DateTime.now().millisecondsSinceEpoch}';

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isRetrieving => _isRetrieving;
  bool get isThinkingState => _isThinkingState;
  bool get hasEverChatted => _hasEverChatted;

  /// 正在输出答案（最后一条 AI 消息未完成且已有答案内容）
  bool get isAnswering {
    if (_messages.isEmpty) return false;
    final last = _messages.last;
    return last.role == MessageRole.assistant &&
        !last.done &&
        last.content.isNotEmpty;
  }

  /// 正在思考（最后一条 AI 消息未完成且还没有答案内容）
  bool get isThinking {
    if (_messages.isEmpty) return false;
    final last = _messages.last;
    return last.role == MessageRole.assistant &&
        !last.done &&
        last.content.isEmpty;
  }

  ChatProvider() {
    _messages.add(ChatMessage.system(
      '炼钢规程助手已就绪，请通过语音提问。\n'
      '您可以询问操作规程、安全注意事项等内容。',
    ));
  }

  String _nextId() => '${DateTime.now().millisecondsSinceEpoch}-${_seq++}';

  /// 添加用户消息
  void addUserMessage(String content, {bool isVoice = true}) {
    _hasEverChatted = true;
    _messages.add(ChatMessage(
      id: _nextId(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      isVoiceInput: isVoice,
    ));
    notifyListeners();
  }

  /// 发送消息并流式获取回复
  ///
  /// AI 回答边接收边更新到 assistant 消息，界面实时刷新；
  /// 整个流结束后方法才返回，调用方可据此触发 TTS 播报完整回答。
  Future<void> sendMessage(String content, {bool isVoice = true, Function(String)? onChunk}) async {
    addUserMessage(content, isVoice: isVoice);
    _isLoading = true;
    _isRetrieving = false;
    _isThinkingState = false;
    notifyListeners();

    // 先放一条 assistant 消息（带加载占位），随流式增量更新
    // 用唯一 id，避免和用户消息（同毫秒创建）id 冲突
    final replyId = _nextId();
    _messages.add(ChatMessage(
      id: replyId,
      role: MessageRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      done: false,
    ));
    notifyListeners();

    var lastRaw = '';
    try {
      await for (final raw in ChatApi.streamRaw(
        message: content,
        conversationId: _conversationId,
      )) {
        if (onChunk != null) {
          final newChunk = raw.substring(lastRaw.length);
          if (newChunk.isNotEmpty) onChunk(newChunk);
        }
        lastRaw = raw;
        final upperRaw = raw.toUpperCase();
        final lastToolIdx = upperRaw.lastIndexOf('[TOOL]');
        final lastThoughtIdx = upperRaw.lastIndexOf('THOUGHT');
        final lastThinkTagIdx = upperRaw.lastIndexOf('<THINK>');
        final lastRespTagIdx = upperRaw.lastIndexOf('<RESPONSE>');
        final maxThoughtIdx = [lastThoughtIdx, lastThinkTagIdx, lastRespTagIdx].reduce((a, b) => a > b ? a : b);
        
        if (ChatApi.hasSeparator(raw)) {
          _isRetrieving = false;
          _isThinkingState = false;
        } else if (lastToolIdx > maxThoughtIdx) {
          _isRetrieving = true;
          _isThinkingState = false;
        } else if (maxThoughtIdx > lastToolIdx) {
          _isRetrieving = false;
          _isThinkingState = true;
        }

        // 思考过程 + 答案都实时更新（思考在 --- 之前，答案在 --- 之后）
        _updateAssistant(
          replyId,
          reasoning: ChatApi.extractReasoning(raw),
          content: ChatApi.extractAnswer(raw),
          done: false,
        );
      }

      _isThinkingState = false;
      _isRetrieving = false;
      final finalAnswer = ChatApi.extractAnswer(lastRaw, finished: true);
      _updateAssistant(
        replyId,
        reasoning: ChatApi.extractReasoning(lastRaw),
        content: finalAnswer.isEmpty ? '抱歉，没有获取到回答，请重试。' : finalAnswer,
        done: true,
      );

    } catch (e) {
      debugPrint('[ChatApi Error] 无法连接问答接口 $e');
      _updateAssistant(
        replyId,
        reasoning: ChatApi.extractReasoning(lastRaw),
        content: ChatApi.extractAnswer(lastRaw, finished: true).isEmpty
            ? '网络异常，请重试。($e)'
            : ChatApi.extractAnswer(lastRaw, finished: true),
        done: true,
      );
    } finally {

      _isLoading = false;
      _isRetrieving = false;
      _isThinkingState = false;
      notifyListeners();
    }
  }

  /// 流式更新 assistant 消息的思考过程 / 答案 / 完成状态
  void _updateAssistant(
    String id, {
    String? reasoning,
    String? content,
    bool? done,
  }) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final old = _messages[idx];
    _messages[idx] = ChatMessage(
      id: old.id,
      role: old.role,
      content: content ?? old.content,
      timestamp: old.timestamp,
      reasoning: reasoning ?? old.reasoning,
      done: done ?? old.done,
    );
    notifyListeners();
  }

  /// 清空对话并重置返回待机首页
  void clearMessages() {
    _messages.clear();
    _hasEverChatted = false;
    _isLoading = false;
    _isRetrieving = false;
    _isThinkingState = false;
    notifyListeners();
  }
}

