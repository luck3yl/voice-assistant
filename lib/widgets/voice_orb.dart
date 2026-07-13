import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/voice_provider.dart';
import '../theme/app_theme.dart';

/// 语音交互球 - 核心视觉组件
///
/// 蓝色发光球体 + 内部声波图标 + 外圈光晕扩散动画
/// 根据语音状态变化：
/// - 休眠：暗淡，微弱呼吸
/// - 唤醒/待命：稳定发光
/// - 聆听：脉冲跳动 + 声波随音量变化
/// - 处理中：旋转光环
/// - 播报中：平滑呼吸
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    // 呼吸动画
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // 脉冲动画（聆听时）
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 涟漪扩散动画
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voiceProvider, _) {
        final isActive = voiceProvider.isListening ||
            voiceProvider.isAwake ||
            voiceProvider.isProcessing ||
            voiceProvider.isSpeaking;

        // 聆听时加速脉冲
        if (voiceProvider.isListening && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!voiceProvider.isListening && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([
            _breathController,
            _pulseController,
            _rippleController,
          ]),
          builder: (context, child) {
            final breathValue = _breathController.value;
            final pulseValue = _pulseController.value;
            final rippleValue = _rippleController.value;

            return SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 外圈涟漪（唤醒状态下显示）
                  if (isActive) ...[
                    _buildRipple(rippleValue, 0.0),
                    _buildRipple(rippleValue, 0.33),
                    _buildRipple(rippleValue, 0.66),
                  ],

                  // 外层光晕
                  Container(
                    width: 130 + (isActive ? breathValue * 8 : breathValue * 4),
                    height: 130 + (isActive ? breathValue * 8 : breathValue * 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.voiceActiveColor.withValues(
                            alpha: isActive ? 0.3 + breathValue * 0.2 : 0.1,
                          ),
                          blurRadius: isActive ? 30 + breathValue * 20 : 15,
                          spreadRadius: isActive ? 5 + breathValue * 5 : 2,
                        ),
                      ],
                    ),
                  ),

                  // 主球体
                  Container(
                    width: 110 +
                        (voiceProvider.isListening ? pulseValue * 6 : 0),
                    height: 110 +
                        (voiceProvider.isListening ? pulseValue * 6 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor.withValues(
                            alpha: isActive ? 0.9 : 0.4,
                          ),
                          AppTheme.voiceActiveColor.withValues(
                            alpha: isActive ? 0.7 : 0.3,
                          ),
                          AppTheme.surfaceColor.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(
                          alpha: isActive ? 0.6 : 0.2,
                        ),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _buildInnerContent(voiceProvider),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 涟漪圈
  Widget _buildRipple(double animValue, double offset) {
    final value = (animValue + offset) % 1.0;
    final size = 120 + value * 60;
    final opacity = (1.0 - value) * 0.3;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }

  /// 球体内部内容（声波图标）
  Widget _buildInnerContent(VoiceProvider provider) {
    if (provider.isProcessing) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      );
    }

    // 声波柱状图
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(5, (i) {
        double height;
        if (provider.isListening) {
          // 聆听时根据音量变化
          final volume = provider.volumeLevel;
          final randomFactor = sin((i + _pulseController.value * 6) * 1.2);
          height = 12 + (volume * 20 + randomFactor * 8).clamp(0.0, 28.0);
        } else if (provider.isSpeaking) {
          height = 12 + sin((i + _breathController.value * 4) * 1.5) * 10;
        } else {
          height = 10 + sin((i + _breathController.value * 2) * 1.2) * 4;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 5,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// 合并多个 Listenable 的 AnimatedWidget
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
