// ...existing code...
import 'dart:async';
// ignore_for_file: avoid_print, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final bool? useWebView;
  final Duration? initialPosition; // Yeni eklendi

  const VideoPlayerPage({
    required this.videoUrl,
    this.videoTitle = '',
    this.useWebView,
    this.initialPosition,
    super.key,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // WebView ve Video Player kontrolleri
  WebViewController? _webViewController;
  VideoPlayerController? _videoController;

  // UI State
  bool _isLoading = true;
  bool _useWebView = false;
  bool _showControls = true;
  bool _hasError = false;
  String _errorMessage = '';

  // Video kontrolleri
  Timer? _hideControlsTimer;

  Key _webViewKey = const ValueKey('webview_0'); // EKLENDİ

  @override
  void initState() {
    super.initState();
    _setupFullScreen();
    _determinePlayerType();
    _initializePlayer();
  }

  @override
  void dispose() {
    _exitFullScreen();
    _hideControlsTimer?.cancel();

    // Pozisyonu arka planda kaydet
    _savePositionInBackground();

    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _savePositionInBackground() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'video_position_${widget.videoTitle}',
        _videoController!.value.position.inMilliseconds,
      );
    }
  }

  void _setupFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _determinePlayerType() {
    final urlLower = widget.videoUrl.toLowerCase();
    // Kural: Sadece mp4 ise native, değilse webview
    if (urlLower.endsWith('.mp4')) {
      _useWebView = false;
      print('Native video player selected for: ${widget.videoUrl}');
    } else {
      _useWebView = true;
      print('WebView player selected for: ${widget.videoUrl}');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      if (_useWebView) {
        await _initializeWebView();
      } else {
        await _initializeVideoPlayer();
      }

      setState(() {
        _isLoading = false;
      });

      _startHideControlsTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Video yüklenirken hata oluştu: $e';
      });
    }
  }

  Future<void> _initializeWebView() async {
    setState(() {
      // Her yeni video için key değiştir
      _webViewKey = ValueKey('webview_${widget.videoUrl.hashCode}');
    });

    // WebView'e yüklenecek HTML içeriği
    String htmlContent = ''';
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
      <style>
        body, html { margin: 0; padding: 0; overflow: hidden; background: #000; }
        iframe { 
          position: absolute; 
          top: 0; left: 0; width: 100%; height: 100%; 
          border: none; 
        }
      </style>
    </head>
    <body>
      <iframe 
        id="videoPlayer" 
        src="${widget.videoUrl}${widget.videoUrl.contains('?') ? '&' : '?'}controls=0&showinfo=0&rel=0" 
        allow="encrypted-media;" 
        allowfullscreen>
      </iframe>
      <script>
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('videoPlayer', {
            events: {
              'onReady': onPlayerReady,
              'onStateChange': onPlayerStateChange
            }
          });
        }

        function onPlayerReady(event) {
          window.flutter_inappwebview.callHandler('videoReady');
        }

        function onPlayerStateChange(event) {
          // Implement state change handling if needed
        }

        function playVideo() {
          if (player && typeof player.playVideo === 'function') {
            player.playVideo();
          } else {
            var videoElement = document.querySelector('video');
            if (videoElement) videoElement.play();
          }
        }

        function pauseVideo() {
          if (player && typeof player.pauseVideo === 'function') {
            player.pauseVideo();
          } else {
            var videoElement = document.querySelector('video');
            if (videoElement) videoElement.pause();
          }
        }

        function seekTo(seconds) {
          if (player && typeof player.seekTo === 'function') {
            player.seekTo(seconds, true);
          } else {
            var videoElement = document.querySelector('video');
            if (videoElement) videoElement.currentTime = seconds;
          }
        }
      </script>
    </body>
    </html>
  ''';

    if (widget.videoUrl.contains('youtube.com') ||
        widget.videoUrl.contains('youtu.be')) {
      final videoId = _extractYouTubeId(widget.videoUrl);
      if (videoId != null) {
        htmlContent = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
          <style>
            body, html { margin: 0; padding: 0; overflow: hidden; background: #000; }
            iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; }
          </style>
        </head>
        <body>
          <iframe 
            id="videoPlayer" 
            src="https://www.youtube.com/embed/$videoId?enablejsapi=1&controls=0&showinfo=0&rel=0" 
            allow="encrypted-media;" 
            allowfullscreen>
          </iframe>
          <script src="https://www.youtube.com/iframe_api"></script>
          <script>
            var player;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('videoPlayer', {
                events: {
                  'onReady': onPlayerReady,
                  'onStateChange': onPlayerStateChange
                }
              });
            }

            function onPlayerReady(event) {
              window.flutter_inappwebview.callHandler('videoReady');
            }

            function onPlayerStateChange(event) {
              // Implement state change handling if needed
            }

            function playVideo() {
              if (player && typeof player.playVideo === 'function') {
                player.playVideo();
              }
            }

            function pauseVideo() {
              if (player && typeof player.pauseVideo === 'function') {
                player.pauseVideo();
              }
            }

            function seekTo(seconds) {
              if (player && typeof player.seekTo === 'function') {
                player.seekTo(seconds, true);
              }
            }
          </script>
        </body>
        </html>
      ''';
      }
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'flutter_inappwebview',
        onMessageReceived: (JavaScriptMessage message) async {
          if (message.message == 'videoReady') {
            print('VideoPlayerPage: WebView video ready.');
            // Apply initial position if available
            if (widget.initialPosition != null &&
                widget.initialPosition!.inMilliseconds > 0) {
              await _webViewController!.runJavaScript(
                  'seekTo(${widget.initialPosition!.inSeconds});');
              print(
                  'VideoPlayerPage: WebView video seeked to ${widget.initialPosition!.inSeconds}s');
            }
            // Play with a delay for smoother transition
            await Future.delayed(const Duration(seconds: 1)); // 1 second delay
            if (mounted) {
              await _webViewController!.runJavaScript('playVideo();');
              setState(() {
                _isLoading = false; // Video started, hide loading
              });
              print('VideoPlayerPage: WebView video started playing.');
            }
          }
        },
      )
      ..loadHtmlString(htmlContent);
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  // Stub for missing method to fix compile error
  Future<void> _initializeVideoPlayer() async {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoController!.initialize();

    // initialPosition varsa, oraya git
    if (widget.initialPosition != null &&
        widget.initialPosition!.inMilliseconds > 0) {
      await _videoController!.seekTo(widget.initialPosition!);
    }

    // Oynat
    await _videoController!.play();

    // Pozisyonu her saniye kaydet
    _videoController!.addListener(() {
      _saveCurrentPosition();
    });

    setState(() {});
  }

// Sadece pozisyonu kaydet, async olmayan versiyon
  void _saveCurrentPosition() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final prefs = SharedPreferences.getInstance();
      prefs.then((value) {
        value.setInt(
          'video_position_${widget.videoTitle}',
          _videoController!.value.position.inMilliseconds,
        );
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() {});
    }
  }

  void _seekBackward() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final newPosition = currentPosition - const Duration(seconds: 10);
      _videoController!
          .seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
    }
  }

  void _seekForward() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final duration = _videoController!.value.duration;
      final newPosition = currentPosition + const Duration(seconds: 10);
      _videoController!.seekTo(newPosition < duration ? newPosition : duration);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          _exitFullScreen();
        },
        child: Stack(
          children: [
            // Ana video/webview widget
            Positioned.fill(
              child: _buildMainContent(),
            ),

            // Geri butonu (her zaman görünür)
            Positioned(
              top: 40,
              left: 16,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            // Kontroller (sadece native video için)
            if (!_useWebView && _showControls) _buildVideoControls(),

            // WebView kontrolleri
            if (_useWebView && _showControls) _buildWebViewControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.red,
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Video yükleniyor...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Video Yüklenemedi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _initializePlayer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_useWebView) {
      return _buildWebViewPlayer();
    } else {
      return _buildNativeVideoPlayer();
    }
  }

  Widget _buildWebViewPlayer() {
    if (_webViewController == null) {
      return const Center(
        child: Text(
          'WebView başlatılamadı',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // WebView
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleControls,
              child: WebViewWidget(
                key: _webViewKey,
                controller:
                    _webViewController!, // Use the initialized controller
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Video yükleniyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNativeVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Video progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Zaman bilgisi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_videoController!.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    _formatDuration(_videoController!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _seekBackward,
                  icon: const Icon(Icons.replay_10,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _seekForward,
                  icon: const Icon(Icons.forward_10,
                      color: Colors.white, size: 32),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewControls() {
    return Positioned(
      top: 40,
      right: 16,
      child: SafeArea(
        child: Row(
          children: [
            // Reload button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _webViewController?.reload();
                },
                tooltip: 'Yenile',
              ),
            ),
            const SizedBox(width: 8),
            // Fullscreen toggle (no JavaScript, just placeholder)
            /*
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: () {
                  // Optionally implement fullscreen for WebView if possible
                },
                tooltip: 'Tam Ekran',
              ),
            ),
            const SizedBox(width: 8),
            */
            // Close button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Kapat',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
