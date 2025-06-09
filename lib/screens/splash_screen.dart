// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:videoapp/models/auth_service.dart';
import 'package:videoapp/screens/sign_in_page.dart';
// Import SignUpPage
import 'package:videoapp/screens/video_list_page.dart'; // Import VideoListPage
import 'package:package_info_plus/package_info_plus.dart'; // Import ekleyin
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth import edin

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();
  
  // Sürüm bilgisi için değişken ekleyin
  String _appVersion = 'v1.0.0'; // Varsayılan değer

  @override
  void initState() {
    super.initState();
    
    // Ekranı dikey ve tam ekran moduna ayarla
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Sürüm bilgisini yükle
    _loadAppVersion();
    
    // Animasyon kontrolcüsü
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Fade-in animasyonu
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    // Animasyonu başlat
    _animationController.forward();
    
    // 3 saniye sonra ana sayfaya geç
    Timer(const Duration(seconds: 3), () {
      _checkAuthState();
    });
  }

  // Sürüm bilgisini yükleme fonksiyonu ekleyin
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}';
        });
      }
    } catch (e) {
      print("Sürüm bilgisi yüklenirken hata: $e");
    }
  }

  Future<void> _checkAuthState() async {
    try {
      // Firebase'in hazır olmasını bekleme
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mevcut bir oturum var mı?
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        print('Mevcut oturum bulundu: ${user.email}');
        // Kullanıcı zaten giriş yapmış, ana sayfaya yönlendir
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VideoListPage()),
        );
      } else {
        print('Oturum bulunamadı, giriş sayfasına yönlendiriliyor');
        // Oturum yok, giriş sayfasına yönlendir
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      }
    } catch (e) {
      print('Oturum kontrolünde hata: $e');
      // Hata durumunda güvenli yönlendirme
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 100,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Uygulama adı
                const Text(
                  'Playtoon',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 20),
                // Yükleniyor animasyonu
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                // Versiyon - şimdi dinamik değişkeni kullanıyor
                Text(
                  _appVersion, // Sabit değer yerine değişken kullanın
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}