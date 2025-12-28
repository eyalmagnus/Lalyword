import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';
import '../config/app_theme.dart';

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
      return Scaffold(
        backgroundColor: AppTheme.lightGrey,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    if (session.isEmpty || currentWord == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightGrey,
        appBar: AppBar(
          title: const Text('Empty List'),
          backgroundColor: AppTheme.pureWhite,
          foregroundColor: AppTheme.darkGrey,
        ),
        body: Center(
          child: Text(
            'No words in this list.',
            style: TextStyle(color: AppTheme.darkGrey),
          ),
        ),
      );
    }

    final isCurrentKnown = notifier.isWordKnown(currentWord);
    final titleText = isCurrentKnown 
        ? 'Word (checked) / ${notifier.visibleCount}'
        : 'Word ${notifier.currentVisiblePosition} / ${notifier.visibleCount}';
    
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.darkGrey,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
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
                backgroundColor: AppTheme.pureWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
               final hasKnown = notifier.hasKnownWords;
               if (!hasKnown) {
                 if (mounted) {
                   notifier.setWords(session);
                 }
                 return;
               }
               
               final confirmed = await showDialog<bool>(
                 context: context,
                 builder: (context) => AlertDialog(
                   backgroundColor: AppTheme.pureWhite,
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(16),
                   ),
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
                 notifier.setWords(session);
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
  late bool _showSyllablesLocal;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _syllablesTrackedForCurrentWord = false;

  @override
  void initState() {
    super.initState();
    _showSyllablesLocal = ref.read(settingsProvider).showSyllables;
    _checkEnrichment();
    _trackWordShown();
  }

  @override
  void didUpdateWidget(covariant FlashcardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.englishWord != widget.word.englishWord) {
      setState(() {
        _isFlipped = false;
        _enriching = false;
        _showSyllablesLocal = ref.read(settingsProvider).showSyllables;
        _syllablesTrackedForCurrentWord = false;
      });
      _checkEnrichment();
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
    
    bool needsDictionary = widget.word.audioUrl == null || 
                          widget.word.audioUrl!.isEmpty ||
                          widget.word.syllables == null || 
                          widget.word.syllables!.isEmpty;
    bool needsTranslation = widget.word.hebrewWord == null || 
                           widget.word.hebrewWord!.isEmpty;
    
    if (!needsDictionary && !needsTranslation) return;

    setState(() => _enriching = true);

    WordItem updated = widget.word;

    if (needsDictionary) {
      final dictService = ref.read(dictionaryServiceProvider);
      updated = await dictService.enrichWord(updated);
    }

    if (updated.hebrewWord == null || updated.hebrewWord!.isEmpty) {
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
        _trackSoundHeard();
        
        final hasSyllables = widget.word.syllables != null && 
                            widget.word.syllables!.isNotEmpty;
        if (hasSyllables && !_showSyllablesLocal) {
          setState(() {
            _showSyllablesLocal = true;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Error playing audio: $e'),
             backgroundColor: AppTheme.studyOrange,
           ),
        );
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: const Text('No audio available'),
             backgroundColor: AppTheme.softGrey,
           ),
        );
    }
  }

  void _handleVerticalDrag(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      widget.onNext();
    } else if (details.primaryVelocity! > 0) {
      widget.onPrev();
    }
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    final wasFlipped = _isFlipped;
    setState(() {
      _isFlipped = !_isFlipped;
    });
    if (!wasFlipped && _isFlipped) {
      _trackHebrewShown();
    }
  }
  
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
    widget.onEnrich(updatedWord);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _handleVerticalDrag,
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.lightGrey,
              AppTheme.pureWhite,
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight * 0.75;
            final cardWidth = constraints.maxWidth;
            return Center(
              child: SizedBox(
                height: cardHeight,
                width: cardWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 48),
                      if (_isFlipped) ...[
                          Text(
                            widget.word.hebrewWord ?? 'Translating...',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '(Swipe to flip back)',
                            style: TextStyle(color: AppTheme.softGrey),
                          ),
                      ] else ...[
                          Builder(builder: (context) {
                             final hasSyllables = widget.word.syllables != null && 
                                                 widget.word.syllables!.isNotEmpty;
                             
                             String formattedWord = widget.word.englishWord;
                             if (formattedWord.toLowerCase().startsWith('to ') && formattedWord.length > 3) {
                               formattedWord = '(to) ${formattedWord.substring(3)}';
                             } else if (formattedWord.toLowerCase().endsWith(' to') && formattedWord.length > 4) {
                               formattedWord = '${formattedWord.substring(0, formattedWord.length - 3)} {to}';
                             }
                             
                             var displayText = (_showSyllablesLocal && hasSyllables) 
                                 ? widget.word.syllables! 
                                 : formattedWord;

                             if (_showSyllablesLocal && hasSyllables && !displayText.contains('.')) {
                               displayText = '$displayText.';
                             }
                             
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
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            displayText,
                                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.darkGrey,
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
                                            color: AppTheme.softGrey,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              final wasShowing = _showSyllablesLocal;
                                              _showSyllablesLocal = !_showSyllablesLocal;
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue)
                            ),
                          
                          const SizedBox(height: 48),
                          
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.blueGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty)
                                    ? _playSound
                                    : null,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: const Icon(Icons.volume_up, size: 32, color: AppTheme.pureWhite),
                                ),
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.word.phonetic != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      widget.word.phonetic!,
                                      style: TextStyle(color: AppTheme.softGrey, fontStyle: FontStyle.italic),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (widget.word.originalWord != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: widget.word.phonetic != null ? 8.0 : 0.0,
                                      left: 8.0,
                                      right: 8.0,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.word.originalWord!.toLowerCase().startsWith('to ')
                                            ? '(to) ${widget.word.originalWord!.substring(3)}'
                                            : widget.word.originalWord!.toLowerCase().endsWith(' to') && widget.word.originalWord!.length > 4
                                                ? '${widget.word.originalWord!.substring(0, widget.word.originalWord!.length - 3)} {to}'
                                                : widget.word.originalWord!,
                                        style: TextStyle(color: AppTheme.studyOrange),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      if (widget.onToggleKnown != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: widget.isKnown,
                                onChanged: (_) => widget.onToggleKnown!(),
                              ),
                              Flexible(
                                child: Text(
                                  'I know this word',
                                  style: widget.isKnown
                                      ? const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)
                                      : const TextStyle(color: AppTheme.darkGrey),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isKnown)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                                ),
                            ],
                          ),
                        ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: IconButton(
                          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.softGrey),
                          onPressed: widget.onNext,
                          tooltip: 'Next word',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Swipe Up/Down for Next/Prev', style: TextStyle(color: AppTheme.softGrey, fontSize: 12)),
                      Text('Swipe Left/Right to Flip', style: TextStyle(color: AppTheme.softGrey, fontSize: 12)),
                      const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.expand_less_rounded, color: AppTheme.softGrey),
                            onPressed: widget.onPrev,
                            tooltip: 'Previous word',
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.softGrey),
                            onPressed: () {
                              setState(() {
                                final wasFlipped = _isFlipped;
                                _isFlipped = !_isFlipped;
                                if (!wasFlipped && _isFlipped) {
                                  _trackHebrewShown();
                                }
                              });
                            },
                            tooltip: 'Flip card',
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.softGrey),
                            onPressed: () {
                              setState(() {
                                final wasFlipped = _isFlipped;
                                _isFlipped = !_isFlipped;
                                if (!wasFlipped && _isFlipped) {
                                  _trackHebrewShown();
                                }
                              });
                            },
                            tooltip: 'Flip card',
                          ),
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
          },
        ),
      ),
    );
  }
}
