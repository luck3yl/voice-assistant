part of 'home_page.dart';

class _TopBar extends StatelessWidget {
  final VoiceProvider voiceProvider;

  const _TopBar({required this.voiceProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧 logo + 标题


          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.headset,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '炼钢规程智能体',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '语音交互 · 安全高效 · 专业可靠',
                        style: TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 中间唤醒词（居中）
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSoundWaveDecor(),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '唤醒语',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.accentColor),
                        ),
                        const Text(
                          '"小智，小智"',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _buildSoundWaveDecor(),
                  ],
                ),
              ),
            ),
          ),

          // 右侧设备信息（恢复初始样式）
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DeviceInfoChip(
                    icon: Icons.location_on,
                    label: '炼钢车间',
                    sublabel: '转炉区域',
                  ),
                  const SizedBox(width: 12),
                  _DeviceInfoChip(
                    icon: Icons.battery_full,
                    label: '100%',
                    sublabel: '设备电量',
                  ),
                  const SizedBox(width: 12),
                  _DeviceInfoChip(
                    icon: Icons.wifi,
                    label: _getCurrentTime(),
                    sublabel: _getCurrentDate(),
                  ),
                ],

              ),
            ),
          ),

        ],
      ),
    );
  }

  static Widget _buildSoundWaveDecor() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final heights = [8.0, 14.0, 10.0, 6.0];
        return Container(
          width: 2.5,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  static String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }
}

// =============================================
// 设备信息小卡片
// =============================================
class _DeviceInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _DeviceInfoChip({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 9, color: Colors.white38),
        ),
      ],
    );
  }
}





