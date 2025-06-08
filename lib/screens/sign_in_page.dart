// lib/screens/auth/sign_in_page.dart
import 'package:flutter/material.dart';
import 'package:videoapp/models/auth_service.dart';
import 'package:videoapp/screens/video_list_page.dart';
import 'package:videoapp/screens/sign_up_page.dart';
import 'package:videoapp/utils/custom_snackbar.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);
  
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hata mesajlarını kullanıcı dostu hale getiren fonksiyon buraya eklenir
  String _getErrorMessage(String errorCode) {
    // Firebase hata kodu mesajdan ayıklanır
    if (errorCode.contains('user-not-found')) {
      return 'Bu e-posta adresine kayıtlı bir hesap bulamadık. Kayıt olmak ister misiniz?';
    } else if (errorCode.contains('wrong-password')) {
      return 'Girdiğiniz şifre doğru değil. Şifrenizi hatırlamıyorsanız sıfırlama yapabilirsiniz.';
    } else if (errorCode.contains('invalid-email')) {
      return 'E-posta adresi geçerli bir formatta değil. Lütfen kontrol ediniz.';
    } else if (errorCode.contains('user-disabled')) {
      return 'Hesabınız askıya alınmış. Destek ekibiyle iletişime geçebilirsiniz.';
    } else if (errorCode.contains('too-many-requests')) {
      return 'Çok fazla giriş denemesi nedeniyle hesabınıza erişim geçici olarak kısıtlandı. Lütfen daha sonra tekrar deneyin.';
    } else if (errorCode.contains('network-request-failed')) {
      return 'İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.';
    } else if (errorCode.contains('account-exists-with-different-credential')) {
      return 'Bu e-posta adresi başka bir yöntemle kayıtlı. Farklı bir giriş yöntemi kullanmayı deneyin.';
    } else {
      return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
    }
  }

  // _signIn metodunu güncelleyin
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Güncellenmiş metodu kullan - UserCredential veya null döner
      final signInSuccess = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted) {
        if (signInSuccess == true) {
          // Başarılı giriş - ana ekrana git
          print('Başarılı giriş');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const VideoListPage()),
          );
        } else {
          // Başarısız giriş - hata göster
          print('Giriş başarısız: Kullanıcı bilgileri geçersiz');
          CustomSnackbar.show(
            context: context,
            message: 'E-posta veya şifre yanlış. Lütfen tekrar deneyin.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: _getErrorMessage(e.toString()),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      const Icon(Icons.play_circle_fill, size: 80, color: Colors.white),
                      const SizedBox(height: 40),
                      
                      // Başlık
                      const Text(
                        'Playtoon',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Email alanı
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.blueAccent, // İmleç rengi mavi yapıldı
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: Colors.white70),
                          errorStyle: const TextStyle(
                            color: Colors.orange, // Kırmızı yerine turuncu daha okunaklı
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.email, color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blueAccent),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.redAccent),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.redAccent),
                          ),
                          filled: true,
                          fillColor: Colors.black45,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen e-posta adresinizi giriniz';
                          } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Geçerli bir e-posta adresi giriniz (örn: adi@domain.com)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Şifre alanı
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.blueAccent, // İmleç rengi mavi yapıldı
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          labelStyle: const TextStyle(color: Colors.white70),
                          errorStyle: const TextStyle(
                            color: Colors.orange, // Kırmızı yerine turuncu daha okunaklı
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blueAccent),
                          ),
                          filled: true,
                          fillColor: Colors.black45,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifrenizi giriniz';
                          } else if (value.length < 6) {
                            return 'Şifreniz en az 6 karakter olmalıdır';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Giriş butonu
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white, // Metin rengini açıkça belirt
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: Colors.blueAccent.withOpacity(0.6), // Devre dışı renk
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8), // Butonun kenarlarını yuvarla
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                                )
                              : const Text(
                                  'Giriş Yap', 
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Kayıt butonu
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignUpPage()),
                          );
                        },
                        child: const Text('Hesap oluştur', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}