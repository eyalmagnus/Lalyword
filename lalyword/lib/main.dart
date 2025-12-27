import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'config/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LalyApp(),
    ),
  );
}

class LalyApp extends ConsumerWidget {
  const LalyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LalyWord',
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}


