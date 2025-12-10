import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    // Load words from selected list
    try {
      final words = await ref.read(wordsListProvider.future);
      if (words.isNotEmpty) {
        ref.read(sessionProvider.notifier).setWords(words);
      }
    } catch (e) {
      print("Error loading session: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final currentWord = notifier.currentWord;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isEmpty || currentWord == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Empty List')),
        body: const Center(child: Text('No words in this list.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Word ${notifier.currentIndex + 1} / ${notifier.total}'),
        actions: [
          IconButton(
             icon: const Icon(Icons.shuffle),
             onPressed: () => notifier.setWords(session), // Reshuffles
          )
        ],
      ),
      body: FlashcardContent(
        word: currentWord,
        onNext: notifier.next,
        onPrev: notifier.prev,
        onEnrich: (enriched) => notifier.updateCurrentItem(enriched),
      ),
    );
  }
}

class FlashcardContent extends ConsumerStatefulWidget {
  final WordItem word;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(WordItem) onEnrich;

  const FlashcardContent({
    super.key,
    required this.word,
    required this.onNext,
    required this.onPrev,
    required this.onEnrich,
  });

  @override
  ConsumerState<FlashcardContent> createState() => _FlashcardContentState();
}

class _FlashcardContentState extends ConsumerState<FlashcardContent> {
  bool _isFlipped = false;
  bool _enriching = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _checkEnrichment();
  }

  @override
  void didUpdateWidget(covariant FlashcardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.englishWord != widget.word.englishWord) {
      setState(() {
        _isFlipped = false;
        _enriching = false;
      });
      _checkEnrichment();
    }
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkEnrichment() async {
    if (_enriching) return;
    
    // Check if we need to enrich (missing audio/syllables or missing translation AND Hebrew)
    // Note: if sheet had hebrew, we might not need translation service.
    // If audioUrl is null, we try dictionary.
    
    bool needsDictionary = widget.word.audioUrl == null || widget.word.syllables == null;
    bool needsTranslation = widget.word.hebrewWord == null;
    
    if (!needsDictionary && !needsTranslation) return;

    setState(() => _enriching = true);

    WordItem updated = widget.word;

    // 1. Dictionary
    if (needsDictionary) {
      final dictService = ref.read(dictionaryServiceProvider);
      updated = await dictService.enrichWord(updated);
    }

    // 2. Translation
    if (updated.hebrewWord == null) {
      final transService = ref.read(translationServiceProvider);
      final rawDetails = await transService.translate(updated.englishWord);
      if (rawDetails != null) {
        updated = updated.copyWith(hebrewWord: rawDetails);
      }
    }

    if (mounted) {
       widget.onEnrich(updated);
       setState(() => _enriching = false);
    }
  }

  Future<void> _playSound() async {
    if (widget.word.audioUrl != null) {
      try {
        await _audioPlayer.play(UrlSource(widget.word.audioUrl!));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('No audio available')),
        );
    }
  }

  void _handleVerticalDrag(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      // Swipe Up -> Next
      widget.onNext();
    } else if (details.primaryVelocity! > 0) {
      // Swipe Down -> Prev
      widget.onPrev();
    }
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    // Swipe Side -> Flip
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _handleVerticalDrag,
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: Container(
        color: Theme.of(context).colorScheme.surface, // Background
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: AspectRatio(
          aspectRatio: 0.7, // Card shape
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isFlipped) ...[
                      // HEBREW SIDE
                      Text(
                        widget.word.hebrewWord ?? 'Translating...',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '(Swipe to flip back)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                  ] else ...[
                      // ENGLISH SIDE
                      // ENGLISH SIDE
                      // If Syllables enabled AND available, show syllables as MAIN text or sub text?
                      // User said: "when enabled, all the English words show a dot between silables"
                      // This implies the main "English Word" display should be the syllabified version.
                      
                      Builder(builder: (context) {
                         final settings = ref.watch(settingsProvider);
                         final showSyllables = settings.showSyllables;
                         final hasSyllables = widget.word.syllables != null;
                         
                         final displayText = (showSyllables && hasSyllables) 
                             ? widget.word.syllables! 
                             : widget.word.englishWord;

                         return Column(
                           children: [
                             Text(
                               displayText,
                               style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                 fontWeight: FontWeight.bold,
                               ),
                               textAlign: TextAlign.center,
                             ),
                             // If we show syllables as main, maybe show original below? Or nothing?
                             // User requirement is simple: "words show a dot". 
                             // So we just replace the main text.
                           ],
                         );
                      }),
                      
                      const SizedBox(height: 16),

                      if (_enriching)
                        const SizedBox(
                          width: 20, height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        ),
                      
                      const SizedBox(height: 48),
                      
                      // Audio Button
                      IconButton.filled(
                        icon: const Icon(Icons.volume_up, size: 32),
                        onPressed: _playSound,
                        style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                      
                      if (widget.word.phonetic != null)
                         Padding(
                           padding: const EdgeInsets.only(top: 16.0),
                           child: Text(
                             widget.word.phonetic!,
                             style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                           ),
                         ),
                  ],
                  
                  const Spacer(),
                  const Text('Swipe Up/Down for Next/Prev', style: TextStyle(color: Colors.grey)),
                  const Text('Swipe Left/Right to Flip', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
