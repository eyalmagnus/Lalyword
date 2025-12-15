import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';

class SpellScreen extends ConsumerStatefulWidget {
  const SpellScreen({super.key});

  @override
  ConsumerState<SpellScreen> createState() => _SpellScreenState();
}

class _SpellScreenState extends ConsumerState<SpellScreen> {
  bool _isLoading = true;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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
                  notifier.setWords(session);
                  _textController.clear();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _focusNode.requestFocus();
                  });
                }
                return;
              }
              
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
                notifier.setWords(session);
                _textController.clear();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _focusNode.requestFocus();
                });
              }
            },
          )
        ],
      ),
      body: SpellContent(
        word: currentWord,
        isKnown: notifier.isWordKnown(currentWord),
        onNext: () {
          notifier.next();
          _textController.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNode.requestFocus();
          });
        },
        onPrev: () {
          notifier.prev();
          _textController.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNode.requestFocus();
          });
        },
        onEnrich: (enriched) => notifier.updateCurrentItem(enriched),
        onMarkKnown: () => notifier.toggleWordKnown(currentWord),
        textController: _textController,
        focusNode: _focusNode,
      ),
    );
  }
}

class SpellContent extends ConsumerStatefulWidget {
  final WordItem word;
  final bool isKnown;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(WordItem) onEnrich;
  final VoidCallback onMarkKnown;
  final TextEditingController textController;
  final FocusNode focusNode;

  const SpellContent({
    super.key,
    required this.word,
    required this.isKnown,
    required this.onNext,
    required this.onPrev,
    required this.onEnrich,
    required this.onMarkKnown,
    required this.textController,
    required this.focusNode,
  });

  @override
  ConsumerState<SpellContent> createState() => _SpellContentState();
}

