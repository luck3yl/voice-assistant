import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';

class DebugLogModal extends StatefulWidget {
  const DebugLogModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DebugLogModal(),
    );
  }

  @override
  State<DebugLogModal> createState() => _DebugLogModalState();
}

class _DebugLogModalState extends State<DebugLogModal> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _copyToClipboard(List<String> logs) {
    final text = logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 调试日志已一键复制到剪贴板！可直接发微信/钉钉'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 760,
        height: 520,
        decoration: BoxDecoration(
          color: const Color(0xFF081426).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            // 头部标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: AppTheme.accentColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '运行调试日志（远程诊断专用）',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 日志内容流
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: AppLogger.instance.logStream,
                initialData: AppLogger.instance.logs,
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  if (logs.isEmpty) {
                    return const Center(
                      child: Text(
                        '暂无日志数据，请触发麦克风或说“小智”尝试...',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF030914),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final line = logs[index];
                        Color color = Colors.white70;
                        if (line.contains('FAILED') || line.contains('错误') || line.contains('Error')) {
                          color = Colors.redAccent;
                        } else if (line.contains('WAKE') || line.contains('唤醒')) {
                          color = Colors.amberAccent;
                        } else if (line.contains('connected') || line.contains('成功')) {
                          color = Colors.greenAccent;
                        } else if (line.contains('rms=')) {
                          color = Colors.lightBlueAccent.withValues(alpha: 0.7);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: SelectableText(
                            line,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // 底部操作按钮栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _autoScroll,
                        activeColor: AppTheme.accentColor,
                        onChanged: (val) {
                          setState(() {
                            _autoScroll = val ?? true;
                          });
                        },
                      ),
                      const Text(
                        '自动滚到底部',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => AppLogger.instance.clear(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white70),
                    label: const Text('清空', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(AppLogger.instance.logs),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.black),
                    label: const Text('📋 一键复制日志', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
