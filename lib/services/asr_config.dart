import 'dart:convert';

/// 实时语音识别（流式）后端协议配置
///
/// 后端要求：前端推送 **16kHz / 16bit / 单声道的裸 PCM 字节流**（Raw Bytes），
/// 不要传 WebM/MP3 等压缩格式（解压会带来明显延迟）。
///
/// 本文件集中管理 WebSocket 地址与消息解析，方便和后端对齐字段。
class AsrConfig {
  AsrConfig._();

  // === 音频参数（必须与后端约定一致）===
  /// 采样率：16kHz
  static const int sampleRate = 16000;

  /// 声道数：单声道
  static const int numChannels = 1;

  // === WebSocket 地址 ===
  /// 实时识别 WebSocket 地址（后端实时转写流式接口）
  static const String wsEndpoint = 'ws://47.121.133.67/api/wugang-stt/ws/transcribe';

  /// 唤醒前 partial 停止更新多久清空累积缓冲（毫秒）。
  /// 仅用于唤醒前避免噪音识别越积越多，不参与断句（断句由后端 final 决定）。
  static const int partialSilenceMs = 1800;

  // === 本地 VAD（仅用于检测静音后给后端发 done，不做本地断句提交）===
  /// 归一化 RMS 能量阈值（0~1）。高于此值视为"正在说话"。
  /// 关掉 autoGain 后语音信号偏小，阈值不宜过高，否则正常说话会被误判为静音。
  static const double vadRmsThreshold = 0.01;

  /// 检测到麦克风静音持续多久（毫秒）→ 给后端发 done，触发非流式模型出 final。
  static const int vadSilenceMs = 2000;

  /// 单句最长时长（毫秒），超时也强制发 done，防止一直不静音卡住。
  static const int maxUtteranceMs = 20000;

  /// 发给后端的"说完了"信号内容（静音 2 秒后发送）。
  /// 若后端期望 JSON，改成 '{"type":"done"}' 即可。
  static const String doneMessage = 'done';

  /// 发送 done 后等待后端 final 的最长时间（毫秒），超时用最后的 partial 兜底提交。
  /// 因为后端处理长句（如 20 秒音频）可能需要 20-30 秒，因此这里的兜底超时必须足够长。
  static const int finalTimeoutMs = 60000;

  /// 录音启动 / TTS 停止后，丢弃前几百毫秒的音频数据（毫秒）。
  /// 麦克风启动/TTS结束后，丢弃前N毫秒的音频，避免因为麦克风激活时的POP噪音或TTS的尾音回声污染识别结果。
  static const int audioLeadInMs = 100;

  /// 调试开关：打印连接状态、收到的原始消息等
  static const bool debug = true;

  /// 是否启用语音播报（TTS）。关掉后只识别+显示文字，不出声。
  static const bool ttsEnabled = true;
}

/// 后端 -> 前端 的流式消息类型
enum AsrEventType {
  partial, // ASR 中间结果
  finalResult, // ASR 最终结果（一句话识别完成）
  wake, // 唤醒词命中
  speechStart, // 检测到说话开始
  speechEnd, // 检测到说话结束
  aiReply, // AI 回复文字
  error, // 错误
  unknown, // 未识别的消息
}

/// 解析后端返回的一条流式消息
///
/// 兼容多种常见 JSON 形态，便于和后端对齐：
/// 1. `{"type":"partial","text":"..."}`
/// 2. `{"type":"final","text":"..."}`
/// 3. `{"code":200,"data":"...","is_final":true}`
/// 4. `{"text":"...","is_final":false}`
class AsrEvent {
  final AsrEventType type;
  final String text;

  const AsrEvent(this.type, this.text);

  /// 尝试解析一条文本消息。解析失败返回 unknown。
  static AsrEvent parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const AsrEvent(AsrEventType.unknown, '');

    // 不是 JSON 就当作纯文本最终结果
    if (!trimmed.startsWith('{')) {
      return AsrEvent(AsrEventType.finalResult, trimmed);
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      return const AsrEvent(AsrEventType.unknown, '');
    }

    // 错误码
    final code = json['code'];
    if (code != null && code != 200 && code != 0) {
      final msg = (json['message'] ?? json['msg'] ?? '识别错误').toString();
      return AsrEvent(AsrEventType.error, msg);
    }

    final text =
        (json['text'] ?? json['data'] ?? json['result'] ?? '').toString();

    // 显式 type 字段优先
    final typeStr = (json['type'] ?? json['event'] ?? '').toString().toLowerCase();
    switch (typeStr) {
      case 'partial':
      case 'interim':
      case 'temp':
        return AsrEvent(AsrEventType.partial, text);
      case 'final':
      case 'sentence':
        return AsrEvent(AsrEventType.finalResult, text);
      case 'wake':
      case 'wakeup':
      case 'wake_up':
        return AsrEvent(AsrEventType.wake, text);
      case 'speech_start':
      case 'speechstart':
      case 'begin':
        return const AsrEvent(AsrEventType.speechStart, '');
      case 'speech_end':
      case 'speechend':
      case 'end':
        return const AsrEvent(AsrEventType.speechEnd, '');
      case 'ai':
      case 'reply':
      case 'answer':
        return AsrEvent(AsrEventType.aiReply, text);
      case 'error':
        return AsrEvent(AsrEventType.error, text.isEmpty ? '识别错误' : text);
    }

    // 没有 type，用 is_final / isFinal / final 判断中间还是最终结果
    final isFinal = json['is_final'] ?? json['isFinal'] ?? json['final'] ?? false;
    if (isFinal == true) {
      return AsrEvent(AsrEventType.finalResult, text);
    }
    if (text.isNotEmpty) {
      return AsrEvent(AsrEventType.partial, text);
    }
    return const AsrEvent(AsrEventType.unknown, '');
  }
}
