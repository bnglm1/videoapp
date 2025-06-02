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
    return Series(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cover: json['cover'] ?? '',
      categories: json['categories'] != null 
        ? List<String>.from(json['categories']) 
        : [],
      type: json['type'] != null 
        ? List<String>.from(json['type']) 
        : [],
      year: json['year'] ?? 0,
      imdb: (json['imdb'] ?? 0).toDouble(),
      seasons: json['seasons'] != null
        ? (json['seasons'] as List)
            .map((season) => Season.fromJson(season))
            .toList()
        : [],
    );
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
    return Season(
      seasonNumber: json['seasonNumber'] ?? 0,
      coverImage: json['coverImage'] ?? '', // Add this property
      episodes: json['episodes'] != null
        ? (json['episodes'] as List)
            .map((episode) => Episode.fromJson(episode))
            .toList()
        : [],
    );
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

  Episode({
    required this.title,
    required this.thumbnail,
    required this.videoUrl,
  });

  // JSON'dan Episode nesnesine dönüştürme
  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
    );
  }

  // Optional: toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'thumbnail': thumbnail,
      'videoUrl': videoUrl,
    };
  }
}