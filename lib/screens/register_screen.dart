import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();

  bool _isLoading = false;
  bool _isObscure = true;

  // --- LOGIKA DAFTAR KE API LARAVEL ---
  Future<void> _prosesDaftar() async {
    // Validasi data kosong
    if (_namaController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _hpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua data!'), backgroundColor: AppColors.error));
      return;
    }

    // Validasi Email
    final bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim());
    if (!emailValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format email salah!'), backgroundColor: AppColors.error));
      return;
    }

    // Validasi No HP (hanya angka, panjang 9-15 digit)
    final bool hpValid = RegExp(r'^[0-9]{9,15}$').hasMatch(_hpController.text.trim());
    if (!hpValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No HP harus berupa angka (9-15 digit)!'), backgroundColor: AppColors.error));
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password minimal 6 karakter!'), backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isLoading = true);

    final String url = '${AppConfig.baseUrl}/register';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'nama': _namaController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'no_hp': _hpController.text,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan']), backgroundColor: AppColors.success));
        Navigator.pop(context); // Kembali ke layar Login setelah sukses
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'Registrasi gagal.'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan jaringan!'), backgroundColor: AppColors.error));
      print(e);
    }
    
    setState(() => _isLoading = false);
  }

  // Fungsi pembuat TextField yang seragam
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false, TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        keyboardType: inputType,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
          focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.primary, width: 2), borderRadius: BorderRadius.circular(16)),
        ),
      ),
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
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text('Registrasi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 48), // Spacer to balance back button
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildTextField('Nama Lengkap', Icons.person_outline, _namaController),
                    _buildTextField('Email', Icons.email_outlined, _emailController, inputType: TextInputType.emailAddress),
                    _buildTextField('Password', Icons.lock_outline, _passwordController, isPassword: true),
                    _buildTextField('No. Hp (WA)', Icons.phone_outlined, _hpController, inputType: TextInputType.phone),
                    
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _prosesDaftar,
                        child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Buat Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
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
