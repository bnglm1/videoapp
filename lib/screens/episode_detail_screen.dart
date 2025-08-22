import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:videoapp/screens/video_player_page.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:videoapp/screens/sign_in_page.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoapp/models/github_service.dart';
// Dosyanın başına ekleyin

class EpisodeDetailsPage extends StatefulWidget {
  final String videoUrl;
  final String episodeTitle;
  final String? thumbnailUrl;
  final String? seriesId;
  final String? episodeId;
  final int? seasonIndex;
  final int? episodeIndex;
  final List<Map<String, dynamic>>? episodeList; // Bölüm listesi
  final int? currentIndex; // Mevcut bölüm index'i
  final Map<String, dynamic>? episode; // Episode data with videoSources

  const EpisodeDetailsPage({
    required this.videoUrl,
    required this.episodeTitle,
    this.thumbnailUrl,
    this.seriesId,
    this.episodeId,
    this.seasonIndex,
    this.episodeIndex,
    this.episodeList,
    this.currentIndex,
    this.episode,
    super.key,
  });

  @override
  State<EpisodeDetailsPage> createState() => _EpisodeDetailsPageState();
}

class _EpisodeDetailsPageState extends State<EpisodeDetailsPage> {
  // Kaynak değişimi animasyonu için
  bool _isSwitchingSource = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GitHubService _githubService = GitHubService();

  // Video oynatıcı
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _showVideoControls = true;
  Timer? _hideVideoControlsTimer;

  // WebView kontrolü
  bool _isWebViewVideoPlaying = false;

  // Video Sources - Yeni eklenen
  List<Map<String, dynamic>> _videoSources = [];
  int _selectedSourceIndex = 0;
  final bool _isVideoSourceSelectorExpanded = false;

  // Reklamlar
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Favori durumu
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;
  bool _isProcessing = false;

  // API'den gelen veriler
  Map<String, dynamic>? _episodeDetails;

  // GitHub'dan gelen seri bilgisi
  String? _seriesTitle;
  bool _isLoadingSeriesTitle = true;

  // Diğer
  bool _hasIncrementedView = false;

  // Yorumlar
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isAddingComment = false;

  // Yeni state değişkenleri ekleyin
  int _localViewCount = 0;

  late final WebViewController _webViewController;

