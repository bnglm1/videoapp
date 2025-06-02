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
  bool _isExpanded = false;
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
                            color: Colors.orangeAccent,
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
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final season = widget.series.seasons[index];

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isExpanded
                                ? Colors.grey.withOpacity(0.5)
                                : Colors.grey[850]?.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _isExpanded = expanded;
                              });
                            },
                            leading: const Icon(
                              Icons.tv,
                              color: Colors.orangeAccent,
                              size: 30,
                            ),
                            title: Text(
                              "Sezon ${season.seasonNumber}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: season.episodes.map((episode) {
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    episode.thumbnail,
                                    width: 80,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 60,
                                        color: Colors.grey,
                                        child: const Icon(Icons.broken_image, color: Colors.white),
                                      );
                                    },
                                  ),
                                ),
                                title: Text(
                                  episode.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                trailing: const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                                onTap: () {
                                  if (episode.videoUrl.isNotEmpty) {
                                    // Eğer video bağlantısı varsa, video detay sayfasına yönlendir
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EpisodeDetailsPage(
                                          videoUrl: episode.videoUrl,
                                          episodeTitle: episode.title,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Eğer video bağlantısı yoksa, kullanıcıya mesaj göster
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Videoya ait link bulunamadı",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    childCount: widget.series.seasons.length,
                  ),
                ),
              ],
            ),
          ),
          // 📌 Banner Reklam Alanı
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
