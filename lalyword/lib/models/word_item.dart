class WordItem {
  final String englishWord;
  final String? hebrewWord;
  final String? syllables; // e.g. "beau.ti.ful"
  final String? audioUrl;
  final String? phonetic;

  WordItem({
    required this.englishWord,
    this.hebrewWord,
    this.syllables,
    this.audioUrl,
    this.phonetic,
  });

  WordItem copyWith({
    String? englishWord,
    String? hebrewWord,
    String? syllables,
    String? audioUrl,
    String? phonetic,
  }) {
    return WordItem(
      englishWord: englishWord ?? this.englishWord,
      hebrewWord: hebrewWord ?? this.hebrewWord,
      syllables: syllables ?? this.syllables,
      audioUrl: audioUrl ?? this.audioUrl,
      phonetic: phonetic ?? this.phonetic,
    );
  }
}
