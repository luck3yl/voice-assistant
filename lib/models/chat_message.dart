/// 聊天消息模型
enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isVoiceInput;

  /// AI 思考过程（仅 assistant 消息使用，可为空）
  final String reasoning;

  /// 该 assistant 消息是否已生成完成
  final bool done;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isVoiceInput = false,
    this.reasoning = '',
    this.done = true,
  });

  factory ChatMessage.user(String content, {bool isVoice = true}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      isVoiceInput: isVoice,
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.system,
      content: content,
      timestamp: DateTime.now(),
    );
  }
}
