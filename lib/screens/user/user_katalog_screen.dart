import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

// Sesuaikan dengan nama file detail barang user Anda!
import 'user_detail_barang_screen.dart'; 

class UserKatalogScreen extends StatefulWidget {
  const UserKatalogScreen({super.key});

  @override
  State<UserKatalogScreen> createState() => _UserKatalogScreenState();
}

class _UserKatalogScreenState extends State<UserKatalogScreen> {
  List<Map<String, dynamic>> daftarBarang = [];
  bool _isLoading = true;

  // Daftar Kategori Dinamis
  List<String> kategoriList = ['Semua', 'Tenda', 'Carrier', 'Alat Masak'];
  String kategoriAktif = 'Semua';

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilKategori();
    _ambilDataKatalog();
  }

  // --- AMBIL KATEGORI DINAMIS DARI SERVER ---
  Future<void> _ambilKategori() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/kategori'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          // Gabungkan 'Semua' dengan daftar kategori dari database
          kategoriList = ['Semua', ...data.map((e) => e.toString())];
        });
      }
    } catch (e) {
      print("Error Kategori: $e");
    }
  }

  // --- AMBIL DATA DARI SERVER ---
  Future<void> _ambilDataKatalog() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/barang'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            daftarBarang = List<Map<String, dynamic>>.from(jsonDecode(response.body));
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error Katalog: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logika Filter Kategori Sederhana dan Pencarian
    List<Map<String, dynamic>> barangDifilter = daftarBarang.where((b) {
      bool matchKategori = kategoriAktif == 'Semua' || b['tipe_barang'] == kategoriAktif;
      bool matchSearch = _searchQuery.isEmpty || 
          (b['nama_barang'] != null && b['nama_barang'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      return matchKategori && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _ambilKategori();
                await _ambilDataKatalog();
              },
              child: Column(
              children: [
                // KOTAK PENCARIAN
                Container(
                  color: AppColors.background, 
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                      border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari Disini...', 
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: AppColors.secondary), 
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                      )
                    ),
                  ),
                ),
                
                // SLIDER KATEGORI (Tenda, Carrier, dst)
                Container(
                  color: Colors.white, height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(), // Memastikan slider bisa digeser
                    itemCount: kategoriList.length,
                    itemBuilder: (context, index) {
                      bool isSelected = kategoriAktif == kategoriList[index];
                      return GestureDetector(
                        onTap: () => setState(() => kategoriAktif = kategoriList[index]),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : AppColors.surface,
                            border: Border.all(color: isSelected ? Colors.transparent : AppColors.accentLight.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Text(kategoriList[index], style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
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
                          final int persenDiskon = barang['persen_diskon'] ?? 0;
                          final bool adaDiskon = persenDiskon > 0;
                          final hargaAsli = barang['harga_sewa'];
                          final hargaDiskon = barang['harga_setelah_diskon'];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => UserDetailBarangScreen(barang: barang),
                              ));
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.accentLight.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.04),
                                    blurRadius: 10, offset: const Offset(0, 4)
                                  )
                                ]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // FOTO BARANG + BADGE DISKON
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            color: AppColors.surface,
                                            child: barang['url_foto'] != null
                                                ? Image.network(barang['url_foto'], fit: BoxFit.cover)
                                                : const Icon(Icons.image, size: 50, color: Colors.grey),
                                          ),
                                          if (adaDiskon)
                                            Positioned(
                                              top: 10, left: 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  gradient: AppColors.goldGradient,
                                                  borderRadius: BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
                                                  ]
                                                ),
                                                child: Text(
                                                  '-$persenDiskon%',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                                                ),
                                              ),
                                            ),
                                        ],
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
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (adaDiskon) ...[
                                          Text(
                                            'Rp ${formatRupiah(hargaAsli)}/hari',
                                            style: TextStyle(
                                              color: Colors.grey.shade500, fontSize: 11,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          Text(
                                            'Rp ${formatRupiah(hargaDiskon)}/hari',
                                            style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                        ] else
                                          Text(
                                            'Rp ${formatRupiah(hargaAsli)}/hari',
                                            style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tersedia: ${barang['stok']} unit',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
          ),
    );
  }
}
