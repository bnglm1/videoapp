import 'package:firebase_database/firebase_database.dart';
import 'package:videoapp/models/video_model.dart';

class FirebaseService {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('series');

  Future<List<Series>> fetchSeries() async {
    try {
      final snapshot = await _databaseRef.get();
      if (snapshot.exists && snapshot.value != null) {
        List<Series> seriesList = [];
        if (snapshot.value is Map) {
          Map<dynamic, dynamic> rawValues = snapshot.value as Map<dynamic, dynamic>;
          rawValues.forEach((key, value) {
            try {
              // Explicitly convert to Map<String, dynamic>
              Map<String, dynamic> seriesMap = _convertToStringDynamicMap(value);
              
              // Debug bilgisi
              print("İşlenen seri: ${seriesMap['title']}");
              
              // Create Series object directly from seriesMap
              Series series = Series.fromJson(seriesMap);
              seriesList.add(series);
            } catch (e) {
              print("Seri dönüştürme hatası ($key): $e");
              print("Hatalı veri: $value");
            }
          });
        }
        print("Yüklenen seri sayısı: ${seriesList.length}");
        return seriesList;
      }
      print("Firebase'de veri bulunamadı.");
      return [];
    } catch (e) {
      print("Firebase veri çekme hatası: $e");
      return [];
    }
  }

  Future<Series?> fetchSeriesById(String id) async {
    try {
      final snapshot = await _databaseRef.child(id).get();
      if (snapshot.exists && snapshot.value is Map) {
        // Explicitly convert to Map<String, dynamic>
        final data = _convertToStringDynamicMap(snapshot.value);
        
        // Debug bilgisi
        print("İşlenen seri: ${data['title']}");
        
        // Create Series object directly from data
        return Series.fromJson(data);
      } else {
        print("Seri bulunamadı.");
        return null;
      }
    } catch (e) {
      print("Firebase'den seri alınırken hata oluştu: $e");
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
      return value.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), 
          // Recursively convert nested maps and lists
          value is Map 
            ? _convertToStringDynamicMap(value)
            : value is List
              ? _convertListToDynamic(value)
              : value
        )
      );
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
}