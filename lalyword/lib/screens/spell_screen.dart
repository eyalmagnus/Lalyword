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

    final titleText = 'Word ${notifier.currentVisiblePosition} / ${notifier.visibleCount}';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () async {
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
        textController: _textController,
        focusNode: _focusNode,
      ),
    );
  }
}

class SpellContent extends ConsumerStatefulWidget {
  final WordItem word;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Function(WordItem) onEnrich;
  final TextEditingController textController;
  final FocusNode focusNode;

  const SpellContent({
    super.key,
    required this.word,
    required this.onNext,
    required this.onPrev,
    required this.onEnrich,
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

  @override
  void initState() {
    super.initState();
    _checkEnrichment();
    // Request focus after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.focusNode.requestFocus();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: _handleVerticalDrag,
      onHorizontalDragEnd: _handleHorizontalDrag,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: AspectRatio(
          aspectRatio: 0.7,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 20),
                    Text(
                      '(Swipe to flip back)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ] else ...[
                    // HEBREW SIDE (default)
                    Text(
                      widget.word.hebrewWord ?? 'Translating...',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                    
                    const SizedBox(height: 32),
                    
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
                    
                    const SizedBox(height: 32),
                    
                    // Text input field
                    TextField(
                      controller: widget.textController,
                      focusNode: widget.focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.none,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Type the word...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                    ),
                  ],
                  
                  const Spacer(),
                  
                  const Text(
                    'Swipe Up/Down for Next/Prev',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    'Swipe Left/Right to Flip',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

