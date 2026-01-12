import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'flashcard_screen.dart';
import 'spell_screen.dart';

class VideoTransitionScreen extends StatefulWidget {
  final String targetScreen; // 'flashcard' or 'spell'
  
  const VideoTransitionScreen({
    super.key,
    required this.targetScreen,
  });

  @override
  State<VideoTransitionScreen> createState() => _VideoTransitionScreenState();
}

class _VideoTransitionScreenState extends State<VideoTransitionScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _hasNavigated = false;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/funnylaly.mp4');
      await controller.initialize();
      _controller = controller;
      
      if (mounted) {
        // Set looping to false
        await _controller!.setLooping(false);
        
        setState(() {
          _isInitialized = true;
        });
        
        await _controller!.play();
        
        // Start periodic check for video completion
        _startCompletionCheck();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        // Navigate immediately on error
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasNavigated) {
            _hasNavigated = true;
            _navigateToTarget();
          }
        });
      }
    }
  }

  void _startCompletionCheck() {
    _completionTimer?.cancel();
    _completionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_hasNavigated || _controller == null || !mounted) {
        timer.cancel();
        return;
      }
      
      final value = _controller!.value;
      
      // Check if video has completed
      if (value.duration.inMilliseconds > 0) {
        final positionMs = value.position.inMilliseconds;
        final durationMs = value.duration.inMilliseconds;
        
        print('Transition video position: $positionMs / $durationMs');
        
        // Video is complete if position is at or past duration
        if (positionMs >= durationMs - 50) {
          print('Transition video completed! Navigating...');
          timer.cancel();
          _hasNavigated = true;
          _navigateToTarget();
        }
      }
    });
    
    // Fallback: navigate after video duration + buffer
    final duration = _controller!.value.duration;
    print('Transition video duration: ${duration.inMilliseconds}ms');
    if (duration.inMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: duration.inMilliseconds + 1000), () {
        print('Fallback timer triggered. Has navigated: $_hasNavigated, mounted: $mounted');
        if (mounted && !_hasNavigated) {
          _completionTimer?.cancel();
          _hasNavigated = true;
          _navigateToTarget();
        }
      });
    }
  }

  void _skipVideo() {
    if (_hasNavigated || !mounted) {
      return;
    }
    _hasNavigated = true;
    _completionTimer?.cancel();
    _controller?.pause();
    _navigateToTarget();
  }

  void _navigateToTarget() {
    print('_navigateToTarget called. Has navigated: $_hasNavigated, mounted: $mounted');
    if (!mounted) {
      print('Not mounted, skipping navigation');
      return;
    }
    Widget targetWidget;
    if (widget.targetScreen == 'spell') {
      targetWidget = const SpellScreen();
    } else {
      targetWidget = const FlashcardScreen();
    }
    
    print('Navigating to ${widget.targetScreen} screen...');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetWidget),
    );
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _skipVideo,
        child: Center(
          child: _hasError
              ? const Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white),
                )
              : _isInitialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : const CircularProgressIndicator(
                      color: Colors.white,
                    ),
        ),
      ),
    );
  }
}

