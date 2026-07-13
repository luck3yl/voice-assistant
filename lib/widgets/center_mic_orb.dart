import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/voice_provider.dart';
import '../theme/app_theme.dart';

/// 居中麦克风语音球 - 匹配设计稿
///
/// 中心为麦克风图标的发光圆球，外圈两层同心圆环，
/// 左右两侧延伸出声波柱动画。
class CenterMicOrb extends StatefulWidget {
  /// 中心球体直径
  final double orbSize;

  /// 单侧声波区域宽度
  final double waveWidth;

  const CenterMicOrb({
    super.key,
    this.orbSize = 110,
    this.waveWidth = 140,
  });

  @override
  State<CenterMicOrb> createState() => _CenterMicOrbState();
}

class _CenterMicOrbState extends State<CenterMicOrb>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, vp, _) {
        final isActive =
            vp.isListening || vp.isAwake || vp.isProcessing || vp.isSpeaking;

        return AnimatedBuilder(
          animation: Listenable.merge([_waveController, _breathController]),
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 左侧声波
                _buildSoundWave(isActive, vp.volumeLevel, reversed: true),
                const SizedBox(width: 10),
                // 中心麦克风球
                _buildOrb(isActive),
                const SizedBox(width: 10),
                // 右侧声波
                _buildSoundWave(isActive, vp.volumeLevel, reversed: false),
              ],
            );
          },
        );
      },
    );
  }

  /// 中心球体
  Widget _buildOrb(bool isActive) {
    final breath = _breathController.value;
    final size = widget.orbSize;

    return SizedBox(
      width: size + 56,
      height: size + 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 刻度环（雷达表盘感）
          SizedBox(
            width: size + 52,
            height: size + 52,
            child: CustomPaint(
              painter: _TickRingPainter(
                color: AppTheme.accentColor
                    .withValues(alpha: isActive ? 0.5 : 0.3),
              ),
            ),
          ),
          // 外层同心圆环
          Container(
            width: size + 30,
            height: size + 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentColor
                    .withValues(alpha: isActive ? 0.4 : 0.2),
                width: 1.5,
              ),
            ),
          ),
          // 主球体
          Container(
            width: size + (isActive ? breath * 6 : 0),
            height: size + (isActive ? breath * 6 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentColor.withValues(alpha: isActive ? 0.5 : 0.3),
                  AppTheme.primaryColor.withValues(alpha: isActive ? 0.7 : 0.4),
                  AppTheme.surfaceColor.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              border: Border.all(
                color: AppTheme.accentColor
                    .withValues(alpha: isActive ? 0.7 : 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor
                      .withValues(alpha: isActive ? 0.4 + breath * 0.2 : 0.15),
                  blurRadius: isActive ? 30 + breath * 15 : 12,
                  spreadRadius: isActive ? 4 : 1,
                ),
              ],
            ),
            child: Icon(
              Icons.mic,
              size: size * 0.4,
              color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 一侧声波柱
  Widget _buildSoundWave(bool isActive, double volume, {required bool reversed}) {
    const barCount = 7;
    final bars = List.generate(barCount, (i) {
      // 中间高两边低的基础形态
      final distFromCenter = (i - (barCount - 1) / 2).abs();
      final base = 22 - distFromCenter * 5;

      double h;
      if (isActive) {
        final phase = _waveController.value * 2 * pi;
        final wave = sin(phase + i * 0.9) * 0.5 + 0.5;
        h = base * (0.4 + wave * 0.6) + volume * 14;
      } else {
        // 待机时也保留轻微起伏的波形，避免显得空荡
        final phase = _waveController.value * 2 * pi;
        final wave = sin(phase + i * 0.9) * 0.5 + 0.5;
        h = base * (0.45 + wave * 0.35);
      }
      h = h.clamp(4.0, 36.0);

      return Container(
        width: 3.5,
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentColor
              .withValues(alpha: isActive ? 0.9 : 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });

    return SizedBox(
      width: widget.waveWidth,
      child: Row(
        mainAxisAlignment:
            reversed ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: reversed ? bars.reversed.toList() : bars,
      ),
    );
  }
}

/// 刻度环 - 在圆周上绘制等距小刻度，营造雷达表盘效果
class _TickRingPainter extends CustomPainter {
  final Color color;

  _TickRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const tickCount = 60;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i / tickCount) * 2 * pi;
      // 每 5 格画一根长刻度
      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 6.0 : 3.0;
      final outer = radius;
      final inner = radius - tickLen;
      final p1 = Offset(
        center.dx + cos(angle) * outer,
        center.dy + sin(angle) * outer,
      );
      final p2 = Offset(
        center.dx + cos(angle) * inner,
        center.dy + sin(angle) * inner,
      );
      paint.color = color.withValues(
        alpha: isMajor ? color.a : color.a * 0.5,
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
