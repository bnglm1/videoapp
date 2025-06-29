import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:videoapp/utils/custom_snackbar.dart';

class RequestBoxPage extends StatefulWidget {
  const RequestBoxPage({super.key});

  @override
  State<RequestBoxPage> createState() => _RequestBoxPageState();
}

class _RequestBoxPageState extends State<RequestBoxPage> {
  final TextEditingController _requestController = TextEditingController();
  bool _isSubmitting = false;

  void _sendRequest() async {
    final request = _requestController.text.trim();

    if (request.isEmpty) {
      CustomSnackbar.show(
        context: context,
        message: "Lütfen istek/öneri alanını doldurun",
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Mevcut kullanıcıyı al
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        CustomSnackbar.show(
          context: context,
          message: "Öneri göndermek için giriş yapmalısınız",
          type: SnackbarType.error,
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Kullanıcı bilgilerini ve isteği Firestore'a kaydet
      await FirebaseFirestore.instance.collection('requests').add({
        'userId': user.uid,
        'userEmail': user.email,
        'displayName': user.displayName ?? 'İsimsiz Kullanıcı',
        'request': request,
        'timestamp': FieldValue.serverTimestamp(),
      });

      CustomSnackbar.show(
        context: context,
        message: "İsteğiniz başarıyla gönderildi",
        type: SnackbarType.success,
      );

      _requestController.clear();
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: "İstek gönderilirken bir hata oluştu",
        type: SnackbarType.error,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "İstek Kutusu",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Görüşlerinizi Bizimle Paylaşın!",
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "İzlemek istediğiniz içerikleri veya önerilerinizi buradan iletebilirsiniz",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16, 
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Kart ile İstek Alanı
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _requestController,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: "İstek / Öneri",
                              labelStyle: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(
                                Icons.message,
                                color: Colors.blueAccent,
                              ),
                              hintText: "İzlemek istediğiniz içerikleri veya önerilerinizi yazın",
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                            maxLines: 5,
                            minLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Gönder Butonu
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 4,
                    ),
                    icon: _isSubmitting 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _isSubmitting ? "Gönderiliyor..." : "Gönder", 
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    onPressed: _isSubmitting ? null : _sendRequest,
                  ),

                  const SizedBox(height: 20),

                  // Geri Dön Butonu
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      "Geri Dön", 
                      style: TextStyle(color: Colors.white, fontSize: 16)
                    ),
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
