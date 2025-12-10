import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/services.dart';
import '../config/constants.dart';
import '../models/word_item.dart';
import '../config/fallback_data.dart';

// Service Providers
final sheetServiceProvider = Provider<SheetService>((ref) => SheetService());
final dictionaryServiceProvider = Provider<DictionaryService>((ref) => DictionaryService());
final translationServiceProvider = Provider<TranslationService>((ref) => TranslationService());

// Settings State
class SettingsState {
  final String credentialsJson;
  final String sheetId;
  final String wordnikApiKey;
  final bool isConfigured;
  final bool showSyllables;

  SettingsState({
    this.credentialsJson = '',
    this.sheetId = '',
    this.wordnikApiKey = '',
    this.isConfigured = false,
    this.showSyllables = false,
  });

  SettingsState copyWith({
    String? credentialsJson,
    String? sheetId,
    String? wordnikApiKey,
    bool? showSyllables,
  }) {
    return SettingsState(
      credentialsJson: credentialsJson ?? this.credentialsJson,
      sheetId: sheetId ?? this.sheetId,
      wordnikApiKey: wordnikApiKey ?? this.wordnikApiKey,
      isConfigured: (credentialsJson ?? this.credentialsJson).isNotEmpty && 
                    (sheetId ?? this.sheetId).isNotEmpty,
      showSyllables: showSyllables ?? this.showSyllables,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final creds = prefs.getString(AppConstants.sheetCredentialsKey) ?? '';
    final sid = prefs.getString(AppConstants.sheetIdKey) ?? '';
    final apiKey = prefs.getString('wordnik_api_key') ?? '';
    final showSyllables = prefs.getBool('show_syllables') ?? false;
    
    state = SettingsState(
      credentialsJson: creds,
      sheetId: sid,
      wordnikApiKey: apiKey.isNotEmpty ? apiKey : AppConstants.wordnikApiKey,
      showSyllables: showSyllables,
    );
  }

  Future<void> saveSettings({
    required String credentialsJson,
    required String sheetId,
    required String wordnikApiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sheetCredentialsKey, credentialsJson);
    await prefs.setString(AppConstants.sheetIdKey, sheetId);
    await prefs.setString('wordnik_api_key', wordnikApiKey);

    state = state.copyWith(
      credentialsJson: credentialsJson,
      sheetId: sheetId,
      wordnikApiKey: wordnikApiKey,
    );
  }
  
  Future<void> toggleSyllables(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_syllables', value);
    state = state.copyWith(showSyllables: value);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

// Initialization Provider
final sheetInitProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (!settings.isConfigured) return false;
  
  final sheetService = ref.read(sheetServiceProvider);
  try {
    await sheetService.init(settings.credentialsJson, settings.sheetId);
    return true;
  } catch (e) {
    print('Sheet Init Error: $e');
    // If it fails, strictly speaking we are not ready, but we return false
    return false;
  }
});

// Headers Provider (List Names)
final sheetHeadersProvider = FutureProvider<Map<String, int>>((ref) async {
  final fallbackLists = FallbackData.lists.keys.fold(<String, int>{}, (map, key) {
    map[key] = -1; // -1 indicates fallback list
    return map;
  });

  final isReady = await ref.watch(sheetInitProvider.future);
  if (!isReady) return fallbackLists;
  
  final sheetService = ref.read(sheetServiceProvider);
  try {
    final sheetHeaders = await sheetService.getHeaders();
    return {...fallbackLists, ...sheetHeaders};
  } catch (e) {
    print('Error fetching sheet headers: $e');
    return fallbackLists;
  }
});

// Selected List Provider
final selectedListProvider = StateProvider<String?>((ref) => null);

// Words List Provider
final wordsListProvider = FutureProvider<List<WordItem>>((ref) async {
  final selectedList = ref.watch(selectedListProvider);
  if (selectedList == null) return [];
  
  // Check if it's a fallback list
  if (FallbackData.lists.containsKey(selectedList)) {
    final rawWords = FallbackData.lists[selectedList]!;
    return rawWords.map((e) {
       final english = e['english'] ?? '';
       final hebrew = e['hebrew']; // Nullable
       final syllables = e['syllables']; // Nullable
       return WordItem(
          englishWord: english,
          hebrewWord: hebrew, 
          syllables: syllables,
       );
    }).toList();
  }

  final headers = await ref.watch(sheetHeadersProvider.future);
  final index = headers[selectedList];
  
  if (index == null || index == -1) return []; // Should be caught by fallback check if -1
  
  final sheetService = ref.read(sheetServiceProvider);
  return sheetService.getWordsExample(index);
});

// Session Manager (Randomization)
// Manages the current list of words to show, shuffled.
class SessionNotifier extends StateNotifier<List<WordItem>> {
  SessionNotifier() : super([]);
  
  int _currentIndex = 0;
  
  void setWords(List<WordItem> words) {
    // Shuffle and reset
    final shuffled = List<WordItem>.from(words)..shuffle();
    _currentIndex = 0;
    state = shuffled;
  }

  WordItem? get currentWord => state.isNotEmpty ? state[_currentIndex] : null;

  void next() {
    if (state.isEmpty) return;
    if (_currentIndex < state.length - 1) {
      _currentIndex++;
    } else {
      // Loop or re-shuffle? "never neglecting a word" implies finishing the list.
      // After finishing, maybe re-shuffle? 
      // User says "Navigating up or down moves to the next word in the list."
      // Let's just wrap around but maybe re-shuffle if we want endless?
      // "never neglecting a word" -> usually means deck of cards. 
      // I'll wrap around to 0 but maybe keeping same order? 
      // "Random order" -> done at start. 
      _currentIndex = 0; // simplistic wrap
    }
    state = [...state]; // Trigger notify
  }

  void prev() {
    if (state.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = state.length - 1;
    }
    state = [...state];
  }
  
  void updateCurrentItem(WordItem enriched) {
    if (state.isEmpty) return;
    state[_currentIndex] = enriched;
    state = [...state]; // Notify
  }
  
  int get currentIndex => _currentIndex;
  int get total => state.length;
}

final sessionProvider = StateNotifierProvider<SessionNotifier, List<WordItem>>((ref) {
  return SessionNotifier();
});
