import 'dart:convert';

import 'package:http/http.dart' as http;

/// 后端 AI 问答接口（流式）
///
/// 接口：POST {endpoint}
/// 请求体：{"message": "...", "agent_name": "...", "conversation_id": "..."}
/// 返回：流式纯文本碎片，拼接后是一段带「思考过程」的文本：
///   - 思考/检索过程含标记：`**THOUGHT**:`、`[TOOL] ...`、`[ERROR]`、`EVALUATION:`
///   - 用一行 `---`（分隔线）把「思考过程」与「最终答案」分开，**答案在分隔线之后**
///   - 以 `[DONE]` 结束
///
/// 因此前端只展示/播报 `---` 之后的答案部分，思考过程不展示。
class ChatApi {
  ChatApi._();

  /// 问答流式接口地址
  static const String endpoint = 'http://192.168.193.3:8001/api/chat/stream';

  /// 智能体名称
  static const String agentName = '钢铁设备知识助手';

  /// 请求超时
  static const Duration timeout = Duration(seconds: 120);

  /// 流式请求 AI 回答。每收到一段就 yield「**当前已拼接的完整原始文本**」，
  /// 调用方用 [extractAnswer] 从中取出答案部分做流式显示。
  static Stream<String> streamRaw({
    required String message,
    required String conversationId,
  }) async* {
    final uri = Uri.parse(endpoint);
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'message': message,
        'agent_name': agentName,
        'conversation_id': conversationId,
      });

    final client = http.Client();
    final raw = StringBuffer();
    try {
      final resp = await client.send(request).timeout(timeout);
      if (resp.statusCode != 200) {
        throw Exception('AI 接口请求失败：HTTP ${resp.statusCode}');
      }

      final lines =
          resp.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in lines) {
        final chunk = _stripSsePrefix(line);
        if (chunk == null) continue; // SSE 控制行/空行
        if (chunk.trim() == '[DONE]') break;
        raw.write(chunk);
        yield raw.toString();
      }
    } finally {
      client.close();
    }
  }

  /// 去掉 SSE 的 `data:` 前缀；返回 null 表示该行应忽略
  static String? _stripSsePrefix(String line) {
    var s = line;
    if (s.startsWith('data:')) {
      s = s.substring(5);
      if (s.startsWith(' ')) s = s.substring(1);
    } else if (s.startsWith('event:') ||
        s.startsWith('id:') ||
        s.startsWith('retry:') ||
        s.startsWith(':')) {
      return null;
    }
    if (s.isEmpty) return null;
    return s;
  }

  /// 从拼接后的原始文本里取出「思考过程」部分（`---` 分隔线之前），并清理标记。
  /// 没有思考标记时返回空字符串。
  static String extractReasoning(String raw) {
    var text = raw.replaceAll('\\n', '\n').replaceAll('\r\n', '\n');
    text = text.replaceAll('[DONE]', '');

    // 兼容各种分隔符格式：比如行尾没有回车、有空格、或者是 ***，或者是 </think>
    final sepPattern = RegExp(r'\n\s*(?:-{3,}|\*{3,}|_{3,})\s*(?:\n|$)|</think>', caseSensitive: false);
    final sep = sepPattern.firstMatch(text);
    final part = sep != null ? text.substring(0, sep.start) : text;

    if (!RegExp(r'THOUGHT|\[TOOL\]|EVALUATION|<think>', caseSensitive: false)
        .hasMatch(part)) {
      return '';
    }

    var cleaned = part
        .replaceAll(RegExp(r'<think>\s*\n?', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\*{0,2}THOUGHT\*{0,2}\s*:?\s*', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'\*{0,2}\[TOOL\]\*{0,2}\s*\w*>?\s*', caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\*{0,2}EVALUATION\*{0,2}\s*:?\s*', caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\[ERROR\][^\n]*'), '');
    cleaned = cleaned
        .replaceAllMapped(RegExp(r'(^|\n)>\s?'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'\*{2,}'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return cleaned;
  }

  /// 从拼接后的原始文本里取出「最终答案」部分（`---` 分隔线之后），并清理 markdown。
  ///
  /// 答案总是在 `---` 分隔线之后。分隔线出现前一律返回空（视为思考/检索中），
  /// 避免把逐字流入的思考过程（如 `**THOUGHT**`）误当答案显示。
  /// [finished] 为 true 表示流已结束：此时若仍无分隔线且全程无思考标记，
  /// 才把整段当作答案（兜底无思考过程的简单回答）。
  static String extractAnswer(String raw, {bool finished = false}) {
    var text = raw.replaceAll('\\n', '\n').replaceAll('\r\n', '\n');
    text = text.replaceAll('[DONE]', '');

    final sepPattern = RegExp(r'\n\s*(?:-{3,}|\*{3,}|_{3,})\s*(?:\n|$)|</think>\s*(?:\n|$)?', caseSensitive: false);
    final sep = sepPattern.firstMatch(text);
    if (sep != null) {
      return _toPlain(text.substring(sep.end));
    }

    // 还没出现分隔线
    if (finished) {
      // 兜底：如果对话已经结束，但大模型犯傻忘了写 `---` 分隔线
      // 我们至少把整段文字作为答案兜底返回，保证页面上能显示出回答
      return _toPlain(text); 
    }
    return ''; // 思考/检索进行中，答案尚未开始
  }

  /// 把 markdown 转成适合显示/朗读的纯文本
  static String _toPlain(String input) {
    var t = input;
    // [文本](链接) -> 文本
    t = t.replaceAllMapped(
        RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');
    // 去掉残留标记词
    t = t.replaceAll(RegExp(r'\[ERROR\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[TOOL\][^\n]*', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'</?think>', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\*{0,2}THOUGHT\*{0,2}\s*:?', caseSensitive: false), '');
    t = t.replaceAll(
        RegExp(r'\*{0,2}EVALUATION\*{0,2}\s*:?', caseSensitive: false), '');
    // 加粗 / 行内代码标记
    t = t.replaceAll(RegExp(r'\*{1,3}'), '');
    t = t.replaceAll(RegExp(r'`{1,3}'), '');
    // 标题 #：去掉行首的 # 号
    t = t.replaceAllMapped(
        RegExp(r'(^|\n)#{1,6}\s*'), (m) => m.group(1) ?? '');
    // 引用符号 >
    t = t.replaceAllMapped(RegExp(r'(^|\n)>\s?'), (m) => m.group(1) ?? '');
    // 多余空行
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }
}
