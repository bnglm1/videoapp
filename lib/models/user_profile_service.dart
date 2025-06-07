import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Mevcut kullanıcı ID'sini al
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Kullanıcı profil bilgilerini getir
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUserId == null) return null;
    
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    return userDoc.data();
  }
  
  // Son izlenen videoları getir
  Future<List<Map<String, dynamic>>> getRecentlyWatched({int limit = 10}) async {
    if (currentUserId == null) return [];
    
    final watchHistorySnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('watchHistory')
        .orderBy('lastWatched', descending: true)
        .limit(limit)
        .get();
    
    return watchHistorySnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }
  
  // Favori serileri getir
  Future<List<Map<String, dynamic>>> getFavorites() async {
    if (currentUserId == null) return [];
    
    final favoritesSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('favorites')
        .get();
    
    return favoritesSnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }
  
  // Bitirilen serileri getir
  Future<List<Map<String, dynamic>>> getCompletedShows() async {
    if (currentUserId == null) return [];
    
    final completedSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('completedShows')
        .get();
    
    return completedSnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }
  
  // Kullanıcı isteklerini getir
  Future<List<Map<String, dynamic>>> getUserRequests() async {
    if (currentUserId == null) return [];
    
    final requestsSnapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('requests')
        .orderBy('timestamp', descending: true)
        .get();
    
    return requestsSnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }
  
  // Yeni istek ekle
  Future<void> addRequest(String requestText) async {
    if (currentUserId == null) return;
    
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('requests')
        .add({
          'text': requestText,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending', // pending, approved, rejected
        });
  }
  
  // Seriyi favorilere ekle/çıkar
  Future<void> toggleFavorite(String seriesId, String seriesTitle, String posterUrl) async {
    if (currentUserId == null) return;
    
    final docRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('favorites')
        .doc(seriesId);
        
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'seriesId': seriesId,
        'title': seriesTitle, 
        'posterUrl': posterUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Seriyi tamamlandı olarak işaretle/kaldır
  Future<void> toggleCompleted(String seriesId, String seriesTitle, String posterUrl) async {
    if (currentUserId == null) return;
    
    final docRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('completedShows')
        .doc(seriesId);
        
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'seriesId': seriesId,
        'title': seriesTitle,
        'posterUrl': posterUrl,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}