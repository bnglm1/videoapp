import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Ekran oranı seçenekleri için helper sınıf
class AspectRatioOption {
  final String name;
  final double? ratio;
  final String description;
  
  AspectRatioOption(this.name, this.ratio, this.description);
}

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final bool? useWebView; // WebView kullanılması gerekip gerekmediği

  const VideoPlayerPage({
    required this.videoUrl,
    this.videoTitle = '',
    this.useWebView,
    super.key,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final bool _isLoading = false;
  bool _shouldUseWebView = false;
  
  // Video oynatıcı değişkenleri
  VideoPlayerController? _videoPlayerController;
  WebViewController? _webViewController;
  bool isFullScreen = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  String videoId = '';
  String videoTitle = '';
  
  // Ekran oranı seçenekleri
  int _aspectRatioIndex = 0;
  final List<AspectRatioOption> _aspectRatioOptions = [
    AspectRatioOption('Otomatik', null, 'Videonun orijinal oranı'),
    AspectRatioOption('16:9', 16/9, 'Geniş ekran'),
    AspectRatioOption('4:3', 4/3, 'Klasik TV'),
    AspectRatioOption('21:9', 21/9, 'Sinema'),
    AspectRatioOption('1:1', 1/1, 'Kare'),
    AspectRatioOption('9:16', 9/16, 'Dikey'),
    AspectRatioOption('Tam Ekran', -1, 'Ekranı doldur'),
  ];
  
  // Ses ve hız kontrolleri
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    
    // WebView kullanılıp kullanılmayacağını belirle
    _shouldUseWebView = _determineIfWebViewNeeded();
    
    // Video bilgilerini ayarla
    videoId = widget.videoUrl.hashCode.toString();
    videoTitle = widget.videoTitle.isNotEmpty 
        ? widget.videoTitle 
        : 'Video ${videoId.substring(0, videoId.length > 6 ? 6 : videoId.length)}';
    
    // Ekran ayarları
    _enterFullScreen();
    _startHideControlsTimer();
    
    if (_shouldUseWebView) {
      // WebView başlat
      _initializeWebView();
    } else {
      // Video URL'sini kontrol et ve video player'ı başlat
      if (!widget.videoUrl.toLowerCase().endsWith('.mp4')) {
        // MP4 değilse hata göster
        _showErrorDialog();
        return;
      }
      
      // Hemen videoyu yüklemeye başla
      _loadAndStartVideo();
    }
  }

  bool _determineIfWebViewNeeded() {
    // Eğer açık bir şekilde belirtilmişse
    if (widget.useWebView != null) return widget.useWebView!;
    
    // Video URL'sine göre otomatik belirleme
    final url = widget.videoUrl.toLowerCase();
    
    // .mp4 dosyaları native player ile oynatılır
    if (url.endsWith('.mp4')) return false;
    
    // YouTube, Vimeo, Dailymotion vs. gibi platformlar WebView ile oynatılır
    if (url.contains('youtube.com') || 
        url.contains('youtu.be') ||
        url.contains('vimeo.com') ||
        url.contains('dailymotion.com') ||
        url.contains('facebook.com') ||
        url.contains('instagram.com') ||
        url.contains('tiktok.com') ||
        url.contains('twitch.tv') ||
        url.contains('embed') ||
        url.contains('iframe')) {
      return true;
    }
    
    return false;
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Loading progress
          },
          onPageStarted: (String url) {
            // Page started loading
          },
          onPageFinished: (String url) {
            // Page finished loading
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.videoUrl));
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Desteklenmeyen Video Formatı',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            _shouldUseWebView 
              ? 'Bu video WebView ile yüklenemedi. Lütfen internet bağlantınızı kontrol edin.'
              : 'Bu uygulama sadece .mp4 formatındaki videoları oynatabilir.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                Navigator.of(context).pop(); // VideoPlayerPage'i kapat
              },
              child: const Text(
                'Tamam',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  // Gecikmeden sonra videoyu yükle ve başlat
  void _loadAndStartVideo() {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _videoPlayerController!.initialize().then((_) {
      if (mounted) {
        // Başlangıç ses seviyesini ayarla
        _videoPlayerController!.setVolume(_volume);
        setState(() {});
        
        // Kaydedilen pozisyonu yükle ve hemen oynat
        _loadSavedVideoPosition().then((_) {
          if (mounted) {
            _videoPlayerController!.play();
          }
        });
        
        // Video pozisyon değişikliklerini dinle ve sürekli kaydet
        _videoPlayerController!.addListener(() {
          if (mounted) {
            setState(() {
              // UI güncellemesi için setState çağır
            });
            _saveVideoPosition();
          }
        });
      }
    }).catchError((error) {
      debugPrint('Video yükleme hatası: $error');
      if (mounted) {
        _showVideoErrorDialog();
      }
    });
  }

  // Video pozisyonunu kaydet
  Future<void> _saveVideoPosition() async {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final position = _videoPlayerController!.value.position.inMilliseconds;
        final videoKey = 'video_position_${widget.videoTitle}';
        await prefs.setInt(videoKey, position);
      } catch (e) {
        print('Video pozisyon kaydetme hatası: $e');
      }
    }
  }

  // Kaydedilen video pozisyonunu yükle
  Future<void> _loadSavedVideoPosition() async {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final videoKey = 'video_position_${widget.videoTitle}';
        final savedPosition = prefs.getInt(videoKey) ?? 0;
        
        if (savedPosition > 0) {
          final duration = Duration(milliseconds: savedPosition);
          await _videoPlayerController!.seekTo(duration);
          print('Video pozisyon yüklendi: ${duration.inSeconds}s');
        } else {
          print('Kaydedilmiş video pozisyonu bulunamadı');
        }
      } catch (e) {
        print('Video pozisyon yükleme hatası: $e');
      }
    }
  }

  void _showVideoErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Video Yükleme Hatası',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Video yüklenirken bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                Navigator.of(context).pop(); // VideoPlayerPage'i kapat
              },
              child: const Text(
                'Tamam',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        );
      },
    );
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

  // Ekran oranı seçim dialogu
  void _showAspectRatioDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Ekran Oranı Seçin',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _aspectRatioOptions.length,
              itemBuilder: (context, index) {
                final option = _aspectRatioOptions[index];
                final isSelected = index == _aspectRatioIndex;
                
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.white70,
                  ),
                  title: Text(
                    option.name,
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    option.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  onTap: () {
                    setState(() {
                      _aspectRatioIndex = index;
                    });
                    Navigator.of(context).pop();
                    _startHideControlsTimer(); // Kontrolleri tekrar gizle
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  // Oynatma hızı seçim dialogu
  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Oynatma Hızı',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _speedOptions.length,
              itemBuilder: (context, index) {
                final speed = _speedOptions[index];
                final isSelected = speed == _playbackSpeed;
                String speedText = speed == 1.0 ? 'Normal' : '${speed}x';
                
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.white70,
                  ),
                  title: Text(
                    speedText,
                    style: TextStyle(
                      color: isSelected ? Colors.blue : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _playbackSpeed = speed;
                      _videoPlayerController?.setPlaybackSpeed(speed);
                    });
                    Navigator.of(context).pop();
                    _startHideControlsTimer();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  // Ses seviyesi ayarlama dialogu
  void _showVolumeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Ses Seviyesi',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _volume == 0 ? Icons.volume_off : 
                        _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          activeColor: Colors.blue,
                          inactiveColor: Colors.grey,
                          onChanged: (value) {
                            setDialogState(() {
                              _volume = value;
                            });
                            setState(() {
                              _volume = value;
                              _videoPlayerController?.setVolume(value);
                            });
                          },
                        ),
                      ),
                      Text(
                        '${(_volume * 100).round()}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _volume = 0.0;
                          });
                          setState(() {
                            _volume = 0.0;
                            _videoPlayerController?.setVolume(0.0);
                          });
                        },
                        child: const Text('Sessiz', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _volume = 0.5;
                          });
                          setState(() {
                            _volume = 0.5;
                            _videoPlayerController?.setVolume(0.5);
                          });
                        },
                        child: const Text('50%', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _volume = 1.0;
                          });
                          setState(() {
                            _volume = 1.0;
                            _videoPlayerController?.setVolume(1.0);
                          });
                        },
                        child: const Text('Maksimum', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startHideControlsTimer();
                  },
                  child: const Text(
                    'Tamam',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
    
    // Ana widget - WebView veya Video Player
    Widget mainWidget;
    
    if (_shouldUseWebView) {
      // WebView için widget
      if (_webViewController != null) {
        mainWidget = GestureDetector(
          onTap: _toggleControlsVisibility,
          child: Container(
            color: Colors.black,
            child: WebViewWidget(controller: _webViewController!),
          ),
        );
      } else {
        mainWidget = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                "WebView yüklenemedi",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "İnternet bağlantınızı kontrol edin",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Video Player için widget
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        // Video başarıyla yüklendi ve hazır
        Widget videoChild;
        final currentOption = _aspectRatioOptions[_aspectRatioIndex];
        
        if (currentOption.ratio == -1) {
          // Tam ekran modu - ekranı doldur
          videoChild = SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoPlayerController!.value.size.width,
                height: _videoPlayerController!.value.size.height,
                child: VideoPlayer(_videoPlayerController!),
              ),
            ),
          );
        } else if (currentOption.ratio != null) {
          // Belirli bir ekran oranı
          videoChild = Center(
            child: AspectRatio(
              aspectRatio: currentOption.ratio!,
              child: VideoPlayer(_videoPlayerController!),
            ),
          );
        } else {
          // Otomatik - video'nun orijinal oranı
          videoChild = Center(
            child: AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            ),
          );
        }
        
        mainWidget = SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _toggleControlsVisibility,
                child: Container(
                  color: Colors.black,
                  child: videoChild,
                ),
              ),
              if (_showControls && !_shouldUseWebView) _buildVideoControls(),
            ],
          ),
        );
      } else if (_videoPlayerController != null && _videoPlayerController!.value.hasError) {
        // Video yükleme hatası var
        mainWidget = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                "Video yüklenemedi",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Sadece .mp4 formatı desteklenir",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      } else {
        // Video henüz yüklenmemiş, tamamen siyah ekran göster
        mainWidget = Container(
          color: Colors.black,
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        onPopInvoked: (didPop) {
          if (didPop) {
            _exitFullScreen();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: mainWidget,
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
            // WebView için basic kontroller
            if (_shouldUseWebView && _showControls)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          _webViewController?.reload();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
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
        // Üst kısımda ekran oranı bilgisi
        Positioned(
          top: 60,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _aspectRatioOptions[_aspectRatioIndex].name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Text(
                  _playbackSpeed == 1.0 ? 'Normal' : '${_playbackSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '•',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Icon(
                  _volume == 0 ? Icons.volume_off : 
                  _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
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
            // Ana oynatma kontrolleri (ortada)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 10 saniye geri
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 40),
                  onPressed: () {
                    _videoPlayerController!.seekTo(
                      Duration(seconds: _videoPlayerController!.value.position.inSeconds - 10),
                    );
                  },
                ),
                const SizedBox(width: 30),
                // Ana oynatma/durdurma butonu (büyük)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 60,
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
                ),
                const SizedBox(width: 30),
                // 10 saniye ileri
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 40),
                  onPressed: () {
                    _videoPlayerController!.seekTo(
                      Duration(seconds: _videoPlayerController!.value.position.inSeconds + 10),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Alt kontrol butonları (küçük)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Ses kontrolü
                GestureDetector(
                  onTap: () {
                    _showVolumeDialog();
                  },
                  onLongPress: () {
                    setState(() {
                      if (_volume > 0) {
                        _volume = 0.0;
                      } else {
                        _volume = 1.0;
                      }
                      _videoPlayerController?.setVolume(_volume);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _volume == 0 ? Icons.volume_off : 
                      _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                      color: Colors.white, 
                      size: 24
                    ),
                  ),
                ),
                // Hız kontrolü
                GestureDetector(
                  onTap: () {
                    _showSpeedDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.speed, color: Colors.white, size: 24),
                  ),
                ),
                // Ekran oranı
                GestureDetector(
                  onTap: () {
                    _showAspectRatioDialog();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.aspect_ratio, color: Colors.white, size: 24),
                  ),
                ),
                // Küçük oynatıcıya geç
                GestureDetector(
                  onTap: () async {
                    // Video pozisyonunu kaydet
                    await _saveVideoPosition();
                    // Video oynatıcıyı duraklat
                    _videoPlayerController?.pause();
                    // Episode detail sayfasına geri dön
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
    // Video pozisyonunu kaydet
    _saveVideoPosition();
    
    // Zamanlayıcıları iptal et
    _hideControlsTimer?.cancel();
    
    // Video oynatıcısını temizle
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      _videoPlayerController!.dispose();
    }
    
    _exitFullScreen();
    super.dispose();
  }
}