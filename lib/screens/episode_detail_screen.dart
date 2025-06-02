import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'video_player_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class EpisodeDetailsPage extends StatefulWidget {
  final String videoUrl;
  final String episodeTitle;

  const EpisodeDetailsPage({
    required this.videoUrl,
    required this.episodeTitle,
    super.key,
  });

  @override
  State<EpisodeDetailsPage> createState() => _EpisodeDetailsPageState();
}

class _EpisodeDetailsPageState extends State<EpisodeDetailsPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  BannerAd? _bannerAd; // Banner reklam değişkeni
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _loadBannerAd(); // Banner reklamı yükle
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-7690250755006392/8813706277',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _navigateToVideoPlayer(); // Reklam kapanınca video ekranına geç
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _navigateToVideoPlayer();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print("Reklam yüklenemedi: $error");
        },
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7690250755006392/7705897910', // Banner reklam birim kimliği
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

  void _showAdOrNavigate() async {
    await _incrementViewCount();
    
    // Kullanıcıya yükleme göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orangeAccent),
      ),
    );
    
    // Reklamın yüklenmesi için gecikme ekle
    if (!_isAdLoaded) {
      // Reklam yüklü değilse, yüklenmesi için biraz bekle
      await Future.delayed(const Duration(seconds: 2));
    }
    
    // Dialog'u kapat
    Navigator.of(context).pop();
    
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      // Hala yüklenmediyse, son bir deneme daha yap
      InterstitialAd.load(
        adUnitId: 'ca-app-pub-7690250755006392/8813706277',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _navigateToVideoPlayer();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _navigateToVideoPlayer();
              },
            );
            // Reklamı göster
            ad.show();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print("Reklam yüklenemedi: $error");
            _navigateToVideoPlayer();
          },
        ),
      );
    }
  }

  void _navigateToVideoPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(videoUrl: widget.videoUrl),
      ),
    );
  }

  void _sendComment(String username, String comment) async {
    if (username.isEmpty || comment.isEmpty) return;

    try {
      final documentId = widget.episodeTitle;

      await FirebaseFirestore.instance
          .collection('comments')
          .doc(documentId)
          .collection('comments')
          .add({
        'username': username,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print("Yorum gönderildi.");
    } catch (e) {
      print("Yorum gönderilirken hata oluştu: $e");
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final videoDoc =
          FirebaseFirestore.instance.collection('videos').doc(widget.episodeTitle);

      await videoDoc.set(
        {'viewCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      print("Görüntülenme sayısı artırıldı.");
    } catch (e) {
      print("Görüntülenme sayısı artırılırken hata oluştu: $e");
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose(); // Banner reklamı temizle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.episodeTitle, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📌 Video Oynatıcı
                  GestureDetector(
                    onTap: _showAdOrNavigate,
                    child: Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black, Colors.grey[900]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, color: Colors.orangeAccent, size: 80),
                      ),
                    ),
                  ),

                  // 📌 Bölüm Başlığı
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.episodeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.grey, thickness: 1.0, height: 20.0),

                  // 📌 Yorum Yapma Alanı
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Yorum Yap",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Kullanıcı adınızı yazın..."),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Yorum yaz..."),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            final username = _usernameController.text.trim();
                            final comment = _commentController.text.trim();

                            if (username.isNotEmpty && comment.isNotEmpty) {
                              _sendComment(username, comment);
                              _usernameController.clear();
                              _commentController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          ),
                          child: const Text("Gönder"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📌 Banner Reklam
          if (_isBannerAdLoaded)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[800]!.withOpacity(0.7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }
}
