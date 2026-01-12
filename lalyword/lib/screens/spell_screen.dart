import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_providers.dart';
import '../models/word_item.dart';
import '../config/app_theme.dart';

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
  bool? _isCorrect;
  String? _lastCheckedText;
  
  @override
  void initState() {
    super.initState();
    _checkEnrichment();
    widget.textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.focusNode.requestFocus();
      }
    });
  }
  
  void _onTextChanged() {
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
        _isFlipped = false;
        _isCorrect = null;
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
    if (widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty) {
      try {
        await _audioPlayer.play(UrlSource(widget.word.audioUrl!));
        _trackSoundHeard();
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
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _checkSpelling() {
    final typedText = widget.textController.text.trim().toLowerCase();
    final correctWord = widget.word.englishWord.toLowerCase();
    
    if (typedText.isEmpty) {
      return;
    }
    
    setState(() {
      _lastCheckedText = typedText;
      _isCorrect = typedText == correctWord;
      
      if (_isCorrect == true) {
        widget.onMarkKnown();
      }
    });
    
    _trackSpellChecked();
  }
  
  Future<void> _trackSoundHeard() async {
    final notifier = ref.read(sessionProvider.notifier);
    final currentWord = notifier.currentWord;
    
    if (currentWord == null) return;
    
    final storageService = ref.read(storageServiceProvider);
    final allWords = await storageService.getAllWordsWithActivity();
    final storedWord = allWords.firstWhere(
      (w) => w.englishWord.toLowerCase() == currentWord.englishWord.toLowerCase(),
      orElse: () => currentWord,
    );
    
    final currentCount = storedWord.timesHeard;
    final newCount = currentCount + 1;
    
    final updated = currentWord.copyWith(
      timesHeard: newCount,
      timesShown: storedWord.timesShown > currentWord.timesShown ? storedWord.timesShown : currentWord.timesShown,
      timesSpellChecked: storedWord.timesSpellChecked > currentWord.timesSpellChecked ? storedWord.timesSpellChecked : currentWord.timesSpellChecked,
      timesSyllablesShown: storedWord.timesSyllablesShown > currentWord.timesSyllablesShown ? storedWord.timesSyllablesShown : currentWord.timesSyllablesShown,
      timesHebrewShown: storedWord.timesHebrewShown > currentWord.timesHebrewShown ? storedWord.timesHebrewShown : currentWord.timesHebrewShown,
    );
    await storageService.updateWordActivity(updated);
    widget.onEnrich(updated);
  }

  Future<void> _trackSpellChecked() async {
    final notifier = ref.read(sessionProvider.notifier);
    final currentWord = notifier.currentWord;
    
    if (currentWord == null) return;
    
    final storageService = ref.read(storageServiceProvider);
    final allWords = await storageService.getAllWordsWithActivity();
    final storedWord = allWords.firstWhere(
      (w) => w.englishWord.toLowerCase() == currentWord.englishWord.toLowerCase(),
      orElse: () => currentWord,
    );
    
    final currentCount = storedWord.timesSpellChecked;
    final newCount = currentCount + 1;
    
    final updated = currentWord.copyWith(
      timesSpellChecked: newCount,
      timesShown: storedWord.timesShown > currentWord.timesShown ? storedWord.timesShown : currentWord.timesShown,
      timesHeard: storedWord.timesHeard > currentWord.timesHeard ? storedWord.timesHeard : currentWord.timesHeard,
      timesSyllablesShown: storedWord.timesSyllablesShown > currentWord.timesSyllablesShown ? storedWord.timesSyllablesShown : currentWord.timesSyllablesShown,
      timesHebrewShown: storedWord.timesHebrewShown > currentWord.timesHebrewShown ? storedWord.timesHebrewShown : currentWord.timesHebrewShown,
    );
    await storageService.updateWordActivity(updated);
    widget.onEnrich(updated);
  }

  Widget _buildLetterFeedback(String typedText, String correctWord) {
    final List<Widget> letterWidgets = [];
    
    final maxWordLength = correctWord.length > typedText.length ? correctWord.length : typedText.length;
    final fontSize = maxWordLength > 12 ? 12.0 : maxWordLength > 10 ? 13.0 : 14.0;
    final horizontalPadding = maxWordLength > 12 ? 3.0 : maxWordLength > 10 ? 4.0 : 5.0;
    final verticalPadding = maxWordLength > 12 ? 2.0 : maxWordLength > 10 ? 3.0 : 3.0;
    final horizontalMargin = maxWordLength > 12 ? 1.0 : maxWordLength > 10 ? 1.0 : 2.0;
    final borderWidth = maxWordLength > 12 ? 1.0 : maxWordLength > 10 ? 1.5 : 2.0;
    
    for (int i = 0; i < typedText.length; i++) {
      if (i < correctWord.length && typedText[i] == correctWord[i]) {
        letterWidgets.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              border: Border.all(color: AppTheme.primaryGreen, width: borderWidth),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typedText[i],
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      } else {
        letterWidgets.add(
          Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            decoration: BoxDecoration(
              color: AppTheme.studyOrange.withOpacity(0.2),
              border: Border.all(color: AppTheme.studyOrange, width: borderWidth),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typedText[i],
              style: TextStyle(
                color: AppTheme.studyOrange,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ),
        );
      }
    }
    
    if (typedText.length < correctWord.length) {
      letterWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: AppTheme.studyOrange.withOpacity(0.2),
            border: Border.all(color: AppTheme.studyOrange, width: borderWidth),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SizedBox(
            width: fontSize * 0.7,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFlipped) ...[
                                const SizedBox(height: 60),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.word.englishWord.toLowerCase().startsWith('to ') && widget.word.englishWord.length > 3
                                            ? '(to) ${widget.word.englishWord.substring(3)}'
                                            : widget.word.englishWord.toLowerCase().endsWith(' to') && widget.word.englishWord.length > 4
                                                ? '${widget.word.englishWord.substring(0, widget.word.englishWord.length - 3)} {to}'
                                                : widget.word.englishWord,
                                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkGrey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '(Swipe to flip back)',
                                        style: TextStyle(color: AppTheme.softGrey),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 60),
                              ] else ...[
                                const SizedBox(height: 32),
                              Text(
                                widget.word.hebrewWord ?? 'Translating...',
                                style: widget.word.hebrewWord == null || widget.word.hebrewWord!.isEmpty
                                    ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.normal,
                                        color: AppTheme.softGrey,
                                      )
                                    : Theme.of(context).textTheme.displayMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.darkGrey,
                                      ),
                                textAlign: TextAlign.center,
                                textDirection: widget.word.hebrewWord != null && widget.word.hebrewWord!.isNotEmpty
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                              
                              SizedBox(height: _isCorrect == false ? 16 : 20),
                              
                              if (_enriching)
                                const SizedBox(
                                  width: 20, height: 20, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue)
                                )
                              else
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
                                        padding: const EdgeInsets.all(14),
                                        child: const Icon(Icons.volume_up, size: 28, color: AppTheme.pureWhite),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              SizedBox(height: _isCorrect == false ? 16 : 20),
                              
                              TextField(
                                controller: widget.textController,
                                focusNode: widget.focusNode,
                                autofocus: true,
                                textInputAction: TextInputAction.done,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.none,
                                autocorrect: false,
                                enableSuggestions: false,
                                enabled: _isCorrect != true,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _isCorrect == true ? AppTheme.pureWhite : AppTheme.darkGrey,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: _isCorrect == true ? 'Correct!' : 'Type the word...',
                                  filled: _isCorrect == true,
                                  fillColor: _isCorrect == true ? AppTheme.primaryGreen : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _isCorrect == true 
                                          ? AppTheme.primaryGreen 
                                          : _isCorrect == false 
                                              ? AppTheme.studyOrange 
                                              : AppTheme.softGrey,
                                      width: _isCorrect != null ? 3 : 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _isCorrect == true 
                                          ? AppTheme.primaryGreen 
                                          : _isCorrect == false 
                                              ? AppTheme.studyOrange 
                                              : AppTheme.softGrey,
                                      width: _isCorrect != null ? 3 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _isCorrect == true 
                                          ? AppTheme.primaryGreen 
                                          : _isCorrect == false 
                                              ? AppTheme.studyOrange 
                                              : AppTheme.primaryBlue,
                                      width: _isCorrect != null ? 3 : 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                                ],
                                onTap: () {
                                  widget.focusNode.requestFocus();
                                },
                                onChanged: (value) {
                                  if (_isCorrect != null && value != _lastCheckedText) {
                                    setState(() {
                                      _isCorrect = null;
                                      _lastCheckedText = null;
                                    });
                                  }
                                },
                              ),
                              
                              if (_isCorrect == false && _lastCheckedText != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                                  child: _buildLetterFeedback(_lastCheckedText!, widget.word.englishWord.toLowerCase()),
                                ),
                              
                              if (_isCorrect == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                                      SizedBox(width: 6),
                                      Text(
                                        'Correct!',
                                        style: TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              SizedBox(height: _isCorrect == false ? 8 : 12),
                              
                              if (!_isFlipped)
                                AppTheme.gradientButton(
                                  text: 'Check',
                                  onPressed: (widget.textController.text.trim().isEmpty || _isCorrect == true) 
                                      ? null 
                                      : _checkSpelling,
                                  gradient: (widget.textController.text.trim().isEmpty || _isCorrect == true)
                                      ? LinearGradient(colors: [AppTheme.softGrey, AppTheme.softGrey])
                                      : AppTheme.blueGradient,
                                  icon: Icons.check,
                                ),
                              
                              if (!_isFlipped)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: widget.isKnown,
                                        onChanged: (_) => widget.onMarkKnown(),
                                      ),
                                      Text(
                                        'I know this word',
                                        style: widget.isKnown
                                            ? const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)
                                            : const TextStyle(color: AppTheme.darkGrey),
                                      ),
                                      if (widget.isKnown)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8.0),
                                          child: Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                            const SizedBox(height: 24),
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
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Swipe Up/Down for Next/Prev',
                              style: TextStyle(color: AppTheme.softGrey, fontSize: 12),
                            ),
                            const Text(
                              'Swipe Left/Right to Flip',
                              style: TextStyle(color: AppTheme.softGrey, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(Icons.expand_more_rounded, color: AppTheme.softGrey),
                              onPressed: widget.onNext,
                              tooltip: 'Next word',
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 120,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.softGrey),
                          onPressed: () {
                            setState(() {
                              _isFlipped = !_isFlipped;
                            });
                          },
                          tooltip: 'Flip card',
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 120,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.softGrey),
                          onPressed: () {
                            setState(() {
                              _isFlipped = !_isFlipped;
                            });
                          },
                          tooltip: 'Flip card',
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
