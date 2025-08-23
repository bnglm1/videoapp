import 'dart:async';
import 'dart:ui'; // BackdropFilter için eklendi
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:videoapp/models/auth_service.dart';
import 'package:videoapp/models/video_model.dart';
import 'package:videoapp/screens/privacy_policy_screen.dart';
import 'package:videoapp/screens/request_box.dart';
import 'package:videoapp/screens/season_list_page.dart';
import 'package:videoapp/screens/category_screen.dart';
import 'package:videoapp/models/github_service.dart'; // GitHub servisi
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:videoapp/screens/sign_in_page.dart';
import 'package:videoapp/screens/profile_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  _VideoListPageState createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage>
    with SingleTickerProviderStateMixin {
  final GitHubService _githubService = GitHubService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Series> seriesList = [];
  bool isLoading = true;
  Map<String, List<Series>> groupedSeriesList = {};
  int _selectedIndex = 0;
  String _appVersion = 'v1.0.0';

  // Arama özelliği için yeni değişkenler
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Series> _searchResults = [];
  bool _showSearchResults = false;

  // Banner reklam için değişken
  late BannerAd _bannerAd;
  late AnimationController _animationController;

  // Kullanıcı bilgileri için yeni değişkenler
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String _username = '';
  String _email = '';
  String? _photoUrl;
  bool _isLoadingProfile = true;

  // Stream subscription için değişken
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _loadSeries();
    _loadBannerAd();
    _loadAppVersion();

    // Arama kontrolcüsüne dinleyici ekle
    _searchController.addListener(_onSearchChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Kullanıcı bilgilerini yükle
    _currentUser = _auth.currentUser;
    _loadUserData();
    _setupUserDataListener();
  }

  // Kullanıcı verilerini gerçek zamanlı dinleme metodu:
  void _setupUserDataListener() {
    if (_currentUser == null) return;

    _userDataSubscription = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (!mounted) return;

      if (snapshot.exists) {
        Map<String, dynamic> userData = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _username =
              userData['username'] ?? _currentUser!.displayName ?? 'Kullanıcı';
          _email = _currentUser!.email ?? '';
          _photoUrl = userData['photoUrl'] ?? _currentUser!.photoURL;
        });
      }
    }, onError: (e) {
      print('Kullanıcı veri dinleme hatası: $e');
    });
  }

  // Yeni metot - Kullanıcı bilgilerini yükle:
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingProfile = true;
    });

    if (_currentUser != null) {
      try {
        // İlk yükleme için
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();

        if (!mounted) return;

        setState(() {
          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            _username = userData['username'] ??
                _currentUser!.displayName ??
                'Kullanıcı';
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

  @override
  void dispose() {
    _bannerAd.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    _userDataSubscription?.cancel();
    super.dispose();
  }

  Widget _buildAdvancedPlaytoonLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated play button
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.play_arrow_outlined,
                size: 26,
                color: Colors.blueAccent,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Stylized "laytoon" text
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: [
                  Colors.white,
                  Color(0xFFBBDEFB),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            child: Text(
              'playtoon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Arama değeri değiştiğinde çağrılır
  void _onSearchChanged() {
    _performSearch(_searchController.text);
  }

  // Arama işlemini gerçekleştirir
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    final queryLower = query.toLowerCase();
    final results = seriesList.where((series) {
      return series.title.toLowerCase().contains(queryLower);
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  // Arama modunu aç/kapat
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _showSearchResults = false;
      } else {
        // Arama kutusu açıldığında klavye odağını kur
        FocusScope.of(context).requestFocus();
      }
    });
  }

  // Banner Reklamı Yükleme
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'cca-app-pub-7690250755006392/7705897910',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          // Banner yüklendi
        },
      ),
    );

    _bannerAd.load();
  }

  // Ana serileri yükle ve kategorilere göre grupla
  Future<void> _loadSeries() async {
    try {
      print("Seri yükleme başlıyor...");
      final allSeries = await _githubService.fetchSeries();

      print("Alınan seri sayısı: ${allSeries.length}");

      // YENİ: Sadece bu 7 kategori
      Map<String, List<Series>> groupedSeries = {
        "Aksiyon & Macera": [],
        "Anime": [],
        "Dövüş": [],
        "Spor": [],
        "Aile": [],
        "Komedi": [],
        "Dram": [],
        "Kült": [],
      };

      for (var series in allSeries) {
        print("İşlenen seri: ${series.title}, Types: ${series.type}");
        for (var type in series.type) {
          if (groupedSeries.containsKey(type)) {
            groupedSeries[type]!.add(series);
            print("  -> $type kategorisine eklendi");
          } else {
            print("  -> Bilinmeyen kategori: $type");
          }
        }
      }

      // Debug: Kategori bazında seri sayıları
      groupedSeries.forEach((key, value) {
        print("$key: ${value.length} seri");
      });

      setState(() {
        seriesList = allSeries;
        groupedSeriesList = groupedSeries;
        isLoading = false;
      });

      if (allSeries.isEmpty) {
        print("Uyarı: Hiç seri yüklenmedi!");
        _showErrorDialog("Veri Yüklenemedi",
            "GitHub'dan hiçbir seri verisi alınamadı. Lütfen internet bağlantınızı kontrol edin.");
      }
    } catch (e) {
      print("Veri alınırken hata oluştu: $e");
      setState(() => isLoading = false);
      _showErrorDialog(
          "Bağlantı Hatası", "Veri yüklenirken bir hata oluştu: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Tamam',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => isLoading = true);
                _loadSeries(); // Tekrar dene
              },
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}';
    });
  }

  // Ekranlar
  List<Widget> _screens() {
    return [
      _buildHomeScreen(),
      CategoryScreen(
        allSeries: seriesList,
        categoryImages: const {},
      ),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Dizi/Film ara...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
                cursorColor: Colors.white,
                onChanged: _performSearch,
              )
            : _buildAdvancedPlaytoonLogo(),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          // Arama ikonu ekle
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      drawer: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.55,
            child: Drawer(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.grey[900]!.withOpacity(0.85),
                      Colors.blue[900]!.withOpacity(0.7),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Modern Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.withOpacity(0.3),
                              Colors.purple.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(25),
                            bottomRight: Radius.circular(25),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Profil resmi - play icon yerine kullanıcı resmi
                            _isLoadingProfile
                                ? Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[800],
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.blue,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withOpacity(0.8),
                                          Colors.white.withOpacity(0.8),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 38,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: _photoUrl != null
                                          ? NetworkImage(_photoUrl!)
                                          : null,
                                      child: _photoUrl == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 40,
                                            )
                                          : null,
                                    ),
                                  ),
                            const SizedBox(height: 16),

                            // Kullanıcı adı
                            _isLoadingProfile
                                ? Container(
                                    width: 120,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  )
                                : ShaderMask(
                                    shaderCallback: (Rect bounds) {
                                      return LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.blue[200]!,
                                        ],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      _username,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                            const SizedBox(height: 8),

                            // Email - opsiyonel
                            if (_email.isNotEmpty && !_isLoadingProfile)
                              Text(
                                _email,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Menu Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildModernDrawerItem(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Gizlilik Politikası',
                              gradient: [Colors.green, Colors.teal],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PrivacyPolicyPage(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            _buildModernDrawerItem(
                              icon: Icons.feedback_outlined,
                              title: 'İstek Kutusu',
                              gradient: [Colors.orange, Colors.red],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RequestBoxPage(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Separator
                            Container(
                              height: 1,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            _buildModernDrawerItem(
                              icon: Icons.logout,
                              title: 'Çıkış Yap',
                              gradient: [Colors.red, Colors.red[800]!],
                              onTap: () async {
                                await AuthService().signOut();
                                if (mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const SignInPage(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Version at bottom
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Decorative line
                            Container(
                              width: 60,
                              height: 3,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.5),
                                    Colors.purple.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),

                            // Version info
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  ShaderMask(
                                    shaderCallback: (Rect bounds) {
                                      return LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.9),
                                          Colors.blue.withOpacity(0.7),
                                        ],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      _appVersion,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Arama sonuçları gösteriliyorsa
          if (_showSearchResults && _searchResults.isNotEmpty)
            Expanded(
              child: _buildSearchResults(),
            ),
          if (_showSearchResults && _searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text(
                      'Sonuç bulunamadı',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Farklı bir arama terimi deneyin',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Normal içerik
          if (!_showSearchResults)
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue))
                  : IndexedStack(
                      index: _selectedIndex,
                      children: _screens(),
                    ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              // Arama modundayken herhangi bir sekmeye geçiş yapılırsa arama modunu kapat
              if (_isSearching) {
                _isSearching = false;
                _showSearchResults = false;
              }
              if (index == 0) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: AnimatedIcon(
                icon: AnimatedIcons.home_menu,
                progress: _animationController,
              ),
              label: 'Ana Sayfa',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Kategoriler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profilim',
            ),
          ],
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  // Modern Drawer Item Widget'ı
  Widget _buildModernDrawerItem({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: gradient),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 16),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                // Arrow icon
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

  // Arama sonuçlarını göster
  Widget _buildSearchResults() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final series = _searchResults[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.grey[850],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: series.cover,
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                        child: CircularProgressIndicator(color: Colors.blue)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              title: Text(
                series.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                series.description.length > 70
                    ? '${series.description.substring(0, 70)}...'
                    : series.description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              // Sağ tarafta küçük bir 'aç' ikonu
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
              onTap: () {
                // Arama modunu kapat ve seçilen serinin sezon sayfasına git
                setState(() {
                  _isSearching = false;
                  _showSearchResults = false;
                  _searchController.clear();
                });

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeasonListPage(series),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeaturedContent(),
          const SizedBox(height: 20.0),

          // Popüler Bölümler (Madalya sistemi ile)
          _buildPopularEpisodesSection(),

          // Kategoriler - Modern tasarım ile
          ...[
            "Aksiyon & Macera",
            "Anime",
            "Dövüş",
            "Aile",
            "Spor",
            "Komedi",
            "Dram",
            "Kült",
          ].map((category) {
            final items = groupedSeriesList[category] ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildModernSectionTitle(category),
                _buildModernHorizontalList(items, category),
              ],
            );
          }).toList(),

          const SizedBox(height: 30.0),
        ],
      ),
    );
  }

  Widget _buildFeaturedContent() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_fire_department,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Öne Çıkanlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Carousel
          CarouselSlider.builder(
            itemCount: seriesList.length,
            itemBuilder: (context, index, realIndex) {
              final series = seriesList[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Arka plan görseli
                      Positioned.fill(
                        child: Image.network(
                          series.cover,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.8),
                                Colors.black.withOpacity(0.95),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // İçerik
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kategoriler
                            Wrap(
                              spacing: 6,
                              children: series.type
                                  .take(2)
                                  .map((type) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          type,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 8),

                            // Başlık
                            Text(
                              series.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Açıklama
                            Text(
                              series.description,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),

                            // Buton
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.blue, Colors.blueAccent],
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SeasonListPage(series),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_outlined,
                                    color: Colors.white, size: 20),
                                label: const Text(
                                  "İzle",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 280,
              autoPlay: true,
              enlargeCenterPage: true,
              autoPlayInterval: const Duration(seconds: 5),
              viewportFraction: 0.85,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getCategoryGradient(title),
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getCategoryGradient(title)[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              _getCategoryIcon(title),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _getCategoryGradient(title)[0].withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              '${groupedSeriesList[title]?.length ?? 0}',
              style: TextStyle(
                color: _getCategoryGradient(title)[0],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHorizontalList(List<Series> items, String category) {
    return SizedBox(
      height: 220.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SeasonListPage(item),
                ),
              );
            },
            child: Container(
              width: 140.0,
              margin: const EdgeInsets.only(right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Görsel kısmı - Sabit yükseklik
                  Container(
                    height: 170.0, // Sabit yükseklik
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: _getCategoryGradient(category)[0]
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Stack(
                        children: [
                          // Ana görsel
                          CachedNetworkImage(
                            imageUrl: item.cover,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _getCategoryGradient(category)[0],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.error,
                                color: _getCategoryGradient(category)[0],
                              ),
                            ),
                          ),

                          // Gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Kategori badge
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getCategoryGradient(category),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Play butonu
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getCategoryGradient(category)[0],
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_outlined,
                                color: _getCategoryGradient(category)[0],
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Başlık - Sabit yükseklik
                  const SizedBox(height: 12.0),
                  SizedBox(
                    height: 34.0, // Sabit yükseklik (2 satır için)
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _getCategoryGradient(String category) {
    switch (category) {
      case "Aksiyon & Macera":
        return [Colors.red, Colors.orange];
      case "Anime":
        return [Colors.pink, Colors.purple];
      case "Dövüş":
        return [Colors.red[800]!, Colors.red[600]!];
      case "Spor":
        return [Colors.green, Colors.teal];
      case "Aile":
        return [Colors.blue, Colors.lightBlue];
      case "Komedi":
        return [Colors.yellow, Colors.orange];
      case "Dram":
        return [Colors.indigo, Colors.blue];
      case "Kült":
        return [Colors.purple, Colors.deepPurple];
      default:
        return [Colors.grey, Colors.blueGrey];
    }
  }

// Kategori ikonlarını belirle
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Aksiyon & Macera":
        return Icons.flash_on;
      case "Anime":
        return Icons.auto_awesome;
      case "Dövüş":
        return Icons.sports_mma;
      case "Spor":
        return Icons.sports_soccer;
      case "Aile":
        return Icons.family_restroom;
      case "Komedi":
        return Icons.sentiment_very_satisfied;
      case "Dram":
        return Icons.theater_comedy;
      case "Kült":
        return Icons.star;
      default:
        return Icons.movie;
    }
  }

  // home_page.dart dosyasına popüler bölümler bölümü ekleyin
  Widget _buildPopularEpisodesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.trending_up,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Popüler Bölümler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('videos')
                  .orderBy('views', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.amber));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz popüler bölüm yok',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Bilinmeyen Bölüm';
                    final views = (data['views'] as num?)?.toInt() ?? 0;

                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        color: Colors.grey[850],
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getMedalColor(index + 1).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey[850]!,
                                Colors.grey[900]!,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Madalya ve görsel alanı
                                Stack(
                                  children: [
                                    Container(
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: _getMedalColor(index + 1)
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.video_library,
                                            color: _getMedalColor(index + 1),
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Madalya - Sol üst köşede
                                    Positioned(
                                      top: -5,
                                      left: -5,
                                      child: _buildMedal(index + 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Bölüm başlığı
                                Tooltip(
                                  message: title,
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SizedBox(
                                    height: 65,
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                        shadows: [
                                          Shadow(
                                            color: _getMedalColor(index + 1)
                                                .withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Sıralama ve izlenme sayısı
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Sıralama
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getMedalColor(index + 1)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getMedalColor(index + 1)
                                              .withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _getRankText(index + 1),
                                        style: TextStyle(
                                          color: _getMedalColor(index + 1),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    // İzlenme sayısı
                                    Row(
                                      children: [
                                        Icon(Icons.visibility,
                                            size: 12,
                                            color: _getMedalColor(index + 1)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatViewCount(views),
                                          style: TextStyle(
                                            color: _getMedalColor(index + 1),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Madalya widget'ı oluştur
  Widget _buildMedal(int rank) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _getMedalColor(rank),
            _getMedalColor(rank).withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _getMedalColor(rank).withOpacity(0.6),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Dış çember
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getMedalColor(rank).withOpacity(0.8),
                width: 2,
              ),
            ),
          ),

          // İç içerik
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getMedalIcon(rank),
                  color: Colors.white,
                  size: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 2,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Madalya rengini belirle
  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Altın
      case 2:
        return const Color(0xFFC0C0C0); // Gümüş
      case 3:
        return const Color(0xFFCD7F32); // Bronz
      case 4:
        return Colors.blue[600]!; // Mavi
      case 5:
        return Colors.green[600]!; // Yeşil
      default:
        return Colors.grey[600]!;
    }
  }

// Madalya ikonunu belirle
  IconData _getMedalIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.workspace_premium; // Altın madalya
      case 2:
        return Icons.workspace_premium; // Gümüş madalya
      case 3:
        return Icons.workspace_premium; // Bronz madalya
      case 4:
        return Icons.star; // Yıldız
      case 5:
        return Icons.star; // Yıldız
      default:
        return Icons.circle;
    }
  }

// Sıralama metnini belirle
  String _getRankText(int rank) {
    switch (rank) {
      case 1:
        return '1. ALTIN';
      case 2:
        return '2. GÜMÜŞ';
      case 3:
        return '3. BRONZ';
      case 4:
        return '4. SIRA';
      case 5:
        return '5. SIRA';
      default:
        return '$rank. SIRA';
    }
  }

  // View count'ı okunabilir formata çevirir
  String _formatViewCount(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}B';
    } else {
      return views.toString();
    }
  }

  // Sıralama rengini belirle
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Altın
      case 2:
        return Colors.grey[400]!; // Gümüş
      case 3:
        return Colors.orange[800]!; // Bronz
      case 4:
        return Colors.blue;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
