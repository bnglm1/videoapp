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

  // Yeni: Ekran oranı
  double _aspectRatio = 16 / 9; // Varsayılan
  final Map<String, double> _aspectRatios = {
    '16:9 (Standart)': 16 / 9,
    '21:9 (Sinema)': 21 / 9,
    '4:3 (Eski TV)': 4 / 3,
    '1:1 (Kare)': 1.0,
    'Tam Ekran': -1, // Özel: BoxFit.cover ile tam ekran
  };

  @override
  void initState() {
    super.initState();
    _loadAspectRatio(); // Kayıtlı oranı yükle
    _setupFullScreen();
    _determinePlayerType();
    _initializePlayer();
  }

  // Kayıtlı oranı yükle
  Future<void> _loadAspectRatio() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRatio = prefs.getDouble('aspect_ratio') ?? (16 / 9);
    if (mounted) {
      setState(() {
        _aspectRatio = savedRatio;
      });
    }
  }

  // Oranı kaydet
  Future<void> _saveAspectRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('aspect_ratio', ratio);
  }

  void _showAspectRatioMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Ekran Oranı',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _aspectRatios.entries
                .map(
                  (entry) => RadioListTile<double>(
                    title: Text(
                      entry.key,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: entry.value,
                    groupValue: _aspectRatio,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _aspectRatio = value;
                        });
                        _saveAspectRatio(value);
                        Navigator.pop(context);
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exitFullScreen();
    _hideControlsTimer?.cancel();

    // Pozisyonu kaydet
    if (_videoController != null && _videoController!.value.isInitialized) {
      _savePositionInBackground();
    }

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
    } else {
      _hideControlsTimer?.cancel();
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
        onPopInvokedWithResult: (didPop, result) => _exitFullScreen(),
        child: Stack(
          children: [
            // 1. ANA İÇERİK (Video)
            _buildMainContent(),

            // 2. GESTURE DETECTOR: Tüm ekranı kaplasın
            if (!_useWebView)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),

            // 3. WEBVIEW İÇİN GESTURE DETECTOR: Video alanını hariç tut
            if (_useWebView) _buildWebViewGestureDetector(),

            // 3. VİDEO KONTROLLERİ (En altta olacak)
            if (!_useWebView && _showControls) _buildVideoControls(),

            // 4. ÜST BUTONLAR (Video kontrollerinin üstünde olacak)
            if (_showControls) ...[
              // Geri Butonu
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ),

              // Ayar Butonu
              Positioned(
                top: 40,
                right: 16,
                child: SafeArea(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _showAspectRatioMenu,
                        tooltip: 'Ekran Oranı',
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // 5. WEBVIEW KONTROLLERİ (Sadece WebView için, ayarı sağ tarafta tutmak için)
            if (_useWebView && _showControls) _buildWebViewExtraControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewGestureDetector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // WebView'ın boyutlarını hesapla
        double videoWidth = constraints.maxWidth;
        double videoHeight =
            videoWidth / (_aspectRatio > 0 ? _aspectRatio : 16 / 9);

        if (videoHeight > constraints.maxHeight) {
          videoHeight = constraints.maxHeight;
          videoWidth = videoHeight * (_aspectRatio > 0 ? _aspectRatio : 16 / 9);
        }

        // Video merkezi hesapla
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final videoLeft = centerX - (videoWidth / 2);
        final videoTop = centerY - (videoHeight / 2);
        final videoRight = centerX + (videoWidth / 2);
        final videoBottom = centerY + (videoHeight / 2);

        return Stack(
          children: [
            // Sol alan
            if (videoLeft > 0)
              Positioned(
                left: 0,
                top: 0,
                width: videoLeft,
                height: constraints.maxHeight,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Sağ alan
            if (videoRight < constraints.maxWidth)
              Positioned(
                left: videoRight,
                top: 0,
                width: constraints.maxWidth - videoRight,
                height: constraints.maxHeight,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Üst alan
            if (videoTop > 0)
              Positioned(
                left: videoLeft,
                top: 0,
                width: videoWidth,
                height: videoTop,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Alt alan
            if (videoBottom < constraints.maxHeight)
              Positioned(
                left: videoLeft,
                top: videoBottom,
                width: videoWidth,
                height: constraints.maxHeight - videoBottom,
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        );
      },
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
      return const Center(child: Text('WebView başlatılamadı'));
    }

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double height = width / (_aspectRatio > 0 ? _aspectRatio : 16 / 9);

          if (height > constraints.maxHeight) {
            height = constraints.maxHeight;
            width = height * (_aspectRatio > 0 ? _aspectRatio : 16 / 9);
          }

          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // WebView
                Positioned.fill(
                  child: WebViewWidget(
                    key: _webViewKey,
                    controller: _webViewController!,
                  ),
                ),

                // Loading overlay
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.red),
                            SizedBox(height: 16),
                            Text('Yükleniyor...',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNativeVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final videoAspectRatio = _videoController!.value.aspectRatio;
          double width = constraints.maxWidth * 0.95;
          double height =
              width / (_aspectRatio > 0 ? _aspectRatio : videoAspectRatio);

          if (height > constraints.maxHeight * 0.95) {
            height = constraints.maxHeight * 0.95;
            width =
                height * (_aspectRatio > 0 ? _aspectRatio : videoAspectRatio);
          }

          return SizedBox(
            width: width,
            height: height,
            child: Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: videoAspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video progress
            VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),

            const SizedBox(height: 8),

            // Zaman bilgisi
            Row(
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

            const SizedBox(height: 16),

            // Kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    onPressed: _seekBackward,
                    icon: const Icon(Icons.replay_10,
                        color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(width: 20),
                Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
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
                ),
                const SizedBox(width: 20),
                Material(
                  color: Colors.transparent,
                  child: IconButton(
                    onPressed: _seekForward,
                    icon: const Icon(Icons.forward_10,
                        color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewExtraControls() {
    return Positioned(
      top: 40,
      right: 80, // Ayar butonunun solunda
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
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
        ),
      ),
    );
  }
}
