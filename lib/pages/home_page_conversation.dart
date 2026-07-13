part of 'home_page.dart';

class _ConversationLayout extends StatelessWidget {
  final VoiceProvider voiceProvider;
  final ChatProvider chatProvider;
  final GlobalKey<_ChatListState> chatListKey;

  const _ConversationLayout({
    required this.voiceProvider,
    required this.chatProvider,
    required this.chatListKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部栏
        _TopBar(voiceProvider: voiceProvider),

        // 主内容
        Expanded(
          child: Row(
            children: [
              // 左侧对话列表（自动滚动到底部）
              Expanded(
                flex: 7,
                child: _ChatList(
                  key: chatListKey,
                  voiceProvider: voiceProvider,
                ),
              ),

              // 右侧语音球状态
              SizedBox(
                width: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 识别文字已移到对话区展示，右侧面板不再显示
                    const SizedBox(
                      width: 100,
                      height: 100,
                      child: VoiceOrb(),
                    ),
                    const SizedBox(height: 10),
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) => _buildStatusText(chatProvider),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 底部状态栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _OnlineStatus(isConnected: voiceProvider.isConnected),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(ChatProvider chatProvider) {
    String text = '';
    if (voiceProvider.isConfirming) {
      text = '等待确认发送...\n确认请说："发送"\n想要修改请说："取消"';
    } else if (voiceProvider.isListening) {
      text = '正在聆听...';
    } else if (chatProvider.isAnswering) {
      text = '正在回答...\n翻页请说：\n"上一页"、"下一页"\n"第一页" 或 "最后一页"';
    } else if (chatProvider.isRetrieving) {
      text = '正在检索...';
    } else if (chatProvider.isThinkingState || chatProvider.isThinking || voiceProvider.isProcessing) {
      text = '正在思考...';
    } else if (voiceProvider.isAwake) {
      text = '继续提问请说:\n"下一个问题"\n翻页请说:\n"上一页"、"下一页"\n"第一页" 或 "最后一页"';
    }

    if (text.isEmpty) return const SizedBox.shrink();

    List<InlineSpan> spans = [];
    final RegExp regex = RegExp(r'("[^"]+")');
    final matches = regex.allMatches(text);
    
    int lastMatchEnd = 0;
    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 18, // 放大指令字体
          fontWeight: FontWeight.w900, // 加粗指令
        ),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 16, // 基础描述文字大小
          fontWeight: FontWeight.w600,
          color: AppTheme.accentColor,
          height: 1.6,
        ),
        children: spans,
      ),
      textAlign: TextAlign.center,
    );
  }
}