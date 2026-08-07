part of 'home_page.dart';

class _IdleLayout extends StatelessWidget {
  final VoiceProvider voiceProvider;

  const _IdleLayout({required this.voiceProvider});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // === 左侧头盔形象（垂直居中，独立图层）===
        Positioned(
          left: 30,
          top: 70,
          bottom: 60,
          child: Center(
            child: _HelmetAvatar(),
          ),
        ),

        // === 中央内容：气泡 + 语音球 + 状态（全宽自适应，不挤压中间内容）===
        Positioned(
          left: 0,
          right: 0,
          top: 70,
          bottom: 56,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 介绍气泡（待机首页始终完整展示欢迎语）
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _IntroductionBubble(),
                ),


                const SizedBox(height: 24),

                // 语音球 + 两侧声波（支持点击手动唤醒）
                GestureDetector(
                  onTap: () => voiceProvider.onWakeUp(),
                  child: const CenterMicOrb(),
                ),
                const SizedBox(height: 14),

                // 状态文字
                Text(
                  _getStatusText(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (!voiceProvider.isListening && 
                             !voiceProvider.isProcessing) ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                // 实时识别文字（边说边显示）
                if (voiceProvider.recognizedText.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        voiceProvider.recognizedText,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                if (voiceProvider.isAwake)
                  Container(
                    padding: const EdgeInsets.only(top: 6, left: 28, right: 28),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white24, width: 1),
                      ),
                    ),
                    child: const Text(
                      '请说出您的问题',
                      style: TextStyle(fontSize: 13, color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),






        // === 顶部栏 ===
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopBar(voiceProvider: voiceProvider),
        ),

        // === 底部左侧在线状态 ===
        Positioned(
          left: 30,
          bottom: 14,
          child: _OnlineStatus(isConnected: voiceProvider.isConnected),
        ),
        // === 底部右侧提示 === (已移除)
      ],
    );
  }

  String _getStatusText() {
    if (voiceProvider.isListening) return '正在聆听...';
    if (voiceProvider.isProcessing) return '正在思考...';
    if (voiceProvider.isAwake) return '我在听，请说';
    return '等待唤醒...';
  }
}

// =============================================
// 头盔形象 - 带发光圆环
// =============================================
class _HelmetAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外发光圆环
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentColor.withValues(alpha: 0.0),
                  AppTheme.accentColor.withValues(alpha: 0.12),
                ],
                stops: const [0.6, 1.0],
              ),
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // 内圈装饰环
          Container(
            width: 165,
            height: 165,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          // 头盔图片
          ClipOval(
            child: SizedBox(
              width: 158,
              height: 158,
              child: Image.asset(
                'assets/helmet.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================
// 对话布局 - 横屏对话视图
// =============================================
class _IntroductionBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CustomPaint(
        painter: _BubbleTailPainter(),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xCC1A3A5C).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.accentColor.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Text(
            '您好，我是炼钢规程智能体，\n'
            '您可以随时向我提问炼钢相关的规程、工艺、参数、\n'
            '操作步骤及安全注意事项等内容。',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.7,
            ),
          ),

        ),
      ),
    );
  }
}

/// 气泡左侧指向尾巴
class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xCC1A3A5C).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(8, size.height * 0.45)
      ..lineTo(0, size.height * 0.55)
      ..lineTo(8, size.height * 0.65)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================
// 在线状态指示
// =============================================
class _OnlineStatus extends StatelessWidget {
  final bool isConnected;

  const _OnlineStatus({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? AppTheme.safeColor : Colors.red,
            boxShadow: [
              BoxShadow(
                color: (isConnected ? AppTheme.safeColor : Colors.red)
                    .withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? '智能体在线' : '连接中...',
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        // 声波小装饰
        ...List.generate(3, (i) {
          return Container(
            width: 2,
            height: 4.0 + (i == 1 ? 4 : 0),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.accentColor : Colors.white38,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ],
    );
  }
}

// =============================================
// 实时识别气泡 - 边说边显示正在识别的文字
// =============================================
class _LiveRecognitionBubble extends StatelessWidget {
  final String text;

  const _LiveRecognitionBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(40, 4, 20, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              // 跳动的小圆点，表示正在识别
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentColor,
                ),
              ),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================
// 推荐示例问题组件（包含两条专业炼钢与热轧问题卡片）
// =============================================
class _RecommendedQuestions extends StatelessWidget {
  const _RecommendedQuestions();

  static const List<String> questions = [
    '请阐述高炉操作中温度控制的重要性，并列举关于高炉炉顶温度和炉缸冷却水温差的具体安全监控要求。',
    '热轧过程中，单道次压下率通常应控制在什么范围？压下率过大会导致什么缺陷？',
  ];

  void _onQuestionTap(BuildContext context, String questionText) {
    final cleanText = questionText.trim();
    context.read<VoiceProvider>().onSpeechEnd(cleanText);
    context.read<ChatProvider>().sendMessage(cleanText);
    getPlatformVoiceService().resumeListening();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 6),
            Text(
              '您可以尝试这样问：',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...questions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onQuestionTap(context, q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07142A).withValues(alpha: 0.85),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.45),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            q,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppTheme.accentColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}






