class WordItem {
  final String englishWord;
  final String? hebrewWord;
  final String? syllables; // e.g. "beau.ti.ful"
  final String? audioUrl;
  final String? phonetic;
  final String? originalWord; // Original word before modification (e.g., "behaviors" -> "behavior")
  
  // Activity tracking
  final int timesShown; // Number of times this word was shown
  final int timesHeard; // Number of times this word was heard by sound
  final int timesSyllablesShown; // Number of times word was presented in syllables mode
  final int timesHebrewShown; // Number of times Hebrew translation has been shown
  final int timesSpellChecked; // Number of times spelling was checked

  WordItem({
    required this.englishWord,
    this.hebrewWord,
    this.syllables,
    this.audioUrl,
    this.phonetic,
    this.originalWord,
    this.timesShown = 0,
    this.timesHeard = 0,
    this.timesSyllablesShown = 0,
    this.timesHebrewShown = 0,
    this.timesSpellChecked = 0,
  });

  WordItem copyWith({
    String? englishWord,
    String? hebrewWord,
    String? syllables,
    String? audioUrl,
    String? phonetic,
    String? originalWord,
    int? timesShown,
    int? timesHeard,
    int? timesSyllablesShown,
    int? timesHebrewShown,
    int? timesSpellChecked,
  }) {
    return WordItem(
      englishWord: englishWord ?? this.englishWord,
      hebrewWord: hebrewWord ?? this.hebrewWord,
      syllables: syllables ?? this.syllables,
      audioUrl: audioUrl ?? this.audioUrl,
      phonetic: phonetic ?? this.phonetic,
      originalWord: originalWord ?? this.originalWord,
      timesShown: timesShown ?? this.timesShown,
      timesHeard: timesHeard ?? this.timesHeard,
      timesSyllablesShown: timesSyllablesShown ?? this.timesSyllablesShown,
      timesHebrewShown: timesHebrewShown ?? this.timesHebrewShown,
      timesSpellChecked: timesSpellChecked ?? this.timesSpellChecked,
    );
  }
  
  // Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'englishWord': englishWord,
      'hebrewWord': hebrewWord,
      'syllables': syllables,
      'audioUrl': audioUrl,
      'phonetic': phonetic,
      'originalWord': originalWord,
      'timesShown': timesShown,
      'timesHeard': timesHeard,
      'timesSyllablesShown': timesSyllablesShown,
      'timesHebrewShown': timesHebrewShown,
      'timesSpellChecked': timesSpellChecked,
    };
  }
  
  // Create from JSON for local storage
  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(
      englishWord: json['englishWord'] as String,
      hebrewWord: json['hebrewWord'] as String?,
      syllables: json['syllables'] as String?,
      audioUrl: json['audioUrl'] as String?,
      phonetic: json['phonetic'] as String?,
      originalWord: json['originalWord'] as String?,
      timesShown: json['timesShown'] as int? ?? 0,
      timesHeard: json['timesHeard'] as int? ?? 0,
      timesSyllablesShown: json['timesSyllablesShown'] as int? ?? 0,
      timesHebrewShown: json['timesHebrewShown'] as int? ?? 0,
      timesSpellChecked: json['timesSpellChecked'] as int? ?? 0,
    );
  }
}
