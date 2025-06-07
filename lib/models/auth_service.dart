// lib/models/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı giriş durumunu kontrol et
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Mevcut kullanıcıyı al
  User? get currentUser => _auth.currentUser;

  // Email ve şifre ile giriş yap
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      print("Giriş denemesi: $email");
      
      // Firebase'e giriş yap
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        print("Giriş başarılı: ${user.uid}");
        
        // Kullanıcının Firestore bilgilerini güncelle
        _updateUserLastLogin(user.uid, email);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print("Giriş hatası: $e");
      
      // PigeonUserDetails hatası aldıysak ve kullanıcı var ise yine de başarılı sayalım
      if (e.toString().contains('PigeonUserDetails') && _auth.currentUser != null) {
        print("PigeonUserDetails hatası görmezden gelindi, kullanıcı giriş yapmış sayıldı");
        return true;
      }
      
      rethrow;
    }
  }

  // Email ve şifre ile kayıt ol - TAMAMEN YENİLENMİŞ
  Future<bool> signUpWithEmail(String email, String password, String username) async {
    String? userId;
    
    // ADIM 1: Auth ile kullanıcı oluştur
    try {
      print("Kullanıcı oluşturma denemesi: $email");
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      userId = userCredential.user?.uid;
      print("Kullanıcı oluşturuldu: $userId");
      
      // UpdateDisplayName çağrısını ATLA - PigeonUserDetails hatası burada oluşuyor
      
    } catch (e) {
      print("Kullanıcı oluşturma hatası: $e");
      
      // PigeonUserDetails hatası alındıysa ve kullanıcı oluşmuşsa devam et
      if (e.toString().contains('PigeonUserDetails') && _auth.currentUser != null) {
        userId = _auth.currentUser!.uid;
        print("PigeonUserDetails hatası görmezden gelindi, kullanıcı oluşturulmuş sayıldı: $userId");
      } else {
        rethrow; // Diğer hataları tekrar fırlat
      }
    }
    
    // ADIM 2: Firestore'a kullanıcı bilgilerini ekle (userId varsa)
    if (userId != null) {
      try {
        print("Firestore'a kullanıcı bilgileri ekleniyor: $userId");
        
        await _firestore.collection('users').doc(userId).set({
          'username': username,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        print("Firestore'a kullanıcı bilgileri eklendi");
        
        // Kullanıcı adını local storage'a kaydet
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', username);
          await prefs.setString('uid', userId);
          print("SharedPreferences'e kullanıcı bilgileri kaydedildi");
        } catch (e) {
          print("SharedPreferences hatası: $e");
        }
        
        return true;
      } catch (firestoreError) {
        print("Firestore kayıt hatası: $firestoreError");
        // Firestore hatası kayıt işlemini engellemesin, kullanıcı zaten oluşturuldu
        return true;
      }
    }
    
    return false;
  }
  
  // Kullanıcı son giriş bilgilerini güncelle
  Future<void> _updateUserLastLogin(String userId, String email) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        // Kullanıcı Firestore'da yoksa yeni oluştur
        await _firestore.collection('users').doc(userId).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print("Kullanıcı Firestore'da yoktu, yeni kayıt oluşturuldu");
      } else {
        // Sadece son giriş zamanını güncelle
        await _firestore.collection('users').doc(userId).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print("Kullanıcının son giriş zamanı güncellendi");
      }
    } catch (e) {
      print("Kullanıcı bilgilerini güncellerken hata: $e");
      // Bu hata işlem akışını engellemesin
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // Local storage'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('uid');
    } catch (e) {
      print("Çıkış hatası: $e");
      throw "Çıkış yapılamadı.";
    }
  }
}