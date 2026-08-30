import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import 'chat_screen.dart'; // Pastikan path ini benar mengarah ke file chat_screen Anda

class AdminInboxScreen extends StatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  List<dynamic> daftarRuangChat = [];
  bool _isLoading = true;
  String _pesanError = ''; 

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDaftarInbox();
  }

  Future<void> _ambilDaftarInbox() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/rooms'));
      
      if (response.statusCode == 200) {
        setState(() {
          daftarRuangChat = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // --- FITUR BARU: MENGAMBIL PESAN ERROR ASLI DARI DATABASE LARAVEL ---
        String errorAsli = 'Error tidak diketahui';
        try {
          errorAsli = jsonDecode(response.body)['pesan'];
        } catch(e) {
          errorAsli = response.body;
        }
        
        setState(() {
          _isLoading = false;
          _pesanError = 'GAGAL MEMUAT (ERROR DATABASE):\n\n$errorAsli';
        });
      }
    } catch (e) {

      setState(() {
        _isLoading = false;
        _pesanError = 'Terjadi kesalahan jaringan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pesan Masuk', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _pesanError.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 50),
                      const SizedBox(height: 10),
                      Text(_pesanError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: () { setState(() { _isLoading = true; _pesanError = ''; }); _ambilDaftarInbox(); }, child: const Text('Coba Lagi'))
                    ],
                  ),
                ),
              )
            : daftarRuangChat.isEmpty
                ? const Center(child: Text('Belum ada pesan masuk.', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: daftarRuangChat.length,
                    itemBuilder: (context, index) {
                      final room = daftarRuangChat[index];
                      String urlFoto = room['foto_profil'] ?? '';
                      String nama = room['nama_user'] ?? 'Pelanggan';
                      String pesanTerakhir = room['pesan_terakhir'] ?? '...';
                      String idUser = room['id_user'].toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColors.secondary.withOpacity(0.1),
                            backgroundImage: urlFoto.isNotEmpty ? NetworkImage(urlFoto) : null,
                            child: urlFoto.isEmpty ? const Icon(Icons.person, color: AppColors.secondary) : null,
                          ),
                          title: Text(nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                          subtitle: Text(pesanTerakhir, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                targetIdUser: idUser, 
                                namaLawanBicara: nama,
                              ),
                            ));
                          },
                        ),
                      );
                    },
                  ),
    );
  }
}
