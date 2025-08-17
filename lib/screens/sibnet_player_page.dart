import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SibnetPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const SibnetPlayerPage({
    required this.videoUrl,
    required this.videoTitle,
    super.key,
  });

  @override
  State<SibnetPlayerPage> createState() => _SibnetPlayerPageState();
}

class _SibnetPlayerPageState extends State<SibnetPlayerPage> {
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _setupFullScreen();
    _initWebView();
  }

  @override
  void dispose() {
    _exitFullScreen();
    super.dispose();
  }

  void _setupFullScreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('✅ Sibnet sayfası yüklendi: $url');
            // Sayfa yüklendiğinde 1.5 saniye sonra temizle
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                _removeSibnetElements();
              }
            });

            // MutationObserver ile sürekli izle (gecikmeli yüklenen logolar için)
            _startMutationObserver();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView hatası: $error');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.videoUrl));
  }

  void _startMutationObserver() {
    _webViewController.runJavaScript('''
      // MutationObserver: DOM değişikliklerini izle
      const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          // Yeni eklenen node'ları kontrol et
          if (mutation.addedNodes.length > 0) {
            // ID'ye göre kaldır
            const logo = document.getElementById('vjs-logobrand-image');
            if (logo) logo.remove();

            // Class'lara göre kaldır
            const elements = document.querySelectorAll(
              '.vjs-logobrand, .ad-banner, .watermark, .popup-ad, .overlay-logo, .vjs-control-bar'
            );
            elements.forEach(el => el.remove());
          }
        });
      });

      // Gözlemlemeye başla
      observer.observe(document.body, { childList: true, subtree: true });
    ''');
  }

  void _removeSibnetElements() {
    _webViewController.runJavaScript('''
      // 1. Direk kaldır
      const logo = document.getElementById('vjs-logobrand-image');
      if (logo) logo.remove();

      const elements = document.querySelectorAll(
        '.vjs-logobrand, .ad-banner, .watermark, .popup-ad, .overlay-logo, .vjs-control-bar'
      );
      elements.forEach(el => el.remove());

      // 2. iframe içindeyse (bazı Sibnet videoları iframe kullanır)
      const iframe = document.querySelector('iframe');
      if (iframe && iframe.contentDocument) {
        const iframeLogo = iframe.contentDocument.getElementById('vjs-logobrand-image');
        if (iframeLogo) iframeLogo.remove();
        iframe.contentDocument.querySelectorAll('.vjs-logobrand').forEach(el => el.remove());
      }

      // 3. CSS ile gizle (son önlem)
      const style = document.createElement('style');
      style.textContent = `
        .vjs-logobrand, #vjs-logobrand-image, .ad-banner, .watermark, .popup-ad {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          height: 0 !important;
          width: 0 !important;
        }
      `;
      document.head.appendChild(style);
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _webViewController),

          // Geri Butonu
          Positioned(
            top: 40,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // "Temizle" Butonu (Manuel)
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.block, color: Colors.white),
                  onPressed: () {
                    _removeSibnetElements();
                  },
                  tooltip: 'Logoyu Kaldır',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
