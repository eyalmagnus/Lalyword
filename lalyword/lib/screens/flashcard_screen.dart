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

    final isCurrentKnown = notifier.isWordKnown(currentWord);
    final titleText = isCurrentKnown 
        ? 'Word (checked) / ${notifier.visibleCount}'
        : 'Word ${notifier.currentVisiblePosition} / ${notifier.visibleCount}';
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Skip warning if no words are marked as known
            final hasKnown = notifier.hasKnownWords;
            if (!hasKnown) {
              if (mounted) {
                Navigator.of(context).pop();
              }
              return;
            }
            
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit?'),
                content: const Text('Are you sure? This will reset all "I know this word" checkboxes and reshuffle the order.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(titleText),
        actions: [
          IconButton(
             icon: const Icon(Icons.shuffle),
             onPressed: () async {
               // Skip warning if no words are marked as known
               final hasKnown = notifier.hasKnownWords;
               if (!hasKnown) {
                 if (mounted) {
                   notifier.setWords(session); // Reshuffles and clears known states
                 }
                 return;
               }
               
               // Show confirmation dialog
               final confirmed = await showDialog<bool>(
                 context: context,
                 builder: (context) => AlertDialog(
                   title: const Text('Reshuffle words?'),
                   content: const Text('Are you sure? This will reset all "I know this word" checkboxes and reshuffle the order.'),
                   actions: [
                     TextButton(
                       onPressed: () => Navigator.of(context).pop(false),
                       child: const Text('Cancel'),
                     ),
                     TextButton(
                       onPressed: () => Navigator.of(context).pop(true),
                       child: const Text('Yes'),
                     ),
                   ],
                 ),
               );
               if (confirmed == true && mounted) {
                 notifier.setWords(session); // Reshuffles and clears known states
               }
             },
          )
        ],
      ),
      body: FlashcardContent(
        word: currentWord,
        onNext: notifier.next,
        onPrev: notifier.prev,
        onEnrich: (enriched) => notifier.updateCurrentItem(enriched),
        isKnown: notifier.isWordKnown(currentWord),
        onToggleKnown: () => notifier.toggleWordKnown(currentWord),
      ),
    );
  }
}

class FlashcardContent extends ConsumerStatefulWidget {
  final WordItem word;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(WordItem) onEnrich;
  final bool isKnown;
  final VoidCallback? onToggleKnown;

  const FlashcardContent({
    super.key,
    required this.word,
    required this.onNext,
    required this.onPrev,
    required this.onEnrich,
    required this.isKnown,
    this.onToggleKnown,
  });

  @override
  ConsumerState<FlashcardContent> createState() => _FlashcardContentState();
}

class _FlashcardContentState extends ConsumerState<FlashcardContent> {
  bool _isFlipped = false;
  bool _enriching = false;
  // Local toggle state. Initialized from global settings.
  late bool _showSyllablesLocal;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _syllablesTrackedForCurrentWord = false; // Track if we've already counted syllables for this word

  @override
  void initState() {
    super.initState();
    // Initialize local state from global settings
    _showSyllablesLocal = ref.read(settingsProvider).showSyllables;
    _checkEnrichment();
    // Track that word was shown
    _trackWordShown();
  }

  @override
  void didUpdateWidget(covariant FlashcardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.englishWord != widget.word.englishWord) {
      setState(() {
        _isFlipped = false;
        _enriching = false;
        // Reset local state when word changes
        _showSyllablesLocal = ref.read(settingsProvider).showSyllables;
        _syllablesTrackedForCurrentWord = false;
      });
      _checkEnrichment();
      // Track that new word was shown
      _trackWordShown();
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
    // Treat empty strings the same as null (missing data)
    
    bool needsDictionary = widget.word.audioUrl == null || 
                          widget.word.audioUrl!.isEmpty ||
                          widget.word.syllables == null || 
                          widget.word.syllables!.isEmpty;
    bool needsTranslation = widget.word.hebrewWord == null || 
                           widget.word.hebrewWord!.isEmpty;
    
    if (!needsDictionary && !needsTranslation) return;

    setState(() => _enriching = true);

    WordItem updated = widget.word;
    print('=== ENRICHMENT START for: ${widget.word.englishWord} ===');
    print('Initial syllables: "${updated.syllables}"');
    print('Initial hebrewWord: "${updated.hebrewWord}"');

    // 1. Dictionary
    if (needsDictionary) {
      final dictService = ref.read(dictionaryServiceProvider);
      print('Calling enrichWord');
      updated = await dictService.enrichWord(updated);
      print('After enrichWord - syllables: "${updated.syllables}", audioUrl: ${updated.audioUrl}');
    }

    // 2. Translation
    if (updated.hebrewWord == null || updated.hebrewWord!.isEmpty) {
      final transService = ref.read(translationServiceProvider);
      final rawDetails = await transService.translate(updated.englishWord);
      if (rawDetails != null) {
        updated = updated.copyWith(hebrewWord: rawDetails);
        print('After translation - hebrewWord: "${updated.hebrewWord}"');
      }
    }

    print('=== ENRICHMENT END - Final syllables: "${updated.syllables}" ===');

    if (mounted) {
       widget.onEnrich(updated);
       setState(() => _enriching = false);
    }
  }