class _SpellContentState extends ConsumerState<SpellContent> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _enriching = false;
  bool _isFlipped = false;
  bool? _isCorrect; // null = not checked, true = correct, false = incorrect
  String? _lastCheckedText; // Store the last checked text for highlighting
  
  @override
  void initState() {
    super.initState();
    _checkEnrichment();
    // Listen to text changes to enable/disable check button
    widget.textController.addListener(_onTextChanged);
    // Request focus after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.focusNode.requestFocus();
      }
    });
  }
  
  void _onTextChanged() {
    // Update state when text changes to rebuild button
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant SpellContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.englishWord != widget.word.englishWord) {
      widget.textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.focusNode.requestFocus();
      });
      setState(() {
        _enriching = false;
        _isFlipped = false; // Reset flip state when word changes
        _isCorrect = null; // Reset check state
        _lastCheckedText = null;
      });
      _checkEnrichment();
    }
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkEnrichment() async {
    if (_enriching) return;
    
    // Check if we need to enrich (missing audio/syllables or missing translation)
    bool needsDictionary = widget.word.audioUrl == null || 
                          widget.word.audioUrl!.isEmpty ||
                          widget.word.syllables == null || 
                          widget.word.syllables!.isEmpty;
    bool needsTranslation = widget.word.hebrewWord == null || 
                           widget.word.hebrewWord!.isEmpty;
    
    if (!needsDictionary && !needsTranslation) return;

    setState(() => _enriching = true);

    WordItem updated = widget.word;

    // 1. Dictionary
    if (needsDictionary) {
      final dictService = ref.read(dictionaryServiceProvider);
      updated = await dictService.enrichWord(updated);
    }

    // 2. Translation (important for spell screen as Hebrew is shown at top)
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
    if (widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty) {
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
    // Swipe Left/Right -> Flip
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _checkSpelling() {
    final typedText = widget.textController.text.trim().toLowerCase();
    final correctWord = widget.word.englishWord.toLowerCase();
    
    if (typedText.isEmpty) {
      return; // Don't check empty input
    }
    
    setState(() {
      _lastCheckedText = typedText;
      _isCorrect = typedText == correctWord;
      
      if (_isCorrect == true) {
        // Mark as known when correct
        widget.onMarkKnown();
      }
    });
    
    // Track spelling check activity
    _trackSpellChecked();
  }
  
  Future<void> _trackSpellChecked() async {
    // Get the current word from the session
    final notifier = ref.read(sessionProvider.notifier);
    final currentWord = notifier.currentWord;
    
    if (currentWord == null) return;
    
    final storageService = ref.read(storageServiceProvider);
    
    // Load the latest word from storage to ensure we have the most recent activity data
    final allWords = await storageService.getAllWordsWithActivity();
    final storedWord = allWords.firstWhere(
      (w) => w.englishWord.toLowerCase() == currentWord.englishWord.toLowerCase(),
      orElse: () => currentWord,
    );
    
    // Use the stored word's count if available, otherwise use current word's count
    final currentCount = storedWord.timesSpellChecked;
    final newCount = currentCount + 1;
    
    // Create updated word with incremented count, preserving display data from current word
    // This ensures Hebrew, audio, syllables etc. don't disappear
    final updated = currentWord.copyWith(
      timesSpellChecked: newCount,
      // Preserve other activity counts from stored word if they're higher
      timesShown: storedWord.timesShown > currentWord.timesShown ? storedWord.timesShown : currentWord.timesShown,
      timesHeard: storedWord.timesHeard > currentWord.timesHeard ? storedWord.timesHeard : currentWord.timesHeard,
      timesSyllablesShown: storedWord.timesSyllablesShown > currentWord.timesSyllablesShown ? storedWord.timesSyllablesShown : currentWord.timesSyllablesShown,
      timesHebrewShown: storedWord.timesHebrewShown > currentWord.timesHebrewShown ? storedWord.timesHebrewShown : currentWord.timesHebrewShown,
    );
    await storageService.updateWordActivity(updated);
    
    // Also update in session - this preserves all display data (Hebrew, audio, etc.)
    widget.onEnrich(updated);
  }

  Widget _buildLetterFeedback(String typedText, String correctWord) {
    final List<Widget> letterWidgets = [];
    
    // Calculate size based on word length to fit up to 15 letters
    final maxWordLength = correctWord.length > typedText.length ? correctWord.length : typedText.length;
    final fontSize = maxWordLength > 12 ? 12.0 : maxWordLength > 10 ? 13.0 : 14.0;
    final horizontalPadding = maxWordLength > 12 ? 3.0 : maxWordLength > 10 ? 4.0 : 5.0;
    final verticalPadding = maxWordLength > 12 ? 2.0 : maxWordLength > 10 ? 3.0 : 3.0;
    final horizontalMargin = maxWordLength > 12 ? 1.0 : maxWordLength > 10 ? 1.0 : 2.0;
    final borderWidth = maxWordLength > 12 ? 1.0 : maxWordLength > 10 ? 1.5 : 2.0;
    
    for (int i = 0; i < typedText.length; i++) {
      if (i < correctWord.length && typedText[i] == correctWord[i]) {
        // Correct letter in correct position - green
        letterWidgets.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              border: Border.all(color: Colors.green, width: borderWidth),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typedText[i],
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      } else {
        // Incorrect letter or position - red
        letterWidgets.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              border: Border.all(color: Colors.red, width: borderWidth),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typedText[i],
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      }
    }
    
    // Add empty red containers for missing letters if typed text is shorter
    if (typedText.length < correctWord.length) {
      letterWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            border: Border.all(color: Colors.red, width: borderWidth),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SizedBox(
            width: fontSize * 0.7, // Approximate width of a letter
            height: fontSize * 1.2,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: letterWidgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _handleVerticalDrag,
      onHorizontalDragEnd: _handleHorizontalDrag,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use most of the screen height, leaving space for app bar and some padding
            final cardHeight = constraints.maxHeight * 0.85;
            return Center(
              child: SizedBox(
                height: cardHeight,
                width: double.infinity,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  if (_isFlipped) ...[
                    // ENGLISH SIDE (flipped)
                    Text(
                      widget.word.englishWord,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '(Swipe to flip back)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ] else ...[
                    // HEBREW SIDE (default)
                    Text(
                      widget.word.hebrewWord ?? 'Translating...',
                      style: widget.word.hebrewWord == null || widget.word.hebrewWord!.isEmpty
                          ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.normal,
                              color: Colors.grey,
                            )
                          : Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      textAlign: TextAlign.center,
                      textDirection: widget.word.hebrewWord != null && widget.word.hebrewWord!.isNotEmpty
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                    
                    SizedBox(height: _isCorrect == false ? 20 : 28),
                    
                    // Sound button
                    if (_enriching)
                      const SizedBox(
                        width: 20, height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    else
                      IconButton.filled(
                        icon: const Icon(Icons.volume_up, size: 32),
                        onPressed: (widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty)
                            ? _playSound
                            : null,
                        style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                    
                    SizedBox(height: _isCorrect == false ? 20 : 28),
                    
                    // Text input field
                    TextField(
                      controller: widget.textController,
                      focusNode: widget.focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      enabled: _isCorrect != true, // Disable if correct
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isCorrect == true ? Colors.white : null,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: _isCorrect == true ? 'Correct!' : 'Type the word...',
                        filled: _isCorrect == true,
                        fillColor: _isCorrect == true ? Colors.green : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isCorrect == true 
                                ? Colors.green 
                                : _isCorrect == false 
                                    ? Colors.red 
                                    : Theme.of(context).inputDecorationTheme.border?.borderSide.color ?? Colors.grey,
                            width: _isCorrect != null ? 3 : 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isCorrect == true 
                                ? Colors.green 
                                : _isCorrect == false 
                                    ? Colors.red 
                                    : Colors.grey,
                            width: _isCorrect != null ? 3 : 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isCorrect == true 
                                ? Colors.green 
                                : _isCorrect == false 
                                    ? Colors.red 
                                    : Theme.of(context).colorScheme.primary,
                            width: _isCorrect != null ? 3 : 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), // Only English letters and spaces
                      ],
                      onTap: () {
                        widget.focusNode.requestFocus();
                      },
                      onChanged: (value) {
                        // Reset check state when user types again after checking
                        if (_isCorrect != null && value != _lastCheckedText) {
                          setState(() {
                            _isCorrect = null;
                            _lastCheckedText = null;
                          });
                        }
                      },
                    ),
                    
                    // Show letter-by-letter feedback for incorrect spelling
                    if (_isCorrect == false && _lastCheckedText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, left: 8.0, right: 8.0),
                        child: _buildLetterFeedback(_lastCheckedText!, widget.word.englishWord.toLowerCase()),
                      ),
                    
                    // Success message when correct
                    if (_isCorrect == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Correct!',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: _isCorrect == false ? 12 : 20),
                    
                    // Check button
                    if (!_isFlipped)
                      ElevatedButton.icon(
                        onPressed: (widget.textController.text.trim().isEmpty || _isCorrect == true) 
                            ? null 
                            : _checkSpelling,
                        icon: const Icon(Icons.check),
                        label: const Text('Check'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    
                    // "I know this word" checkbox
                    if (!_isFlipped)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: widget.isKnown,
                              onChanged: (_) => widget.onMarkKnown(),
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
                  ],
                        const SizedBox(height: 12),
                        
                        const Text(
                          'Swipe Up/Down for Next/Prev',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const Text(
                          'Swipe Left/Right to Flip',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
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

