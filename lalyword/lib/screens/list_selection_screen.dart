import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'flashcard_screen.dart';
import 'settings_screen.dart';
import 'activity_screen.dart';

class ListSelectionScreen extends ConsumerWidget {
  const ListSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headersAsync = ref.watch(sheetHeadersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a List'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.settings),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.build, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Setup'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: StatefulBuilder(
                  builder: (context, setState) {
                     // We use a consumer to read the value, but inside a menu it's tricky to rebuild.
                     // Better to just show the checkbox.
                     final settings = ref.watch(settingsProvider);
                     return Row(
                       children: [
                         Icon(
                           settings.showSyllables ? Icons.check_box : Icons.check_box_outline_blank,
                           color: Colors.grey,
                         ),
                         const SizedBox(width: 8),
                         const Text('Show Syllables'),
                       ],
                     );
                  },
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('See Activity'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              } else if (value == 2) {
                 final current = ref.read(settingsProvider).showSyllables;
                 await ref.read(settingsProvider.notifier).toggleSyllables(!current);
                 // Force menu rebuild if needed or just snackbar
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(!current ? 'Syllables Enabled' : 'Syllables Disabled')),
                 );
              } else if (value == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ActivityScreen()),
                );
              }
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
                  subtitle: headers[name] == -1 
                    ? const Text('Built-in List', style: TextStyle(fontSize: 12, color: Colors.grey))
                    : const Text('From Google Sheet', style: TextStyle(fontSize: 12, color: Colors.blue)),
                  leading: CircleAvatar(
                    backgroundColor: headers[name] == -1 ? Colors.orange.shade100 : Colors.blue.shade100,
                    child: Icon(
                      headers[name] == -1 ? Icons.local_library : Icons.cloud,
                      color: headers[name] == -1 ? Colors.orange : Colors.blue,
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
