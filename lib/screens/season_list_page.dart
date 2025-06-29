import 'package:flutter/material.dart';
import 'package:videoapp/models/video_model.dart';
import 'episode_detail_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class SeasonListPage extends StatefulWidget {
  final Series series;

  const SeasonListPage(this.series, {super.key});

  @override
  _SeasonListPageState createState() => _SeasonListPageState();
}

class _SeasonListPageState extends State<SeasonListPage> {
  int _selectedSeasonIndex = 0; // Seçili sezon için değişken ekledik
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;
  final ScrollController _scrollController = ScrollController();
  double _titleAlignment = 0.0; // 0.0 = left, 1.0 = center

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7690250755006392/7705897910', // Google test reklamı
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

  void _onScroll() {
    final double offset = _scrollController.offset;
    const double maxOffset = 200.0; // Başlığın ne kadar scroll'da ortaya geleceği

    setState(() {
      _titleAlignment = (offset / maxOffset).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.blueAccent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.series.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    titlePadding: EdgeInsets.only(
                      left: 16.0 * (1 - _titleAlignment),
                      bottom: 16,
                      right: 16.0 * (1 - _titleAlignment),
                    ),
                    centerTitle: _titleAlignment == 1.0,
                    background: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(widget.series.cover),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.series.categories.join(", "),
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.series.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                
                // Yeni Modern Sezon Seçici
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                          child: Text(
                            'Sezonlar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.series.seasons.length,
                            itemBuilder: (context, index) {
                              final isSelected = _selectedSeasonIndex == index;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedSeasonIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blueAccent : Colors.grey[850],
                                      borderRadius: BorderRadius.circular(25),
                                      border: Border.all(
                                        color: isSelected ? Colors.blueAccent : Colors.grey[700]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Sezon ${widget.series.seasons[index].seasonNumber}',
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Seçilen sezonun bölümleri
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, episodeIndex) {
                      final episode = widget.series.seasons[_selectedSeasonIndex].episodes[episodeIndex];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: Card(
                          color: Colors.grey[850],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              if (episode.videoUrl.isNotEmpty) {
                                // Mevcut sezonun tüm bölümlerini episodeList olarak hazırla
                                final currentSeasonEpisodes = widget.series.seasons[_selectedSeasonIndex].episodes;
                                final episodeList = currentSeasonEpisodes.map((ep) => {
                                  'videoUrl': ep.videoUrl,
                                  'title': ep.title,
                                  'thumbnail': ep.thumbnail,
                                  'episodeId': ep.title, // episodeId olarak title kullanıyoruz
                                }).toList();
                                
                                // Mevcut bölümün index'ini bul
                                final currentIndex = episodeIndex; // Zaten doğru index
                                
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EpisodeDetailsPage(
                                        videoUrl: episode.videoUrl,
                                        episodeTitle: episode.title,
                                        thumbnailUrl: episode.thumbnail,
                                        seriesId: widget.series.title,
                                        episodeId: episode.title, // episodeId parametresini ekliyoruz
                                        episodeList: episodeList,
                                        currentIndex: currentIndex,
                                        seasonIndex: widget.series.seasons[_selectedSeasonIndex].seasonNumber,
                                        episodeIndex: episodeIndex,
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Videoya ait link bulunamadı"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          episode.thumbnail,
                                          width: 120,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 120,
                                              height: 80,
                                              color: Colors.grey,
                                              child: const Icon(Icons.broken_image, color: Colors.white),
                                            );
                                          },
                                        ),
                                        // Bölüm numarası
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            color: Colors.black.withOpacity(0.7),
                                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                            child: Text(
                                              'Bölüm ${episodeIndex + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Bölüm bilgileri
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            episode.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          // Removed the duration line that caused the error
                                          const SizedBox(height: 4),
                                          // You can add other episode details here if needed
                                          Text(
                                            'Bölüm ${episodeIndex + 1}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Oynat butonu
                                  const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.blue,
                                    size: 36,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: widget.series.seasons[_selectedSeasonIndex].episodes.length,
                  ),
                ),
              ],
            ),
          ),
          // Banner Reklam Alanı
          SizedBox(
            height: 50, // Banner yüksekliği
            child: _isBannerAdLoaded
                ? AdWidget(ad: _bannerAd)
                : Container(
                    color: Colors.black,
                    child: const Center(
                      child: Text(
                        "Reklam yüklenemedi",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
