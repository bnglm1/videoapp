class Series {
  final String title;
  final String description;
  final String cover;
  final List<String> categories;
  final int year;
  final double imdb;
  final List<Season> seasons;
  final List<String> type;

  Series({
    required this.title,
    required this.description,
    required this.cover,
    required this.categories,
    required this.year,
    required this.imdb,
    required this.seasons,
    required this.type,
  });

  // JSON'dan Series nesnesine dönüştürme
  factory Series.fromJson(Map<String, dynamic> json) {
    try {
      // Debug bilgisi
      print("Series.fromJson - JSON keys: ${json.keys.toList()}");
      
      // Seasons verilerini güvenli bir şekilde işle
      List<Season> seasonsList = [];
      if (json.containsKey('seasons')) {
        var seasonsData = json['seasons'];
        print("Seasons data type: ${seasonsData.runtimeType}");
        
        if (seasonsData is Map) {
          // Seasons Map formatındaysa
          Map<String, dynamic> seasonsMap = Map<String, dynamic>.from(seasonsData);
          seasonsMap.forEach((key, value) {
            try {
              Season season = Season.fromJson(Map<String, dynamic>.from(value));
              seasonsList.add(season);
            } catch (e) {
              print("Season dönüştürme hatası ($key): $e");
            }
          });
        } else if (seasonsData is List) {
          // Seasons List formatındaysa
          for (var seasonData in seasonsData) {
            try {
              Season season = Season.fromJson(Map<String, dynamic>.from(seasonData));
              seasonsList.add(season);
            } catch (e) {
              print("Season dönüştürme hatası: $e");
            }
          }
        }
      }
      
      return Series(
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        cover: json['cover']?.toString() ?? '',
        categories: json['categories'] != null 
          ? List<String>.from(json['categories'].map((x) => x.toString()))
          : [],
        type: json['type'] != null 
          ? List<String>.from(json['type'].map((x) => x.toString()))
          : [],
        year: int.tryParse(json['year']?.toString() ?? '0') ?? 0,
        imdb: double.tryParse(json['imdb']?.toString() ?? '0') ?? 0.0,
        seasons: seasonsList,
      );
    } catch (e) {
      print("Series.fromJson hatası: $e");
      print("JSON data: $json");
      rethrow;
    }
  }

  // Optional: toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'cover': cover,
      'categories': categories,
      'type': type,
      'year': year,
      'imdb': imdb,
      'seasons': seasons.map((season) => season.toJson()).toList(),
    };
  }
}

class Season {
  final int seasonNumber;
  final String coverImage; // Add this property
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.coverImage, // Add this property
    required this.episodes,
  });

  // JSON'dan Season nesnesine dönüştürme
  factory Season.fromJson(Map<String, dynamic> json) {
    try {
      print("Season.fromJson - JSON keys: ${json.keys.toList()}");
      
      // Episodes verilerini güvenli bir şekilde işle
      List<Episode> episodesList = [];
      if (json.containsKey('episodes')) {
        var episodesData = json['episodes'];
        print("Episodes data type: ${episodesData.runtimeType}");
        
        if (episodesData is Map) {
          // Episodes Map formatındaysa
          Map<String, dynamic> episodesMap = Map<String, dynamic>.from(episodesData);
          episodesMap.forEach((key, value) {
            try {
              Episode episode = Episode.fromJson(Map<String, dynamic>.from(value));
              episodesList.add(episode);
            } catch (e) {
              print("Episode dönüştürme hatası ($key): $e");
            }
          });
        } else if (episodesData is List) {
          // Episodes List formatındaysa
          for (var episodeData in episodesData) {
            try {
              Episode episode = Episode.fromJson(Map<String, dynamic>.from(episodeData));
              episodesList.add(episode);
            } catch (e) {
              print("Episode dönüştürme hatası: $e");
            }
          }
        }
      }
      
      return Season(
        seasonNumber: int.tryParse(json['seasonNumber']?.toString() ?? '1') ?? 1,
        coverImage: json['coverImage']?.toString() ?? '',
        episodes: episodesList,
      );
    } catch (e) {
      print("Season.fromJson hatası: $e");
      print("JSON data: $json");
      rethrow;
    }
  }

  // Optional: toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'seasonNumber': seasonNumber,
      'coverImage': coverImage, // Add this property
      'episodes': episodes.map((episode) => episode.toJson()).toList(),
    };
  }
}

class Episode {
  final String title;
  final String thumbnail;
  final String videoUrl;
  final bool? useWebView; // WebView ile oynatılması gerekip gerekmediği
  final String? playerType; // "webview" veya "native" (varsayılan: native)

  Episode({
    required this.title,
    required this.thumbnail,
    required this.videoUrl,
    this.useWebView,
    this.playerType,
  });

  // WebView kullanılması gerekip gerekmediğini belirler
  bool get shouldUseWebView {
    if (useWebView != null) return useWebView!;
    if (playerType != null) return playerType!.toLowerCase() == 'webview';
    
    // Video URL'sine göre otomatik belirleme
    final url = videoUrl.toLowerCase();
    
    // .mp4 dosyaları native player ile oynatılır
    if (url.endsWith('.mp4')) return false;
    
    // tau-video.xyz, YouTube, Vimeo, Dailymotion vs. gibi platformlar WebView ile oynatılır
    if (url.contains('tau-video.xyz') ||
        url.contains('youtube.com') || 
        url.contains('youtu.be') ||
        url.contains('vimeo.com') ||
        url.contains('dailymotion.com') ||
        url.contains('facebook.com') ||
        url.contains('instagram.com') ||
        url.contains('tiktok.com') ||
        url.contains('twitch.tv') ||
        url.contains('embed') ||
        url.contains('iframe')) {
      return true;
    }
    
    // Diğer durumlarda native player kullan
    return false;
  }

  // JSON'dan Episode nesnesine dönüştürme
  factory Episode.fromJson(Map<String, dynamic> json) {
    try {
      return Episode(
        title: json['title']?.toString() ?? '',
        thumbnail: json['thumbnail']?.toString() ?? '',
        videoUrl: json['videoUrl']?.toString() ?? '',
        useWebView: json['useWebView'] as bool?,
        playerType: json['playerType']?.toString(),
      );
    } catch (e) {
      print("Episode.fromJson hatası: $e");
      print("JSON data: $json");
      rethrow;
    }
  }

  // Episode'u Map formatına çevir (navigation için)
  Map<String, dynamic> toNavigationMap() {
    return {
      'title': title,
      'thumbnail': thumbnail,
      'videoUrl': videoUrl,
      'useWebView': shouldUseWebView,
      'playerType': shouldUseWebView ? 'webview' : 'native',
    };
  }

  // Optional: toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'thumbnail': thumbnail,
      'videoUrl': videoUrl,
      if (useWebView != null) 'useWebView': useWebView,
      if (playerType != null) 'playerType': playerType,
    };
  }
}