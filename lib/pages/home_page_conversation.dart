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
    if (voiceProvider.isListening) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSimpleText('正在聆听...'),
          const SizedBox(height: 12),
          _buildVoiceCommandsPanel(['发送', '取消']),
        ],
      );
    } else if (chatProvider.isAnswering) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSimpleText('正在回答...'),
          const SizedBox(height: 12),
          _buildVoiceCommandsPanel(['上一页', '下一页', '第一页', '最后一页']),
        ],
      );
    } else if (chatProvider.isRetrieving) {
      return _buildSimpleText('正在检索...');
    } else if (chatProvider.isThinkingState || chatProvider.isThinking || voiceProvider.isProcessing) {
      return _buildSimpleText('正在思考...');
    } else if (voiceProvider.isAwake) {
      return _buildVoiceCommandsPanel(['下一个问题', '上一页', '下一页', '第一页', '最后一页']);
    }

    return const SizedBox.shrink();
  }

  Widget _buildSimpleText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.accentColor,
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildVoiceCommandsPanel(List<String> commands) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF050B14).withOpacity(0.65), // Darker glass background for better contrast
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic,
                  size: 18,
                  color: AppTheme.accentColor, // Changed back to blue
                ),
                const SizedBox(width: 6),
                Text(
                  '用户语音指令',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.accentColor, // Changed back to blue
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ...commands.asMap().entries.map((entry) {
            final isLast = entry.key == commands.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8.0),
              child: _buildCommandTag(entry.value),
            );
          }),
        ],
      ),
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandTag(String command) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2), // Distinct soft background
        borderRadius: BorderRadius.circular(4), // Small border radius
      ),
      alignment: Alignment.center, // Center text inside the stretched tag
      child: Text(
        '"$command"',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white, // Changed to white as requested for prominence
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}