  Future<void> _playSound() async {
    if (widget.word.audioUrl != null) {
      try {
        await _audioPlayer.play(UrlSource(widget.word.audioUrl!));
        // Track that sound was heard
        _trackSoundHeard();
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
    final wasFlipped = _isFlipped;
    setState(() {
      _isFlipped = !_isFlipped;
    });
    // Track Hebrew shown when flipping to Hebrew side
    if (!wasFlipped && _isFlipped) {
      _trackHebrewShown();
    }
  }
  
  // Track activity methods
  Future<void> _trackWordShown() async {
    final updated = widget.word.copyWith(timesShown: widget.word.timesShown + 1);
    await _updateWordActivity(updated);
  }
  
  Future<void> _trackSoundHeard() async {
    final updated = widget.word.copyWith(timesHeard: widget.word.timesHeard + 1);
    await _updateWordActivity(updated);
  }
  
  Future<void> _trackSyllablesShown() async {
    final updated = widget.word.copyWith(timesSyllablesShown: widget.word.timesSyllablesShown + 1);
    await _updateWordActivity(updated);
  }
  
  Future<void> _trackHebrewShown() async {
    final updated = widget.word.copyWith(timesHebrewShown: widget.word.timesHebrewShown + 1);
    await _updateWordActivity(updated);
  }
  
  Future<void> _updateWordActivity(WordItem updatedWord) async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.updateWordActivity(updatedWord);
    // Also update in session
    widget.onEnrich(updatedWord);
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
                         // Use local state
                         // Check both null AND empty string
                         final hasSyllables = widget.word.syllables != null && 
                                            widget.word.syllables!.isNotEmpty;
                         
                         var displayText = (_showSyllablesLocal && hasSyllables) 
                             ? widget.word.syllables! 
                             : widget.word.englishWord;

                         // Single syllable check: if we are showing syllables, and there are no dots inside, add one at end.
                         if (_showSyllablesLocal && hasSyllables && !displayText.contains('.')) {
                           displayText = '$displayText.';
                         }
                         
                         // Track syllables shown when displaying syllables (only once per word display)
                         if (_showSyllablesLocal && hasSyllables && !_syllablesTrackedForCurrentWord) {
                           WidgetsBinding.instance.addPostFrameCallback((_) {
                             _trackSyllablesShown();
                             _syllablesTrackedForCurrentWord = true;
                           });
                         }

                         return Column(
                           children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  // Invisible spacer to balance the icon if we want it strictly centered
                                  // Or just place icon to the right/top-right
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        displayText,
                                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  if (hasSyllables) 
                                    IconButton(
                                      icon: Icon(
                                        _showSyllablesLocal ? Icons.visibility_off : Icons.visibility,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          final wasShowing = _showSyllablesLocal;
                                          _showSyllablesLocal = !_showSyllablesLocal;
                                          // Track when syllables are toggled on
                                          if (!wasShowing && _showSyllablesLocal && hasSyllables) {
                                            _trackSyllablesShown();
                                            _syllablesTrackedForCurrentWord = true;
                                          }
                                        });
                                      },
                                      tooltip: _showSyllablesLocal ? 'Hide Syllables' : 'Show Syllables',
                                    ),
                               ],
                             ),
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
                        onPressed: (widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty)
                            ? _playSound
                            : null,
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
                  
                  // "I know this word" checkbox
                  if (widget.onToggleKnown != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: widget.isKnown,
                            onChanged: (_) => widget.onToggleKnown!(),
                            checkColor: Colors.white,
                            fillColor: widget.isKnown 
                                ? WidgetStateProperty.all(Colors.green)
                                : WidgetStateProperty.all(null),
                          ),
                          Text(
                            'I know this word',
                            style: widget.isKnown
                                ? const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                                : null,
                          ),
                          if (widget.isKnown)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ),
                        ],
                      ),
                    ),
                  
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
