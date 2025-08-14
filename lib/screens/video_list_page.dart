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
// Gerekirse ekleyin

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  _VideoListPageState createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage>
    with SingleTickerProviderStateMixin {
  final GitHubService _githubService = GitHubService();
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // BU SATIRI EKLEYİN
  List<Series> seriesList = [];
  bool isLoading = true;
  Map<String, List<Series>> groupedSeriesList = {};
  int _selectedIndex = 0;
  String _appVersion = 'v1.0.0'; // SINIF İÇİNE TAŞINDI

  // Arama özelliği için yeni değişkenler
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Series> _searchResults = [];
  bool _showSearchResults = false;

  // Banner reklam için değişken
  late BannerAd _bannerAd;

  late AnimationController _animationController;

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
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
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
        "Spor": [],
        "Aile": [],
        "Komedi": [],
        "Dram": [],
        "Kült": [],
        "Dövüş": [],
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
            : const Text(
                'Playtoon',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.55,
          child: Drawer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.9),
                    Colors.black.withOpacity(0.9)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const DrawerHeader(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue, Colors.grey],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Text(
                              'Menü',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip,
                                color: Colors.white),
                            title: const Text('Gizlilik Politikası',
                                style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PrivacyPolicyPage()),
                              );
                            },
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.feedback, color: Colors.white),
                            title: const Text('İstek Kutusu',
                                style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const RequestBoxPage()),
                              );
                            },
                          ),
                          // Çıkış yapma butonu
                          ListTile(
                            leading:
                                const Icon(Icons.logout, color: Colors.white),
                            title: const Text('Çıkış Yap',
                                style: TextStyle(color: Colors.white)),
                            onTap: () async {
                              await AuthService().signOut();
                              if (mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const SignInPage()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    // Version text at bottom
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 32.0,
                        left: 16.0,
                        right: 16.0,
                      ),
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.7),
                              Colors.blue.withOpacity(0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Text(
                          _appVersion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
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
                      child: CircularProgressIndicator(
                          color: Colors.blue)) // Renk değiştirildi
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
                        child: CircularProgressIndicator(
                            color: Colors.blue)), // Renk eklendi
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
          const SizedBox(height: 16.0),
          // Popüler Bölümler
          _buildPopularEpisodesSection(),

          // YENİ: Sadece bu 7 kategori sırayla gösteriliyor
          ...[
            "Aksiyon & Macera",
            "Anime",
            "Spor",
            "Aile",
            "Komedi",
            "Dram",
            "Kült",
            "Dövüş"
          ].map((category) {
            final items = groupedSeriesList[category] ?? [];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _buildSectionTitle(category),
                _buildHorizontalList(items),
              ],
            );
          }).toList(),

          const SizedBox(height: 20.0),
        ],
      ),
    );
  }

  Widget _buildFeaturedContent() {
    return CarouselSlider.builder(
      itemCount: seriesList.length,
      itemBuilder: (context, index, realIndex) {
        final series = seriesList[index];
        return Stack(
          children: [
            // Arka plana bulanık görsel ekleyerek sinematik bir görünüm sağlıyoruz.
            Positioned.fill(
              child: Image.network(
                series.cover,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            // Öne çıkan içerik
            Positioned(
              bottom: 40,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeasonListPage(series),
                        ),
                      );
                    },
                    child: const Text(
                      "İzlemeye Başla",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      options: CarouselOptions(
        height: 250,
        autoPlay: true,
        enlargeCenterPage: true,
        autoPlayInterval: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<Series> items) {
    return SizedBox(
      height: 180.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
              width: 120.0,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: CachedNetworkImage(
                        imageUrl: item.cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue)), // Renk eklendi
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // home_page.dart dosyasına popüler bölümler bölümü ekleyin
  Widget _buildPopularEpisodesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Popüler Bölümler',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240, // Yüksekliği daha da artırdık
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('videos')
                  .orderBy('views', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.blue));
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
                      width: 190, // Genişliği daha da artırdık
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        color: Colors.grey[850],
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sıralama numarası ve görsel alanı
                              Stack(
                                children: [
                                  Container(
                                    height: 100, // Yüksekliği artırdık
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.video_library,
                                        color: Colors.white54,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  // Sıralama numarası sağ üstte
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getRankColor(index + 1),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '#${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Bölüm başlığı - Tooltip ile tam metin gösterimi
                              Tooltip(
                                message: title, // Tam metni tooltip'te göster
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SizedBox(
                                  height: 65, // Başlık alanını büyüttük
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15, // Font boyutunu artırdık
                                      fontWeight:
                                          FontWeight.w600, // Daha kalın yaptık
                                      height: 1.3, // Satır aralığını artırdık
                                    ),
                                    maxLines: 4, // 4 satıra çıkardık
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                              // Sadece izlenme sayısı
                              Row(
                                children: [
                                  const Icon(Icons.visibility,
                                      size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatViewCount(views),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
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
              },
            ),
          ),
        ],
      ),
    );
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