  void _loadWebView(String videoUrl) {
    String htmlContent = '''
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
          pointer-events: none; /* Kullanıcı etkileşimi engellenir, sadece oynatma */
        }
      </style>
    </head>
    <body>
      <iframe 
        src="$videoUrl${videoUrl.contains('?') ? '&' : '?'}autoplay=1&mute=1&controls=0" 
        allow="autoplay; encrypted-media;"
        allowfullscreen>
      </iframe>
    </body>
    </html>
  ''';

    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      final videoId = _extractYouTubeId(videoUrl);
      if (videoId != null) {
        htmlContent = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
          <style>
            body, html { margin: 0; padding: 0; overflow: hidden; background: #000; }
            iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; pointer-events: none; }
          </style>
        </head>
        <body>
          <iframe 
            src="https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&controls=0&showinfo=0&rel=0" 
            allow="autoplay; encrypted-media;" 
            allowfullscreen>
          </iframe>
        </body>
        </html>
      ''';
      }
    }

    _webViewController?.loadHtmlString(htmlContent);
  }

  String? _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match != null ? match.group(1) : null;
  }

  @override
  void initState() {
    super.initState();
    print('🎬 EpisodeDetailsPage başlatılıyor...');
    print('📍 EpisodeID: ${widget.episodeId}');
    print('📍 EpisodeTitle: ${widget.episodeTitle}');

    _loadVideoSources(); // Video kaynaklarını yükle
    _loadInterstitialAd();
    _loadBannerAd();
    _checkIfFavorite();
    _saveToWatchHistory();
    _incrementViewCounts();
    _initializeVideo();
    _loadSeriesTitleFromGitHub();
    _loadComments();
    _loadViewCount(); // İzlenme sayısını hemen yükle

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(_currentVideoUrl));
  }

  Widget _buildWebViewPlayer() {
    return Stack(
      children: [
        WebViewWidget(
          controller: _webViewController,
        ),

        // Sağ üst köşede kontrol butonları
        Positioned(
          right: 8,
          top: 8,
          child: Row(
            children: [
              // Oynat/Duraklat butonu
              _buildMiniControlButton(
                icon: _isWebViewVideoPlaying ? Icons.pause : Icons.play_arrow,
                onTap: () {
                  if (_isWebViewVideoPlaying) {
                    // WebView içinde gerçek pause yapılamıyor, simülasyon
                    setState(() {
                      _isWebViewVideoPlaying = false;
                    });
                  } else {
                    // Yeni URL yükle
                    _webViewController.loadRequest(Uri.parse(_currentVideoUrl));
                    setState(() {
                      _isWebViewVideoPlaying = true;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              // Tam ekran butonu
              _buildMiniControlButton(
                icon: Icons.fullscreen,
                onTap: _navigateToFullScreenPlayer,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _hideVideoControlsTimer?.cancel();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // Video kaynaklarını yükle
  void _loadVideoSources() {
    print('🔍 Episode data kontrolü: ${widget.episode != null}');
    print('🔍 Episode keys: ${widget.episode?.keys.toList()}');
    if (widget.episode != null && widget.episode!['videoSources'] != null) {
      // Her kaynak için hem videoUrl hem url anahtarını kontrol et
      _videoSources = (widget.episode!['videoSources'] as List).map((source) {
        final src = Map<String, dynamic>.from(source as Map);
        final url = src['videoUrl'] ?? src['url'] ?? '';
        return {
          ...src,
          'url': url,
        };
      }).toList();
      print('🎥 Video kaynakları yüklendi: ${_videoSources.length} kaynak');
      for (int i = 0; i < _videoSources.length; i++) {
        print(
            '   $i: ${_videoSources[i]['name']} (${_videoSources[i]['quality']}) url: ${_videoSources[i]['url']}');
      }
    } else {
      // Geriye uyumluluk - eski format
      _videoSources = [
        {
          'name': 'Varsayılan',
          'quality': 'HD',
          'url': widget.videoUrl,
        }
      ];
      print('🎥 Eski format kullanılıyor - varsayılan kaynak eklendi');
      print('🔍 Widget.videoUrl: ${widget.videoUrl}');
    }
  }

  // Seçili video URL'ini döndür
  String get _currentVideoUrl {
    if (_videoSources.isNotEmpty &&
        _selectedSourceIndex < _videoSources.length) {
      final url = _videoSources[_selectedSourceIndex]['url'];
      if (url != null && url.toString().isNotEmpty) return url;
    }
    // Eğer videoSources yoksa, ana videoUrl'i kullan
    return widget.episode?['videoUrl'] ?? widget.videoUrl;
  }

  // Video kaynak seçici widget'ı
  Widget _buildVideoSourceSelector() {
    if (_videoSources.length <= 1) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('Video Kaynağı Seç'),
      children: [
        if (_isSwitchingSource)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
            ),
          ),
        ...List.generate(_videoSources.length, (i) {
          final source = _videoSources[i];
          final isSelected = _selectedSourceIndex == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(source['name'] ?? 'Kaynak ${i + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.blue[700] : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
              subtitle: Text(source['quality'] ?? '',
                  style: TextStyle(
                    color: isSelected ? Colors.blue[300] : Colors.grey[400],
                  )),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : null,
              onTap: () async {
                if (_selectedSourceIndex == i || _isSwitchingSource) return;
                setState(() {
                  _isSwitchingSource = true;
                  _selectedSourceIndex = i;
                });
                // SnackBar ile bilgilendirme
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kaynak değiştiriliyor...'),
                    duration: Duration(milliseconds: 700),
                    backgroundColor: Colors.blue,
                  ),
                );
                await _reinitializeVideoWithNewSource();
                if (mounted) {
                  setState(() {
                    _isSwitchingSource = false;
                  });
                }
              },
            ),
          );
        }),
      ],
    );
  }

  // Yeni kaynak seçildiğinde video player'ı yeniden başlat
  Future<void> _reinitializeVideoWithNewSource() async {
    // Mevcut video controller'ı dispose et
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;

    setState(() {
      _isVideoInitialized = false;
    });

    // Video timer'ı iptal et
    _hideVideoControlsTimer?.cancel();

    // Yeni kaynakla video'yu yeniden başlat
    await _initializeVideo();
  }

  // Yorumları yükle
  // Yorumları yükle
  Future<void> _loadComments() async {
    print('_loadComments çağrıldı. episodeId: "${widget.episodeId}"');
    print('Episode title: "${widget.episodeTitle}"');

    if (widget.episodeId == null || widget.episodeId!.isEmpty) {
      print(
          'episodeId null veya boş, title ile deneniyor: "${widget.episodeTitle}"');

      // episodeId yoksa title ile dene
      if (widget.episodeTitle.isNotEmpty) {
        setState(() {
          _isLoadingComments = true;
        });

        try {
          final snapshot = await _firestore
              .collection('comments')
              .where('episodeId', isEqualTo: widget.episodeTitle)
              .get(); // orderBy'ı kaldır

          final comments = <Map<String, dynamic>>[];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            comments.add(data);
          }

          // Manuel sıralama yap
          comments.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          setState(() {
            _comments = comments;
            _isLoadingComments = false;
          });

          print('Title ile ${comments.length} yorum yüklendi');
          return;
        } catch (e) {
          print('Title ile yorum yükleme hatası: $e');
        }
      }

      setState(() {
        _isLoadingComments = false;
      });
      return;
    }

    setState(() {
      _isLoadingComments = true;
    });

    try {
      final snapshot = await _firestore
          .collection('comments')
          .where('episodeId', isEqualTo: widget.episodeId)
          .get(); // orderBy'ı kaldır

      final comments = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        comments.add(data);
      }

      // Manuel sıralama yap
      comments.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });

      print('episodeId ile ${comments.length} yorum yüklendi');
    } catch (e) {
      print('Yorumlar yüklenirken hata: $e');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  // Yorum ekle
  Future<void> _addComment() async {
    final user = _auth.currentUser;
    print(
        '_addComment çağrıldı. user: ${user?.email}, episodeId: ${widget.episodeId}');

    if (user == null) {
      print('Kullanıcı giriş yapmamış');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      print('Yorum boş');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir yorum yazın'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.episodeId == null || widget.episodeId!.isEmpty) {
      print('episodeId null veya boş');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bölüm bilgisi bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAddingComment = true;
    });

    try {
      print('Firestore\'a yorum ekleniyor: ${_commentController.text.trim()}');

      // Kullanıcı adını Firestore'dan al
      String userName = 'Bilinmeyen Kullanıcı';
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['username'] ??
              userData['displayName'] ??
              user.displayName ??
              user.email?.split('@')[0] ??
              'Bilinmeyen Kullanıcı';
        } else {
          // Firestore'da kullanıcı yoksa, mevcut bilgilerden al
          userName = user.displayName ??
              user.email?.split('@')[0] ??
              'Bilinmeyen Kullanıcı';
        }
      } catch (e) {
        print('Kullanıcı adı alınırken hata: $e');
        userName = user.displayName ??
            user.email?.split('@')[0] ??
            'Bilinmeyen Kullanıcı';
      }

      print('Kullanıcı adı belirlendi: $userName');

      await _firestore.collection('comments').add({
        'episodeId': widget.episodeId,
        'userId': user.uid,
        'userEmail': user.email ?? 'Bilinmeyen Kullanıcı',
        'userName': userName,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'photoUrl': _auth.currentUser!.photoURL,
      });

      print('Yorum başarıyla eklendi');
      _commentController.clear();
      await _loadComments(); // Yorumları yeniden yükle

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum başarıyla eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Yorum eklenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yorum eklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isAddingComment = false;
      });
    }
  }

  // Yorum sil
  Future<void> _deleteComment(String commentId, String userId) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu yorumu silme yetkiniz yok'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('comments').doc(commentId).delete();
      await _loadComments(); // Yorumları yeniden yükle

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Yorum silinirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum silinirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Yorumu kopyala
  void _copyComment(String comment) {
    Clipboard.setData(ClipboardData(text: comment));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yorum kopyalandı'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Yorum seçenekleri menüsü
  void _showCommentOptions(Map<String, dynamic> comment) {
    final isOwnComment = _auth.currentUser?.uid == comment['userId'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kopyala
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title:
                  const Text('Kopyala', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _copyComment(comment['comment']?.toString() ?? '');
              },
            ),

            // Sadece kendi yorumları için silme
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment['id'], comment['userId']);
                },
              ),

            // Rapor et (başkasının yorumu için)
            if (!isOwnComment)
              ListTile(
                leading: const Icon(Icons.report, color: Colors.red),
                title: const Text('Rapor Et',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Rapor etme işlemi
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Yorum rapor edildi'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Zamanı formatla (örn: "2 saat önce", "1 gün önce")
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  // GitHub'dan seri ismini yükle
  Future<void> _loadSeriesTitleFromGitHub() async {
    setState(() {
      _isLoadingSeriesTitle = true;
    });

    try {
      print("GitHub'dan seri bilgileri yükleniyor...");

      // Tüm serileri GitHub'dan çek
      final allSeries = await _githubService.fetchSeries();

      String? foundSeriesTitle;

      // Bölüm başlığından seri ismini çıkarma
      String episodeTitle = widget.episodeTitle;

      // Her seriyi kontrol et ve bu bölümün hangi seriye ait olduğunu bul
      for (var series in allSeries) {
        // Seri ismiyle eşleşme kontrolü
        if (episodeTitle.toLowerCase().contains(series.title.toLowerCase())) {
          foundSeriesTitle = series.title;
          print("Seri bulundu: ${series.title}");
          break;
        }

        // Ayrıca seasonara bakarak da kontrol edebiliriz
        for (var season in series.seasons) {
          for (var episode in season.episodes) {
            if (episode.title.toLowerCase() == episodeTitle.toLowerCase() ||
                episode.videoUrl == widget.videoUrl) {
              foundSeriesTitle = series.title;
              print("Episode match ile seri bulundu: ${series.title}");
              break;
            }
          }
          if (foundSeriesTitle != null) break;
        }
        if (foundSeriesTitle != null) break;
      }

      if (mounted) {
        setState(() {
          _seriesTitle = foundSeriesTitle;
          _isLoadingSeriesTitle = false;
        });

        if (foundSeriesTitle != null) {
          print("GitHub'dan seri ismi yüklendi: $foundSeriesTitle");
        } else {
          print("GitHub'da eşleşen seri bulunamadı: $episodeTitle");
        }
      }
    } catch (e) {
      print("GitHub'dan seri ismi yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _isLoadingSeriesTitle = false;
        });
      }
    }
  }

  // Video başlatma
  Future<void> _initializeVideo() async {
    try {
      print("🚀 Video başlatılıyor: ${widget.videoUrl}");

      String videoUrl = _currentVideoUrl;
      print('� Video URL kullanılıyor: $videoUrl');

      if (videoUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Videoya ait link bulunamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isVideoInitialized = false;
        });
        return;
      }

      // WebView gerekip gerekmediğini kontrol et
      if (_shouldVideoUseWebView(videoUrl)) {
        // WebView ile oynat
        setState(() {
          _isVideoInitialized = true;
          _isWebViewVideoPlaying =
              false; // Başlangıçta duraklatılmış gibi göster
        });
        print("Video WebView ile oynatılacak");

        // WebView'ı hazırla
        _loadWebView(videoUrl);
        return;
      }

      print("▶️ Video controller başlatılıyor...");
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();

      // Kaydedilen pozisyonu yükle
      final prefs = await SharedPreferences.getInstance();
      final savedPosition =
          prefs.getInt('video_position_${widget.episodeTitle}') ?? 0;

      if (savedPosition > 0) {
        await _videoPlayerController!
            .seekTo(Duration(milliseconds: savedPosition));
      }

      setState(() {
        _isVideoInitialized = true;
      });

      print("✅ Video başarıyla başlatıldı!");

      // Kontrolleri başlangıçta göster ve 3 saniye sonra gizle
      _showVideoControls = true;
      _hideVideoControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showVideoControls = false;
          });
        }
      });

      // Video durumu değişikliklerini dinle
      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {
            // UI güncellemesi için setState çağır
          });
          _saveVideoPosition();
        }
      });

      print("Video başlatıldı");
    } catch (e) {
      print("❌ Video başlatma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video başlatma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Video pozisyonunu kaydet
  Future<void> _saveVideoPosition() async {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      final position = _videoPlayerController!.value.position.inMilliseconds;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('video_position_${widget.episodeTitle}', position);
    }
  }

  // Kaydedilen video pozisyonunu yükle
  Future<void> _loadSavedVideoPosition() async {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedPosition =
            prefs.getInt('video_position_${widget.episodeTitle}') ?? 0;

        if (savedPosition > 0) {
          final duration = Duration(milliseconds: savedPosition);
          await _videoPlayerController!.seekTo(duration);
        }
      } catch (e) {
        print('Video pozisyon yükleme hatası: $e');
      }
    }
  }

  // Video kontrollerini göster/gizle
  void _toggleVideoControls() {
    setState(() {
      _showVideoControls = !_showVideoControls;
    });

    if (_showVideoControls) {
      _hideVideoControlsTimer?.cancel();
      _hideVideoControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showVideoControls = false;
          });
        }
      });
    }
  }

  // Oynat/Duraklat
  void _togglePlayPause() {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      setState(() {});
    }
  }

  // Tam ekran oynatıcıya git
  void _navigateToFullScreenPlayer() {
    _showAdOrNavigate();
  }

  // Reklam yükleme
  Future<void> _loadInterstitialAd() async {
    _interstitialAd?.dispose();
    _isAdLoaded = false;

    await InterstitialAd.load(
      adUnitId: 'ca-app-pub-7690250755006392/8813706277',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _navigateToVideoPlayer();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _navigateToVideoPlayer();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print("Reklam yüklenemedi: $error");
          _isAdLoaded = false;
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7690250755006392/7705897910',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print("Banner reklam yüklenemedi: $error");
          ad.dispose();
        },
      ),
    )..load();
  }

  // Favori kontrol
  Future<void> _checkIfFavorite() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isCheckingFavorite = false;
      });
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(widget.episodeTitle)
          .get();

      setState(() {
        _isFavorite = doc.exists;
        _isCheckingFavorite = false;
      });
    } catch (e) {
      print("Favori kontrol hatası: $e");
      setState(() {
        _isCheckingFavorite = false;
      });
    }
  }

  // Favori toggle
  Future<void> _toggleFavorite() async {
    if (_auth.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isFavorite) {
        await _removeFavorite();
      } else {
        await _addToFavorite();
      }
      await _checkIfFavorite();
    } catch (e) {
      print("Favori işlem hatası: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _removeFavorite() async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(widget.episodeTitle)
          .delete();
    } catch (e) {
      print("Favoriden kaldırma hatası: $e");
    }
  }

  Future<void> _addToFavorite() async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(widget.episodeTitle)
          .set({
        'title': widget.episodeTitle,
        'videoUrl': widget.videoUrl,
        'thumbnailUrl': widget.thumbnailUrl,
        'seriesId': widget.seriesId,
        'episodeId': widget.episodeId,
        'seasonIndex': widget.seasonIndex,
        'episodeIndex': widget.episodeIndex,
        'addedAt': FieldValue.serverTimestamp(),
      });

      print("Favoriye eklendi: ${widget.episodeTitle}");
    } catch (e) {
      print("Favoriye ekleme hatası: $e");
    }
  }

  // İzleme geçmişi
  Future<void> _saveToWatchHistory() async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('watchHistory')
          .doc(widget.episodeTitle)
          .set({
        'videoTitle': widget.episodeTitle, // Bu alanı ekleyin
        'title': widget.episodeTitle,
        'videoUrl': widget.videoUrl,
        'thumbnailUrl': widget.thumbnailUrl,
        'seriesId': widget.seriesId,
        'episodeId': widget.episodeId,
        'seasonIndex': widget.seasonIndex,
        'episodeIndex': widget.episodeIndex,
        'lastWatched': FieldValue.serverTimestamp(), // Bu alan önemli
        'watchedAt': FieldValue.serverTimestamp(),
      });

      print("İzleme geçmişine eklendi: ${widget.episodeTitle}");
    } catch (e) {
      print("İzleme geçmişi kaydetme hatası: $e");
    }
  }

  // Görüntülenme sayısı artırma
  Future<void> _incrementViewCounts() async {
    if (_hasIncrementedView) return;

    try {
      await _incrementViewCount();
      _hasIncrementedView = true;
    } catch (e) {
      print("Görüntülenme sayısı artırma hatası: $e");
    }
  }

  // Mevcut _incrementViewCount metodunu şu şekilde güncelleyin:
  Future<void> _incrementViewCount() async {
    try {
      final docRef = _firestore.collection('videos').doc(widget.episodeTitle);

      // Tekli artış (1)
      const int increment = 1;

      // Local state'i artırmıyoruz, sadece Firestore'u güncelliyoruz
      // Kullanıcı ekrandan çıkıp tekrar girdiğinde artışı görebilecek

      // Firestore'u arka planda güncelle
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        int currentViews = 0;
        if (doc.exists) {
          currentViews = doc.data()?['views'] ?? 0;
        }

        transaction.set(
            docRef,
            {
              'title': widget.episodeTitle,
              'views': currentViews + increment,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        print(
            "📊 İzlenme sayısı 1 kadar artırıldı. Yeni toplam: ${currentViews + increment}");
      });
    } catch (e) {
      print("Görüntülenme sayısı güncellenirken hata: $e");
    }
  }

  // İzlenme sayısını hızlıca yükle
  Future<void> _loadViewCount() async {
    try {
      final doc =
          await _firestore.collection('videos').doc(widget.episodeTitle).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final viewCount = (data['views'] as num?)?.toInt() ?? 0;

        if (mounted) {
          setState(() {
            _localViewCount = viewCount;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _localViewCount = 0;
          });
        }
      }
    } catch (e) {
      print("İzlenme sayısı yükleme hatası: $e");
      if (mounted) {
        setState(() {
          _localViewCount = 0;
        });
      }
    }
  }

  // Reklam göster veya direkt git
  void _showAdOrNavigate() async {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _navigateToVideoPlayer();
    }
  }

  void _navigateToVideoPlayer() async {
    // Mevcut video pozisyonunu kaydet
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isInitialized) {
      await _saveVideoPosition();
      // Mini oynatıcıyı duraklat
      _videoPlayerController!.pause();
    }

    // Seçili kaynağın URL'ini al
    final videoUrl = _currentVideoUrl;
    print('🎬 Tam ekran oynatıcıya geçiliyor: $videoUrl');

    // WebView kullanılıp kullanılmayacağını belirle
    bool shouldUseWebView = _shouldVideoUseWebView(videoUrl);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: videoUrl,
          videoTitle: widget.episodeTitle,
          useWebView: shouldUseWebView,
        ),
      ),
    );

    // Tam ekran oynatıcıdan döndükten sonra pozisyonu yükle ve mini oynatıcıyı güncelle
    await _loadSavedVideoPosition();
  }

  // WebView kullanılması gerekip gerekmediğini belirle
  bool _shouldVideoUseWebView(String videoUrl) {
    final url = videoUrl.toLowerCase();

    // .mp4 dosyaları native player ile oynatılır
    if (url.endsWith('.mp4')) return false;

    // Diğer desteklenen video formatları
    if (url.endsWith('.avi') ||
        url.endsWith('.mkv') ||
        url.endsWith('.mov') ||
        url.endsWith('.wmv') ||
        url.endsWith('.flv') ||
        url.endsWith('.webm') ||
        url.endsWith('.m3u8')) {
      return false;
    }

    // Online video platformları WebView ile oynatılır
    if (url.contains('sibnet.ru') ||
        url.contains('ok.ru') ||
        url.contains('vk.com') ||
        url.contains('rumble')) {
      return true;
    }

    // Bilinmeyen formatlar için WebView kullan (güvenli seçenek)
    return true;
  }

  // Paylaş
  void _shareVideo() async {
    try {
      await Share.share(
        'Bu harika videoyu izle: ${widget.episodeTitle}\n${widget.videoUrl}',
        subject: widget.episodeTitle,
      );
    } catch (e) {
      print("Paylaşım hatası: $e");
    }
  }

  // Seçenekler menüsü
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('Bilgi', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Bilgi dialog'u göster
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title:
                  const Text('Rapor Et', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Rapor et
              },
            ),
            // Alt boşluk ekle
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Firestore test fonksiyonu (debug amaçlı)
  // Görüntülenme sayısını formatla
  String _formatViewCount(int viewCount) {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return viewCount.toString();
    }
  }

  // Aksiyon butonu
  Widget _buildActionButtonNew({
    required IconData? icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Önceki bölüme git
  // Önceki bölüme git
  // Önceki bölüme git
  void _navigateToPreviousEpisode() {
    if (widget.episodeList == null || widget.currentIndex == null) return;
    if (widget.currentIndex! <= 0) return;

    final previousEpisode = widget.episodeList![widget.currentIndex! - 1];

    // episodeId'yi doğru şekilde al
    String? episodeId = previousEpisode['episodeId'] ??
        previousEpisode['id'] ??
        previousEpisode['title']; // Fallback olarak title kullan

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: previousEpisode['videoUrl'] ?? '',
          episodeTitle: previousEpisode['title'] ?? 'Önceki Bölüm',
          thumbnailUrl: previousEpisode['thumbnail'],
          seriesId: widget.seriesId,
          episodeId: episodeId, // Bu satırı düzelttik
          seasonIndex: widget.seasonIndex,
          episodeIndex: widget.currentIndex! - 1,
          episodeList: widget.episodeList,
          currentIndex: widget.currentIndex! - 1,
          episode: previousEpisode,
        ),
      ),
    );
  }

// Sonraki bölüme git
  void _navigateToNextEpisode() {
    if (widget.episodeList == null || widget.currentIndex == null) return;
    if (widget.currentIndex! >= widget.episodeList!.length - 1) return;

    final nextEpisode = widget.episodeList![widget.currentIndex! + 1];

    // episodeId'yi doğru şekilde al
    String? episodeId = nextEpisode['episodeId'] ??
        nextEpisode['id'] ??
        nextEpisode['title']; // Fallback olarak title kullan

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: nextEpisode['videoUrl'] ?? '',
          episodeTitle: nextEpisode['title'] ?? 'Sonraki Bölüm',
          thumbnailUrl: nextEpisode['thumbnail'],
          seriesId: widget.seriesId,
          episodeId: episodeId, // Bu satırı düzelttik
          seasonIndex: widget.seasonIndex,
          episodeIndex: widget.currentIndex! + 1,
          episodeList: widget.episodeList,
          currentIndex: widget.currentIndex! + 1,
          episode: nextEpisode,
        ),
      ),
    );
  }

  // Mini kontrol butonu helper
  Widget _buildMiniControlButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        centerTitle: false,
        title: Text(
          _isLoadingSeriesTitle
              ? 'Yükleniyor...'
              : _seriesTitle?.isNotEmpty == true
                  ? _seriesTitle!
                  : _episodeDetails?['api_title']?.isNotEmpty == true
                      ? _episodeDetails!['api_title']
                      : _episodeDetails?['seriesTitle']?.isNotEmpty == true
                          ? _episodeDetails!['seriesTitle']
                          : 'Bölüm Detayları',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [
          // Actions can be added here if needed
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Player
                    Stack(
                      children: [
                        // Video Player Container
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            gradient: LinearGradient(
                              colors: [Colors.black, Colors.grey[900]!],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Video içeriği
                        Positioned.fill(
                          child: _shouldVideoUseWebView(_currentVideoUrl)
                              ? _buildWebViewPlayer() // Yeni: WebView ile oynat
                              : _videoPlayerController != null &&
                                      _isVideoInitialized
                                  ? GestureDetector(
                                      onTap: _toggleVideoControls,
                                      child: AspectRatio(
                                        aspectRatio: _videoPlayerController!
                                            .value.aspectRatio,
                                        child: Stack(
                                          children: [
                                            VideoPlayer(
                                                _videoPlayerController!),
                                            if (_showVideoControls)
                                              Positioned(
                                                right: 8,
                                                top: 8,
                                                child: Row(
                                                  children: [
                                                    _buildMiniControlButton(
                                                      icon:
                                                          _videoPlayerController!
                                                                  .value
                                                                  .isPlaying
                                                              ? Icons.pause
                                                              : Icons
                                                                  .play_arrow,
                                                      onTap: _togglePlayPause,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    _buildMiniControlButton(
                                                      icon: Icons.fullscreen,
                                                      onTap:
                                                          _navigateToFullScreenPlayer,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: _navigateToFullScreenPlayer,
                                      child: widget.thumbnailUrl != null
                                          ? Stack(
                                              children: [
                                                Image.network(
                                                  widget.thumbnailUrl!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                                Center(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              50),
                                                    ),
                                                    child: const Icon(
                                                      Icons.play_arrow,
                                                      color: Colors.white,
                                                      size: 48,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.red),
                                            ),
                                    ),
                        ),
                      ],
                    ),

                    // Bölüm Başlığı
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.episodeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // İzlenme sayısı göstergesi - Local state ile hızlı gösterim
                          Row(
                            children: [
                              const Icon(Icons.visibility,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                "${_formatViewCount(_localViewCount)} görüntüleme",
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                        color: Colors.grey, thickness: 0.5, height: 15),

                    // Önceki/Sonraki Bölüm Navigasyonu
                    if (widget.episodeList != null &&
                        widget.currentIndex != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            // Önceki Bölüm
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (widget.currentIndex! > 0)
                                    ? _navigateToPreviousEpisode
                                    : null,
                                icon: const Icon(Icons.skip_previous,
                                    color: Colors.white),
                                label: const Text(
                                  'Önceki Bölüm',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (widget.currentIndex! > 0)
                                      ? Colors.blue.withOpacity(0.8)
                                      : Colors.grey.withOpacity(0.3),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Sonraki Bölüm
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (widget.currentIndex! <
                                        widget.episodeList!.length - 1)
                                    ? _navigateToNextEpisode
                                    : null,
                                icon: const Icon(Icons.skip_next,
                                    color: Colors.white),
                                label: const Text(
                                  'Sonraki Bölüm',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (widget.currentIndex! <
                                          widget.episodeList!.length - 1)
                                      ? Colors.blue.withOpacity(0.8)
                                      : Colors.grey.withOpacity(0.3),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Aksiyon Butonları
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButtonNew(
                              icon: Icons.share,
                              label: 'Paylaş',
                              onTap: _shareVideo,
                              color: Colors.blue,
                            ),
                          ),
                          Container(
                              width: 1, height: 40, color: Colors.grey[800]),
                          Expanded(
                            child: _buildActionButtonNew(
                              icon: _isProcessing
                                  ? null
                                  : (_isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border),
                              label: _isProcessing
                                  ? 'İşleniyor...'
                                  : (_isFavorite ? 'Favorilerde' : 'Favorile'),
                              onTap: (_isCheckingFavorite || _isProcessing)
                                  ? null
                                  : _toggleFavorite,
                              color: _isFavorite ? Colors.red : Colors.pink,
                              isLoading: _isProcessing,
                            ),
                          ),
                          Container(
                              width: 1, height: 40, color: Colors.grey[800]),
                          Expanded(
                            child: _buildActionButtonNew(
                              icon: Icons.more_horiz,
                              label: 'Daha Fazla',
                              onTap: _showOptionsMenu,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Video Kaynak Seçici
                    _buildVideoSourceSelector(),

                    // Yorumlar bölümü
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Yorumlar başlık
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.comment,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Yorumlar (${_comments.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Yorum ekleme bölümü
                          if (_auth.currentUser != null)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _commentController,
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 3,
                                    decoration: const InputDecoration(
                                      hintText: 'Yorumunuzu yazın...',
                                      hintStyle:
                                          TextStyle(color: Colors.white54),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_isAddingComment)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.red),
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: _addComment,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Yorum Yap',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Yorum yapabilmek için giriş yapın',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignInPage(),
                                      ),
                                    ),
                                    child: const Text(
                                      'Giriş Yap',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Yorumlar listesi
                          if (_isLoadingComments)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.red),
                                ),
                              ),
                            )
                          else if (_comments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Henüz yorum yapılmamış.\nİlk yorumu siz yapın!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else if (_comments.isNotEmpty)
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _comments.length,
                              separatorBuilder: (context, index) {
                                // Güvenli separator
                                if (index < 0 ||
                                    index >= _comments.length - 1) {
                                  return const SizedBox.shrink();
                                }
                                return Divider(
                                  color: Colors.white.withOpacity(0.1),
                                  height: 1,
                                );
                              },
                              itemBuilder: (context, index) {
                                // Güvenli indeks kontrolü
                                if (index < 0 || index >= _comments.length) {
                                  return const SizedBox.shrink();
                                }

                                final comment = _comments[index];
                                final createdAt =
                                    comment['createdAt'] as Timestamp?;
                                final timeAgo = createdAt != null
                                    ? _formatTimeAgo(createdAt.toDate())
                                    : 'Bilinmiyor';

                                // Güvenli userName erişimi ve formatlaması
                                String userName = 'Bilinmeyen Kullanıcı';
                                if (comment['userName'] != null &&
                                    comment['userName']
                                        .toString()
                                        .trim()
                                        .isNotEmpty) {
                                  userName =
                                      comment['userName'].toString().trim();
                                } else if (comment['userEmail'] != null &&
                                    comment['userEmail']
                                        .toString()
                                        .trim()
                                        .isNotEmpty) {
                                  // Email'den kullanıcı adı çıkar
                                  final email = comment['userEmail'].toString();
                                  if (email.contains('@')) {
                                    userName = email.split('@')[0];
                                  } else {
                                    userName = email;
                                  }
                                }

                                // Kullanıcı adını güzelleştir (ilk harfleri büyük yap)
                                userName = userName
                                    .split(' ')
                                    .map((word) => word.isNotEmpty
                                        ? word[0].toUpperCase() +
                                            word.substring(1).toLowerCase()
                                        : word)
                                    .join(' ');

                                final userInitial = userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'U';

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundImage:
                                                comment['photoUrl'] != null &&
                                                        comment['photoUrl']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? NetworkImage(
                                                        comment['photoUrl'])
                                                    : null,
                                            backgroundColor: Colors.red,
                                            child:
                                                (comment['photoUrl'] == null ||
                                                        comment['photoUrl']
                                                            .toString()
                                                            .isEmpty)
                                                    ? Text(
                                                        userInitial,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  userName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  timeAgo,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // 3 nokta menüsü (her yorum için)
                                          IconButton(
                                            onPressed: () =>
                                                _showCommentOptions(comment),
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        comment['comment']?.toString() ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Banner reklamı
            if (_isBannerAdLoaded && _bannerAd != null)
              SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}
