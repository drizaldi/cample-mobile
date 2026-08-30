import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import 'register_screen.dart'; 
import 'admin/admin_main_screen.dart'; 
import 'user/user_main_screen.dart'; 
import '../sesi_user.dart'; 
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;

  // State untuk Lupa Password
  bool _isLupaPasswordLoading = false;
  String _resetEmail = '';
  String _resetNoHp = '';

  Future<void> _prosesLogin() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi email dan password!'), backgroundColor: AppColors.error)
      );
      return;
    }

    final bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(username);
    if (!emailValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email tidak valid!'), backgroundColor: AppColors.error)
      );
      return;
    }

    setState(() => _isLoading = true);

    // --- KEMBALI KE LOCALHOST ---
    final String url = '${AppConfig.baseUrl}/login';
                                
    try {
      final response = await http.post(
        Uri.parse(url),
        // HEADER NGROK SUDAH DIHAPUS TOTAL
        body: {'email': username, 'password': password},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final userData = data['data'];

        await SesiUser.simpanSesi(
          id: userData['id'].toString(),
          nama: userData['nama'] ?? 'User',
          mail: userData['email'] ?? '',
          hakAkses: userData['role'] ?? 'user',
          foto: userData['foto_profil'],
          authToken: data['token'], // ← FIX: simpan token Sanctum agar request auth berhasil
        );

        if (SesiUser.role == 'admin') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AdminMainScreen()), (route) => false);
        } else {
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true); // Kembali ke halaman sebelumnya dengan status sukses
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserMainScreen()));
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['pesan'] ?? 'Login Gagal'), backgroundColor: AppColors.error)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal terhubung ke server!'), backgroundColor: AppColors.error)
      );
    }

    setState(() => _isLoading = false);
  }

  // --- ALUR LUPA PASSWORD (EMAIL OTP) ---
  void _showForgotPasswordDialog() {
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController hpCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Lupa Password', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Masukkan Email dan No HP Anda yang terdaftar. Kami akan mengirimkan kode OTP ke Email Anda.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email terdaftar', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), prefixIcon: const Icon(Icons.email_outlined, color: AppColors.secondary))),
                  const SizedBox(height: 16),
                  TextField(controller: hpCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'No HP terdaftar (WA)', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.secondary))),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isLupaPasswordLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    onPressed: _isLupaPasswordLoading ? null : () async {
                      if (emailCtrl.text.isEmpty || hpCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi Email dan No HP!'), backgroundColor: AppColors.error));
                        return;
                      }
                      
                      setStateDialog(() => _isLupaPasswordLoading = true);
                      
                      try {
                        final response = await http.post(
                          Uri.parse('${AppConfig.baseUrl}/lupa-password/kirim-otp'),
                          body: {'email': emailCtrl.text, 'no_hp': hpCtrl.text},
                        );
                        final data = jsonDecode(response.body);
                        
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        
                        if (response.statusCode == 200) {
                          Navigator.pop(context);
                          _resetEmail = emailCtrl.text;
                          _resetNoHp = hpCtrl.text;
                          _showOTPDialog();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'Gagal memverifikasi data'), backgroundColor: AppColors.error));
                        }
                      } catch (e) {
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
                      }
                    },
                    child: _isLupaPasswordLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kirim OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showOTPDialog() {
    TextEditingController otpCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Masukkan OTP', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Silakan cek Email Anda untuk melihat kode OTP 4 digit.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl, 
                    keyboardType: TextInputType.number, 
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    decoration: InputDecoration(counterText: "", filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isLupaPasswordLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    onPressed: _isLupaPasswordLoading ? null : () async {
                      if (otpCtrl.text.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP harus 4 digit!'), backgroundColor: AppColors.error));
                        return;
                      }

                      setStateDialog(() => _isLupaPasswordLoading = true);
                      
                      try {
                        final response = await http.post(
                          Uri.parse('${AppConfig.baseUrl}/lupa-password/verifikasi-otp'),
                          body: {'email': _resetEmail, 'otp': otpCtrl.text},
                        );
                        final data = jsonDecode(response.body);
                        
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        
                        if (response.statusCode == 200) {
                          Navigator.pop(context);
                          _showResetPasswordDialog(data['reset_token']); // Token agar aman
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'OTP Salah!'), backgroundColor: AppColors.error));
                        }
                      } catch (e) {
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
                      }
                    },
                    child: _isLupaPasswordLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verifikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showResetPasswordDialog(String resetToken) {
    TextEditingController pwdCtrl = TextEditingController();
    TextEditingController konfirmasiCtrl = TextEditingController();
    bool isObscureReset1 = true;
    bool isObscureReset2 = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Buat Password Baru', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pwdCtrl, 
                    obscureText: isObscureReset1, 
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondary),
                      suffixIcon: IconButton(
                        icon: Icon(isObscureReset1 ? Icons.visibility_off : Icons.visibility, color: AppColors.secondary),
                        onPressed: () => setStateDialog(() => isObscureReset1 = !isObscureReset1)
                      )
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: konfirmasiCtrl, 
                    obscureText: isObscureReset2, 
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.secondary),
                      suffixIcon: IconButton(
                        icon: Icon(isObscureReset2 ? Icons.visibility_off : Icons.visibility, color: AppColors.secondary),
                        onPressed: () => setStateDialog(() => isObscureReset2 = !isObscureReset2)
                      )
                    )
                  ),
                ],
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    onPressed: _isLupaPasswordLoading ? null : () async {
                      if (pwdCtrl.text.isEmpty || konfirmasiCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi semua field!'), backgroundColor: AppColors.error));
                        return;
                      }
                      if (pwdCtrl.text != konfirmasiCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password tidak cocok!'), backgroundColor: AppColors.error));
                        return;
                      }
                      if (pwdCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password minimal 6 karakter!'), backgroundColor: AppColors.error));
                        return;
                      }

                      setStateDialog(() => _isLupaPasswordLoading = true);
                      
                      try {
                        final response = await http.post(
                          Uri.parse('${AppConfig.baseUrl}/lupa-password/reset'),
                          body: {'email': _resetEmail, 'reset_token': resetToken, 'password': pwdCtrl.text},
                        );
                        
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        
                        if (response.statusCode == 200) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil direset! Silakan login.'), backgroundColor: AppColors.success));
                        } else {
                          final data = jsonDecode(response.body);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'Gagal reset password'), backgroundColor: AppColors.error));
                        }
                      } catch (e) {
                        setStateDialog(() => _isLupaPasswordLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
                      }
                    },
                    child: _isLupaPasswordLoading 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 10,
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.terrain, size: 72, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text('Cample.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    const Text('Mulai petualangan alammu', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _isObscure = !_isObscure),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _showForgotPasswordDialog,
                        child: const Text('Lupa Password?', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isLoading ? null : _prosesLogin,
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum punya akun? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                          child: const Text('Buat Akun', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Masuk sebagai ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        GestureDetector(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserMainScreen()));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 2), // Jarak antara teks dan garis
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            child: const Text(
                              'Guest', 
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
