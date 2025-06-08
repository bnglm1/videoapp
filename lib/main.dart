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
      systemNavigationBarIconBrightness: Brightness.light, // Gezinti çubuğu simgeleri beyaz
    ),
  );

  // Uygulamayı başlat
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playtoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blueAccent,
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent,
        ),
        // Metin seçimi teması - imlec ve seçim balonları rengi
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.blueAccent, // İmleç rengi
          selectionHandleColor: Colors.blueAccent, // İmleç uçlarındaki balonlar
          selectionColor: Colors.blueAccent, // Metin seçim rengi (transparanlık otomatik)
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
