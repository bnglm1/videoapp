import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:videoapp/models/video_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GitHubService {
  // Birden fazla JSON dosyası URL'leri
  static const List<String> _githubJsonUrls = [
    'https://raw.githubusercontent.com/playtoon1/content-json/refs/heads/main/content.json',
    'https://raw.githubusercontent.com/playtoon1/content-json/refs/heads/main/content2.json',
    // İleriye dönük: content3.json, content4.json vb. ekleyebilirsiniz
  ];

  // Wikipedia API endpoints
  static const String _wikipediaApiUrl = 'https://tr.wikipedia.org/api/rest_v1';
  static const String _wikipediaSearchUrl =
      'https://tr.wikipedia.org/w/api.php';

  // Tüm JSON dosyalarından series verilerini çek ve birleştir
  Future<List<Series>> fetchSeries() async {
    List<Series> allSeries = [];

    print("Toplam ${_githubJsonUrls.length} adet JSON dosyası işlenecek");

    for (int i = 0; i < _githubJsonUrls.length; i++) {
      try {
        print(
            "JSON dosyası ${i + 1}/${_githubJsonUrls.length} işleniyor: ${_githubJsonUrls[i]}");

        final seriesFromFile =
            await _fetchSeriesFromUrl(_githubJsonUrls[i], i + 1);
        allSeries.addAll(seriesFromFile);

        print(
            "✅ JSON ${i + 1} başarılı: ${seriesFromFile.length} seri eklendi");
      } catch (e) {
        print("❌ JSON ${i + 1} hata: $e");
        // Bir dosya hata verse bile diğerlerini çekmeye devam et
        continue;
      }
    }

    print("Toplam yüklenen seri sayısı: ${allSeries.length}");
    return allSeries;
  }

  // Tek bir JSON dosyasından series verilerini çek
  Future<List<Series>> _fetchSeriesFromUrl(String url, int fileNumber) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      if (response.statusCode == 200) {
        final String jsonString = response.body;

        if (jsonString.isEmpty) {
          print("Boş JSON response alındı - Dosya $fileNumber");
          return [];
        }

        late Map<String, dynamic> jsonData;
        try {
          jsonData = json.decode(jsonString);
        } catch (e) {
          print("JSON decode hatası - Dosya $fileNumber: $e");
          return [];
        }

        List<Series> seriesList = [];

        // JSON yapısını kontrol et
        if (jsonData.containsKey('series')) {
          var seriesData = jsonData['series'];

          if (seriesData is Map) {
            Map<String, dynamic> seriesMap =
                Map<String, dynamic>.from(seriesData);

            seriesMap.forEach((key, value) {
              try {
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(value);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
              } catch (e) {
                print("Seri dönüştürme hatası ($key) - Dosya $fileNumber: $e");
              }
            });
          } else if (seriesData is List) {
            List<dynamic> seriesArray = List<dynamic>.from(seriesData);

            for (int i = 0; i < seriesArray.length; i++) {
              try {
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(seriesArray[i]);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
              } catch (e) {
                print(
                    "Seri dönüştürme hatası (index $i) - Dosya $fileNumber: $e");
              }
            }
          }
        } else {
          // Eğer JSON direkt olarak series array'i ise
          if (jsonData is List) {
            for (int i = 0; i < jsonData.length; i++) {
              try {
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(jsonData[i]);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
              } catch (e) {
                print(
                    "Seri dönüştürme hatası (index $i) - Dosya $fileNumber: $e");
              }
            }
          }
        }

        return seriesList;
      } else {
        print(
            "GitHub'dan veri çekme hatası - Dosya $fileNumber: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("GitHub veri çekme hatası - Dosya $fileNumber: $e");
      return [];
    }
  }

  // Belirli bir seriyi tüm JSON dosyalarında ara
  Future<Series?> fetchSeriesById(String id) async {
    try {
      // Tüm serileri çek ve ID'ye göre filtrele
      final allSeries = await fetchSeries();

      for (var series in allSeries) {
        if (series.title.toLowerCase().replaceAll(' ', '') ==
            id.toLowerCase()) {
          return series;
        }
      }

      print("ID'si $id olan seri bulunamadı.");
      return null;
    } catch (e) {
      print("GitHub'dan seri alınırken hata oluştu: $e");
      return null;
    }
  }

  // Episode detaylarını tüm JSON dosyalarında ara
  Future<Map<String, dynamic>?> fetchEpisodeDetails(String episodeId) async {
    for (int i = 0; i < _githubJsonUrls.length; i++) {
      try {
        print("Episode aranıyor - Dosya ${i + 1}: $episodeId");

        final response = await http.get(
          Uri.parse(_githubJsonUrls[i]),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Flutter App',
          },
        );

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          // Episode'u bu JSON dosyasında ara
          final episodeDetails = _searchEpisodeInJsonData(jsonData, episodeId);

          if (episodeDetails != null) {
            print(
                "Episode bulundu - Dosya ${i + 1}: ${episodeDetails['title']}");
            return episodeDetails;
          }
        }
      } catch (e) {
        print("Episode arama hatası - Dosya ${i + 1}: $e");
        continue;
      }
    }

    print("Episode detayları bulunamadı: $episodeId");
    return null;
  }

  // JSON data içinde episode arama yardımcı metodu
  Map<String, dynamic>? _searchEpisodeInJsonData(
      Map<String, dynamic> jsonData, String episodeId) {
    if (jsonData.containsKey('series')) {
      final seriesData = jsonData['series'];

      if (seriesData is Map) {
        for (var seriesEntry in seriesData.entries) {
          final series = seriesEntry.value;
          if (series is Map && series.containsKey('seasons')) {
            final seasons = series['seasons'];
            if (seasons is Map) {
              for (var seasonEntry in seasons.entries) {
                final season = seasonEntry.value;
                if (season is Map && season.containsKey('episodes')) {
                  final episodes = season['episodes'];
                  if (episodes is Map && episodes.containsKey(episodeId)) {
                    final episode = episodes[episodeId];
                    if (episode is Map) {
                      Map<String, dynamic> episodeDetails =
                          Map<String, dynamic>.from(episode);

                      // Ek meta bilgiler ekle
                      episodeDetails['seriesId'] = seriesEntry.key;
                      episodeDetails['seriesTitle'] = series['title'] ?? '';
                      episodeDetails['seasonId'] = seasonEntry.key;
                      episodeDetails['episodeId'] = episodeId;

                      return episodeDetails;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  // İlgili bölümleri getir - tüm JSON dosyalarında ara
  Future<List<Map<String, dynamic>>> fetchRelatedEpisodes(
      String seriesId, String seasonId,
      {int limit = 5}) async {
    for (int i = 0; i < _githubJsonUrls.length; i++) {
      try {
        final response = await http.get(
          Uri.parse(_githubJsonUrls[i]),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Flutter App',
          },
        );

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          final relatedEpisodes = _getRelatedEpisodesFromJsonData(
              jsonData, seriesId, seasonId, limit);

          if (relatedEpisodes.isNotEmpty) {
            print(
                "${relatedEpisodes.length} ilgili bölüm bulundu - Dosya ${i + 1}");
            return relatedEpisodes;
          }
        }
      } catch (e) {
        print("İlgili bölümler getirme hatası - Dosya ${i + 1}: $e");
        continue;
      }
    }

    return [];
  }

  // JSON data'dan ilgili bölümleri getiren yardımcı metod
  List<Map<String, dynamic>> _getRelatedEpisodesFromJsonData(
      Map<String, dynamic> jsonData,
      String seriesId,
      String seasonId,
      int limit) {
    List<Map<String, dynamic>> relatedEpisodes = [];

    if (jsonData.containsKey('series')) {
      final seriesData = jsonData['series'];

      if (seriesData is Map &&
          seriesData.containsKey(seriesId) &&
          seriesData[seriesId] is Map) {
        final series = seriesData[seriesId];
        if (series.containsKey('seasons') &&
            series['seasons'] is Map &&
            series['seasons'].containsKey(seasonId)) {
          final season = series['seasons'][seasonId];
          if (season is Map && season.containsKey('episodes')) {
            final episodes = season['episodes'];

            if (episodes is Map) {
              var episodeEntries = episodes.entries.take(limit).toList();

              for (var entry in episodeEntries) {
                if (entry.value is Map) {
                  Map<String, dynamic> episode =
                      Map<String, dynamic>.from(entry.value);
                  episode['episodeId'] = entry.key;
                  episode['seriesId'] = seriesId;
                  episode['seasonId'] = seasonId;
                  relatedEpisodes.add(episode);
                }
              }
            }
          }
        }
      }
    }

    return relatedEpisodes;
  }

  // Seri bilgilerini tüm JSON dosyalarında ara
  Future<Map<String, dynamic>?> fetchSeriesInfo(String seriesId) async {
    for (int i = 0; i < _githubJsonUrls.length; i++) {
      try {
        final response = await http.get(
          Uri.parse(_githubJsonUrls[i]),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Flutter App',
          },
        );

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          if (jsonData.containsKey('series')) {
            final seriesData = jsonData['series'];

            if (seriesData is Map && seriesData.containsKey(seriesId)) {
              final series = seriesData[seriesId];
              if (series is Map) {
                Map<String, dynamic> seriesInfo =
                    Map<String, dynamic>.from(series);
                seriesInfo['seriesId'] = seriesId;

                print(
                    "Seri bilgileri bulundu - Dosya ${i + 1}: ${seriesInfo['title']}");
                return seriesInfo;
              }
            }
          }
        }
      } catch (e) {
        print("Seri bilgileri getirme hatası - Dosya ${i + 1}: $e");
        continue;
      }
    }

    return null;
  }

  // Utility method to convert dynamic map to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>((key, value) => MapEntry(
          key.toString(),
          value is Map
              ? _convertToStringDynamicMap(value)
              : value is List
                  ? _convertListToDynamic(value)
                  : value));
    }

    print("Uyarı: Geçersiz veri türü - ${value.runtimeType}");
    return {};
  }

  // Utility method to convert lists with mixed types
  List<dynamic> _convertListToDynamic(List? list) {
    if (list == null) return [];

    return list.map((item) {
      if (item is Map) {
        return _convertToStringDynamicMap(item);
      }
      if (item is List) {
        return _convertListToDynamic(item);
      }
      return item;
    }).toList();
  }

  // Wikipedia metodları değişmedi - mevcut kodunuz aynen kalabilir
  Future<List<Map<String, dynamic>>> searchWikipedia(String query) async {
    try {
      print("Wikipedia'da aranan: $query");

      final searchParams = {
        'action': 'query',
        'format': 'json',
        'list': 'search',
        'srsearch': query,
        'srlimit': '5',
        'srprop': 'snippet|titlesnippet',
        'formatversion': '2',
      };

      final uri =
          Uri.parse(_wikipediaSearchUrl).replace(queryParameters: searchParams);

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Flutter VideoApp/1.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData.containsKey('query') &&
            jsonData['query'].containsKey('search')) {
          List<dynamic> searchResults = jsonData['query']['search'];

          List<Map<String, dynamic>> results = [];
          for (var result in searchResults) {
            if (result is Map) {
              results.add({
                'title': result['title'] ?? '',
                'snippet': result['snippet'] ?? '',
                'pageid': result['pageid'] ?? 0,
              });
            }
          }

          print("Wikipedia'da ${results.length} sonuç bulundu");
          return results;
        }
      }

      return [];
    } catch (e) {
      print("Wikipedia arama hatası: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getWikipediaSummary(String title) async {
    try {
      print("Wikipedia özeti getiriliyor: $title");

      final encodedTitle = Uri.encodeComponent(title);
      final summaryUrl = '$_wikipediaApiUrl/page/summary/$encodedTitle';

      final response = await http.get(
        Uri.parse(summaryUrl),
        headers: {
          'User-Agent': 'Flutter VideoApp/1.0',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        return {
          'title': jsonData['title'] ?? '',
          'extract': jsonData['extract'] ?? '',
          'description': jsonData['description'] ?? '',
          'thumbnail': jsonData['thumbnail']?['source'] ?? '',
          'content_urls': jsonData['content_urls']?['desktop']?['page'] ?? '',
        };
      } else if (response.statusCode == 404) {
        print("Wikipedia'da sayfa bulunamadı: $title");
        return null;
      }

      return null;
    } catch (e) {
      print("Wikipedia özet getirme hatası: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWikipediaInfoForSeries(
      String seriesTitle) async {
    try {
      var summary = await getWikipediaSummary(seriesTitle);
      if (summary != null) {
        return summary;
      }

      var searchResults = await searchWikipedia(seriesTitle);
      if (searchResults.isNotEmpty) {
        String firstResultTitle = searchResults.first['title'];
        summary = await getWikipediaSummary(firstResultTitle);
        return summary;
      }

      return null;
    } catch (e) {
      print("Wikipedia seri bilgisi getirme hatası: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getWikipediaInfoForEpisode(
      String episodeTitle, String seriesTitle) async {
    try {
      String combinedTitle = "$seriesTitle $episodeTitle";
      var summary = await getWikipediaSummary(combinedTitle);
      if (summary != null) {
        return summary;
      }

      summary = await getWikipediaSummary(episodeTitle);
      if (summary != null) {
        return summary;
      }

      var searchResults = await searchWikipedia("$seriesTitle $episodeTitle");
      if (searchResults.isNotEmpty) {
        String firstResultTitle = searchResults.first['title'];
        summary = await getWikipediaSummary(firstResultTitle);
        return summary;
      }

      return null;
    } catch (e) {
      print("Wikipedia bölüm bilgisi getirme hatası: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllEpisodesFlat() async {
    try {
      final allSeries = await fetchSeries();
      List<Map<String, dynamic>> allEpisodes = [];

      for (var series in allSeries) {
        for (var season in series.seasons) {
          for (var episode in season.episodes) {
            allEpisodes.add({
              'title': episode.title,
              'thumbnail': episode.thumbnail,
              'videoUrl': episode.videoUrl,
              'useWebView': episode.shouldUseWebView,
              'playerType': episode.shouldUseWebView ? 'webview' : 'native',
              'seriesId': series.title,
              'seriesTitle': series.title,
              'seasonNumber': season.seasonNumber,
              'episodeIndex': allEpisodes.length,
            });
          }
        }
      }

      return allEpisodes;
    } catch (e) {
      print("Tüm episode listesi getirme hatası: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSeriesEpisodes(
      String seriesTitle) async {
    try {
      final allSeries = await fetchSeries();
      List<Map<String, dynamic>> seriesEpisodes = [];

      for (var series in allSeries) {
        if (series.title.toLowerCase() == seriesTitle.toLowerCase()) {
          for (var season in series.seasons) {
            for (var episode in season.episodes) {
              seriesEpisodes.add({
                'title': episode.title,
                'thumbnail': episode.thumbnail,
                'videoUrl': episode.videoUrl,
                'useWebView': episode.shouldUseWebView,
                'playerType': episode.shouldUseWebView ? 'webview' : 'native',
                'seriesId': series.title,
                'seriesTitle': series.title,
                'seasonNumber': season.seasonNumber,
                'episodeIndex': seriesEpisodes.length,
              });
            }
          }
          break;
        }
      }

      return seriesEpisodes;
    } catch (e) {
      print("Seri episode listesi getirme hatası: $e");
      return [];
    }
  }

  Future<int?> findEpisodeIndex(
      String episodeTitle, String? seriesTitle) async {
    try {
      List<Map<String, dynamic>> episodeList;

      if (seriesTitle != null && seriesTitle.isNotEmpty) {
        episodeList = await getSeriesEpisodes(seriesTitle);
      } else {
        episodeList = await getAllEpisodesFlat();
      }

      for (int i = 0; i < episodeList.length; i++) {
        if (episodeList[i]['title'].toString().toLowerCase() ==
            episodeTitle.toLowerCase()) {
          return i;
        }
      }

      return null;
    } catch (e) {
      print("Episode index bulma hatası: $e");
      return null;
    }
  }

  Future<Map<String, int>> calculateSeriesViewCounts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final videosSnapshot = await firestore.collection('videos').get();

      Map<String, int> seriesViewCounts = {};

      for (var doc in videosSnapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String?;
        final views = (data['views'] as num?)?.toInt() ?? 0;

        if (title != null && title.isNotEmpty) {
          String seriesName = _extractSeriesName(title);

          if (seriesViewCounts.containsKey(seriesName)) {
            seriesViewCounts[seriesName] =
                seriesViewCounts[seriesName]! + views;
          } else {
            seriesViewCounts[seriesName] = views;
          }
        }
      }

      return seriesViewCounts;
    } catch (e) {
      print("Seri izlenme sayıları hesaplanırken hata: $e");
      return {};
    }
  }

  String _extractSeriesName(String episodeTitle) {
    String cleanTitle = episodeTitle;

    final patterns = [
      RegExp(r'\s*\d+\.\s*Sezon.*', caseSensitive: false),
      RegExp(r'\s*Sezon\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*\d+\.\s*Bölüm.*', caseSensitive: false),
      RegExp(r'\s*Bölüm\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*Episode\s*\d+.*', caseSensitive: false),
      RegExp(r'\s*S\d+E\d+.*', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      cleanTitle = cleanTitle.replaceFirst(pattern, '');
    }

    return cleanTitle.trim();
  }
}
