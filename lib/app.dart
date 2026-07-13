import 'package:flutter/material.dart';

import 'pages/home_page.dart';

import 'theme/app_theme.dart';

/// 全局 NavigatorKey，供语音指令导航使用
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SteelVoiceApp extends StatelessWidget {
  const SteelVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '炼钢规程助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
      },
    );
  }
}
