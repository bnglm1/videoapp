import 'dart:async'; // Stream için gerekli
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:videoapp/screens/episode_detail_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  
  // Stream abonelikleri
  StreamSubscription<QuerySnapshot>? _favoritesSubscription;
  StreamSubscription<QuerySnapshot>? _historySubscription;
  
  // Kullanıcı bilgileri
  String _username = '';
  String _email = '';
  String? _photoUrl;
  
  // Favoriler ve izleme geçmişi
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _watchHistory = [];
  
  // Yükleniyor durumları
  bool _isLoadingProfile = true;
  bool _isLoadingFavorites = true;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentUser = _auth.currentUser;
    _loadUserData();
    _setupFavoritesListener();
    _setupWatchHistoryListener();
  }

  // Kullanıcı bilgilerini yükle
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingProfile = true;
    });

    if (_currentUser != null) {
      try {
        // Firestore'dan kullanıcı bilgilerini al
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (!mounted) return;

        setState(() {
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            _username = userData['username'] ?? _currentUser!.displayName ?? 'Kullanıcı';
            _email = _currentUser!.email ?? '';
            _photoUrl = userData['photoUrl'] ?? _currentUser!.photoURL;
          } else {
            _username = _currentUser!.displayName ?? 'Kullanıcı';
            _email = _currentUser!.email ?? '';
            _photoUrl = _currentUser!.photoURL;
          }
          _isLoadingProfile = false;
        });
      } catch (e) {
        print('Kullanıcı bilgileri yüklenirken hata: $e');
        if (mounted) {
          setState(() {
            _username = _currentUser!.displayName ?? 'Kullanıcı';
            _email = _currentUser!.email ?? '';
            _photoUrl = _currentUser!.photoURL;
            _isLoadingProfile = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  // Favoriler için Stream Dinleyici - Gerçek zamanlı güncellemeler için
  void _setupFavoritesListener() {
    setState(() {
      _isLoadingFavorites = true;
    });

    if (_currentUser == null) {
      setState(() {
        _isLoadingFavorites = false;
      });
      return;
    }

    // Favorileri stream olarak dinle
    _favoritesSubscription = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          
          List<Map<String, dynamic>> favorites = [];
          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;
            favorites.add(data);
          }

          setState(() {
            _favorites = favorites;
            _isLoadingFavorites = false;
          });
        }, onError: (e) {
          print('Favoriler dinlenirken hata: $e');
          if (mounted) {
            setState(() {
              _isLoadingFavorites = false;
            });
          }
        });
  }

  // İzleme geçmişi için Stream Dinleyici - Gerçek zamanlı güncellemeler için
  void _setupWatchHistoryListener() {
    setState(() {
      _isLoadingHistory = true;
    });

    if (_currentUser == null) {
      setState(() {
        _isLoadingHistory = false;
      });
      return;
    }

    // İzleme geçmişini stream olarak dinle
    _historySubscription = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('watchHistory')
        .orderBy('lastWatched', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          
          List<Map<String, dynamic>> history = [];
          for (var doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;
            history.add(data);
          }

          setState(() {
            _watchHistory = history;
            _isLoadingHistory = false;
          });
        }, onError: (e) {
          print('İzleme geçmişi dinlenirken hata: $e');
          if (mounted) {
            setState(() {
              _isLoadingHistory = false;
            });
          }
        });
  }

  // İstatistik kart widgeti
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Boş durum göstergesi
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 70,
              color: Colors.blue[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Modern profil başlığı
  Widget _buildProfileHeader() {
    if (_isLoadingProfile) {
      return Container(
        height: 200,
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Container(
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade800,
            Colors.black,
          ],
        ),
      ),
      child: Column(
        children: [
          // Profil Resmi
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[800],
              backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
              child: _photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white70) : null,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Kullanıcı Adı
          Text(
            _username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          
          // Email
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              _email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // İstatistikler
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  "Favoriler",
                  _isLoadingFavorites ? "..." : _favorites.length.toString(),
                  Icons.favorite,
                  Colors.red,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[700],
                ),
                _buildStatCard(
                  "İzlenmiş",
                  _isLoadingHistory ? "..." : _watchHistory.length.toString(),
                  Icons.visibility,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Favoriler tabı
  Widget _buildFavoritesTab() {
    if (_isLoadingFavorites) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_favorites.isEmpty) {
      return _buildEmptyState('Henüz favorilere eklediğiniz video yok', Icons.favorite_border);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        
        // Basitleştirilmiş kart yapısı
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 3,
          child: InkWell(
            onTap: () => _openVideoFromFavorites(favorite),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Thumbnail - sabit boyut
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: favorite['thumbnailUrl'] != null
                        ? Image.network(
                            favorite['thumbnailUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, _) => Container(
                              color: Colors.grey[700],
                              child: const Icon(Icons.movie, color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[700],
                            child: const Icon(Icons.movie, color: Colors.white54),
                          ),
                    ),
                  ),
                  
                  // İçerik bilgileri - esnek alan
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            favorite['videoTitle'] ?? 'Bilinmeyen Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (favorite['addedAt'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _formatTimeAgo(favorite['addedAt']),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Butonlar - sağ kenar
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Oynat butonu
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.blue, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _openVideoFromFavorites(favorite),
                      ),
                      // Sil butonu
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _removeFavorite(favorite['videoId']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Favori videoyu aç - artık eski yenileme kaldırıldı
  void _openVideoFromFavorites(Map<String, dynamic> favorite) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: favorite['videoUrl'],
          episodeTitle: favorite['videoTitle'],
          thumbnailUrl: favorite['thumbnailUrl'],
          seriesId: favorite['seriesId'],
          episodeId: favorite['videoId'],
        ),
      ),
    );
    // Artık .then içinde yenilemeye gerek yok - stream otomatik güncelliyor
  }

  // Favoriyi sil
  Future<void> _removeFavorite(String videoId) async {
    try {
      // Silme işlemi için onay al
      bool confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('Favorilerden Kaldır', style: TextStyle(color: Colors.white)),
          content: const Text('Bu video favorilerinizden kaldırılacak. Emin misiniz?', 
            style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmed) return;

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(videoId)
          .delete();

      // setState artık gerekli değil - stream otomatik güncelliyor

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video favorilerinizden kaldırıldı')),
      );
    } catch (e) {
      print('Favori silinirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favori kaldırılırken bir hata oluştu')),
      );
    }
  }

  // İzleme geçmişi tabı
  Widget _buildWatchHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (_watchHistory.isEmpty) {
      return _buildEmptyState('Henüz izleme geçmişiniz yok', Icons.history);
    }

    return Column(
      children: [
        // Temizleme butonu
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _confirmClearAllHistory,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Geçmişi Temizle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        
        // İzleme geçmişi listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _watchHistory.length,
            itemBuilder: (context, index) {
              final historyItem = _watchHistory[index];
              final bool isFirstDayItem = index == 0 || 
                  !_isSameDay(_watchHistory[index-1]['lastWatched'], historyItem['lastWatched']);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih başlığı
                  if (isFirstDayItem)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
                      child: Text(
                        _formatDateHeader(historyItem['lastWatched']),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                  // Video kartı
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openVideoFromHistory(historyItem),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Video küçük resmi
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 90,
                                      height: 60,
                                      child: historyItem['thumbnailUrl'] != null ?
                                        Image.network(
                                          historyItem['thumbnailUrl'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, _) => Container(
                                            color: Colors.grey[700],
                                            child: const Icon(Icons.movie, color: Colors.white54),
                                          ),
                                        ) : 
                                        Container(
                                          color: Colors.grey[700],
                                          child: const Icon(Icons.movie, color: Colors.white54),
                                        ),
                                    ),
                                  ),
                                  // İzleme sayısı göstergesi
                                  if ((historyItem['watchCount'] ?? 0) > 1)
                                    Positioned(
                                      right: 5,
                                      bottom: 5,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${historyItem['watchCount']}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Video bilgileri
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      historyItem['videoTitle'] ?? 'Bilinmeyen Video',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(historyItem['lastWatched']),
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // İşlem butonları
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_outline, color: Colors.blue, size: 22),
                                    onPressed: () => _openVideoFromHistory(historyItem),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 20,
                                  ),
                                  const SizedBox(height: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                    onPressed: () => _deleteWatchHistoryItem(historyItem['id']),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    splashRadius: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // İzleme geçmişi videosunu açma metodu - artık eski yenileme kaldırıldı
  void _openVideoFromHistory(Map<String, dynamic> historyItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: historyItem['videoUrl'],
          episodeTitle: historyItem['videoTitle'] ?? 'Video',
          thumbnailUrl: historyItem['thumbnailUrl'],
          seriesId: historyItem['seriesId'],
          episodeId: historyItem['videoId'],
        ),
      ),
    );
    // Artık .then içinde yenilemeye gerek yok - stream otomatik güncelliyor
  }

  // İzleme geçmişinden tek bir öğeyi silme
  Future<void> _deleteWatchHistoryItem(String documentId) async {
    try {
      await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('watchHistory')
        .doc(documentId)
        .delete();
      
      // setState artık gerekli değil - stream otomatik güncelliyor
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İzleme geçmişinden kaldırıldı')),
      );
    } catch (e) {
      print('Geçmiş silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş silinirken bir hata oluştu')),
      );
    }
  }

  // Tüm izleme geçmişini silme onayı
  Future<void> _confirmClearAllHistory() async {
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Tüm Geçmişi Temizle', style: TextStyle(color: Colors.white)),
        content: const Text('Tüm izleme geçmişiniz silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      await _clearAllHistory();
    }
  }

  // Tüm izleme geçmişini silme
  Future<void> _clearAllHistory() async {
    try {
      final WriteBatch batch = _firestore.batch();
      final historyRef = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('watchHistory');
      
      final snapshot = await historyRef.get();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // setState artık gerekli değil - stream otomatik güncelliyor
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm izleme geçmişi temizlendi')),
      );
    } catch (e) {
      print('Tüm geçmişi silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş temizlenirken bir hata oluştu')),
      );
    }
  }

  // Yardımcı metotlar
  String _formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day.$month.$year';
    }
  }

  String _formatDateHeader(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Bugün';
    } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
      return 'Dün';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
  
  String _formatTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  bool _isSameDay(Timestamp timestamp1, Timestamp timestamp2) {
    final date1 = timestamp1.toDate();
    final date2 = timestamp2.toDate();
    
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxScrolled) => [
            // Modern Profil Başlığı
            SliverToBoxAdapter(
              child: _buildProfileHeader(),
            ),
            // Modern Tab Bar
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.favorite, size: 20),
                      text: 'Favoriler',
                    ),
                    Tab(
                      icon: Icon(Icons.history, size: 20),
                      text: 'İzleme Geçmişi',
                    ),
                  ],
                ),
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFavoritesTab(),
              _buildWatchHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Stream aboneliklerini iptal et
    _favoritesSubscription?.cancel();
    _historySubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}

// Tab bar için SliverPersistentHeaderDelegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  
  _SliverTabBarDelegate(this.tabBar);
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: tabBar,
    );
  }
  
  @override
  double get maxExtent => tabBar.preferredSize.height;
  
  @override
  double get minExtent => tabBar.preferredSize.height;
  
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}