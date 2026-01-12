import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';
import '../config/app_theme.dart';

class _ListItem {
  final bool isHeader;
  final String? listName;
  final WordItem? word;

  _ListItem({
    required this.isHeader,
    this.listName,
    this.word,
  });
}

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text('See Activity'),
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.darkGrey,
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
        data: (wordsByList) {
          if (wordsByList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.blueGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.analytics_outlined, color: AppTheme.pureWhite, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No activity data available.\n\nWords will appear here after you:\n• View word lists\n• Interact with flashcards\n\nTry selecting a word list and viewing some words first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.darkGrey),
                    ),
                  ],
                ),
              ),
            );
          }

          final sortedListNames = wordsByList.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          
          final List<_ListItem> items = [];
          for (final listName in sortedListNames) {
            final words = wordsByList[listName]!;
            final sortedWords = List<WordItem>.from(words)
              ..sort((a, b) => a.englishWord.toLowerCase().compareTo(b.englishWord.toLowerCase()));
            
            items.add(_ListItem(isHeader: true, listName: listName));
            for (final word in sortedWords) {
              items.add(_ListItem(isHeader: false, word: word));
            }
          }

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.pureWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildHeaderRow(context),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isHeader) {
                      return _buildSectionHeader(context, item.listName!);
                    } else {
                      return _buildDataRow(context, item.word!);
                    }
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.orangeGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 48, color: AppTheme.pureWhite),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading activity: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.darkGrey),
                ),
                const SizedBox(height: 16),
                AppTheme.gradientButton(
                  text: 'Retry',
                  onPressed: () {
                    ref.invalidate(activityDataProvider);
                  },
                  gradient: AppTheme.blueGradient,
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
        gradient: AppTheme.blueGradient,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.softGrey,
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 20,
              child: const Text(
                'Word',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.pureWhite,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Shown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Heard',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 13,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Syllables',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Hebrew',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  'Spell Check',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pureWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String listName) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border(
          top: BorderSide(color: AppTheme.softGrey, width: 2),
          bottom: BorderSide(color: AppTheme.softGrey, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppTheme.greenGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              listName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, WordItem word) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.softGrey.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              flex: 20,
              child: Text(
                word.englishWord,
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${word.timesShown}',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${word.timesHeard}',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                '${word.timesSyllablesShown}',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${word.timesHebrewShown}',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${word.timesSpellChecked}',
                style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
