import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.black87],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Başlık İkonu
                  const Icon(Icons.lock_outline, size: 80, color: Colors.white),

                  const SizedBox(height: 20),

                  // Kart Tasarımı
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.white.withOpacity(0.9),
                    child: const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            "Gizlilik Politikası",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Bu uygulama kullanıcı verilerini gizli tutar ve yalnızca uygulama deneyimini geliştirmek için kullanır. "
                            "Kullanıcıların verileri üçüncü taraflarla paylaşılmaz. "
                            "Playtoon 5651 sayılı kanuna göre içerik sağlayıcıdır. Uygulamızda yer alan içerikler, üyelerimiz tarafından yüklenmektedir. "
                            "Uygulamamızda yer alan içeriklerden herhangi bir telif hakkı ihlali söz konusu ise, bizimle playtoonapp@gmail.com mail adresinden iletişime geçmeniz halinde "
                            "ilgili içerik en geç 3 iş günü içerisinde kaldırılacaktır.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Kapat Butonu
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text("Geri Dön", style: TextStyle(fontSize: 16, color: Colors.white)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
