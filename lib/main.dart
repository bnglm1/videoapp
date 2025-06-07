import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:videoapp/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase ve AdMob başlatma
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  
  // Sistem UI'ı tamamen yapılandıralım
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  
  // Ekran yönünü dikey olarak sabitle
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // Sistem UI ayarları - Gezinti çubuğu ve durum çubuğu ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Durum çubuğu şeffaf
      statusBarIconBrightness: Brightness.light, // Durum çubuğu simgeleri beyaz
      systemNavigationBarColor: Colors.black, // Gezinti çubuğu rengi
      systemNavigationBarIconBrightness: Brightness.light, // Gezinti çubuğu simgeleri beyaz
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playtoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.grey[900],
          modalBackgroundColor: Colors.grey[900],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          // Aşağıdaki özellikle Bottom Sheet daha yukarıda başlar
          constraints: const BoxConstraints(
            minWidth: double.infinity,
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 16.0,
        ),
      ),
      home: const SplashScreen(),  
    );
  }
}
