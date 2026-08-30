import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

// PASTIKAN IMPORT MENGARAH KE DETAIL KHUSUS USER
import 'user_detail_barang_screen.dart';
import 'user_katalog_screen.dart'; // Import halaman katalog untuk tombol lihat semua

class UserBerandaScreen extends StatefulWidget {
  final VoidCallback? onGoToKatalog;
  const UserBerandaScreen({super.key, this.onGoToKatalog});

  @override
  _UserBerandaScreenState createState() => _UserBerandaScreenState();
}

class _UserBerandaScreenState extends State<UserBerandaScreen> {
  List<Map<String, dynamic>> daftarBarang = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Konten Promo akan diperbarui dari Database
  String judulPromo = 'Memuat promo...';
  String deskripsiPromo = '...';

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDataBarang();
  }

  // Template judul berdasarkan persentase diskon
  String _judulDariPersen(int persen) {
    if (persen <= 39) return 'Lagi Ada Promo Nih!';
    if (persen <= 69) return 'Diskon Sayang Kalau Dilewatin!';
    if (persen <= 85) return 'Promo Spesial, Stok Terbatas!';
    return 'Diskon Terbesar! Buruan Sebelum Habis!';
  }

  // Cari diskon terbesar dari daftar barang yang sedang aktif
  Map<String, dynamic>? _diskonTerbesar() {
    final aktif = daftarBarang.where((b) => (b['persen_diskon'] ?? 0) > 0).toList();
    if (aktif.isEmpty) return null;
    aktif.sort((a, b) => (b['persen_diskon'] ?? 0).compareTo(a['persen_diskon'] ?? 0));
    return aktif.first;
  }

  Future<void> _ambilDataBarang() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/barang'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            daftarBarang = List<Map<String, dynamic>>.from(jsonDecode(response.body));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error ambil barang: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _ambilDataBarang();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Beranda Cample',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // SEARCH BAR
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                        border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari Alat Camping...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search, color: AppColors.secondary),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // BANNER PROMO DINAMIS — tampil hanya jika ada diskon aktif
                  Builder(builder: (context) {
                    final diskonTop = _diskonTerbesar();
                    if (diskonTop == null) return const SizedBox.shrink();
                    final int persen = diskonTop['persen_diskon'] ?? 0;
                    final String namaAlat = diskonTop['nama_barang'] ?? 'Alat Camping';
                    final String judul = _judulDariPersen(persen);
                    final String sub = '$namaAlat, Hemat $persen% hari ini!';
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF3F7F4), Color(0xFFEAF1EC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
                            ]
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(judul,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                    const SizedBox(height: 8),
                                    Text(sub, 
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                  ]
                                ),
                                child: Text('-$persen%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    );
                  }),

                  // SECTION REKOMENDASI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rekomendasi Alat', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          if (widget.onGoToKatalog != null) {
                            widget.onGoToKatalog!(); // Berpindah ke tab Katalog
                          }
                        }, 
                        child: const Text('Lihat Semua')
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // GRID BARANG
                  (() {
                    List<Map<String, dynamic>> barangDifilter = daftarBarang.where((item) {
                      if (_searchQuery.isEmpty) return true;
                      return item['nama_barang'] != null && item['nama_barang'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    // Urutkan berdasarkan jumlah disewa (terlaris di atas)
                    final barangUrut = List.from(barangDifilter)..sort((a, b) {
                      final disewaA = int.tryParse((a['jumlah_disewa'] ?? 0).toString()) ?? 0;
                      final disewaB = int.tryParse((b['jumlah_disewa'] ?? 0).toString()) ?? 0;
                      return disewaB.compareTo(disewaA); // Descending
                    });

                    // Ambil maksimal 6 barang untuk rekomendasi di beranda
                    final barangDitampilkan = barangUrut.take(6).toList();

                    return barangDitampilkan.isEmpty
                      ? const Center(child: Text('Barang tidak ditemukan.'))
                      : GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: barangDitampilkan.length,
                        itemBuilder: (context, index) {
                          final item = barangDitampilkan[index];
                          final int persenDiskon = item['persen_diskon'] ?? 0;
                          final bool adaDiskon = persenDiskon > 0;
                          final hargaAsli = item['harga_sewa'];
                          final hargaDiskon = item['harga_setelah_diskon'];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailBarangScreen(barang: item)
                                )
                              );
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
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Stack(
                                        children: [
                                          // Foto barang
                                          Container(
                                            width: double.infinity,
                                            color: AppColors.surface,
                                            child: item['url_foto'] != null
                                                ? Image.network(item['url_foto'], fit: BoxFit.cover)
                                                : const Icon(Icons.image, size: 50, color: Colors.grey),
                                          ),
                                          // Badge diskon
                                          if (adaDiskon)
                                            Positioned(
                                              top: 10,
                                              left: 10,
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
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['nama_barang'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 4),
                                        if (adaDiskon) ...[
                                          // Harga asli dicoret
                                          Text(
                                            'Rp ${formatRupiah(hargaAsli)}/hari',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                          // Harga setelah diskon
                                          Text(
                                            'Rp ${formatRupiah(hargaDiskon)}/hari',
                                            style: const TextStyle(
                                              color: AppColors.secondary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ] else
                                          Text(
                                            'Rp ${formatRupiah(hargaAsli)}/hari',
                                            style: const TextStyle(
                                              color: AppColors.secondary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                  })(),

                ],
              ),
            ),
          ),
    );
  }
}

// Tambahan konstanta warna agar tampilan lebih profesional
extension ColorExtension on Colors {
  static const Color blueHeadline = Color(0xFF1A237E);
}
