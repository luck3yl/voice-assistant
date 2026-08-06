part of 'home_page.dart';

class _ChatList extends StatefulWidget {
  final VoiceProvider voiceProvider;

  const _ChatList({super.key, required this.voiceProvider});

  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  late ScrollController _scrollController;
  int _lastPairCount = 0;
  int _lastLiveLength = 0;
  int _lastContentLength = 0;
  int _lastReasoningLength = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _scrollStep {
    if (!_scrollController.hasClients) return 0;
    final viewport = _scrollController.position.viewportDimension;
    // 留出 60 像素的重叠区域，防止文字被截断时下一页看不到
    return viewport > 100 ? viewport - 60 : viewport;
  }

  void scrollUp([VoiceService? voiceService]) {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset <= 1.0) {
      voiceService?.speak("已经是第一页了");
      return;
    }
    final target = (_scrollController.offset - _scrollStep).clamp(
        0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void scrollDown([VoiceService? voiceService]) {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 1.0) {
      voiceService?.speak("已经是最后一页了");
      return;
    }
    final target = (_scrollController.offset + _scrollStep).clamp(
        0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// 自动滚到底部（当有新消息时）
  void jumpToBottom() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset < max) {
      _scrollController.jumpTo(max);
    }
  }

  /// 回到顶部
  void jumpToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.offset > 0) {
      _scrollController.jumpTo(0);
    }
  }

  int get _currentPage {
    if (!_scrollController.hasClients) return 0;
    final offset = _scrollController.offset;
    final step = _scrollStep;
    if (step == 0) return 0;

    if (offset <= 1.0) return 0;
    
    return (offset / step).ceil();
  }

  int get _totalPages {
    if (!_scrollController.hasClients) return 1;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final step = _scrollStep;
    if (step == 0) return 1;
    return (maxScroll / step).ceil() + 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        
        return Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            final conversations = chatProvider.messages
                .where((m) => m.role != MessageRole.system)
            .toList();

        // 将 user+assistant 两两配对
        final List<List<ChatMessage>> messagePairs = [];
        for (int i = 0; i < conversations.length; i++) {
          if (conversations[i].role == MessageRole.user) {
            final pair = [conversations[i]];
            if (i + 1 < conversations.length &&
                conversations[i + 1].role == MessageRole.assistant) {
              pair.add(conversations[i + 1]);
            }
            messagePairs.add(pair);
          }
        }

        final liveText = widget.voiceProvider.recognizedText;
        final pendingText = widget.voiceProvider.pendingQuestion;
        
        final showLive = widget.voiceProvider.isListening && liveText.isNotEmpty;

        if (messagePairs.isEmpty && !showLive) {
          return const SizedBox.shrink();
        }

        final currentPairCount = messagePairs.length;
        final currentLiveLength = liveText.length;
        final currentContentLength = messagePairs.isNotEmpty ? messagePairs.last.last.content.length : 0;
        final currentReasoningLength = messagePairs.isNotEmpty ? messagePairs.last.last.reasoning.length : 0;

        bool shouldJump = false;
        if (currentPairCount > _lastPairCount || currentLiveLength > _lastLiveLength) {
          shouldJump = true;
        } else if (currentReasoningLength > _lastReasoningLength && currentContentLength == 0) {
          // 只在“纯思考阶段”允许自动滚动到底部，方便看思考过程。
          // 一旦正式答案开始输出（currentContentLength > 0），立刻停止自动滚动，防止打断阅读。
          if (!_scrollController.hasClients || 
              _scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
            shouldJump = true;
          }
        }

        _lastPairCount = currentPairCount;
        _lastLiveLength = currentLiveLength;
        _lastContentLength = currentContentLength;
        _lastReasoningLength = currentReasoningLength;

        if (shouldJump) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            jumpToBottom();
          });
        }

        return Column(
          children: [
            // 页码指示器 + 翻页按钮（有历史记录时才显示）
            if (messagePairs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 上一页
                    _PageNavButton(
                      icon: Icons.chevron_left,
                      enabled: _scrollController.hasClients && _scrollController.offset > 1.0,
                      onTap: () {
                        if (!_scrollController.hasClients) return;
                        final target = (_scrollController.offset - _scrollStep).clamp(
                            0.0, _scrollController.position.maxScrollExtent);
                        _scrollController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // 页码文字
                    Text(
                      '第 ${_currentPage + 1} / $_totalPages 页',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 下一页
                    _PageNavButton(
                      icon: Icons.chevron_right,
                      enabled: _scrollController.hasClients && _scrollController.offset < _scrollController.position.maxScrollExtent - 1.0,
                      onTap: () {
                        if (!_scrollController.hasClients) return;
                        final target = (_scrollController.offset + _scrollStep).clamp(
                            0.0, _scrollController.position.maxScrollExtent);
                        _scrollController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ],
                ),
              ),

            // ListView 主体
            Expanded(
              child: LayoutBuilder(
                builder: (context, listConstraints) {
                  final listHeight = listConstraints.maxHeight;
                  return messagePairs.isEmpty
                      // 首次说话还没有历史：居中展示流式识别文字
                      ? Center(
                          child: showLive
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.accentColor,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '正在识别',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.accentColor,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (showLive)
                                        Text(
                                          liveText,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                            height: 1.6,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : (widget.voiceProvider.isAwake 
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.accentColor.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        '等待语音输入...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white54,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink()),
                        )
                      : ShaderMask(
                          shaderCallback: (Rect bounds) {
                            final topFade = 30.0 / bounds.height;
                            final bottomFade = 30.0 / bounds.height;
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: const [
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [
                                0.0,
                                topFade.clamp(0.0, 1.0),
                                (1.0 - bottomFade).clamp(0.0, 1.0),
                                1.0,
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const NeverScrollableScrollPhysics(), // 只能通过按钮/语音翻页
                            child: Column(
                              children: messagePairs.map((pair) {
                                return Container(
                                  constraints: BoxConstraints(minHeight: listHeight),
                                  alignment: Alignment.topCenter,
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: _ConversationPage(messages: pair),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                },
              ),
            ),


            // 有历史记录时，实时识别气泡显示在底部（紧贴最新一页）
            if (showLive && messagePairs.isNotEmpty) 
              _LiveRecognitionBubble(text: liveText),
          ],
        );
      },
    );
      },
    );
  }
}

// =============================================
// 翻页按钒
// =============================================
class _PageNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 18, color: Colors.white70),
        ),
      ),
    );
  }
}

