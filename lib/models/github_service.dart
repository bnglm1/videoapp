import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:videoapp/models/video_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GitHubService {
  // GitHub raw file URL'inizi buraya yazın
  // Örnek: https://raw.githubusercontent.com/kullanici_adi/repo_adi/main/series.json
  static const String _githubJsonUrl =
      'https://raw.githubusercontent.com/playtoon1/content-json/refs/heads/main/content.json';

  // Wikipedia API endpoints
  static const String _wikipediaApiUrl = 'https://tr.wikipedia.org/api/rest_v1';
  static const String _wikipediaSearchUrl =
      'https://tr.wikipedia.org/w/api.php';

  Future<List<Series>> fetchSeries() async {
    try {
      print("GitHub'dan veri çekiliyor: $_githubJsonUrl");

      final response = await http.get(
        Uri.parse(_githubJsonUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      print("HTTP Status Code: ${response.statusCode}");
      print("Response Headers: ${response.headers}");

      if (response.statusCode == 200) {
        final String jsonString = response.body;
        print("JSON Response length: ${jsonString.length}");
        print(
            "First 200 chars: ${jsonString.length > 200 ? jsonString.substring(0, 200) : jsonString}");

        if (jsonString.isEmpty) {
          print("Boş JSON response alındı");
          return [];
        }

        late Map<String, dynamic> jsonData;
        try {
          jsonData = json.decode(jsonString);
          print("JSON decode başarılı. Keys: ${jsonData.keys.toList()}");
        } catch (e) {
          print("JSON decode hatası: $e");
          return [];
        }

        List<Series> seriesList = [];

        // JSON yapısını kontrol et
        if (jsonData.containsKey('series')) {
          print("'series' key'i bulundu");
          var seriesData = jsonData['series'];
          print("Series data type: ${seriesData.runtimeType}");

          if (seriesData is Map) {
            print("Series Map formatında, ${seriesData.length} adet seri");
            Map<String, dynamic> seriesMap =
                Map<String, dynamic>.from(seriesData);

            seriesMap.forEach((key, value) {
              try {
                print("İşleniyor: $key");
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(value);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
                print("✓ İşlenen seri: ${series.title}");
              } catch (e) {
                print("✗ Seri dönüştürme hatası ($key): $e");
                print("Value type: ${value.runtimeType}");
                print("Value: $value");
              }
            });
          } else if (seriesData is List) {
            print("Series List formatında, ${seriesData.length} adet seri");
            List<dynamic> seriesArray = List<dynamic>.from(seriesData);

            for (int i = 0; i < seriesArray.length; i++) {
              try {
                print("İşleniyor index: $i");
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(seriesArray[i]);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
                print("✓ İşlenen seri: ${series.title}");
              } catch (e) {
                print("✗ Seri dönüştürme hatası (index $i): $e");
                print("Value type: ${seriesArray[i].runtimeType}");
              }
            }
          } else {
            print("Beklenmeyen series data formatı: ${seriesData.runtimeType}");
          }
        } else {
          print(
              "JSON'da 'series' key'i bulunamadı. Mevcut keys: ${jsonData.keys.toList()}");

          // Eğer JSON direkt olarak series array'i ise
          if (jsonData is List) {
            print("JSON direkt List formatında");
            for (int i = 0; i < jsonData.length; i++) {
              try {
                Map<String, dynamic> seriesItemData =
                    _convertToStringDynamicMap(jsonData[i]);
                Series series = Series.fromJson(seriesItemData);
                seriesList.add(series);
                print("✓ İşlenen seri: ${series.title}");
              } catch (e) {
                print("✗ Seri dönüştürme hatası (index $i): $e");
              }
            }
          }
        }

        print("GitHub'dan yüklenen seri sayısı: ${seriesList.length}");
        return seriesList;
      } else {
        print("GitHub'dan veri çekme hatası: ${response.statusCode}");
        print("Response body: ${response.body}");
        return [];
      }
    } catch (e) {
      print("GitHub veri çekme hatası: $e");
      print("Stack trace: ${StackTrace.current}");
      return [];
    }
  }

  Future<Series?> fetchSeriesById(String id) async {
    try {
      // Tüm serileri çek ve ID'ye göre filtrele
      final allSeries = await fetchSeries();

      // ID'ye göre seriyi bul (JSON'daki key ile eşleştir)
      for (var series in allSeries) {
        // Eğer series modeline id field'ı eklediyseniz:
        // if (series.id == id) return series;

        // Alternatif olarak title veya başka bir özellikle kontrol edebilirsiniz
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

  // Utility method to convert dynamic map to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    // Handle different map types
    if (value is Map) {
      return value.map<String, dynamic>((key, value) => MapEntry(
          key.toString(),
          // Recursively convert nested maps and lists
          value is Map
              ? _convertToStringDynamicMap(value)
              : value is List
                  ? _convertListToDynamic(value)
                  : value));
    }

    // If not a map, return an empty map
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

  // Episode detaylarını getir
  Future<Map<String, dynamic>?> fetchEpisodeDetails(String episodeId) async {
    try {
      print("Episode detayları getiriliyor: $episodeId");

      // Önce tüm series verilerini getir
      final response = await http.get(
        Uri.parse(_githubJsonUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Episode'u tüm series'lerde ara
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
                          // Episode bilgilerini döndür
                          Map<String, dynamic> episodeDetails =
                              Map<String, dynamic>.from(episode);

                          // Ek meta bilgiler ekle
                          episodeDetails['seriesId'] = seriesEntry.key;
                          episodeDetails['seriesTitle'] = series['title'] ?? '';
                          episodeDetails['seasonId'] = seasonEntry.key;
                          episodeDetails['episodeId'] = episodeId;

                          print(
                              "Episode detayları bulundu: ${episodeDetails['title']}");
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
      }

      print("Episode detayları bulunamadı: $episodeId");
      return null;
    } catch (e) {
      print("Episode detayları getirme hatası: $e");
      return null;
    }
  }

  // İlgili bölümleri getir (aynı seri/sezon)
  Future<List<Map<String, dynamic>>> fetchRelatedEpisodes(
      String seriesId, String seasonId,
      {int limit = 5}) async {
    try {
      print("İlgili bölümler getiriliyor: $seriesId/$seasonId");

      final response = await http.get(
        Uri.parse(_githubJsonUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Flutter App',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
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

        print("${relatedEpisodes.length} ilgili bölüm bulundu");
        return relatedEpisodes;
      }

      return [];
    } catch (e) {
      print("İlgili bölümler getirme hatası: $e");
      return [];
    }
  }

  // Seri bilgilerini getir
  Future<Map<String, dynamic>?> fetchSeriesInfo(String seriesId) async {
    try {
      print("Seri bilgileri getiriliyor: $seriesId");

      final response = await http.get(
        Uri.parse(_githubJsonUrl),
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

              print("Seri bilgileri bulundu: ${seriesInfo['title']}");
              return seriesInfo;
            }
          }
        }
      }

      return null;
    } catch (e) {
      print("Seri bilgileri getirme hatası: $e");
      return null;
    }
  }

  // Wikipedia arama
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

  // Wikipedia özet getir
  Future<Map<String, dynamic>?> getWikipediaSummary(String title) async {
    try {
      print("Wikipedia özeti getiriliyor: $title");

      // Başlığı URL-safe hale getir
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

  // Wikipedia'dan dizi/film bilgisi getir (başlığa göre)
  Future<Map<String, dynamic>?> getWikipediaInfoForSeries(
      String seriesTitle) async {
    try {
      // Önce direkt başlık ile dene
      var summary = await getWikipediaSummary(seriesTitle);
      if (summary != null) {
        return summary;
      }

      // Bulunamazsa arama yap
      var searchResults = await searchWikipedia(seriesTitle);
      if (searchResults.isNotEmpty) {
        // İlk sonucun özetini getir
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

  // Wikipedia'dan bölüm bilgisi getir
  Future<Map<String, dynamic>?> getWikipediaInfoForEpisode(
      String episodeTitle, String seriesTitle) async {
    try {
      // Önce "SeriesTitle episodeTitle" formatında dene
      String combinedTitle = "$seriesTitle $episodeTitle";
      var summary = await getWikipediaSummary(combinedTitle);
      if (summary != null) {
        return summary;
      }

      // Sonra sadece bölüm başlığı ile dene
      summary = await getWikipediaSummary(episodeTitle);
      if (summary != null) {
        return summary;
      }

      // Son olarak arama yap
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

  // Episode navigation için tüm bölümleri flat liste halinde getir
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
              'seriesId': series.title, // Series title as ID
              'seriesTitle': series.title,
              'seasonNumber': season.seasonNumber,
              'episodeIndex': allEpisodes.length, // Global episode index
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

  // Belirli bir serinin tüm bölümlerini getir
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

  // Belirli bir episode'un index'ini bulur
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

  // Seri izlenme sayıları hesaplama
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
          // Seri adını bölüm başlığından çıkar
          // Örnek: "Attack on Titan 1. Sezon 1. Bölüm" -> "Attack on Titan"
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

  // Bölüm başlığından seri adını çıkaran yardımcı metod
  String _extractSeriesName(String episodeTitle) {
    // Yaygın kalıpları temizle
    String cleanTitle = episodeTitle;

    // "1. Sezon", "Sezon 1", "Bölüm 1" gibi ifadeleri kaldır
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
