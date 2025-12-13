import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('See Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(activityDataProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: activityAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No activity data available.\n\nWords will appear here after you:\n• View word lists\n• Interact with flashcards\n\nTry selecting a word list and viewing some words first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Sort words alphabetically by English word
          final sortedWords = List<WordItem>.from(words)
            ..sort((a, b) => a.englishWord.toLowerCase().compareTo(b.englishWord.toLowerCase()));

          return Column(
            children: [
              // Sticky header
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: _buildHeaderRow(context),
              ),
              // Table rows
              Expanded(
                child: ListView.builder(
                  itemCount: sortedWords.length,
                  itemBuilder: (context, index) {
                    final word = sortedWords[index];
                    return _buildDataRow(context, word);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading activity: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(activityDataProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              child: const Text(
                'Word',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Shown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Heard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 13,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Syllables',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Hebrew',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, WordItem word) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              child: Text(
                word.englishWord,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                '${word.timesShown}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                '${word.timesHeard}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 13,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                '${word.timesSyllablesShown}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                '${word.timesHebrewShown}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

