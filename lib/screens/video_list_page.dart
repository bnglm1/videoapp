import 'package:flutter/material.dart';
import 'package:videoapp/models/video_model.dart';
import 'package:videoapp/screens/privacy_policy_screen.dart';
import 'package:videoapp/screens/request_box.dart';
import 'package:videoapp/screens/season_list_page.dart';
import 'package:videoapp/screens/category_screen.dart';
import 'package:videoapp/models/firebase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:carousel_slider/carousel_slider.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  _VideoListPageState createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<Series> seriesList = [];
  bool isLoading = true;
  Map<String, List<Series>> groupedSeriesList = {};
  int _selectedIndex = 0; // Seçili sekmeyi takip etmek için

  // 📌 Banner Reklam için değişken
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadSeries();
    _loadBannerAd(); // Banner reklamı yükle

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _bannerAd.dispose(); // Reklamı temizle
    _animationController.dispose(); // Dispose animation controller
    super.dispose();
  }

  // 📌 Banner Reklamı Yükleme
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'cca-app-pub-7690250755006392/7705897910', 
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
      ),
    );

    _bannerAd.load();
  }

  Future<void> _loadSeries() async {
    try {
      final allSeries = await _firebaseService.fetchSeries();

      // Serileri `type` özelliğine göre gruplandır
      Map<String, List<Series>> groupedSeries = {
        "Önerilenler": [],
        "AnimetoonTr İçerikleri": [],
        "Yeni Eklenenler": [],
      };

      for (var series in allSeries) {
        for (var type in series.type) {
          if (groupedSeries.containsKey(type)) {
            groupedSeries[type]!.add(series);
          }
        }
      }

      setState(() {
        seriesList = allSeries;
        groupedSeriesList = groupedSeries; // Gruplandırılmış seriler
        isLoading = false;
      });
    } catch (e) {
      print("Veri alınırken hata oluştu: $e");
      setState(() => isLoading = false);
    }
  }

  // Ekranlar
  List<Widget> _screens() {
    return [
      _buildHomeScreen(),
      CategoryScreen(
        allSeries: seriesList,
        categoryImages: const {}, // Eğer kategori resimleri varsa buraya ekleyebilirsiniz
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Colors.grey[900], // Ana arka plan rengi
  appBar: AppBar(
    title: const Text(
      'Playtoon',
      style: TextStyle(
        color: Colors.white,
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
      ),
    ),
    centerTitle: true,
    backgroundColor: Colors.transparent, // AppBar arka planı şeffaf
    elevation: 0, // AppBar gölgesini kaldır
    leading: Builder(
      builder: (context) {
        return IconButton(
          icon: const Icon(Icons.menu, color: Colors.white), // Menü simgesi
          onPressed: () {
            Scaffold.of(context).openDrawer(); // Drawer'ı aç
          },
        );
      },
    ),
  ),
  drawer: ClipRRect(
    borderRadius: const BorderRadius.only(
      topRight: Radius.circular(30),
      bottomRight: Radius.circular(30),
    ),
    child: SizedBox(
      width: MediaQuery.of(context).size.width * 0.55, // Ekranın %55'i kadar genişlik
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
                        leading: const Icon(Icons.privacy_tip, color: Colors.white),
                        title: const Text('Gizlilik Politikası', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.feedback, color: Colors.white),
                        title: const Text('İstek Kutusu', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RequestBoxPage()),
                          );
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
                    child: const Text(
                      'v1.0.2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16, // Boyut artırıldı
                        fontWeight: FontWeight.w400, // Font kalınlığı artırıldı
                        letterSpacing: 1.2, // Harfler arası boşluk eklendi
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
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _selectedIndex,
                children: _screens(),
              ),
      ),
      // 📌 Banner Reklamı Göster
    ],
  ),
  bottomNavigationBar: Container(
    decoration: const BoxDecoration(
      color: Colors.transparent, // Şeffaf siyah arka plan
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Kenarları yuvarlat
    ),
    child: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
          // Animate icon when tab changes
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
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.category),
          label: 'Kategoriler',
        ),
      ],
      backgroundColor: Colors.transparent, // Arka plan şeffaf
      elevation: 0, // Gölgeyi kaldır
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.white.withOpacity(0.6),
    ),
  ),
);
  }

  @override
  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeaturedContent(), // ✅ Güncellenmiş Slider çağrıldı!
          const SizedBox(height: 16.0),
          if (groupedSeriesList["Önerilenler"]!.isNotEmpty) ...[
            _buildSectionTitle("Önerilenler"),
            _buildHorizontalList(groupedSeriesList["Önerilenler"]!),
          ],
          if (groupedSeriesList["AnimetoonTr İçerikleri"]!.isNotEmpty) ...[
            _buildSectionTitle("AnimetoonTr İçerikleri"),
            _buildHorizontalList(groupedSeriesList["AnimetoonTr İçerikleri"]!),
          ],
          if (groupedSeriesList["Yeni Eklenenler"]!.isNotEmpty) ...[
            _buildSectionTitle("Yeni Eklenenler"),
            _buildHorizontalList(groupedSeriesList["Yeni Eklenenler"]!),
          ],
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
                    child: const Text("İzlemeye Başla", style: TextStyle(color: Colors.white),),
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
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
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
}
