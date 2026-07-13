import 'streaming_voice_service.dart';
import 'voice_service.dart';

/// Web 平台语音服务创建
///
/// 实时流式：麦克风 → 16kHz/16bit/单声道 PCM 裸流 → WebSocket 推送到后端
VoiceService createPlatformVoiceService() => StreamingVoiceService();
