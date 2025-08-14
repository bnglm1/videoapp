import 'package:http/http.dart' as http;

/// Video kaynaklarını yönetmek için servis sınıfı
class VideoService {
  static const Duration _timeout = Duration(seconds: 30);

  /// Video URL'sinden meta bilgileri çeker
  static Future<Map<String, dynamic>?> getVideoMetadata(String videoUrl) async {
    try {
      print('Video metadata çekiliyor: $videoUrl');

      final response = await http.get(
        Uri.parse(videoUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return {
          'url': videoUrl,
          'contentType': response.headers['content-type'],
          'contentLength': response.headers['content-length'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('Video metadata hatası: $e');
    }
    return null;
  }

  /// Video URL'sinin geçerli olup olmadığını kontrol eder
  static Future<bool> isVideoUrlValid(String videoUrl) async {
    try {
      if (videoUrl.isEmpty) return false;

      // Yerel dosya kontrolü
      if (videoUrl.startsWith('file://') || videoUrl.startsWith('/')) {
        return true; // Yerel dosyalar için true döndür
      }

      // HTTP kontrolü
      final response = await http.head(
        Uri.parse(videoUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(_timeout);

      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      print('Video URL kontrolü hatası: $e');
      return false;
    }
  }

  /// Platform bazında en uygun video kaynağını seçer
  static Map<String, dynamic>? selectBestVideoSource(
      List<Map<String, dynamic>>? videoSources) {
    if (videoSources == null || videoSources.isEmpty) return null;

    print(
        'Video kaynakları arasından en uygun seçiliyor: ${videoSources.length} kaynak');

    // Öncelik sırası: mp4 > webm > m3u8 > diğerleri
    final priorities = ['mp4', 'webm', 'm3u8', 'avi', 'mkv'];

    for (String format in priorities) {
      for (var source in videoSources) {
        final url = source['url']?.toString() ?? '';
        final quality = source['quality']?.toString() ?? '';

        if (url.toLowerCase().contains('.$format') ||
            (source['type']?.toString().toLowerCase().contains(format) ??
                false)) {
          print('En uygun kaynak seçildi: $format - $quality - $url');
          return source;
        }
      }
    }

    // Hiçbiri bulunamazsa ilkini döndür
    print('Varsayılan kaynak seçildi: ${videoSources.first}');
    return videoSources.first;
  }

  /// Video kaynağını kalite bazında filtreler
  static List<Map<String, dynamic>> filterByQuality(
      List<Map<String, dynamic>>? videoSources, String preferredQuality) {
    if (videoSources == null || videoSources.isEmpty) return [];

    final filtered = videoSources.where((source) {
      final quality = source['quality']?.toString().toLowerCase() ?? '';
      return quality.contains(preferredQuality.toLowerCase());
    }).toList();

    return filtered.isNotEmpty ? filtered : videoSources;
  }

  /// Video URL'sinin hangi platformdan olduğunu belirler
  static String detectVideoPlatform(String videoUrl) {
    final url = videoUrl.toLowerCase();

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'youtube';
    } else if (url.contains('vimeo.com')) {
      return 'vimeo';
    } else if (url.contains('dailymotion.com')) {
      return 'dailymotion';
    } else if (url.contains('facebook.com')) {
      return 'facebook';
    } else if (url.contains('instagram.com')) {
      return 'instagram';
    } else if (url.contains('tiktok.com')) {
      return 'tiktok';
    } else if (url.contains('twitch.tv')) {
      return 'twitch';
    } else if (url.contains('sibnet.ru')) {
      return 'sibnet';
    } else if (url.contains('tau-video.xyz')) {
      return 'tau-video';
    } else if (url.contains('embed') || url.contains('iframe')) {
      return 'embedded';
    } else if (url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.avi')) {
      return 'direct';
    }

    return 'unknown';
  }

  /// Platform bazında özel headers döndürür
  static Map<String, String> getPlatformHeaders(String platform) {
    final baseHeaders = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };

    switch (platform) {
      case 'sibnet':
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://sibnet.ru/',
          'Origin': 'https://sibnet.ru',
          'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.8',
        };
      case 'youtube':
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
        };
      case 'vimeo':
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://vimeo.com/',
        };
      default:
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
    }
  }

  /// Video kaynağının WebView kullanması gerekip gerekmediğini belirler
  static bool shouldUseWebView(String videoUrl) {
    final platform = detectVideoPlatform(videoUrl);

    // Direct video dosyaları native player ile oynatılır
    if (platform == 'direct') return false;

    // Embedded ve streaming platformları WebView ile oynatılır
    return [
      'youtube',
      'vimeo',
      'dailymotion',
      'facebook',
      'instagram',
      'tiktok',
      'twitch',
      'sibnet',
      'tau-video',
      'embedded',
      'unknown'
    ].contains(platform);
  }

  /// Video URL'sini temizler ve normalize eder
  static String normalizeVideoUrl(String videoUrl) {
    if (videoUrl.isEmpty) return videoUrl;

    // Başındaki ve sonundaki boşlukları temizle
    videoUrl = videoUrl.trim();

    // HTTP/HTTPS kontrolü
    if (!videoUrl.startsWith('http://') &&
        !videoUrl.startsWith('https://') &&
        !videoUrl.startsWith('file://')) {
      videoUrl = 'https://$videoUrl';
    }

    return videoUrl;
  }

  /// Video kaynakları listesini doğrular ve temizler
  static List<Map<String, dynamic>> validateVideoSources(
      List<Map<String, dynamic>>? sources) {
    if (sources == null) return [];

    return sources.where((source) {
      final url = source['url']?.toString() ?? '';
      return url.isNotEmpty && Uri.tryParse(url) != null;
    }).map((source) {
      return {
        'url': normalizeVideoUrl(source['url']?.toString() ?? ''),
        'quality': source['quality']?.toString() ?? 'Bilinmiyor',
        'type': source['type']?.toString() ?? 'video',
        'platform': detectVideoPlatform(source['url']?.toString() ?? ''),
      };
    }).toList();
  }

  /// Video bilgilerini kaydet (analytics için)
  static Future<void> logVideoPlay({
    required String videoUrl,
    required String title,
    String? platform,
    String? quality,
  }) async {
    try {
      final playData = {
        'url': videoUrl,
        'title': title,
        'platform': platform ?? detectVideoPlatform(videoUrl),
        'quality': quality ?? 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('Video oynatma kaydedildi: $playData');
      // Burada analytics servisine veri gönderebilirsiniz
    } catch (e) {
      print('Video oynatma kaydı hatası: $e');
    }
  }
}
