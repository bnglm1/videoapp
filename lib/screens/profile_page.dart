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
    _loadUserData();
    _loadFavorites();
    _loadWatchHistory();
  }

  // Kullanıcı bilgilerini yükle
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingProfile = true;
    });

    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      try {
        // Firestore'dan kullanıcı bilgilerini al
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

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
        setState(() {
          _username = _currentUser!.displayName ?? 'Kullanıcı';
          _email = _currentUser!.email ?? '';
          _photoUrl = _currentUser!.photoURL;
          _isLoadingProfile = false;
        });
      }
    } else {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  // Favorileri yükle
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoadingFavorites = true;
    });

    if (_currentUser == null) {
      setState(() {
        _isLoadingFavorites = false;
      });
      return;
    }

    try {
      // Firestore'dan favorileri al
      QuerySnapshot favoritesSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      List<Map<String, dynamic>> favorites = [];
      for (var doc in favoritesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        favorites.add(data);
      }

      setState(() {
        _favorites = favorites;
        _isLoadingFavorites = false;
      });
    } catch (e) {
      print('Favoriler yüklenirken hata: $e');
      setState(() {
        _isLoadingFavorites = false;
      });
    }
  }

  // İzleme geçmişini yükle
  Future<void> _loadWatchHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    if (_currentUser == null) {
      setState(() {
        _isLoadingHistory = false;
      });
      return;
    }

    try {
      // Firestore'dan izleme geçmişini al
      QuerySnapshot historySnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('watchHistory')
          .orderBy('lastWatched', descending: true)
          .get();

      List<Map<String, dynamic>> history = [];
      for (var doc in historySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        history.add(data);
      }

      setState(() {
        _watchHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('İzleme geçmişi yüklenirken hata: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  // Favori videoyu aç
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
    ).then((_) {
      // Sayfa geri döndüğünde favorileri yenile
      _loadFavorites();
    });
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

      setState(() {
        _favorites.removeWhere((item) => item['videoId'] == videoId);
      });

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

  // Timestamp formatla
  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Boş durum mesajı
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
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
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: InkWell(
            onTap: () => _openVideoFromFavorites(favorite),
            borderRadius: BorderRadius.circular(15),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: favorite['thumbnailUrl'] != null ? 
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    favorite['thumbnailUrl'],
                    width: 60, height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, _) => Container(
                      width: 60, height: 80,
                      color: Colors.grey[700],
                      child: const Icon(Icons.error, color: Colors.white54),
                    ),
                  ),
                ) : Container(
                  width: 60, height: 80,
                  color: Colors.grey[700],
                  child: const Icon(Icons.movie, color: Colors.white54),
                ),
              title: Text(
                favorite['videoTitle'] ?? 'Bilinmeyen Video',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: favorite['addedAt'] != null ? Text(
                'Eklenme tarihi: ${_formatTimestamp(favorite['addedAt'])}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_filled, color: Colors.blue, size: 28),
                    onPressed: () => _openVideoFromFavorites(favorite),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                    onPressed: () => _removeFavorite(favorite['videoId']),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // İzleme geçmişi tabı
  Widget _buildWatchHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_watchHistory.isEmpty) {
      return _buildEmptyState('Henüz izleme geçmişiniz yok', Icons.history);
    }

    return Column(
      children: [
        // Tüm geçmişi silme butonu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _confirmClearAllHistory,
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                label: const Text('Tüm Geçmişi Temizle', 
                  style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
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
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.grey[850],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () => _openVideoFromHistory(historyItem),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: historyItem['thumbnailUrl'] != null ? 
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          historyItem['thumbnailUrl'],
                          width: 60, height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, _) => Container(
                            width: 60, height: 80,
                            color: Colors.grey[700],
                            child: const Icon(Icons.error, color: Colors.white54),
                          ),
                        ),
                      ) : Container(
                        width: 60, height: 80,
                        color: Colors.grey[700],
                        child: const Icon(Icons.movie, color: Colors.white54),
                      ),
                    title: Text(
                      historyItem['videoTitle'] ?? 'Bilinmeyen Video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'İzleme sayısı: ${historyItem['watchCount'] ?? 1}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        if (historyItem['lastWatched'] != null)
                          Text(
                            'Son izleme: ${_formatTimestamp(historyItem['lastWatched'])}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, 
                            color: Colors.blue, size: 28),
                          onPressed: () => _openVideoFromHistory(historyItem),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, 
                            color: Colors.red, size: 24),
                          onPressed: () => _deleteWatchHistoryItem(historyItem['id']),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // İzleme geçmişi videosunu açma metodu
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
    ).then((_) {
      // Sayfa geri döndüğünde geçmişi yenile
      _loadWatchHistory();
    });
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
      
      setState(() {
        _watchHistory.removeWhere((item) => item['id'] == documentId);
      });
      
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
      // Batch işlemi için çok sayıda belge olabilir, bu yüzden daha güvenli bir yöntem kullanıyoruz
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
      
      setState(() {
        _watchHistory = [];
      });
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profil', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Favoriler', icon: Icon(Icons.favorite)),
            Tab(text: 'İzleme Geçmişi', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Profil bilgileri
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey,
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Tab içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesTab(),
                _buildWatchHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}