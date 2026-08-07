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

              // 右侧语音球状态（自适应防高度溢出）
              SizedBox(
                width: 180,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: VoiceOrb(),
                          ),
                          const SizedBox(height: 8),
                          Consumer<ChatProvider>(
                            builder: (context, chatProvider, _) => _buildStatusText(context, chatProvider),
                          ),

                        ],
                      ),
                    ),
                  ),
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

  Widget _buildStatusText(BuildContext context, ChatProvider chatProvider) {
    // 1. 如果回答已完成（!isLoading 且 !isAnswering），绝对优先展示后置指令控制面板！
    if (!chatProvider.isLoading && !chatProvider.isAnswering && !voiceProvider.isListening) {
      return _buildVoiceCommandsPanel(context, ['下一个问题', '上一页', '下一页', '第一页', '最后一页']);
    }

    if (voiceProvider.isListening) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSimpleText('正在聆听...'),
          const SizedBox(height: 8),
          _buildVoiceCommandsPanel(context, ['发送', '取消']),
        ],
      );
    } else if (chatProvider.isAnswering) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSimpleText('正在回答...'),
          const SizedBox(height: 8),
          _buildVoiceCommandsPanel(context, ['上一页', '下一页', '第一页', '最后一页']),
        ],
      );
    } else if (chatProvider.isRetrieving) {
      return _buildSimpleText('正在检索...');
    } else if (chatProvider.isThinkingState || chatProvider.isThinking || (voiceProvider.isProcessing && chatProvider.isLoading)) {
      return _buildSimpleText('正在思考...');
    }

    return _buildVoiceCommandsPanel(context, ['下一个问题', '上一页', '下一页', '第一页', '最后一页']);
  }







  Widget _buildSimpleText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.accentColor,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildVoiceCommandsPanel(BuildContext context, List<String> commands) {

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF050B14).withOpacity(0.65),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
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
                        size: 16,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '用户语音指令',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...commands.asMap().entries.map((entry) {
                    final isLast = entry.key == commands.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 6.0),
                      child: _buildCommandTag(context, entry.value),
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

  Widget _buildCommandTag(BuildContext context, String command) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleCommandTap(context, command),
        borderRadius: BorderRadius.circular(6),
        splashColor: AppTheme.accentColor.withValues(alpha: 0.3),
        highlightColor: AppTheme.accentColor.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.35),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '"$command"',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }


  void _handleCommandTap(BuildContext context, String command) async {
    final voiceService = getPlatformVoiceService();
    if (command == '发送') {
      final text = voiceProvider.recognizedText.trim();
      if (text.isNotEmpty) {
        context.read<VoiceProvider>().onSpeechEnd(text);
        await context.read<ChatProvider>().sendMessage(text);
        voiceService.resumeListening();
        if (context.mounted) {
          context.read<VoiceProvider>().onSpeakingEnd();
        }
      }
    }

 else if (command == '取消') {
      context.read<VoiceProvider>().onConfirmationCancelled();
      voiceService.stopSpeaking();
    } else if (command == '上一页') {
      chatListKey.currentState?.scrollUp(voiceService);
    } else if (command == '下一页') {
      chatListKey.currentState?.scrollDown(voiceService);
    } else if (command == '第一页') {
      chatListKey.currentState?.jumpToTop();
    } else if (command == '最后一页') {
      chatListKey.currentState?.jumpToBottom();
    } else if (command == '下一个问题') {
      context.read<VoiceProvider>().prepareNextQuestion();
      voiceService.resumeListening();
      voiceService.speak('请说');
    }


 else if (command == '停止') {
      context.read<VoiceProvider>().onSpeakingEnd();
      voiceService.stopSpeaking();
    } else if (command == '返回') {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }
  }
}