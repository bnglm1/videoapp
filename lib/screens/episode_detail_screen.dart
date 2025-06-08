import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:videoapp/screens/video_player_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math'; // Rastgele sayı üreteci için bu import satırını ekleyin
import 'package:videoapp/utils/custom_snackbar.dart';
import 'package:videoapp/screens/sign_in_page.dart'; // Yeni eklenen import

class EpisodeDetailsPage extends StatefulWidget {
  final String videoUrl;
  final String episodeTitle;
  final String? thumbnailUrl;
  final String? seriesId;
  final String? episodeId;
  final int? seasonIndex;
  final int? episodeIndex;

  const EpisodeDetailsPage({
    required this.videoUrl,
    required this.episodeTitle,
    this.thumbnailUrl,
    this.seriesId,
    this.episodeId,
    this.seasonIndex,
    this.episodeIndex,
    super.key,
  });

  @override
  State<EpisodeDetailsPage> createState() => _EpisodeDetailsPageState();
}

class _EpisodeDetailsPageState extends State<EpisodeDetailsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Favori durumu
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;
  bool _isProcessing = false; // Yeni eklenen: İşlem durumu

  // Mevcut sınıf değişkenlerine ek olarak:
  int _addedViewCount = 0; // Yeni eklenen görüntüleme sayısını tutacak değişken
  final Random _random = Random();
  bool _hasIncrementedView = false;
  
  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _loadBannerAd();
    _checkIfFavorite();
    _saveToWatchHistory();
    _incrementViewCounts(); // isim değişti, çoğul oldu
  }

  Future<void> _loadInterstitialAd() async {
    // Mevcut reklamı temizle
    _interstitialAd?.dispose();
    _isAdLoaded = false;
    
    // Yeni reklam yükle
    await InterstitialAd.load(
      adUnitId: 'ca-app-pub-7690250755006392/8813706277',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
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

  // Videonun favori olup olmadığını kontrol et
  Future<void> _checkIfFavorite() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isCheckingFavorite = false;
      });
      return;
    }

    try {
      // Aynı document ID oluşturma mantığını burada da kullanın
      final String docId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('favorites')
          .doc(docId) // Burada da widget.episodeId yerine docId kullanın
          .get();

      setState(() {
        _isFavorite = doc.exists;
        _isCheckingFavorite = false;
      });
    } catch (e) {
      print("Favori kontrolünde hata: $e");
      setState(() {
        _isCheckingFavorite = false;
      });
    }
  }

  // Favorilere ekle/kaldır
  Future<void> _toggleFavorite() async {
    if (_auth.currentUser == null) {
      // Kullanıcı giriş yapmamışsa
      CustomSnackbar.show(
        context: context,
        message: 'Favorilere eklemek için giriş yapmalısınız',
        type: SnackbarType.info,
        actionLabel: 'Giriş Yap',
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SignInPage()),
          );
        },
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isFavorite) {
        await _removeFavorite();
        CustomSnackbar.show(
          context: context,
          message: 'Video favorilerden kaldırıldı',
          type: SnackbarType.info,
        );
      } else {
        await _addToFavorite();
        CustomSnackbar.show(
          context: context,
          message: 'Video favorilere eklendi',
          type: SnackbarType.success,
        );
      }
      
      await _checkIfFavorite();
    } catch (e) {
      print('Favori işleminde hata: $e');
      CustomSnackbar.show(
        context: context,
        message: 'İşlem sırasında bir hata oluştu',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Favoriden silme metodu
  Future<void> _removeFavorite() async {
    try {
      // Daha güvenli bir document ID oluşturma (episodeId null olabilir)
      final String docId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      
      await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('favorites')
        .doc(docId) // widget.episodeId yerine docId kullanın
        .delete();
    
      setState(() {
        _isFavorite = false;
      });
    } catch (e) {
      print('Favoriden kaldırma hatası: $e');
      rethrow; // Üst metotta yakalanacak
    }
  }

  // Favoriye ekleme metodu
  Future<void> _addToFavorite() async {
    try {
      // Daha güvenli bir document ID oluşturma (episodeId null olabilir)
      final String docId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    
      await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('favorites')
        .doc(docId) // widget.episodeId yerine docId kullanın
        .set({
          'videoId': docId, // widget.episodeId yerine docId kullanın
          'videoUrl': widget.videoUrl,
          'videoTitle': widget.episodeTitle,
          'thumbnailUrl': widget.thumbnailUrl,
          'seriesId': widget.seriesId,
          'addedAt': FieldValue.serverTimestamp(),
        });
    
      setState(() {
        _isFavorite = true;
      });
    } catch (e) {
      print('Favoriye ekleme hatası: $e');
      rethrow; // Üst metotta yakalanacak
    }
  }

  void _showAdOrNavigate() async {
    try {
      await _incrementViewCount();
      
      // Reklam yüklenip yüklenmediğinden bağımsız olarak her seferinde gösterelim
      // Kullanıcıya yükleme göster
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.orangeAccent),
          ),
        );
      }
      
      // Her navigasyon için reklam yükleme girişimi yap
      await _loadInterstitialAd();
      
      // Yüklemeye zaman tanı (maksimum 2 saniye)
      await Future.delayed(const Duration(seconds: 2));
      
      // Dialog'u kapat
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Reklam yüklendiyse göster
      if (_isAdLoaded && _interstitialAd != null) {
        _interstitialAd!.show().catchError((error) {
          print("Reklam gösterme hatası: $error");
          _navigateToVideoPlayer();
        });
      } else {
        _navigateToVideoPlayer();
      }
    } catch (e) {
      print("Ad gösterme sürecinde hata: $e");
      _navigateToVideoPlayer();
    }
  }

  void _navigateToVideoPlayer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: widget.videoUrl,
          videoTitle: widget.episodeTitle,
        ),
      ),
    );
  }

  // _incrementViewCount metodunu güncelleyin
  Future<void> _incrementViewCount() async {
    try {
      // Rastgele 5 ile 9 arasında bir artış miktarı belirle
      final Random random = Random();
      _addedViewCount = random.nextInt(5) + 5; // 5-9 arası rastgele sayı
      
      // Daha güvenli bir document ID oluşturma
      final String docId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      
      final videoDoc = _firestore.collection('videos').doc(docId);

      // Set yerine update kullanarak daha güvenli işlem - rastgele artış miktarını kullan
      await videoDoc.set(
        {
          'title': widget.episodeTitle,
          'url': widget.videoUrl,
          'viewCount': FieldValue.increment(_addedViewCount), // Rastgele artış
          'lastViewed': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print("Görüntülenme sayısı artırılırken hata: $e");
      _addedViewCount = 0; // Hata durumunda sıfırla
    }
  }

  // İzleme sayaçlarını artırma metodu
  Future<void> _incrementViewCounts() async {
    if (_hasIncrementedView) return; // İşlem zaten yapıldıysa tekrar yapma
    
    try {
      // Daha güvenli bir document ID oluşturma
      final String docId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      
      final videoDoc = _firestore.collection('videos').doc(docId);
      
      // Rastgele 5 ile 9 arasında bir artış miktarı belirle
      final int randomIncrement = _random.nextInt(5) + 5; // 5-9 arası
      
      // Firestore'da tek işlemle iki farklı sayaç güncellenir
      await videoDoc.set(
        {
          'title': widget.episodeTitle,
          'url': widget.videoUrl,
          'actualViewCount': FieldValue.increment(1), // Gerçek izleme +1
          'displayViewCount': FieldValue.increment(randomIncrement), // Göstermelik izleme +5-9
          'lastViewed': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      
      _hasIncrementedView = true;
    } catch (e) {
      print("Görüntülenme sayıları artırılırken hata: $e");
    }
  }
  
  // İzleme geçmişine kaydetme fonksiyonu
  Future<void> _saveToWatchHistory() async {
    if (_auth.currentUser == null) return;

    try {
      final videoId = widget.episodeId ?? 
          widget.episodeTitle.replaceAll(RegExp(r'[^\w\s]+'), '').trim();

      final userHistoryRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('watchHistory')
          .doc(videoId);

      await userHistoryRef.set({
        'videoId': videoId,
        'videoTitle': widget.episodeTitle,
        'videoUrl': widget.videoUrl,
        'thumbnailUrl': widget.thumbnailUrl,
        'seriesId': widget.seriesId,
        'watchedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("İzleme geçmişine kaydedilirken hata: $e");
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // Yardımcı metod ekleyin
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Metotları ekleyin
  void _shareVideo() {
    // Paylaşılacak bilgileri hazırla
    final String videoTitle = widget.episodeTitle;
    final String shareMessage = "Beraber izleyelim mi kanka 🎬\n\n$videoTitle";
    
    // Paylaşım diyaloğunu göster
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true, // Bu özellik menünün daha fazla alan kaplamasını sağlar
      useSafeArea: true, // Güvenli alanları dikkate alır
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        // Alt kısma ekstra boşluk ekle
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30, // Ekran klavyesi + ekstra alan
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Videoyu Paylaş',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: TextEditingController(text: "Beraber izleyelim mi kanka 🎬"),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Mesajınız...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  fillColor: Colors.grey[850],
                  filled: true,
                ),
                maxLines: 2,
                onChanged: (value) {
                  // Kullanıcı mesajı değiştirirse burada işlenebilir
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // WhatsApp
                  _buildShareButton(
                    icon: FontAwesomeIcons.whatsapp,
                    label: 'WhatsApp',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _shareToApp(shareMessage, 'whatsapp');
                    },
                  ),
                  // Instagram
                  _buildShareButton(
                    icon: FontAwesomeIcons.instagram,
                    label: 'Instagram',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _shareToApp(shareMessage, 'instagram');
                    },
                  ),
                  // Telegram
                  _buildShareButton(
                    icon: FontAwesomeIcons.telegram,
                    label: 'Telegram',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _shareToApp(shareMessage, 'telegram');
                    },
                  ),
                  // Diğer
                  _buildShareButton(
                    icon: FontAwesomeIcons.share,
                    label: 'Diğer',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _shareToApp(shareMessage, '');
                    },
                  ),
                ],
              ),
            ),
            // Ekstra alan ekleyelim
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Uygulama özel paylaşım butonu
  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Belirli uygulamaya paylaşım yapma
  Future<void> _shareToApp(String message, String app) async {
    try {
      String customMessage = message;
      
      // App store linki ekle
      const appStoreLink = "https://play.google.com/store/apps/details?id=com.bintech.videoapp";
      
      // Video URL'ini veya özel link ekle
      if (widget.seriesId != null && widget.episodeId != null) {
        customMessage += "\n\nİzlemek için: https://playtoon.app/watch/${widget.seriesId}/${widget.episodeId}";
      }
      
      // App Store linki ekle
      customMessage += "\n\nUygulamayı indirmek için: $appStoreLink";
      
      if (app.isEmpty) {
        // Genel paylaşım diyaloğunu göster
        await Share.share(customMessage, subject: widget.episodeTitle);
      } else {
        // Belirli uygulamaya yönlendir
        // Not: Bu özellik cihaz ve işletim sistemi uyumluluğuna bağlıdır
        await Share.share(customMessage, subject: widget.episodeTitle);
        
        // Özel uygulama paylaşımı için kapsayıcı kod (platformlar arası uyumluluk için)
        // Bu bölüm gerçek bir uygulama ID'si ile genişletilebilir
      }
    } catch (e) {
      print("Paylaşım hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım sırasında bir hata oluştu: ${e.toString()}')),
      );
    }
  }

  void _downloadVideo() {
    // İndirme işlemleri
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('İndirme özelliği yakında eklenecek')),
    );
  }

  void _addToPlaylist() {
    // Listeye ekleme işlemleri
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liste özelliği yakında eklenecek')),
    );
  }

  // Ayarlar menüsü metodu
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Görsel gösterge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // "Bozuk İçeriği Bildir" seçeneği - sadece bu seçenek kaldı
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.orange),
              title: const Text('Bozuk İçeriği Bildir', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _reportBrokenContent(); // Basitleştirilmiş metot
              },
            ),
            
            // İptal butonu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('İptal', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bozuk içerik bildirme için basitleştirilmiş yeni metot
  Future<void> _reportBrokenContent() async {
    try {
      // E-posta adresi
      const String emailAddress = "playtoonapp@gmail.com"; // Kendi e-posta adresinizle değiştirin
      
      // Konu oluştur
      final String subject = "Bozuk İçerik Bildirimi: ${widget.episodeTitle}";
      
      // E-posta içeriği oluştur
      String body = "Bozuk İçerik Bildirimi\n\n";
      body += "Seri/Dizi: ${widget.seriesId ?? 'Belirtilmemiş'}\n";
      body += "Bölüm: ${widget.episodeTitle}\n";
      body += "Bölüm ID: ${widget.episodeId ?? 'Belirtilmemiş'}\n";
      body += "Sezon: ${widget.seasonIndex ?? 'Belirtilmemiş'}\n";
      body += "Bölüm Numarası: ${widget.episodeIndex ?? 'Belirtilmemiş'}\n\n";
      
      // Kullanıcı bilgilerini ekle
      final user = _auth.currentUser;
      if (user != null) {
        body += "Bildiren Kullanıcı: ${user.email ?? user.uid}\n";
      }
      
      body += "\nTarih: ${DateTime.now().toString()}\n";
      
      // mailto URL'i oluştur
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: emailAddress,
        query: encodeQueryParameters({
          'subject': subject,
          'body': body,
        }),
      );
      
      // E-posta uygulamasını aç
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        
        // Başarı mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildiriminiz için teşekkür ederiz. İçerik en kısa sürede düzeltilecektir.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('E-posta uygulaması açılamadı');
      }
    } catch (e) {
      print("E-posta gönderme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bozuk içerik bildirimi yapılırken bir sorun oluştu.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // URL query parametrelerini kodlama yardımcı fonksiyonu
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
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
          widget.episodeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ///
      ),
      
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Önizleme - Büyük ve daha estetik
                    Stack(
                      children: [
                        // Video Thumbnail/Önizleme
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black, Colors.grey[900]!],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            image: widget.thumbnailUrl != null ? DecorationImage(
                              image: NetworkImage(widget.thumbnailUrl!),
                              fit: BoxFit.cover,
                              opacity: 0.7,
                            ) : null,
                          ),
                        ),
                        
                        // Oynat Butonu Overlay
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showAdOrNavigate,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.orangeAccent, size: 50),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Sezon-Bölüm Bilgisi - Yeni eklenen özellik
                    if (widget.seasonIndex != null || widget.episodeIndex != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.withOpacity(0.5)),
                          ),
                          child: Text(
                            "Sezon ${widget.seasonIndex ?? '?'} • Bölüm ${widget.episodeIndex ?? '?'}",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    // Bölüm Başlığı - Daha büyük ve belirgin
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        widget.episodeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Video İstatistikleri - Yeni eklenen özellik
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('videos').doc(widget.episodeId).get(),
                        builder: (context, snapshot) {
                          int displayViewCount = 0;
                          
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            // Kullanıcılara göstermelik sayacı gösteriyoruz
                            displayViewCount = (data['displayViewCount'] as num?)?.toInt() ?? 0;
                            
                            // Eğer displayViewCount yoksa, eski viewCount'u kullan (geriye dönük uyumluluk için)
                            if (displayViewCount == 0) {
                              displayViewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
                            }
                          }
                          
                          // Görüntüleme sayısını daha okunabilir formata dönüştür
                          String formattedViewCount = _formatNumber(displayViewCount);
                          
                          return Row(
                            children: [
                              const Icon(Icons.visibility, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                "$formattedViewCount görüntüleme",
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          );
                        },
                      ),
                    ),


                    const Divider(color: Colors.grey, thickness: 0.5, height: 15),
                    
                    // Paylaş, İndir ve 3 Nokta Menü Butonları
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
                      margin: const EdgeInsets.all(16.0),
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
                          // Dikey ayırıcı
                          Container(width: 1, height: 40, color: Colors.grey[800]),
                          // İndirme butonu yerine favoriler butonu
                          Expanded(
                            child: _buildActionButtonNew(
                              icon: _isProcessing 
                                ? null // İşlem sürerken ikon gösterme
                                : (_isFavorite ? Icons.favorite : Icons.favorite_border),
                              label: _isProcessing 
                                ? 'İşleniyor...' 
                                : (_isFavorite ? 'Favorilerde' : 'Favorile'),
                              onTap: (_isCheckingFavorite || _isProcessing) ? null : _toggleFavorite, // İşlem sürerken devre dışı bırak
                              color: _isFavorite ? Colors.red : Colors.pink,
                              isLoading: _isProcessing, // Yeni yükleme parametresi
                            ),
                          ),
                          // Dikey ayırıcı
                          Container(width: 1, height: 40, color: Colors.grey[800]),
                          // Listeye Ekle yerine 3 nokta menüsü
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
                    
                    // Daha Fazla Bilgi Bölümü
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video Hakkında',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // İçerik açıklaması
                          FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('videos').doc(widget.episodeId).get(),
                            builder: (context, snapshot) {
                              String description = 'Bu içerik hakkında açıklama bulunmuyor.';
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final data = snapshot.data!.data() as Map<String, dynamic>;
                                if (data.containsKey('description') && data['description'] != null) {
                                  description = data['description'];
                                }
                              }
                              
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[850],
                                ),
                                child: Text(
                                  description,
                                  style: const TextStyle(color: Colors.white70),
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

            // Banner Reklam
            if (_isBannerAdLoaded && _bannerAd != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  width: _bannerAd!.size.width.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Yeniden tasarlanmış eylem butonu
  Widget _buildActionButtonNew({
    required IconData? icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    bool isLoading = false, // Yeni parametre ekleyin
  }) {
    return InkWell(
      onTap: onTap, // null olduğunda otomatik olarak devre dışı kalır
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0, // Devre dışı durumunda soluk görünüm
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sayıları formatlayan yardımcı metot
  String _formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
  }
}
