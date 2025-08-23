import 'dart:async'; // Stream için gerekli
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:videoapp/screens/episode_detail_screen.dart';
import 'package:videoapp/utils/custom_snackbar.dart'; // Özel Snackbar için import
// VideoPlayerPage için import ekleyin

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  // Stream abonelikleri
  StreamSubscription<List<Map<String, dynamic>>>? _favoritesSubscription;
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

  // Profil resmi için yeni değişkenler
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploadingImage = false;

  // Profil resmi seçme metodu:
  Future<void> _pickAndUploadImage() async {
    try {
      print("Resim seçme işlemi başlıyor...");

      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) {
        print("Kullanıcı resim kaynağını seçmedi");
        return;
      }

      print("Resim kaynağı seçildi: ${source.toString()}");

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) {
        print("Resim seçilmedi veya iptal edildi");
        return;
      }

      print("Resim seçildi: ${image.path}");
      print("Dosya boyutu: ${await File(image.path).length()} bytes");

      setState(() {
        _isUploadingImage = true;
      });

      final File imageFile = File(image.path);
      if (!await imageFile.exists()) {
        throw Exception("Seçilen dosya bulunamadı");
      }

      print("Firebase Storage'a yükleme başlıyor...");

      final String fileName =
          'profile_images/${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fileName);

      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print(
            'Upload progress: ${(progress * 100).toStringAsFixed(2)}% - ${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes');
      });

      print("Upload task oluşturuldu, bekleniyor...");
      final TaskSnapshot snapshot = await uploadTask;
      print("Upload tamamlandı, download URL alınıyor...");

      final String downloadURL = await snapshot.ref.getDownloadURL();
      print("Download URL alındı: $downloadURL");

      // DÜZELTME: Firestore'da kullanıcı profilini güncelle - merge kullan
      print("Firestore güncelleniyor...");
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'username': _username,
        'email': _email,
        'photoUrl': downloadURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Firestore güncellendi");

      // Firebase Auth profilini güncelleme
      try {
        print("Firebase Auth profili güncelleniyor...");
        await _currentUser!.updatePhotoURL(downloadURL);
        print("Firebase Auth profili güncellendi");

        await _currentUser!.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
      } catch (authError) {
        print(
            "Firebase Auth profil güncelleme hatası (önemli değil): $authError");
      }

      if (mounted) {
        setState(() {
          _photoUrl = downloadURL;
          _isUploadingImage = false;
        });

        CustomSnackbar.show(
          context: context,
          message: 'Profil resmi başarıyla güncellendi',
          type: SnackbarType.success,
        );
      }

      print("Profil resmi güncelleme işlemi tamamlandı");
    } catch (e, stackTrace) {
      print('Resim yükleme hatası: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });

        String errorMessage;
        if (e.toString().contains('network')) {
          errorMessage = 'İnternet bağlantınızı kontrol edin';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Uygulama izinlerini kontrol edin';
        } else if (e.toString().contains('storage')) {
          errorMessage = 'Dosya yükleme hatası. Tekrar deneyin';
        } else {
          errorMessage = 'Resim yüklenirken bir hata oluştu';
        }

        CustomSnackbar.show(
          context: context,
          message: errorMessage,
          type: SnackbarType.error,
        );
      }
    }
  }

  // Resim kaynağı seçme diyalogu:
  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              const Text(
                'Profil Resmi Seç',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Kamera seçeneği
              _buildImageSourceOption(
                icon: Icons.camera_alt,
                title: 'Kamera',
                subtitle: 'Yeni fotoğraf çek',
                gradient: [Colors.blue, Colors.blueAccent],
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),

              const SizedBox(height: 12),

              // Galeri seçeneği
              _buildImageSourceOption(
                icon: Icons.photo_library,
                title: 'Galeri',
                subtitle: 'Mevcut fotoğraflardan seç',
                gradient: [Colors.green, Colors.teal],
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),

              const SizedBox(height: 20),

              // İptal butonu
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'İptal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Resim kaynağı seçenek widget'ı:
  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: gradient),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Profil header'ın güncellenmiş hali (profil resmine tıklama özelliği ile):
  // profile_page.dart

