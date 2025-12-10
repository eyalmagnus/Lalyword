import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/settings_screen.dart';
import 'screens/list_selection_screen.dart';
import 'providers/app_providers.dart';

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
    // Watch settings to decide initial route
    // However, build should be synchronous. We use a FutureBuilder or just default to home wrapper.
    
    return MaterialApp(
      title: 'LalyWord',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Deep Purple
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const HomeWrapper(),
    );
  }
}

class HomeWrapper extends ConsumerWidget {
  const HomeWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    if (!settings.isConfigured) {
      return const SettingsScreen();
    }
    
    return const ListSelectionScreen();
  }
}
