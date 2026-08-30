// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/utils/format_currency.dart';

// Import halaman detail agar barang di beranda bisa di-klik
import 'detail_barang_screen.dart';

import 'admin_inbox_screen.dart'; // Import inbox

class AdminBerandaScreen extends StatefulWidget {
  const AdminBerandaScreen({super.key});

  @override
  _AdminBerandaScreenState createState() => _AdminBerandaScreenState();
}

class _AdminBerandaScreenState extends State<AdminBerandaScreen> {
  List<Map<String, dynamic>> daftarBarang = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // State untuk Papan Promo 
  String judulPromo = 'Memuat promo...';
  String deskripsiPromo = '...';

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDataBarang();
    _ambilDataPromo(); // Panggil data promo saat halaman pertama kali dibuka
  }

  // --- FUNGSI MENGAMBIL DATA PROMO DARI DATABASE ---
  Future<void> _ambilDataPromo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/profil'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Tangani jika respon berupa List atau langsung Map
        final profil = data is List ? data[0] : data; 
        
        setState(() {
          judulPromo = profil['promo_judul'] ?? 'Promo Sewa Alat Camping';
          deskripsiPromo = profil['promo_sub'] ?? 'Diskon hingga 20% minggu ini!';
        });
      }
    } catch (e) {
      print("Error ambil promo: $e");
    }
  }

  Future<void> _ambilDataBarang() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/barang'));
      if (response.statusCode == 200) {
        setState(() {
          daftarBarang = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  // --- HELPER TEMPLATE PROMO ---
  // Mengembalikan judul template berdasarkan persentase diskon
  String _judulDariPersen(int persen) {
    if (persen <= 39) return 'Lagi Ada Promo Nih!';
    if (persen <= 69) return 'Diskon Sayang Kalau Dilewatin!';
    if (persen <= 85) return 'Promo Spesial, Stok Terbatas!';
    return 'Diskon Terbesar! Buruan Sebelum Habis!';
  }

  // Mencari barang dengan diskon terbesar dari daftar barang yang aktif
  Map<String, dynamic>? _diskonTerbesar() {
    final aktif = daftarBarang.where((b) => (b['persen_diskon'] ?? 0) > 0).toList();
    if (aktif.isEmpty) return null;
    aktif.sort((a, b) => (b['persen_diskon'] ?? 0).compareTo(a['persen_diskon'] ?? 0));
    return aktif.first;
  }

  // FUNGSI EDIT PROMO TELAH DIHAPUS - PROMO SEKARANG 100% DINAMIS

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Beranda Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppColors.secondary),
            tooltip: 'Pesan Masuk',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminInboxScreen()));
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await _ambilDataBarang();
              await _ambilDataPromo();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SEARCH BAR
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                      border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Cari Disini...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: AppColors.secondary),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PAPAN PENGUMUMAN / PROMO (DINAMIS 100%)
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
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(judul, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              Text(sub, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    );
                  }),

                  // BARANG TERSEDIA (RECOMMEND)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Rekomendasi Alat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      // Tombol Lihat Semua dihapus agar tidak membingungkan karena sudah ada tab Barang di bawah
                    ],
                  ),
                  const SizedBox(height: 10),

                  // GRID BARANG
                  (() {
                    List<Map<String, dynamic>> barangDifilter = daftarBarang.where((item) {
                      if (_searchQuery.isEmpty) return true;
                      return item['nama_barang'] != null && item['nama_barang'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                    }).toList();

                    return barangDifilter.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Text('Belum ada barang atau barang tidak ditemukan.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: barangDifilter.length,
                          itemBuilder: (context, index) {
                            final item = barangDifilter[index];
                            final int persenDiskon = item['persen_diskon'] ?? 0;
                            final bool adaDiskon = persenDiskon > 0;
                            final hargaAsli = item['harga_sewa'];
                            final hargaDiskon = item['harga_setelah_diskon'];
                            return GestureDetector(
                              onTap: () async {
                                bool? refresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailBarangScreen(barang: item)));
                                if (refresh == true) _ambilDataBarang();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.accentLight.withOpacity(0.3)),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
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
                                            Container(
                                              width: double.infinity, color: AppColors.surface,
                                              child: item['url_foto'] != null 
                                                  ? Image.network(item['url_foto'], fit: BoxFit.cover) 
                                                  : const Icon(Icons.image, color: Colors.grey),
                                            ),
                                            if (adaDiskon)
                                              Positioned(
                                                top: 10, left: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    gradient: AppColors.goldGradient,
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))],
                                                  ),
                                                  child: Text('-$persenDiskon%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
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
                                          Text(item['nama_barang'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                                          const SizedBox(height: 4),
                                          if (adaDiskon) ...[
                                            Text('Rp ${formatRupiah(hargaAsli)}/hari', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                                            Text('Rp ${formatRupiah(hargaDiskon)}/hari', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.secondary)),
                                          ] else
                                            Text('Rp ${formatRupiah(hargaAsli)}/hari', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.secondary)),
                                          const SizedBox(height: 4),
                                          Text('Stok: ${item['stok']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    )
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