// DEĞİŞTİRİLDİ: Profil başlığı widget'ı
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
          // Profil Resmi - Tıklanabilir (Mevcut kodunuz)
          Stack(
            children: [
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
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
                    backgroundImage:
                        _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
                        ? const Icon(Icons.person,
                            size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
              ),
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.7),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              if (!_isUploadingImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // --- DEĞİŞİKLİK BURADA ---
          // Kullanıcı Adı ve Düzenleme Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 44), // Butonun genişliği kadar boşluk
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
              // Düzenleme butonu
              IconButton(
                splashRadius: 20,
                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                onPressed: _showEditProfileDialog, // Yeni metodu çağır
              )
            ],
          ),
          // --- DEĞİŞİKLİK BİTTİ ---

          // Email (Mevcut kodunuz)
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

          // Profil resmi değiştirme ipucu (Mevcut kodunuz)
          if (!_isUploadingImage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Profil resmini değiştirmek için resme dokun',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 20),

          // İstatistikler (Mevcut kodunuz)
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

//Kullanıcı adı güncelleme diyalogunu gösteren metot

  Future<void> _showEditProfileDialog() async {
    final TextEditingController usernameController =
        TextEditingController(text: _username);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Profili Düzenle',
              style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Kullanıcı adı boş olamaz.';
                }
                if (value.length < 3) {
                  return 'Kullanıcı adı en az 3 karakter olmalıdır.';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              // --- DEĞİŞİKLİK BURADA ---
              child: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.white), // Metin rengi eklendi
              ),
              // --- DEĞİŞİKLİK BİTTİ ---
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Değişiklikleri kaydet ve diyalogu kapat
                  _updateUsername(usernameController.text.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

// Kullanıcı adını Firebase ve Firestore'da güncelleyen metot
  Future<void> _updateUsername(String newUsername) async {
    if (_currentUser == null || newUsername == _username) return;

    setState(() {
      _username = newUsername;
    });

    try {
      // DÜZELTME: Firestore veritabanını güncelle - merge kullan
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'username': newUsername,
        'email': _email,
        'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Firebase Authentication profilini güncelle
      try {
        await _currentUser!.updateDisplayName(newUsername);
        await _currentUser!.reload();
        _currentUser = _auth.currentUser;
      } catch (authError) {
        print(
            "Firebase Auth (DisplayName) güncelleme hatası (yoksayılıyor): $authError");
      }

      // UI'ı anında güncellemek için verileri yeniden yükle
      await _loadUserData();

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Kullanıcı adınız başarıyla güncellendi',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      print('Kullanıcı adı güncellenirken hata: $e');
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Bir hata oluştu, lütfen tekrar deneyin.',
          type: SnackbarType.error,
        );
      }
    }
  }

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
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();

        if (!mounted) return;

        String username;
        String email;
        String? photoUrl;

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          username =
              userData['username'] ?? _currentUser!.displayName ?? 'Kullanıcı';
          email = _currentUser!.email ?? '';
          photoUrl = userData['photoUrl'] ?? _currentUser!.photoURL;
        } else {
          // Eğer Firestore'da kullanıcı bilgisi yoksa, Firebase Auth'dan al ve kaydet
          username = _currentUser!.displayName ?? 'Kullanıcı';
          email = _currentUser!.email ?? '';
          photoUrl = _currentUser!.photoURL;

          // DÜZELTME: Kullanıcı bilgilerini Firestore'a kaydet
          await _saveUserToFirestore(username, email, photoUrl);
        }

        setState(() {
          _username = username;
          _email = email;
          _photoUrl = photoUrl;
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

// Kullanıcı bilgilerini Firestore'a kaydet
  Future<void> _saveUserToFirestore(
      String username, String email, String? photoUrl) async {
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'username': username,
        'email': email,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Kullanıcı bilgileri Firestore'a kaydedildi");
    } catch (e) {
      print("Kullanıcı bilgilerini Firestore'a kaydetme hatası: $e");
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
    _favoritesSubscription = _getFavoritesStream().listen((favorites) {
      if (!mounted) return;

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
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  // Favoriler Tab'ı
  Widget _buildFavoritesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getFavoritesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Hata: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final favorites = snapshot.data ?? [];

        if (favorites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Henüz favori eklenmemiş',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            return _buildFavoriteCard(favorite);
          },
        );
      },
    );
  }

  // İzleme Geçmişi Tab'ı
  Widget _buildWatchHistoryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getWatchHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Hata: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final watchHistory = snapshot.data ?? [];

        if (watchHistory.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'İzleme geçmişi boş',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: watchHistory.length,
          itemBuilder: (context, index) {
            final historyItem = watchHistory[index];
            return _buildHistoryCard(historyItem);
          },
        );
      },
    );
  }

  // Favori kartı oluştur
  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 60,
            child: favorite['thumbnailUrl'] != null
                ? Image.network(
                    favorite['thumbnailUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.video_library,
                            color: Colors.white54),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[800],
                    child:
                        const Icon(Icons.video_library, color: Colors.white54),
                  ),
          ),
        ),
        title: Text(
          favorite['title'] ?? 'Bilinmeyen Bölüm',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTime(favorite['addedAt']),
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeFavorite(favorite['id']),
        ),
        // onTap: () => _openVideoFromFavorites(favorite), // BU SATIRI KALDIR
      ),
    );
  }

  // İzleme geçmişi kartı oluştur
  Widget _buildHistoryCard(Map<String, dynamic> historyItem) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 60,
            child: historyItem['thumbnailUrl'] != null
                ? Image.network(
                    historyItem['thumbnailUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.video_library,
                            color: Colors.white54),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[800],
                    child:
                        const Icon(Icons.video_library, color: Colors.white54),
                  ),
          ),
        ),
        title: Text(
          historyItem['videoTitle'] ??
              historyItem['title'] ??
              'Bilinmeyen Bölüm',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatTime(historyItem['lastWatched'] ?? historyItem['watchedAt']),
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteWatchHistoryItem(historyItem['id']),
        ),
      ),
    );
  }

  // Favori videoyu aç - EpisodeDetailsPage ile
  void _openVideoFromFavorites(Map<String, dynamic> favorite) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: favorite['videoUrl'] ?? '',
          episodeTitle: favorite['title'] ?? 'Bilinmeyen Video',
          thumbnailUrl: favorite['thumbnailUrl'],
          seriesId: favorite['seriesId'],
          episodeId: favorite['episodeId'],
          seasonIndex: favorite['seasonIndex'],
          episodeIndex: favorite['episodeIndex'],
        ),
      ),
    );
  }

  // Favoriyi sil
  Future<void> _removeFavorite(String videoId) async {
    try {
      // Silme işlemi için daha modern bir onay diyaloğu göster
      bool confirmed = await showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // İkon ve başlık
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Başlık
                    const Text(
                      'Favorilerden Kaldır',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // İçerik yazısı
                    const Text(
                      'Bu video favorilerinizden kaldırılacak. Bu işlem geri alınamaz.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Butonlar - yatay düzen
                    Row(
                      children: [
                        // İptal butonu
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('İptal'),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Kaldır butonu
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Kaldır'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ) ??
          false;

      if (!confirmed) return;

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(videoId)
          .delete();

      // CustomSnackbar kullanımı
      CustomSnackbar.show(
        context: context,
        message: 'Video favorilerinizden kaldırıldı',
        type: SnackbarType.info,
      );
    } catch (e) {
      print('Favori silinirken hata: $e');
      CustomSnackbar.show(
        context: context,
        message: 'Favori kaldırılırken bir hata oluştu',
        type: SnackbarType.error,
      );
    }
  }

  // İzleme geçmişi videosunu açma - tam parametreli versiyon
  void _openVideoFromHistory(Map<String, dynamic> historyItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeDetailsPage(
          videoUrl: historyItem['videoUrl'] ?? '',
          episodeTitle: historyItem['title'] ??
              historyItem['videoTitle'] ??
              'Bilinmeyen Video',
          thumbnailUrl: historyItem['thumbnailUrl'],
          seriesId: historyItem['seriesId'],
          episodeId: historyItem['episodeId'],
          seasonIndex: historyItem['seasonIndex'],
          episodeIndex: historyItem['episodeIndex'],
        ),
      ),
    );
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

      // CustomSnackbar ile bildirim
      CustomSnackbar.show(
        context: context,
        message: 'İzleme geçmişinden kaldırıldı',
        type: SnackbarType.info,
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
            title: const Text('Tüm Geçmişi Temizle',
                style: TextStyle(color: Colors.white)),
            content: const Text(
                'Tüm izleme geçmişiniz silinecek. Bu işlem geri alınamaz.',
                style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Temizle', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

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

      // CustomSnackbar ile bildirim
      CustomSnackbar.show(
        context: context,
        message: 'Tüm izleme geçmişi temizlendi',
        type: SnackbarType.info,
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

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Bugün';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
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

  // profile_page.dart dosyasında favoriler stream'ini güncelleyin
  Stream<List<Map<String, dynamic>>> _getFavoritesStream() {
    if (_auth.currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('favorites')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // profile_page.dart dosyasında izleme geçmişi stream'ini güncelleyin
  Stream<List<Map<String, dynamic>>> _getWatchHistoryStream() {
    if (_auth.currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('watchHistory')
        .orderBy('lastWatched', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
