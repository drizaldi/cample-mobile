import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import 'user_detail_barang_screen.dart'; 

class UserBarangScreen extends StatefulWidget {
  const UserBarangScreen({super.key});

  @override
  State<UserBarangScreen> createState() => _UserBarangScreenState();
}

class _UserBarangScreenState extends State<UserBarangScreen> {
  List<dynamic> daftarBarang = [];
  bool _isLoading = true;

  // Daftar Kategori
  final List<String> kategoriList = ['Semua', 'Tenda', 'Carrier', 'Alat Masak', 'Perlengkapan', 'Lainnya'];
  String kategoriAktif = 'Semua';

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDataKatalog();
  }

  // --- AMBIL DATA DARI SERVER ---
  Future<void> _ambilDataKatalog() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/barang'));
      if (response.statusCode == 200) {
        setState(() {
          daftarBarang = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error Katalog: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logika Filter Kategori Sederhana
    List<dynamic> barangDifilter = kategoriAktif == 'Semua' 
        ? daftarBarang 
        : daftarBarang.where((b) => b['tipe_barang'] == kategoriAktif).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cample Catalog', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        // TOMBOL CHAT DI SINI SUDAH DIHAPUS AGAR TIDAK DOUBLE
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // KOTAK PENCARIAN
                Container(
                  color: Colors.white, 
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari Disini...', 
                      prefixIcon: const Icon(Icons.search), 
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))
                    )
                  ),
                ),
                
                // SLIDER KATEGORI (Tenda, Carrier, dst)
                Container(
                  color: Colors.white, height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: kategoriList.length,
                    itemBuilder: (context, index) {
                      bool isSelected = kategoriAktif == kategoriList[index];
                      return GestureDetector(
                        onTap: () => setState(() => kategoriAktif = kategoriList[index]),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentLight : Colors.white,
                            border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(10), // Sedikit dilengkungkan agar rapi
                          ),
                          child: Text(kategoriList[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // GRID VIEW (MENYERUPAI HALAMAN BERANDA)
                Expanded(
                  child: barangDifilter.isEmpty
                    ? const Center(child: Text('Tidak ada barang di kategori ini.', style: TextStyle(color: Colors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // Menjadikan 2 kolom
                          crossAxisSpacing: 15, // Jarak menyamping antar kotak
                          mainAxisSpacing: 15, // Jarak atas-bawah antar kotak
                          childAspectRatio: 0.72, // Mengatur tinggi agar pas dengan foto
                        ),
                        itemCount: barangDifilter.length,
                        itemBuilder: (context, index) {
                          final barang = barangDifilter[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => UserDetailBarangScreen(barang: barang),
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  // Memberikan sedikit efek bayangan halus
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.15),
                                    spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 2)
                                  )
                                ]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // FOTO BARANG BESAR
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                      child: Container(
                                        width: double.infinity,
                                        color: Colors.grey[200],
                                        child: barang['url_foto'] != null
                                            ? Image.network(barang['url_foto'], fit: BoxFit.cover)
                                            : const Icon(Icons.image, size: 50, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  // TEXT NAMA & HARGA
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          barang['nama_barang'] ?? 'Tanpa Nama',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rp ${formatRupiah(barang['harga_sewa'])}/hari', 
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tersedia: ${barang['stok']} unit',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
    );
  }
}
