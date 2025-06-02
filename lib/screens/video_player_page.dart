import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerPage({
    required this.videoUrl,
    super.key,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _webViewController;
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  bool isFullScreen = true;
  bool _showControls = true; // Kontrol düğmelerinin görünürlüğü
  Timer? _hideControlsTimer;

  String videoType = "webview";

  @override
  void initState() {
    super.initState();
    _detectVideoType();
    _enterFullScreen();
    _startHideControlsTimer(); // Kontrol düğmelerini gizlemek için zamanlayıcı başlat

    // Pozisyon değişikliklerini dinlemek için listener ekleyin
    _videoPlayerController?.addListener(() {
      setState(() {}); // Pozisyon değiştiğinde UI'yi güncelle
    });
  }

  void _enterFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  void _detectVideoType() {
    String url = widget.videoUrl;

    if (url.endsWith(".mp4")) {
      videoType = "video_player";
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          setState(() {});
          _videoPlayerController!.play();
        });
    } else if (url.contains("youtube.com") || url.contains("youtu.be")) {
      videoType = "youtube";
      String? videoId = YoutubePlayer.convertUrlToId(url);
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId ?? '',
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
    } else if (url.contains("sibnet")) {
      videoType = "sibnet";
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              _injectSibnetPlayerEnhancements();
              _enterFullScreen();
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    } else {
      videoType = "webview";
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              _injectWebViewEnhancements();
              _enterFullScreen();
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    }
  }

  void _injectSibnetPlayerEnhancements() {
    _webViewController.runJavaScript('''
      const enhancePlayer = () => {
        const player = document.querySelector('.video-js');
        const controlBar = document.querySelector('.vjs-control-bar');
        const progressBar = document.querySelector('.vjs-progress-control');
        const playButton = document.querySelector('.vjs-play-control');
        const volumeControl = document.querySelector('.vjs-volume-panel');
        const fullscreenButton = document.querySelector('.vjs-fullscreen-control');
        const videoElement = document.querySelector('.vjs-tech');
        
        // Add custom styles to head
        const style = document.createElement('style');
        style.textContent = `
          body {
            margin: 0 !important;
            padding: 0 !important;
            background: black !important;
            overflow: hidden !important;
          }
          
          .video-js {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            max-width: none !important;
            max-height: none !important;
          }
          
          .vjs-tech {
            object-fit: fill !important;
            width: 100% !important;
            height: 100% !important;
          }

          /* Control bar düzenlemeleri */
          .vjs-control-bar {
            height: 60px !important;
            display: flex !important;
            align-items: center !important;
            padding: 0 20px !important;
            background: linear-gradient(to top, rgba(0,0,0,0.9), rgba(0,0,0,0.7)) !important;
          }

          /* Progress bar düzenlemeleri */
          .vjs-progress-control {
            position: absolute !important;
            top: -15px !important;
            left: 0 !important;
            width: 100% !important;
            height: 15px !important;
            margin: 0 !important;
          }

          .vjs-progress-holder {
            margin: 0 !important;
            height: 100% !important;
          }

          /* Play button düzenlemesi */
          .vjs-play-control {
            width: 50px !important;
            height: 50px !important;
            margin-right: 15px !important;
          }

          /* Volume control düzenlemesi */
          .vjs-volume-panel {
            display: flex !important;
            align-items: center !important;
            width: 120px !important;
            margin-right: 15px !important;
            order: 2 !important;
          }

          .vjs-volume-control {
            width: 80px !important;
            margin: 0 10px !important;
          }

          /* Time display düzenlemesi */
          .vjs-current-time,
          .vjs-time-divider,
          .vjs-duration {
            display: flex !important;
            align-items: center !important;
            padding: 0 5px !important;
            order: 3 !important;
          }

          /* Fullscreen button düzenlemesi */
          .vjs-fullscreen-control {
            width: 50px !important;
            height: 50px !important;
            margin-left: auto !important;
            order: 4 !important;
          }

          /* Slider düzenlemesi */
          .vjs-slider-horizontal {
            height: 15px !important;
          }

          .vjs-slider-horizontal .vjs-volume-level {
            height: 15px !important;
          }
        `;
        document.head.appendChild(style);
        
        if (player) {
          player.style.width = '100vw';
          player.style.height = '100vh';
          player.style.position = 'fixed';
          player.style.top = '0';
          player.style.left = '0';
        }

        if (videoElement) {
          videoElement.style.objectFit = 'fill';
          videoElement.style.width = '100%';
          videoElement.style.height = '100%';
        }

        if (controlBar) {
          controlBar.style.display = 'flex';
          controlBar.style.alignItems = 'center';
          controlBar.style.height = '60px';
          controlBar.style.padding = '0 20px';
        }

        if (progressBar) {
          progressBar.style.position = 'absolute';
          progressBar.style.top = '-15px';
          progressBar.style.left = '0';
          progressBar.style.width = '100%';
          progressBar.style.height = '15px';
          progressBar.style.margin = '0';
        }

        // Rearrange control elements
        const controls = controlBar?.children;
        if (controls) {
          Array.from(controls).forEach(control => {
            if (control.classList.contains('vjs-volume-panel')) {
              control.style.order = '2';
            } else if (control.classList.contains('vjs-time-control')) {
              control.style.order = '3';
            } else if (control.classList.contains('vjs-fullscreen-control')) {
              control.style.order = '4';
            }
          });
        }

        if (playButton) {
          playButton.style.fontSize = '1.6em';
          playButton.style.width = '55px';
          playButton.style.marginBottom = '15px';
        }

        if (volumeControl) {
          volumeControl.style.fontSize = '1.6em';
          volumeControl.style.width = '80px';
          volumeControl.style.marginBottom = '15px';
        }

        if (fullscreenButton) {
          fullscreenButton.style.fontSize = '1.3em';
          fullscreenButton.style.width = '45px';
          fullscreenButton.style.marginBottom = '15px';
        }
        
        // Hide unwanted elements
        const unwantedElements = document.querySelectorAll('.ad-container, .banner, .promo, #vjs-logobrand-image, .vjs-logobrand-button, .vjs-share-button, .vjs-related-carousel-button, .vjs-loading-spinner, .vjs-big-play-button');
        unwantedElements.forEach(el => el.style.display = 'none');
      };

      enhancePlayer();
      setInterval(enhancePlayer, 1000);
    ''');
  }

  void _injectWebViewEnhancements() {
  _webViewController.runJavaScript('''
    (function() {
      const video = document.querySelector('video');
      if (video) {
        video.play();
        video.requestFullscreen().catch(e => console.log('Fullscreen error:', e));
      }
    })();
  ''');
}


  void toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
    });

    if (isFullScreen) {
      _enterFullScreen();
    } else {
      exitFullScreen();
    }
  }

  void exitFullScreen() {
    setState(() {
      isFullScreen = false;
    });

    _exitFullScreen();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _showControls = false;
      });
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget;

    if (videoType == "youtube" && _youtubeController != null) {
      videoWidget = SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: YoutubePlayer(
          controller: _youtubeController!,
          aspectRatio: MediaQuery.of(context).size.aspectRatio,
        ),
      );
    } else if (videoType == "video_player" && _videoPlayerController != null) {
      videoWidget = SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _toggleControlsVisibility,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoPlayerController!.value.size.width,
                  height: _videoPlayerController!.value.size.height,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            ),
            if (_showControls) _buildVideoControls(),
          ],
        ),
      );
    } else if (videoType == "sibnet") {
      videoWidget = SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: WebViewWidget(controller: _webViewController),
      );
    } else {
      videoWidget = SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: WebViewWidget(controller: _webViewController),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          exitFullScreen();
          return true;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: videoWidget,
            ),
            if (isFullScreen)
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Süre göstergesi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // İzlenme süresi
                  Text(
                    _formatDuration(_videoPlayerController!.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  // Toplam süre
                  Text(
                    _formatDuration(_videoPlayerController!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), // Süre göstergesi ile ilerleme çubuğu arasında boşluk
            // İlerleme göstergesi
            VideoProgressIndicator(
              _videoPlayerController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 10), // İlerleme göstergesi ile butonlar arasında boşluk
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Geri sarma butonu
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 40),
                  onPressed: () {
                    final currentPosition = _videoPlayerController!.value.position;
                    _videoPlayerController!.seekTo(
                      Duration(seconds: currentPosition.inSeconds - 10),
                    );
                  },
                ),
                const SizedBox(width: 20), // Butonlar arasında boşluk
                // Oynatma/Duraklatma butonu
                IconButton(
                  icon: Icon(
                    _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoPlayerController!.value.isPlaying) {
                        _videoPlayerController!.pause();
                      } else {
                        _videoPlayerController!.play();
                      }
                    });
                  },
                ),
                const SizedBox(width: 20), // Butonlar arasında boşluk
                // İleri sarma butonu
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 40),
                  onPressed: () {
                    final currentPosition = _videoPlayerController!.value.position;
                    _videoPlayerController!.seekTo(
                      Duration(seconds: currentPosition.inSeconds + 10),
                    );
                  },
                ),
                const SizedBox(width: 20), // Butonlar arasında boşluk
                // Tam ekran butonu
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 40),
                  onPressed: toggleFullScreen,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  @override
  void dispose() {
    _exitFullScreen(); // Sayfa kapandığında normal moda dön
    _youtubeController?.dispose();
    _videoPlayerController?.removeListener(() {}); // Listener'ı kaldır
    _videoPlayerController?.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }
}