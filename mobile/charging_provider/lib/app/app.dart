import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class ChargingProviderApp extends StatelessWidget {
  const ChargingProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EV Fleet Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}