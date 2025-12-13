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
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// Settings State
class SettingsState {
  final String sheetId;
  final bool isConfigured;
  final bool showSyllables;

  SettingsState({
    this.sheetId = '',
    this.isConfigured = false,
    this.showSyllables = false,
  });

  SettingsState copyWith({
    String? sheetId,
    bool? showSyllables,
  }) {
    return SettingsState(
      sheetId: sheetId ?? this.sheetId,
      isConfigured: (sheetId ?? this.sheetId).isNotEmpty,
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
    final sid = prefs.getString(AppConstants.sheetIdKey) ?? '';
    final showSyllables = prefs.getBool('show_syllables') ?? false;
    
    state = SettingsState(
      sheetId: sid,
      showSyllables: showSyllables,
    );
  }

  Future<void> saveSettings({
    required String sheetId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sheetIdKey, sheetId);

    state = state.copyWith(
      sheetId: sheetId,
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
    // Use simple public API method
    await sheetService.initPublic(settings.sheetId);
    return true;
  } catch (e) {
    print('Sheet Init Error: $e');
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
  
  final storageService = ref.read(storageServiceProvider);
  
  // Check if it's a fallback list
  if (FallbackData.lists.containsKey(selectedList)) {
    // Try to load from local storage first
    final cachedWords = await storageService.loadWordsForList(selectedList);
    if (cachedWords.isNotEmpty) {
      return cachedWords;
    }
    
    // Otherwise use fallback data
    final rawWords = FallbackData.lists[selectedList]!;
    final words = rawWords.map((e) {
       final english = e['english'] ?? '';
       final hebrew = e['hebrew']; // Nullable
       final syllables = e['syllables']; // Nullable
       return WordItem(
          englishWord: english,
          hebrewWord: hebrew, 
          syllables: syllables,
       );
    }).toList();
    
    // Save to local storage
    await storageService.saveWordsForList(selectedList, words);
    return words;
  }

  // Try to load from local storage first
  final cachedWords = await storageService.loadWordsForList(selectedList);
  if (cachedWords.isNotEmpty) {
    return cachedWords;
  }

  // Fetch from Google Sheets
  final headers = await ref.watch(sheetHeadersProvider.future);
  final index = headers[selectedList];
  
  if (index == null || index == -1) return []; // Should be caught by fallback check if -1
  
  final sheetService = ref.read(sheetServiceProvider);
  final words = await sheetService.getWordsExample(index);
  
  // Save to local storage
  if (words.isNotEmpty) {
    await storageService.saveWordsForList(selectedList, words);
  }
  
  return words;
});

// Session Manager (Randomization)
// Manages the current list of words to show, shuffled.
class SessionNotifier extends StateNotifier<List<WordItem>> {
  SessionNotifier() : super([]);
  
  int _currentIndex = 0;
  Set<int> _knownWordIndices = {}; // Track indices of words marked as "known"
  
  void setWords(List<WordItem> words) {
    // Shuffle and reset
    final shuffled = List<WordItem>.from(words)..shuffle();
    _currentIndex = 0;
    _knownWordIndices.clear(); // Clear all known states when reshuffling
    state = shuffled;
    _moveToNextNonKnown(); // Move to first non-known word
  }

  WordItem? get currentWord {
    if (state.isEmpty) return null;
    // Always return the word at current index, even if it's marked as known
    // Navigation will handle skipping known words, but we keep current word visible
    return state[_currentIndex];
  }
  
  int? get currentWordIndex {
    if (state.isEmpty) return null;
    return _currentIndex;
  }

  void next() {
    if (state.isEmpty) return;
    // Start from the next position after current, skip known words
    final nextStart = (_currentIndex + 1) % state.length;
    final nextIndex = _findNextNonKnownIndex(nextStart, forward: true);
    if (nextIndex != null) {
      _currentIndex = nextIndex;
      state = [...state]; // Trigger notify
    } else if (_knownWordIndices.length < state.length) {
      // If we couldn't find next non-known but there are still some, try from beginning
      final fromStart = _findNextNonKnownIndex(0, forward: true);
      if (fromStart != null) {
        _currentIndex = fromStart;
        state = [...state];
      }
    }
  }

  void prev() {
    if (state.isEmpty) return;
    // Start from the previous position before current, skip known words
    final prevStart = (_currentIndex - 1 + state.length) % state.length;
    final prevIndex = _findNextNonKnownIndex(prevStart, forward: false);
    if (prevIndex != null) {
      _currentIndex = prevIndex;
      state = [...state]; // Trigger notify
    } else if (_knownWordIndices.length < state.length) {
      // If we couldn't find prev non-known but there are still some, try from end
      final fromEnd = _findNextNonKnownIndex(state.length - 1, forward: false);
      if (fromEnd != null) {
        _currentIndex = fromEnd;
        state = [...state];
      }
    }
  }
  
  void updateCurrentItem(WordItem enriched) {
    if (state.isEmpty) return;
    final effectiveIndex = currentWordIndex;
    if (effectiveIndex != null) {
      state[effectiveIndex] = enriched;
      state = [...state]; // Notify
    }
  }
  
  void toggleWordKnown(WordItem word) {
    // Find the index of this word
    final wordIndex = state.indexWhere((w) => w.englishWord == word.englishWord);
    if (wordIndex < 0) return;
    
    if (_knownWordIndices.contains(wordIndex)) {
      _knownWordIndices.remove(wordIndex);
    } else {
      _knownWordIndices.add(wordIndex);
      // Don't navigate away - keep the word visible so user can uncheck or navigate manually
    }
    state = [...state]; // Notify
  }
  
  bool isWordKnown(WordItem word) {
    final wordIndex = state.indexWhere((w) => w.englishWord == word.englishWord);
    return wordIndex >= 0 && _knownWordIndices.contains(wordIndex);
  }
  
  void _moveToNextNonKnown() {
    final nextIndex = _findNextNonKnownIndex(_currentIndex, forward: true);
    if (nextIndex != null) {
      _currentIndex = nextIndex;
    }
  }
  
  // Find next/previous non-known word index, wrapping around
  int? _findNextNonKnownIndex(int startIndex, {required bool forward}) {
    if (state.isEmpty) return null;
    if (_knownWordIndices.length >= state.length) return null; // All words are known
    
    int current = startIndex;
    int checked = 0;
    
    while (checked < state.length) {
      if (!_knownWordIndices.contains(current)) {
        return current;
      }
      
      if (forward) {
        current = (current + 1) % state.length;
      } else {
        current = (current - 1 + state.length) % state.length;
      }
      checked++;
    }
    
    return null; // Should not happen if we checked length correctly
  }
  
  int get currentIndex => _currentIndex;
  int get total => state.length;
  int get visibleCount => state.length - _knownWordIndices.length; // Count of non-known words
  
  // Get the position of current word among visible (non-known) words (1-based)
  int get currentVisiblePosition {
    if (state.isEmpty || _knownWordIndices.contains(_currentIndex)) return 0;
    int count = 1;
    for (int i = 0; i < _currentIndex; i++) {
      if (!_knownWordIndices.contains(i)) {
        count++;
      }
    }
    return count;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, List<WordItem>>((ref) {
  return SessionNotifier();
});

// Activity Data Provider
final activityDataProvider = FutureProvider<List<WordItem>>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  final words = await storageService.getAllWordsWithActivity();
  print('Activity data loaded: ${words.length} words');
  return words;
});
