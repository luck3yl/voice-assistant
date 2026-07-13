import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:steel_voice_assistant/app.dart';
import 'package:steel_voice_assistant/providers/voice_provider.dart';
import 'package:steel_voice_assistant/providers/chat_provider.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VoiceProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: const SteelVoiceApp(),
      ),
    );

    expect(find.text('炼钢规程助手'), findsOneWidget);
  });
}
