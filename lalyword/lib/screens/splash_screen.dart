import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'list_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
      final controller = VideoPlayerController.asset('assets/intro.mp4');
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
      print('Error initializing splash video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        // Navigate immediately on error after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasNavigated) {
            _hasNavigated = true;
            _navigateToHome();
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
        
        print('Video position: $positionMs / $durationMs');
        
        // Video is complete if position is at or past duration
        if (positionMs >= durationMs - 50) {
          print('Video completed! Navigating...');
          timer.cancel();
          _hasNavigated = true;
          _navigateToHome();
        }
      }
    });
    
    // Fallback: navigate after video duration + buffer
    final duration = _controller!.value.duration;
    print('Video duration: ${duration.inMilliseconds}ms');
    if (duration.inMilliseconds > 0) {
      Future.delayed(Duration(milliseconds: duration.inMilliseconds + 1000), () {
        print('Fallback timer triggered. Has navigated: $_hasNavigated, mounted: $mounted');
        if (mounted && !_hasNavigated) {
          _completionTimer?.cancel();
          _hasNavigated = true;
          _navigateToHome();
        }
      });
    }
  }

  void _navigateToHome() {
    print('_navigateToHome called. Has navigated: $_hasNavigated, mounted: $mounted');
    if (!mounted) {
      print('Not mounted, skipping navigation');
      return;
    }
    print('Navigating to ListSelectionScreen...');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ListSelectionScreen()),
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
      body: Center(
        child: _hasError
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
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
    );
  }
}

