import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:videoapp/screens/video_player_page.dart';
import 'package:videoapp/screens/sign_in_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoapp/models/github_service.dart';
import 'dart:async';

class EpisodeDetailsPage extends StatefulWidget {
  final String videoUrl;
  final String episodeTitle;
  final String? thumbnailUrl;
  final String? seriesId;
  final String? episodeId;
  final int? seasonIndex;
  final int? episodeIndex;
  final List<Map<String, dynamic>>? episodeList;
  final int? currentIndex;
  final Map<String, dynamic>? episode;

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
  // Services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GitHubService _githubService = GitHubService();

  // Video Player
  VideoPlayerController? _videoController;
  late WebViewController _webViewController;
  bool _isVideoInitialized = false;
  bool _showVideoControls = true;
  bool _isWebViewVideoPlaying = false;
  Timer? _hideControlsTimer;

  // Video Sources
  List<Map<String, dynamic>> _videoSources = [];
  int _selectedSourceIndex = 0;
  bool _isSwitchingSource = false;

  // Ads
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isBannerAdLoaded = false;

  // Data States
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;
  bool _isProcessing = false;
  int _viewCount = 0;
  bool _hasIncrementedView = false;
  String? _seriesTitle;
  bool _isLoadingSeriesTitle = true;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  Map<String, Map<String, dynamic>> _commentUsers = {};
  bool _isLoadingComments = true;
  bool _isAddingComment = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    try {
      // Initialize WebView controller
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(false)
        ..setBackgroundColor(const Color(0x00000000));

      // Initialize all components
      await Future.wait([
        _loadVideoSources(),
        _loadViewCount(),
        _checkIfFavorite(),
        _loadSeriesTitleFromGitHub(),
        _loadComments(),
      ]);

      // Initialize video player
      await _initializeVideo();

      // Background tasks
      _loadAds();
      _saveToWatchHistory();
      _incrementViewCount();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _hideControlsTimer?.cancel();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // VIDEO MANAGEMENT
  Future<void> _loadVideoSources() async {
    if (widget.episode != null && widget.episode!['videoSources'] != null) {
      _videoSources = (widget.episode!['videoSources'] as List).map((source) {
        final src = Map<String, dynamic>.from(source as Map);
        return {
          ...src,
          'url': src['videoUrl'] ?? src['url'] ?? '',
        };
      }).toList();
    } else {
      _videoSources = [
        {
          'name': 'Varsayılan',
          'quality': 'HD',
          'url': widget.videoUrl,
        }
      ];
    }
    setState(() {});
  }

  String get _currentVideoUrl {
    if (_videoSources.isNotEmpty &&
        _selectedSourceIndex < _videoSources.length) {
      final url = _videoSources[_selectedSourceIndex]['url'];
      if (url != null && url.toString().isNotEmpty) return url;
    }
    return widget.episode?['videoUrl'] ?? widget.videoUrl;
  }

  Future<void> _initializeVideo() async {
    try {
      final videoUrl = _currentVideoUrl;
      if (videoUrl.isEmpty) {
        _showErrorSnackBar('Video linki bulunamadı');
        return;
      }

      if (_shouldUseWebView(videoUrl)) {
        _loadWebView(videoUrl);
        setState(() {
          _isVideoInitialized = true;
          _isWebViewVideoPlaying = false;
        });
      } else {
        await _initializeVideoPlayer(videoUrl);
      }
    } catch (e) {
      debugPrint('Video initialization error: $e');
      _showErrorSnackBar('Video başlatma hatası: $e');
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoController!.initialize();

    // Load saved position
    final prefs = await SharedPreferences.getInstance();
    final savedPosition =
        prefs.getInt('video_position_${widget.episodeTitle}') ?? 0;
    if (savedPosition > 0) {
      await _videoController!.seekTo(Duration(milliseconds: savedPosition));
    }

    _videoController!.addListener(_onVideoPlayerStateChanged);

    setState(() {
      _isVideoInitialized = true;
      _showVideoControls = true;
    });

    _startControlsTimer();
  }

  void _onVideoPlayerStateChanged() {
    if (mounted) {
      setState(() {});
      _saveVideoPosition();
    }
  }

  void _loadWebView(String videoUrl) {
    final htmlContent = _generateWebViewHtml(videoUrl);
    _webViewController.loadHtmlString(htmlContent);
  }

  String _generateWebViewHtml(String videoUrl) {
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      final videoId = _extractYouTubeId(videoUrl);
      if (videoId != null) {
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
            src="https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&controls=0&showinfo=0&rel=0" 
            allow="autoplay; encrypted-media;" 
            allowfullscreen>
          </iframe>
        </body>
        </html>
        ''';
      }
    }

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
        src="$videoUrl${videoUrl.contains('?') ? '&' : '?'}autoplay=1&mute=1&controls=0" 
        allow="autoplay; encrypted-media;"
        allowfullscreen>
      </iframe>
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

  bool _shouldUseWebView(String videoUrl) {
    final url = videoUrl.toLowerCase();

    // Direct video files use native player
    if (url.endsWith('.mp4') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv') ||
        url.endsWith('.mov') ||
        url.endsWith('.wmv') ||
        url.endsWith('.flv') ||
        url.endsWith('.webm') ||
        url.endsWith('.m3u8')) {
      return false;
    }

    // Online platforms use WebView
    return url.contains('sibnet.ru') ||
        url.contains('ok.ru') ||
        url.contains('vk.com') ||
        url.contains('rumble') ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');
  }

  Future<void> _switchVideoSource(int newIndex) async {
    if (_selectedSourceIndex == newIndex || _isSwitchingSource) return;

    setState(() {
      _isSwitchingSource = true;
      _selectedSourceIndex = newIndex;
    });

    _showInfoSnackBar('Kaynak değiştiriliyor...');

    // Dispose current video controller
    await _videoController?.dispose();
    _videoController = null;

    setState(() {
      _isVideoInitialized = false;
    });

    _hideControlsTimer?.cancel();
    await _initializeVideo();

    setState(() {
      _isSwitchingSource = false;
    });
  }

  // VIDEO CONTROLS
  void _toggleVideoControls() {
    setState(() {
      _showVideoControls = !_showVideoControls;
    });

    if (_showVideoControls) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showVideoControls = false;
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
    }
  }

  Future<void> _saveVideoPosition() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final position = _videoController!.value.position.inMilliseconds;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('video_position_${widget.episodeTitle}', position);
    }
  }

  void _navigateToFullScreenPlayer() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _openVideoPlayer();
    }
  }

  Future<void> _openVideoPlayer() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      await _saveVideoPosition();
      _videoController!.pause();
    }

    final videoUrl = _currentVideoUrl;
    final shouldUseWebView = _shouldUseWebView(videoUrl);

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

    // Restore video position after returning
    if (_videoController != null && _videoController!.value.isInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final savedPosition =
          prefs.getInt('video_position_${widget.episodeTitle}') ?? 0;
      if (savedPosition > 0) {
        await _videoController!.seekTo(Duration(milliseconds: savedPosition));
      }
    }
  }

  // DATA MANAGEMENT
  Future<void> _loadViewCount() async {
    try {
      final doc =
          await _firestore.collection('videos').doc(widget.episodeTitle).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _viewCount = (data['views'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('View count loading error: $e');
    }
  }

  Future<void> _incrementViewCount() async {
    if (_hasIncrementedView) return;

    try {
      final docRef = _firestore.collection('videos').doc(widget.episodeTitle);

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
            'views': currentViews + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // Update local state
        if (mounted) {
          setState(() {
            _viewCount = currentViews + 1;
          });
        }
      });

      _hasIncrementedView = true;
    } catch (e) {
      debugPrint('View count increment error: $e');
    }
  }

  Future<void> _loadSeriesTitleFromGitHub() async {
    try {
      final allSeries = await _githubService.fetchSeries();
      String? foundSeriesTitle;

      for (var series in allSeries) {
        if (widget.episodeTitle
            .toLowerCase()
            .contains(series.title.toLowerCase())) {
          foundSeriesTitle = series.title;
          break;
        }

        // Check episodes
        for (var season in series.seasons) {
          for (var episode in season.episodes) {
            if (episode.title.toLowerCase() ==
                    widget.episodeTitle.toLowerCase() ||
                episode.videoUrl == widget.videoUrl) {
              foundSeriesTitle = series.title;
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
      }
    } catch (e) {
      debugPrint('Series title loading error: $e');
      if (mounted) {
        setState(() {
          _isLoadingSeriesTitle = false;
        });
      }
    }
  }

  // FAVORITE MANAGEMENT
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

      if (mounted) {
        setState(() {
          _isFavorite = doc.exists;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Favorite check error: $e');
      if (mounted) {
        setState(() {
          _isCheckingFavorite = false;
        });
      }
    }
  }

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
      final userRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(widget.episodeTitle);

      if (_isFavorite) {
        await userRef.delete();
        _showSuccessSnackBar('Favorilerden kaldırıldı');
      } else {
        await userRef.set({
          'title': widget.episodeTitle,
          'videoUrl': widget.videoUrl,
          'thumbnailUrl': widget.thumbnailUrl,
          'seriesId': widget.seriesId,
          'episodeId': widget.episodeId,
          'seasonIndex': widget.seasonIndex,
          'episodeIndex': widget.episodeIndex,
          'addedAt': FieldValue.serverTimestamp(),
        });
        _showSuccessSnackBar('Favorilere eklendi');
      }

      await _checkIfFavorite();
    } catch (e) {
      debugPrint('Favorite toggle error: $e');
      _showErrorSnackBar('İşlem gerçekleştirilemedi');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // WATCH HISTORY
  Future<void> _saveToWatchHistory() async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('watchHistory')
          .doc(widget.episodeTitle)
          .set({
        'videoTitle': widget.episodeTitle,
        'title': widget.episodeTitle,
        'videoUrl': widget.videoUrl,
        'thumbnailUrl': widget.thumbnailUrl,
        'seriesId': widget.seriesId,
        'episodeId': widget.episodeId,
        'seasonIndex': widget.seasonIndex,
        'episodeIndex': widget.episodeIndex,
        'lastWatched': FieldValue.serverTimestamp(),
        'watchedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Watch history save error: $e');
    }
  }

  // COMMENTS MANAGEMENT
  Future<void> _loadComments() async {
    if (widget.episodeId == null || widget.episodeId!.isEmpty) {
      // Fallback to using title if episodeId is empty
      if (widget.episodeTitle.isNotEmpty) {
        await _loadCommentsByTitle();
        return;
      }

      setState(() => _isLoadingComments = false);
      return;
    }

    setState(() {
      _isLoadingComments = true;
      _comments = [];
      _commentUsers = {};
    });

    try {
      final snapshot = await _firestore
          .collection('comments')
          .where('episodeId', isEqualTo: widget.episodeId)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() => _isLoadingComments = false);
        return;
      }

      final comments = <Map<String, dynamic>>[];
      final userIds = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        comments.add(data);
        if (data['userId'] != null && data['userId'].toString().isNotEmpty) {
          userIds.add(data['userId']);
        }
      }

      // Sort comments by date (client-side)
      comments.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      // Load user data
      if (userIds.isNotEmpty) {
        final List<String> userIdsList = userIds.toList();
        final Map<String, Map<String, dynamic>> usersMap = {};

        for (int i = 0; i < userIdsList.length; i += 10) {
          final batch = userIdsList.skip(i).take(10).toList();
          try {
            final usersSnapshot = await _firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

            for (var doc in usersSnapshot.docs) {
              if (doc.exists && doc.data().isNotEmpty) {
                usersMap[doc.id] = doc.data();
              }
            }
          } catch (e) {
            debugPrint('User batch load error: $e');
            continue;
          }
        }

        if (mounted) {
          setState(() {
            _comments = comments;
            _commentUsers = usersMap;
            _isLoadingComments = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _comments = comments;
            _isLoadingComments = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Comments loading error: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _commentUsers = {};
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _loadCommentsByTitle() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final snapshot = await _firestore
          .collection('comments')
          .where('episodeId', isEqualTo: widget.episodeTitle)
          .get();

      final comments = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        comments.add(data);
      }

      // Sort comments manually
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
    } catch (e) {
      debugPrint('Comments loading by title error: $e');
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _addComment() async {
    final user = _auth.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      _showErrorSnackBar('Lütfen bir yorum yazın');
      return;
    }

    final episodeId = widget.episodeId ?? widget.episodeTitle;
    if (episodeId.isEmpty) {
      _showErrorSnackBar('Bölüm bilgisi bulunamadı');
      return;
    }

    setState(() {
      _isAddingComment = true;
    });

    try {
      // Get user name
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
          userName = user.displayName ??
              user.email?.split('@')[0] ??
              'Bilinmeyen Kullanıcı';
        }
      } catch (e) {
        debugPrint('User name fetch error: $e');
        userName = user.displayName ??
            user.email?.split('@')[0] ??
            'Bilinmeyen Kullanıcı';
      }

      await _firestore.collection('comments').add({
        'episodeId': episodeId,
        'userId': user.uid,
        'userEmail': user.email ?? 'Bilinmeyen Kullanıcı',
        'userName': userName,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'photoUrl': user.photoURL,
      });

      _commentController.clear();
      _showSuccessSnackBar('Yorum başarıyla eklendi');
      await _loadComments();
    } catch (e) {
      debugPrint('Comment add error: $e');
      _showErrorSnackBar('Yorum eklenirken hata oluştu');
    } finally {
      setState(() {
        _isAddingComment = false;
      });
    }
  }

  Future<void> _deleteComment(String commentId, String userId) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      _showErrorSnackBar('Bu yorumu silme yetkiniz yok');
      return;
    }

    try {
      await _firestore.collection('comments').doc(commentId).delete();
      _showSuccessSnackBar('Yorum silindi');
      await _loadComments();
    } catch (e) {
      debugPrint('Comment delete error: $e');
      _showErrorSnackBar('Yorum silinirken hata oluştu');
    }
  }

  // ADS MANAGEMENT
  Future<void> _loadAds() async {
    _loadInterstitialAd();
    _loadBannerAd();
  }

  Future<void> _loadInterstitialAd() async {
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
              _openVideoPlayer();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _openVideoPlayer();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial ad load error: $error');
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
          debugPrint('Banner ad load error: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  // NAVIGATION
  void _navigateToPreviousEpisode() {
    if (widget.episodeList == null || widget.currentIndex == null) return;
    if (widget.currentIndex! <= 0) return;

    final previousEpisode = widget.episodeList![widget.currentIndex! - 1];
    _navigateToEpisode(previousEpisode, widget.currentIndex! - 1);
  }

  void _navigateToNextEpisode() {
    if (widget.episodeList == null || widget.currentIndex == null) return;
    if (widget.currentIndex! >= widget.episodeList!.length - 1) return;

    final nextEpisode = widget.episodeList![widget.currentIndex! + 1];
    _navigateToEpisode(nextEpisode, widget.currentIndex! + 1);
  }

  void _navigateToEpisode(Map<String, dynamic> episode, int index) {
    final episodeId = episode['episodeId'] ?? episode['id'] ?? episode['title'];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: episode['videoUrl'] ?? '',
          episodeTitle: episode['title'] ?? 'Bölüm',
          thumbnailUrl: episode['thumbnail'],
          seriesId: widget.seriesId,
          episodeId: episodeId,
          seasonIndex: widget.seasonIndex,
          episodeIndex: index,
          episodeList: widget.episodeList,
          currentIndex: index,
          episode: episode,
        ),
      ),
    );
  }

  // UTILITY METHODS
  String _formatViewCount(int viewCount) {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return viewCount.toString();
    }
  }

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

  void _shareVideo() async {
    try {
      await Share.share(
        'Bu harika videoyu izle: ${widget.episodeTitle}\n${widget.videoUrl}',
        subject: widget.episodeTitle,
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _copyComment(String comment) {
    Clipboard.setData(ClipboardData(text: comment));
    _showSuccessSnackBar('Yorum kopyalandı');
  }

  // SNACKBAR HELPERS
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // UI BUILDERS
  Widget _buildVideoPlayer() {
    if (_shouldUseWebView(_currentVideoUrl)) {
      return _buildWebViewPlayer();
    }

    if (_videoController != null && _isVideoInitialized) {
      return _buildNativeVideoPlayer();
    }

    return _buildVideoPlaceholder();
  }

  Widget _buildWebViewPlayer() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_showVideoControls)
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              children: [
                _buildControlButton(
                  icon: _isWebViewVideoPlaying ? Icons.pause : Icons.play_arrow,
                  onTap: () {
                    setState(() {
                      if (_isWebViewVideoPlaying) {
                        _isWebViewVideoPlaying = false;
                      } else {
                        _webViewController
                            .loadRequest(Uri.parse(_currentVideoUrl));
                        _isWebViewVideoPlaying = true;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildControlButton(
                  icon: Icons.fullscreen,
                  onTap: _navigateToFullScreenPlayer,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNativeVideoPlayer() {
    return GestureDetector(
      onTap: _toggleVideoControls,
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          children: [
            VideoPlayer(_videoController!),
            if (_showVideoControls)
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    _buildControlButton(
                      icon: _videoController!.value.isPlaying
                          ? Icons.pause_outlined
                          : Icons.play_arrow_outlined,
                      onTap: _togglePlayPause,
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      icon: Icons.fullscreen,
                      onTap: _navigateToFullScreenPlayer,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return GestureDetector(
      onTap: _navigateToFullScreenPlayer,
      child: widget.thumbnailUrl != null
          ? Stack(
              children: [
                Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.play_arrow_outlined,
                      color: Colors.blueAccent,
                      size: 48,
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blueAccent, size: 22),
      ),
    );
  }

  Widget _buildVideoSourceSelector() {
    if (_videoSources.length <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: const Text(
          'Video Kaynağı Seç',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        children: [
          if (_isSwitchingSource)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blue),
              ),
            ),
          ...List.generate(_videoSources.length, (i) {
            final source = _videoSources[i];
            final isSelected = _selectedSourceIndex == i;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  source['name'] ?? 'Kaynak ${i + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.blue[700] : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  source['quality'] ?? '',
                  style: TextStyle(
                    color: isSelected ? Colors.blue[300] : Colors.grey[400],
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () => _switchVideoSource(i),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEpisodeInfo() {
    return Padding(
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
          Row(
            children: [
              const Icon(Icons.visibility, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                "${_formatViewCount(_viewCount)} görüntüleme",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeNavigation() {
    if (widget.episodeList == null || widget.currentIndex == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (widget.currentIndex! > 0)
                  ? _navigateToPreviousEpisode
                  : null,
              icon:
                  const Icon(Icons.skip_previous_outlined, color: Colors.white),
              label: const Text(
                'Önceki Bölüm',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: (widget.currentIndex! > 0)
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.grey.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (widget.currentIndex! < widget.episodeList!.length - 1)
                  ? _navigateToNextEpisode
                  : null,
              icon: const Icon(Icons.skip_next_outlined, color: Colors.white),
              label: const Text(
                'Sonraki Bölüm',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (widget.currentIndex! < widget.episodeList!.length - 1)
                        ? Colors.blue.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
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
            child: _buildActionButton(
              icon: Icons.share_outlined,
              label: 'Paylaş',
              onTap: _shareVideo,
              color: Colors.blue,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildActionButton(
              icon: _isProcessing
                  ? null
                  : (_isFavorite ? Icons.favorite : Icons.favorite_border),
              label: _isProcessing
                  ? 'İşleniyor...'
                  : (_isFavorite ? 'Favorilerde' : 'Favorile'),
              onTap: (_isCheckingFavorite || _isProcessing)
                  ? null
                  : _toggleFavorite,
              color: _isFavorite ? Colors.red : Colors.red,
              isLoading: _isProcessing,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildActionButton(
              icon: Icons.more_horiz,
              label: 'Daha Fazla',
              onTap: _showOptionsMenu,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
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
                child: CircularProgressIndicator(strokeWidth: 1),
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

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[800]);
  }

  Widget _buildCommentsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentsHeader(),
          _buildCommentInput(),
          _buildCommentsList(),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.comment, color: Colors.white, size: 20),
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
    );
  }

  Widget _buildCommentInput() {
    if (_auth.currentUser == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white54, size: 20),
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
                MaterialPageRoute(builder: (context) => const SignInPage()),
              ),
              child:
                  const Text('Giriş Yap', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    return Container(
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
              hintStyle: TextStyle(color: Colors.white54),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _addComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Yorum Yap',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoadingComments) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Henüz yorum yapılmamış.\nİlk yorumu siz yapın!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.white.withOpacity(0.1),
        height: 1,
      ),
      itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final userId = comment['userId'];
    final userData = _commentUsers[userId];
    final createdAt = comment['createdAt'] as Timestamp?;
    final timeAgo =
        createdAt != null ? _formatTimeAgo(createdAt.toDate()) : 'Bilinmiyor';

    String userName =
        userData?['username'] ?? comment['userName'] ?? 'Silinmiş Kullanıcı';
    final photoUrl = userData?['photoUrl'] ?? comment['photoUrl'];
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'S';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    (photoUrl != null && photoUrl.toString().isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                backgroundColor: Colors.red,
                child: (photoUrl == null || photoUrl.toString().isEmpty)
                    ? Text(
                        userInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showCommentOptions(comment),
                icon: const Icon(Icons.more_vert,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment['comment']?.toString() ?? '',
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

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
            ListTile(
              leading: const Icon(Icons.copy_all_outlined, color: Colors.blue),
              title:
                  const Text('Kopyala', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _copyComment(comment['comment']?.toString() ?? '');
              },
            ),
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment['id'], comment['userId']);
                },
              ),
            if (!isOwnComment)
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.red),
                title: const Text('Rapor Et',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessSnackBar('Yorum rapor edildi');
                },
              ),
          ],
        ),
      ),
    );
  }

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
              leading: const Icon(Icons.info_outlined, color: Colors.blue),
              title: const Text('Bilgi', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showInfoSnackBar('Video bilgileri gösteriliyor');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined, color: Colors.red),
              title:
                  const Text('Rapor Et', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showSuccessSnackBar('Video rapor edildi');
              },
            ),
          ],
        ),
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
                  : 'Bölüm Detayları',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
                      child: _buildVideoPlayer(),
                    ),

                    // Episode Info
                    _buildEpisodeInfo(),

                    const Divider(
                        color: Colors.grey, thickness: 0.5, height: 15),

                    // Episode Navigation
                    _buildEpisodeNavigation(),

                    // Action Buttons
                    _buildActionButtons(),

                    // Video Source Selector
                    _buildVideoSourceSelector(),

                    const SizedBox(height: 24),

                    // Comments Section
                    _buildCommentsSection(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Banner Ad
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
