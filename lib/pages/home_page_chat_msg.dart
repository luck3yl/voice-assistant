part of 'home_page.dart';

class _ConversationPage extends StatelessWidget {
  final List<ChatMessage> messages;

  const _ConversationPage({required this.messages});

  @override
  Widget build(BuildContext context) {
    final userMsg = messages.firstWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => messages.first,
    );
    final aiMsg = messages.where((m) => m.role == MessageRole.assistant).lastOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户问题（固定高度，最多 3 行）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    userMsg.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // AI 回复
          _AssistantMessage(
            message: aiMsg ??
                ChatMessage(
                  id: 'temp',
                  role: MessageRole.assistant,
                  content: '',
                  timestamp: DateTime.now(),
                  done: false,
                ),
          ),
        ],
      ),
    );
  }
}


// =============================================
// AI 消息：思考过程（可折叠）+ 答案
// =============================================
class _AssistantMessage extends StatefulWidget {
  final ChatMessage message;

  const _AssistantMessage({required this.message});

  @override
  State<_AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<_AssistantMessage> {
  bool? _userExpanded; // null = 跟随默认（有答案前展开，有答案后收起）

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final hasReasoning = msg.reasoning.isNotEmpty;
    final hasAnswer = msg.content.isNotEmpty;
    // 默认：有答案前展开（方便看思考过程），有答案后自动收起
    final expanded = _userExpanded ?? !hasAnswer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.smart_toy, color: AppTheme.accentColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 思考过程（可折叠）
                if (hasReasoning) ...[
                  _ReasoningHeader(
                    expanded: expanded,
                    onTap: () => setState(() => _userExpanded = !expanded),
                  ),
                  if (expanded)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4, bottom: 6, left: 6),
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.white24, width: 1.5),
                        ),
                      ),
                      child: MarkdownBody(
                        data: msg.reasoning,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white54,
                            height: 1.6,
                          ),
                          horizontalRuleDecoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                width: 1.0,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: Border(
                              left: BorderSide(color: Colors.white38, width: 3),
                            ),
                          ),
                          blockquote: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white54,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          code: const TextStyle(
                            fontSize: 12.0,
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],

                // 答案气泡 / 加载状态
                if (hasAnswer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: MarkdownBody(
                      data: msg.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              width: 1.0,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            left: BorderSide(color: Colors.white38, width: 3),
                          ),
                        ),
                        blockquote: TextStyle(
                          fontSize: 14.0,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        code: TextStyle(
                          fontSize: 13.0,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'monospace',
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  )
                else if (!msg.done)
                  // 还没出答案：显示加载动画
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        bool isThinking = chatProvider.isThinkingState || chatProvider.isThinking;
                        if (chatProvider.isRetrieving) isThinking = false;
                        return _TypingIndicator(
                          label: isThinking ? '正在思考' : '正在检索',
                        );
                      }
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================
// 思考过程折叠标题
// =============================================
class _ReasoningHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ReasoningHeader({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: 15, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              '思考过程',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// AI 思考中的加载动画（三个跳动圆点）
// =============================================
class _TypingIndicator extends StatefulWidget {
  final String label;

  const _TypingIndicator({this.label = '正在检索'});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
              fontSize: 14, color: Colors.white70, height: 1.5),
        ),
        const SizedBox(width: 6),
        ...List.generate(3, (i) {
          return ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final t = (_controller.value - i * 0.2) % 1.0;
              final opacity = t < 0.5 ? 0.3 + t : 0.3 + (1 - t);
              return Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentColor
                      .withValues(alpha: opacity.clamp(0.3, 1.0)),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

// =============================================
// 脱离底部提示按钮
// =============================================
class _JumpToBottomPrompt extends StatefulWidget {
  final VoidCallback onTap;

  const _JumpToBottomPrompt({required this.onTap});

  @override
  State<_JumpToBottomPrompt> createState() => _JumpToBottomPromptState();
}

class _JumpToBottomPromptState extends State<_JumpToBottomPrompt> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text(
                '有新内容，回到底部',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
