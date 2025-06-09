import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const VideoPlayerPage({
    required this.videoUrl,
    this.videoTitle = '',
    super.key,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // Reklam değişkenlerini kaldırın veya devre dışı bırakın
  // InterstitialAd? _interstitialAd;
  // bool _isAdLoaded = false;
  bool _videoStarted = false;
  bool _isLoading = true;
  
  // Video oynatıcı değişkenleri
  late WebViewController _webViewController;
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  bool isFullScreen = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  String videoType = "webview";
  Timer? _watchHistoryTimer;
  String videoId = '';
  String videoTitle = '';

  @override
  void initState() {
    super.initState();
    
    // Video bilgilerini ayarla
    videoId = widget.videoUrl.hashCode.toString();
    videoTitle = widget.videoTitle.isNotEmpty 
        ? widget.videoTitle 
        : 'Video ${videoId.substring(0, min(videoId.length, 6))}';
    
    // Ekran ayarları
    _enterFullScreen();
    _startHideControlsTimer();
    
    // Video tipini belirle ama HENÜZ YÜKLEME YAPMA
    _detectVideoTypeWithoutLoading();
    
    // 2 saniye sonra yüklemeyi göster
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false; // Yükleme tamamlandı
        });
        
        // Şimdi videoyu başlat
        _loadAndStartVideo();
      }
    });
  }

  // Video tipini belirleyen ancak hemen URL yüklemeyen yöntem
  void _detectVideoTypeWithoutLoading() {
    String url = widget.videoUrl;

    if (url.endsWith(".mp4")) {
      // Doğrudan MP4 video
      videoType = "video_player";
      // VideoController başlat ama initialize etme
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else if (url.contains("youtube.com") || url.contains("youtu.be")) {
      // YouTube videosu
      videoType = "youtube";
      String? videoId = YoutubePlayer.convertUrlToId(url);
      
      if (videoId != null) {
        this.videoId = videoId;
        // YouTube Controller'ı başlat ama otomatik oynatmaz
      }
    } else if (url.contains("sibnet")) {
      // Sibnet videosu
      videoType = "sibnet";
      // WebViewController oluştur ama URL'yi yükleme
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              _injectSibnetPlayerEnhancements();
            },
          ),
        );
        // URL yükleme şimdilik yapılmıyor
    } else {
      // Diğer web videoları
      videoType = "webview";
      // WebViewController oluştur ama URL'yi yükleme
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              _injectWebViewEnhancements();
            },
          ),
        );
        // URL yükleme şimdilik yapılmıyor
    }
  }

  // Gecikmeden sonra videoyu yükle ve başlat
  void _loadAndStartVideo() {
    if (videoType == "video_player" && _videoPlayerController != null) {
      _videoPlayerController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoPlayerController!.play();
        }
      });
    } else if (videoType == "youtube" && videoId.isNotEmpty) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );
      
      _youtubeController!.addListener(() {
        if (_youtubeController!.metadata.title.isNotEmpty) {
          videoTitle = _youtubeController!.metadata.title;
        }
      });
    } else if (videoType == "webview" || videoType == "sibnet") {
      // WebView için URL'yi şimdi yükle
      _webViewController.loadRequest(Uri.parse(widget.videoUrl));
    }
    
    _videoStarted = true;
    
    // İzleme geçmişi zamanlayıcısını başlat
    _watchHistoryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveWatchHistory();
    });
  }
  
  // Video ekran ayarları
  void _enterFullScreen() {
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

  // Video tipini tespit et
  void _detectVideoType() {
    String url = widget.videoUrl;

    if (url.endsWith(".mp4")) {
      // Doğrudan MP4 video
      videoType = "video_player";
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          setState(() {});
          // Otomatik başlatma yok, reklam sonrası başlayacak
        });
    } else if (url.contains("youtube.com") || url.contains("youtu.be")) {
      // YouTube videosu
      videoType = "youtube";
      String? videoId = YoutubePlayer.convertUrlToId(url);
      
      if (videoId != null) {
        this.videoId = videoId;
        
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false, // Otomatik başlatma yok
            mute: false,
            enableCaption: false,
          ),
        );
        
        _youtubeController!.addListener(() {
          if (_youtubeController!.metadata.title.isNotEmpty) {
            videoTitle = _youtubeController!.metadata.title;
          }
        });
      }
    } else if (url.contains("sibnet")) {
      // Sibnet videosu
      videoType = "sibnet";
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              _injectSibnetPlayerEnhancements();
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    } else {
      // Diğer web videoları
      videoType = "webview";
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              // Sayfanın yüklenmesi tamamlandığında
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    }
  }

  // WebView'da video kontrolü için JavaScript enjeksiyonu
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

  // Sibnet için özel JavaScript enjeksiyonu
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

  // Kontrolü gizleme için zamanlayıcı
  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
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

  // İzleme geçmişini kaydet
  Future<void> _saveWatchHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Video başlığı kontrolü
      String currentVideoTitle = videoTitle.isNotEmpty 
          ? videoTitle 
          : "Video ${videoId.substring(0, min(videoId.length, 6))}";
      
      // Anlamsız başlık kontrolü
      if (currentVideoTitle.contains('.php') || 
          currentVideoTitle.length < 3 || 
          currentVideoTitle.contains('http')) {
        currentVideoTitle = widget.videoTitle.isNotEmpty 
            ? widget.videoTitle 
            : "Video ${videoId.substring(0, min(videoId.length, 6))}";
      }
      
      // Firestore'a kaydet
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('watchHistory')
          .doc(videoId);
      
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // Belge varsa güncelle
        await docRef.update({
          'videoTitle': currentVideoTitle,
          'lastWatched': FieldValue.serverTimestamp(),
          'watchCount': FieldValue.increment(1)
        });
      } else {
        // Belge yoksa oluştur
        await docRef.set({
          'videoTitle': currentVideoTitle,
          'lastWatched': FieldValue.serverTimestamp(),
          'watchCount': 1
        });
      }
    } catch (e) {
      print('İzleme geçmişi kaydedilirken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer hala yükleniyor durumdaysa, yükleme ekranı göster
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.orangeAccent,
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                "Video yükleniyor...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Normal video oynatıcı kodu - mevcut kodu aynen koru
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
    } else {
      // WebView tipindeki videolar için
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
          _exitFullScreen();
          return true; // Normal çıkışa izin ver
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
                    // Sayfadan çık
                    Navigator.of(context).pop();
                  },
                ),
              ),
            // Yükleme göstergesi
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Video kontrol butonları
  Widget _buildVideoControls() {
    if (_videoPlayerController == null || 
        !_videoPlayerController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    
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
                  Text(
                    _formatDuration(_videoPlayerController!.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    _formatDuration(_videoPlayerController!.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            // Kontrol butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Geri sarma butonu
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 40),
                  onPressed: () {
                    _videoPlayerController!.seekTo(
                      Duration(seconds: _videoPlayerController!.value.position.inSeconds - 10),
                    );
                  },
                ),
                const SizedBox(width: 20),
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
                const SizedBox(width: 20),
                // İleri sarma butonu
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 40),
                  onPressed: () {
                    _videoPlayerController!.seekTo(
                      Duration(seconds: _videoPlayerController!.value.position.inSeconds + 10),
                    );
                  },
                ),
                const SizedBox(width: 20),
                // Tam ekran butonu
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 40),
                  onPressed: () {
                    setState(() {
                      isFullScreen = !isFullScreen;
                    });
                    
                    if (isFullScreen) {
                      _enterFullScreen();
                    } else {
                      _exitFullScreen();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Süre formatı
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  @override
  void dispose() {
    // Son izleme kaydet
    _saveWatchHistory();
    
    // Reklam temizleme kodunu kaldırın
    // _interstitialAd?.dispose();
    
    // Zamanlayıcıları iptal et
    _watchHistoryTimer?.cancel();
    _hideControlsTimer?.cancel();
    
    // Video oynatıcıları temizle
    _youtubeController?.dispose();
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
    }
    
    _exitFullScreen();
    super.dispose();
  }
}