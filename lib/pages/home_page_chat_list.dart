part of 'home_page.dart';

class _ChatList extends StatefulWidget {
  final VoiceProvider voiceProvider;

  const _ChatList({super.key, required this.voiceProvider});

  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  late ScrollController _scrollController;
  late ScrollController _liveScrollController1;
  late ScrollController _liveScrollController2;
  int _lastPairCount = 0;
  int _lastLiveLength = 0;
  int _lastContentLength = 0;
  int _lastReasoningLength = 0;
  bool _lastAwake = false;
  bool _lastWaiting = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _liveScrollController1 = ScrollController();
    _liveScrollController2 = ScrollController();
    _scrollController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _liveScrollController1.dispose();
    _liveScrollController2.dispose();
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
    final listHeight = MediaQuery.of(context).size.height - 180;
        
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
        final isWaitingForNext = widget.voiceProvider.isWaitingForNextQuestion;

        if (messagePairs.isEmpty && !showLive && !isWaitingForNext) {
          return const SizedBox.shrink();
        }

        final currentPairCount = messagePairs.length;
        final currentLiveLength = liveText.length;
        final currentContentLength = messagePairs.isNotEmpty ? messagePairs.last.last.content.length : 0;
        final currentReasoningLength = messagePairs.isNotEmpty ? messagePairs.last.last.reasoning.length : 0;
        final currentAwake = widget.voiceProvider.isAwake;
        final currentWaiting = isWaitingForNext;

        bool shouldJump = false;
        if (currentPairCount > _lastPairCount || currentLiveLength > _lastLiveLength || (currentWaiting && !_lastWaiting)) {
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
        _lastAwake = currentAwake;
        _lastWaiting = currentWaiting;

        if (shouldJump) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            jumpToBottom();
            if (_liveScrollController1.hasClients) {
              _liveScrollController1.animateTo(
                _liveScrollController1.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
            if (_liveScrollController2.hasClients) {
              _liveScrollController2.animateTo(
                _liveScrollController2.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }



        return Column(
          children: [
            // 页码指示器 + 翻页按钮 + 最左侧“返回”按钮
            if (messagePairs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                child: Row(
                  children: [
                    // 页码行最左侧：“返回”按钮
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          context.read<ChatProvider>().clearMessages();
                          context.read<VoiceProvider>().onTimeout();
                          getPlatformVoiceService().stopSpeaking();
                          getPlatformVoiceService().resetToIdle();
                        },


                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white70, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '返回',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 中间居中：页码导航 [< 第 1 / 3 页 >]
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PageNavButton(
                            icon: Icons.chevron_left,
                            enabled: _scrollController.hasClients &&
                                _scrollController.offset > 1.0,
                            onTap: () {
                              if (!_scrollController.hasClients) return;
                              final target = (_scrollController.offset - _scrollStep)
                                  .clamp(0.0,
                                      _scrollController.position.maxScrollExtent);
                              _scrollController.animateTo(
                                target,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '第 ${_currentPage + 1} / $_totalPages 页',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _PageNavButton(
                            icon: Icons.chevron_right,
                            enabled: _scrollController.hasClients &&
                                _scrollController.offset <
                                    _scrollController.position.maxScrollExtent -
                                        1.0,
                            onTap: () {
                              if (!_scrollController.hasClients) return;
                              final target = (_scrollController.offset + _scrollStep)
                                  .clamp(0.0,
                                      _scrollController.position.maxScrollExtent);
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

                    // 右侧平衡占位，确保中间页码居中
                    const SizedBox(width: 50),
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
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: listHeight > 240 ? listHeight - 120 : 220,
                                          ),
                                          child: SingleChildScrollView(
                                            controller: _liveScrollController1,
                                            physics: const BouncingScrollPhysics(),
                                            child: Text(
                                              liveText,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                height: 1.6,
                                              ),
                                            ),
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
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // 支持手指/鼠标拖拽手动滚动，同时支持按钮/语音翻页

                            child: Column(
                              children: [
                                ...messagePairs.map((pair) {
                                  return Container(
                                    constraints: BoxConstraints(minHeight: listHeight),
                                    alignment: Alignment.topCenter,
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: _ConversationPage(messages: pair),
                                  );
                                }),
                                // 只有当用户口述/点击"下一个问题"或识别到新语音时，才开辟全屏新一页
                                if (showLive || isWaitingForNext)

                                  Container(
                                    constraints: BoxConstraints(minHeight: listHeight),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: showLive
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: AppTheme.accentColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
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
                                               ConstrainedBox(
                                                 constraints: BoxConstraints(
                                                   maxHeight: listHeight > 240 ? listHeight - 120 : 220,
                                                 ),
                                                 child: SingleChildScrollView(
                                                   controller: _liveScrollController2,
                                                   physics: const BouncingScrollPhysics(),
                                                   child: Text(
                                                     liveText,
                                                     textAlign: TextAlign.center,
                                                     style: const TextStyle(
                                                       fontSize: 18,
                                                       color: Colors.white,
                                                       height: 1.6,
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                        );

                },
              ),
            ),
          ],
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

