import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'flashcard_screen.dart';
import 'settings_screen.dart';

class ListSelectionScreen extends ConsumerWidget {
  const ListSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headersAsync = ref.watch(sheetHeadersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: headersAsync.when(
        data: (headers) {
          if (headers.isEmpty) {
            return const Center(
              child: Text(
                'No lists found.\nVerify your Sheet structure.',
                textAlign: TextAlign.center,
              ),
            );
          }
          
          final listNames = headers.keys.toList();
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listNames.length,
            itemBuilder: (context, index) {
              final name = listNames[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, 
                    vertical: 12,
                  ),
                  title: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ref.read(selectedListProvider.notifier).state = name;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlashcardScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading lists:\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(sheetHeadersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
