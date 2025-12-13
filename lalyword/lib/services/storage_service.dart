import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_item.dart';

class StorageService {
  static const String _wordsKeyPrefix = 'words_list_';
  static const String _allWordsKey = 'all_words_activity';

  // Save all words for a specific list
  Future<void> saveWordsForList(String listName, List<WordItem> words) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_wordsKeyPrefix$listName';
    final jsonList = words.map((w) => w.toJson()).toList();
    await prefs.setString(key, jsonEncode(jsonList));
    
    // Also update the global activity list
    await _updateGlobalActivityList(words);
  }

  // Load words for a specific list
  Future<List<WordItem>> loadWordsForList(String listName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_wordsKeyPrefix$listName';
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final words = jsonList.map((json) => WordItem.fromJson(json as Map<String, dynamic>)).toList();
      
      // Merge activity data from global activity list
      final globalActivityString = prefs.getString(_allWordsKey);
      if (globalActivityString != null) {
        try {
          final globalJsonList = jsonDecode(globalActivityString) as List<dynamic>;
          final Map<String, WordItem> globalActivity = {};
          for (var json in globalJsonList) {
            final item = WordItem.fromJson(json as Map<String, dynamic>);
            globalActivity[item.englishWord.toLowerCase()] = item;
          }
          
          // Update words with latest activity data
          for (int i = 0; i < words.length; i++) {
            final key = words[i].englishWord.toLowerCase();
            if (globalActivity.containsKey(key)) {
              final globalWord = globalActivity[key]!;
              words[i] = words[i].copyWith(
                timesShown: globalWord.timesShown,
                timesHeard: globalWord.timesHeard,
                timesSyllablesShown: globalWord.timesSyllablesShown,
                timesHebrewShown: globalWord.timesHebrewShown,
                timesSpellChecked: globalWord.timesSpellChecked,
              );
            }
          }
        } catch (e) {
          print('Error merging activity data: $e');
        }
      }
      
      return words;
    } catch (e) {
      print('Error loading words for list $listName: $e');
      return [];
    }
  }

  // Update a single word's activity data
  Future<void> updateWordActivity(WordItem word) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_allWordsKey);
    
    Map<String, WordItem> allWords = {};
    if (jsonString != null) {
      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        for (var json in jsonList) {
          final item = WordItem.fromJson(json as Map<String, dynamic>);
          allWords[item.englishWord.toLowerCase()] = item;
        }
      } catch (e) {
        print('Error loading global activity list: $e');
      }
    }
    
    // Merge activity data: preserve existing activity if present, otherwise use new word's activity
    final key = word.englishWord.toLowerCase();
    if (allWords.containsKey(key)) {
      // Merge: use the maximum of existing and new values for each activity counter
      // This ensures we never lose activity data
      final existing = allWords[key]!;
      allWords[key] = word.copyWith(
        timesShown: word.timesShown > existing.timesShown ? word.timesShown : existing.timesShown,
        timesHeard: word.timesHeard > existing.timesHeard ? word.timesHeard : existing.timesHeard,
        timesSyllablesShown: word.timesSyllablesShown > existing.timesSyllablesShown ? word.timesSyllablesShown : existing.timesSyllablesShown,
        timesHebrewShown: word.timesHebrewShown > existing.timesHebrewShown ? word.timesHebrewShown : existing.timesHebrewShown,
        timesSpellChecked: word.timesSpellChecked > existing.timesSpellChecked ? word.timesSpellChecked : existing.timesSpellChecked,
      );
    } else {
      // New word, add it
      allWords[key] = word;
    }
    
    // Save back
    final jsonList = allWords.values.map((w) => w.toJson()).toList();
    await prefs.setString(_allWordsKey, jsonEncode(jsonList));
  }

  // Get all words with activity data
  Future<List<WordItem>> getAllWordsWithActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_allWordsKey);
    
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => WordItem.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading all words with activity: $e');
      return [];
    }
  }

  // Get all words grouped by list name
  Future<Map<String, List<WordItem>>> getAllWordsByList(List<String> listNames) async {
    final Map<String, List<WordItem>> result = {};
    
    for (final listName in listNames) {
      final words = await loadWordsForList(listName);
      if (words.isNotEmpty) {
        result[listName] = words;
      }
    }
    
    return result;
  }

  // Update global activity list when words are saved
  Future<void> _updateGlobalActivityList(List<WordItem> newWords) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_allWordsKey);
    
    Map<String, WordItem> allWords = {};
    if (jsonString != null) {
      try {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        for (var json in jsonList) {
          final item = WordItem.fromJson(json as Map<String, dynamic>);
          allWords[item.englishWord.toLowerCase()] = item;
        }
      } catch (e) {
        print('Error loading global activity list: $e');
      }
    }
    
    // Merge new words, preserving existing activity data
    for (var newWord in newWords) {
      final key = newWord.englishWord.toLowerCase();
      if (allWords.containsKey(key)) {
        // Preserve existing activity data
        final existing = allWords[key]!;
        allWords[key] = newWord.copyWith(
          timesShown: existing.timesShown,
          timesHeard: existing.timesHeard,
          timesSyllablesShown: existing.timesSyllablesShown,
          timesHebrewShown: existing.timesHebrewShown,
          timesSpellChecked: existing.timesSpellChecked,
        );
      } else {
        // New word, add it
        allWords[key] = newWord;
      }
    }
    
    // Save back
    final jsonList = allWords.values.map((w) => w.toJson()).toList();
    await prefs.setString(_allWordsKey, jsonEncode(jsonList));
  }
}

