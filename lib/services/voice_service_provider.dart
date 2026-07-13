import 'voice_service.dart';
import 'voice_service_stub.dart'
    if (dart.library.js_interop) 'voice_service_web.dart'
    if (dart.library.io) 'voice_service_native.dart';

/// 获取当前平台的语音服务实例（单例，供首页与设置页共享）
VoiceService? _instance;
VoiceService getPlatformVoiceService() =>
    _instance ??= createPlatformVoiceService();
