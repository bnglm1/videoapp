import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final bool? useWebView;
  final Duration? initialPosition;

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

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  // WebView ve Video Player kontrolleri
  WebViewController? _webViewController;
  VideoPlayerController? _videoController;

  // UI State
  bool _isLoading = true;
  bool _useWebView = false;
  bool _showControls = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isBuffering = false;

  // Video kontrolleri
  Timer? _hideControlsTimer;
  Timer? _positionSaveTimer;
  Key _webViewKey = const ValueKey('webview_0');

  // Ekran oranı ve hız kontrolleri
  double _aspectRatio = 16 / 9;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.5;

  final Map<String, double> _aspectRatios = {
    '16:9 (Standart)': 16 / 9,
    '21:9 (Sinema)': 21 / 9,
    '4:3 (Eski TV)': 4 / 3,
    '1:1 (Kare)': 1.0,
    'Tam Ekran': -1,
  };

  final List<double> _playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _setupFullScreen();
    _determinePlayerType();
    _initializePlayer();
    _startPositionSaveTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _savePositionInBackground();
      if (_videoController != null && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  // Tüm ayarları yükle
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _aspectRatio = prefs.getDouble('aspect_ratio') ?? (16 / 9);
        _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
        _volume = prefs.getDouble('volume') ?? 1.0;
        _brightness = prefs.getDouble('brightness') ?? 0.5;
      });
    }
  }

  // Pozisyon kaydetme timer'ı
  void _startPositionSaveTimer() {
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _saveCurrentPosition();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exitFullScreen();
    _hideControlsTimer?.cancel();
    _positionSaveTimer?.cancel();

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
    if (urlLower.endsWith('.mp4') ||
        urlLower.endsWith('.mkv') ||
        urlLower.endsWith('.avi') ||
        urlLower.endsWith('.mov') ||
        urlLower.endsWith('.m4v')) {
      _useWebView = false;
    } else {
      _useWebView = true;
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
      _webViewKey = ValueKey('webview_${widget.videoUrl.hashCode}');
    });

    String htmlContent = _generateHtmlContent();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36')
      ..addJavaScriptChannel(
        'flutter_inappwebview',
        onMessageReceived: (JavaScriptMessage message) async {
          if (message.message == 'videoReady') {
            if (widget.initialPosition != null &&
                widget.initialPosition!.inMilliseconds > 0) {
              await _webViewController!.runJavaScript(
                  'seekTo(${widget.initialPosition!.inSeconds});');
            }
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              await _webViewController!.runJavaScript('playVideo();');
              setState(() {
                _isLoading = false;
              });
            }
          }
        },
      )
      ..loadHtmlString(htmlContent);
  }

  String _generateHtmlContent() {
    if (widget.videoUrl.contains('youtube.com') ||
        widget.videoUrl.contains('youtu.be')) {
      final videoId = _extractYouTubeId(widget.videoUrl);
      if (videoId != null) {
        return _generateYouTubeHtml(videoId);
      }
    }
    return _generateGenericHtml();
  }

  String _generateYouTubeHtml(String videoId) {
    return '''
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
        src="https://www.youtube.com/embed/$videoId?enablejsapi=1&controls=0&showinfo=0&rel=0&modestbranding=1&playsinline=1" 
        allow="encrypted-media; fullscreen; picture-in-picture" 
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
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('videoReady');
          }
        }

        function onPlayerStateChange(event) {
          // Handle state changes if needed
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

  String _generateGenericHtml() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
      <style>
        body, html { margin: 0; padding: 0; overflow: hidden; background: #000; }
        iframe, video { 
          position: absolute; 
          top: 0; left: 0; width: 100%; height: 100%; 
          border: none; 
        }
      </style>
    </head>
    <body>
      <iframe 
        id="videoPlayer" 
        src="${widget.videoUrl}" 
        allow="encrypted-media; fullscreen; picture-in-picture" 
        allowfullscreen>
      </iframe>
      <script>
        function playVideo() {
          var videoElement = document.querySelector('video');
          if (videoElement) videoElement.play();
        }

        function pauseVideo() {
          var videoElement = document.querySelector('video');
          if (videoElement) videoElement.pause();
        }

        function seekTo(seconds) {
          var videoElement = document.querySelector('video');
          if (videoElement) videoElement.currentTime = seconds;
        }

        setTimeout(function() {
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('videoReady');
          }
        }, 1000);
      </script>
    </body>
    </html>
    ''';
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _initializeVideoPlayer() async {
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    // Video controller listener - play/pause buton durumunu doğru takip etsin
    _videoController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    await _videoController!.initialize();
    await _videoController!.setVolume(_volume);

    if (widget.initialPosition != null &&
        widget.initialPosition!.inMilliseconds > 0) {
      await _videoController!.seekTo(widget.initialPosition!);
    }

    await _videoController!.play();
    setState(() {});
  }

  void _saveCurrentPosition() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(
          'video_position_${widget.videoTitle}',
          _videoController!.value.position.inMilliseconds,
        );
      });
    }
  }

  // Ayarlar menüleri - Geri eklendi
  void _showAspectRatioMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekran Oranı', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _aspectRatios.entries
                .map((entry) => RadioListTile<double>(
                      title: Text(entry.key,
                          style: const TextStyle(color: Colors.white)),
                      value: entry.value,
                      groupValue: _aspectRatio,
                      activeColor: Colors.blueAccent,
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() => _aspectRatio = value);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble('aspect_ratio', value);
                          Navigator.pop(context);
                        }
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title:
              const Text('Oynatma Hızı', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.grey[900],
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _playbackSpeeds
                  .map((speed) => RadioListTile<double>(
                        title: Text('${speed}x',
                            style: const TextStyle(color: Colors.white)),
                        value: speed,
                        groupValue: _playbackSpeed,
                        activeColor: Colors.blueAccent,
                        onChanged: (value) async {
                          if (value != null && _videoController != null) {
                            await _videoController!.setPlaybackSpeed(value);
                            setState(() => _playbackSpeed = value);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('playback_speed', value);
                            Navigator.pop(context);
                          }
                        },
                      ))
                  .toList(),
            ),
          )),
    );
  }

  void _showVolumeSlider() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Ses Seviyesi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_volume * 100).round()}%',
                activeColor: Colors.blueAccent,
                onChanged: (value) async {
                  setDialogState(() => _volume = value);
                  setState(() => _volume = value);
                  if (_videoController != null) {
                    await _videoController!.setVolume(value);
                  }
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('volume', value);
                },
              ),
              Text('${(_volume * 100).round()}%',
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
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
      setState(() => _showControls = true);
      _startHideControlsTimer();
    }
  }

  void _seekBackward() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final newPosition = currentPosition - const Duration(seconds: 5);
      _videoController!
          .seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
      setState(() => _showControls = true);
      _startHideControlsTimer();
    }
  }

  void _seekForward() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final currentPosition = _videoController!.value.position;
      final duration = _videoController!.value.duration;
      final newPosition = currentPosition + const Duration(seconds: 5);
      _videoController!.seekTo(newPosition < duration ? newPosition : duration);
      setState(() => _showControls = true);
      _startHideControlsTimer();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) => _exitFullScreen(),
        child: Stack(
          children: [
            _buildMainContent(),
            if (!_useWebView)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            if (_useWebView) _buildWebViewGestureDetector(),
            if (!_useWebView && _showControls) _buildVideoControls(),
            if (_showControls) ...[
              Positioned(
                top: 40,
                left: 16,
                child: SafeArea(
                  child: Container(
                    child: IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
            // Loading indicator sadece gerçekten gerekli olduğunda göster
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewGestureDetector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double videoWidth = constraints.maxWidth;
        double videoHeight =
            videoWidth / (_aspectRatio > 0 ? _aspectRatio : 16 / 9);

        if (videoHeight > constraints.maxHeight) {
          videoHeight = constraints.maxHeight;
          videoWidth = videoHeight * (_aspectRatio > 0 ? _aspectRatio : 16 / 9);
        }

        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final videoLeft = centerX - (videoWidth / 2);
        final videoTop = centerY - (videoHeight / 2);
        final videoRight = centerX + (videoWidth / 2);
        final videoBottom = centerY + (videoHeight / 2);

        return Stack(
          children: [
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
            CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 1),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Video Yüklenemedi',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePlayer,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return _useWebView ? _buildWebViewPlayer() : _buildNativeVideoPlayer();
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
                Positioned.fill(
                  child: WebViewWidget(
                    key: _webViewKey,
                    controller: _webViewController!,
                  ),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.blueAccent),
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
      return const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent));
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
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Oynatma / ileri / geri sarma butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _seekBackward,
                  icon: const Icon(Icons.replay_5_outlined,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _togglePlayPause,
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause_outlined
                        : Icons.play_arrow_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _seekForward,
                  icon: const Icon(Icons.forward_5_outlined,
                      color: Colors.white, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Video ilerleme çubuğu
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blueAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.blueAccent,
                trackHeight: 0.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _videoController?.value.position.inMilliseconds
                        .toDouble() ??
                    0,
                max: _videoController?.value.duration.inMilliseconds
                        .toDouble() ??
                    1,
                onChanged: (value) {
                  if (_videoController != null &&
                      _videoController!.value.isInitialized) {
                    _videoController!
                        .seekTo(Duration(milliseconds: value.toInt()));
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Diğer butonlar ve süreler
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_videoController!.value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ekran Oranı Butonu
                    IconButton(
                      onPressed: _showAspectRatioMenu,
                      icon: const Icon(Icons.aspect_ratio_outlined,
                          color: Colors.white, size: 20),
                      tooltip: 'Ekran Oranı',
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 12),

                    // Oynatma Hızı Butonu ve Ses Butonu (sadece native player)
                    if (!_useWebView) ...[
                      InkWell(
                        onTap: _showSpeedMenu,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _showVolumeSlider,
                        icon: Icon(
                          _volume > 0
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Ses Seviyesi',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ],
                ),
                Text(
                  _formatDuration(_videoController!.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
