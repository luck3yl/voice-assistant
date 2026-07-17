
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../providers/voice_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../services/voice_service.dart';
import '../services/voice_service_provider.dart';
import '../services/asr_config.dart';
import '../services/command_handler.dart';
import '../app.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_orb.dart';
import '../widgets/center_mic_orb.dart';
part 'home_page_idle.dart';
part 'home_page_conversation.dart';
part 'home_page_top_bar.dart';
part 'home_page_chat_list.dart';
part 'home_page_chat_msg.dart';

/// 首页 - 语音交互主界面（横屏设计）
///
/// 参考设计稿风格：
/// - 全屏背景图（炼钢场景）
/// - 左上：logo + 标题
/// - 上方中间：唤醒词提示
/// - 右上：设备信息
/// - 左侧：头盔形象
/// - 中间：对话气泡
/// - 右侧：语音球
/// - 底部：状态指示
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> implements VoiceServiceCallback {
  late VoiceService _voiceService;
  late CommandHandler _commandHandler;

  @override
  void initState() {
    super.initState();
    _commandHandler = CommandHandler(navigatorKey: navigatorKey);
    _initVoiceService();
  }

  Future<void> _initVoiceService() async {
    _voiceService = getPlatformVoiceService();
    _voiceService.setCallback(this);
    await _voiceService.connect(AsrConfig.wsEndpoint);
    await _voiceService.startContinuousListening();
  }

  @override
  void dispose() {
    _voiceService.disconnect();
    super.dispose();
  }

  // === VoiceServiceCallback ===
  @override
  void onWakeUp() => context.read<VoiceProvider>().onWakeUp();
  @override
  void onSpeechStart() => context.read<VoiceProvider>().onSpeechStart();
  @override
  void onPartialResult(String text) =>
      context.read<VoiceProvider>().updatePartialResult(text);
  @override
  void onFinalResult(String text) {
    context.read<VoiceProvider>().onSpeechEnd(text);
  }

  @override
  void onConfirmationNeeded(String text) {
    context.read<VoiceProvider>().onConfirmationNeeded(text);
  }

  @override
  void onConfirmationCancelled() {
    context.read<VoiceProvider>().onConfirmationCancelled();
  }

  @override
  void onAiReply(String text) async {
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    await chatProvider.sendMessage(text);
    
    if (!mounted) return;

    // 更新 UI 状态
    context.read<VoiceProvider>().onSpeakingEnd();
    // 解锁 StreamingVoiceService 的 _awaitingReply，允许二次提问
    await _voiceService.resumeListening();
  }

  @override
  void onTtsStart() {} // TTS 播报已禁用
  @override
  void onTtsEnd() {} // TTS 播报已禁用
  @override
  void onSentencePlaying(String sentence) {} // TTS 播报已禁用
  @override
  void onError(String message) =>
      context.read<VoiceProvider>().setError(message);
  @override
  void onConnectionChanged(bool connected) =>
      context.read<VoiceProvider>().setConnected(connected);

  final GlobalKey<_ChatListState> _chatListKey = GlobalKey<_ChatListState>();

  @override
  void onCommand(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.goBack:
        _commandHandler.executeNavigation(command);
        break;
      case VoiceCommand.clearChat:
        context.read<ChatProvider>().clearMessages();
        break;
      case VoiceCommand.stopSpeaking:
        context.read<VoiceProvider>().onSpeakingEnd();
        break;
      case VoiceCommand.repeatLast:
        break;
      case VoiceCommand.scrollUp:
        _chatListKey.currentState?.scrollUp(_voiceService);
        break;
      case VoiceCommand.scrollDown:
        _chatListKey.currentState?.scrollDown(_voiceService);
        break;
      case VoiceCommand.jumpToBottom:
        _chatListKey.currentState?.jumpToBottom();
        break;
      case VoiceCommand.jumpToTop:
        _chatListKey.currentState?.jumpToTop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.92),
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.45),
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Consumer2<VoiceProvider, ChatProvider>(
              builder: (context, voiceProvider, chatProvider, _) {
                final hasHistory = chatProvider.messages.any(
                  (m) => m.role == MessageRole.user,
                );
                // 用户开始说话时立即切换到对话布局，使流式识别文字
                // 显示在对话区的底部，而不是停留在待机首页
                final hasConversation =
                    hasHistory || voiceProvider.isListening || voiceProvider.isConfirming || chatProvider.hasEverChatted;

                if (hasConversation) {
                  return _ConversationLayout(
                    voiceProvider: voiceProvider,
                    chatProvider: chatProvider,
                    chatListKey: _chatListKey,
                  );
                }
                
                return _IdleLayout(voiceProvider: voiceProvider);
              },
            ),
          ),
        ),
      ),
    );
  }
}

