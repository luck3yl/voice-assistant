import 'package:flutter/material.dart';

import 'voice_service.dart';

/// 语音指令处理器
///
/// 将语音识别的文字匹配为导航/操作指令
/// 支持的指令：
///   - "返回" / "后退" → 返回上一页

///   - "停止" / "别说了" → 停止 TTS 播报
///   - "再说一遍" / "重复" → 重复上次回复
///   - "清空对话" → 清空聊天记录
///   - "往上翻" / "上一条" → 滚动
///   - "往下翻" / "下一条" → 滚动
class CommandHandler {
  final GlobalKey<NavigatorState> navigatorKey;

  CommandHandler({required this.navigatorKey});

  /// 尝试匹配语音指令，返回是否命中
  VoiceCommand? matchCommand(String text) {
    final normalized = text.trim().toLowerCase();

    // 返回/后退
    if (_matches(normalized, ['返回', '后退', '回去'])) {
      return VoiceCommand.goBack;
    }



    // 停止播报
    if (_matches(normalized, ['停止', '别说了', '闭嘴', '停'])) {
      return VoiceCommand.stopSpeaking;
    }

    // 重复
    if (_matches(normalized, ['再说一遍', '重复', '重复一下', '再说一次'])) {
      return VoiceCommand.repeatLast;
    }

    // 清空
    if (_matches(normalized, ['清空对话', '清空', '清除记录'])) {
      return VoiceCommand.clearChat;
    }

    // 滚动
    if (_matches(normalized, ['往上翻', '上一条', '上翻'])) {
      return VoiceCommand.scrollUp;
    }
    if (_matches(normalized, ['往下翻', '下一条', '下翻'])) {
      return VoiceCommand.scrollDown;
    }

    return null; // 不是指令，当作问题处理
  }

  /// 执行导航指令
  void executeNavigation(VoiceCommand command) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (command) {
      case VoiceCommand.goBack:
        if (navigator.canPop()) {
          navigator.pop();
        }
        break;

      default:
        break; // 非导航指令由其他逻辑处理
    }
  }

  bool _matches(String input, List<String> keywords) {
    return keywords.any((kw) => input.contains(kw));
  }
}
