import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

// --- 1. IMPORT HALAMAN DETAIL ADMIN BARU ---
import 'admin_detail_pesanan_screen.dart';
import 'form_pelunasan_screen.dart';
import 'admin_form_pengembalian_screen.dart';
import 'admin_inbox_screen.dart'; // Tab Chat / Inbox Admin

class AdminKeranjangScreen extends StatefulWidget {
  const AdminKeranjangScreen({super.key});

  @override
  _AdminKeranjangScreenState createState() => _AdminKeranjangScreenState();
}

class _AdminKeranjangScreenState extends State<AdminKeranjangScreen> {
  List<Map<String, dynamic>> daftarPesanan = [];
  bool _isLoading = true;

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilPesanan();
  }

  // --- FUNGSI AMBIL DATA PESANAN DARI LARAVEL ---
  Future<void> _ambilPesanan() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/transaksi'));
      if (response.statusCode == 200) {
        setState(() {
          daftarPesanan = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      print("Error: $e");
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI UPDATE STATUS ---
  Future<void> _updateStatus(String idTransaksi, String statusBaru) async {
    if (idTransaksi.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pesanan/$idTransaksi/status'), // Menggunakan POST seperti di Detail
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': statusBaru}),
      );

      if (response.statusCode == 200) {
        _ambilPesanan(); // Refresh data agar pesanan pindah tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status Berhasil Diubah ke $statusBaru'), backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah status di server'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      print("Error Koneksi: $e");
    }
    setState(() => _isLoading = false);
  }

  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    // Filter pencarian
    List<Map<String, dynamic>> filteredPesanan = daftarPesanan.where((p) {
      if (_searchQuery.isEmpty) return true;
      String query = _searchQuery.toLowerCase();
      String namaPemesan = (p['nama_pemesan'] ?? '').toLowerCase();
      String idTrx = (p['id_transaksi'] ?? '').toString().toLowerCase();
      String status = (p['status_transaksi'] ?? '').toLowerCase();
      
      bool matchItem = false;
      List detailPesanan = p['detail_pesanan'] ?? [];
      for (var item in detailPesanan) {
        String namaBarang = (item['nama_barang'] ?? '').toLowerCase();
        if (namaBarang.contains(query)) {
          matchItem = true;
          break;
        }
      }
      
      return namaPemesan.contains(query) || idTrx.contains(query) || status.contains(query) || matchItem;
    }).toList();

    // Filter status
    List<Map<String, dynamic>> pesananAkanDisewa = filteredPesanan.where((p) =>
      (p['status_transaksi'] == 'menunggu_konfirmasi' ||
      p['status_transaksi'] == 'dp_dibayar' ||
      p['status_transaksi'] == 'akan_diambil')
    ).toList();

    List<Map<String, dynamic>> pesananRiwayatAktif = filteredPesanan.where((p) {
      String st = (p['status_transaksi'] ?? '').toLowerCase();
      return st == 'disewa' || st == 'selesai' || st == 'ditolak';
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari nama, ID, barang...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
              : const Text('Manajemen Pesanan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.secondary),
              tooltip: _isSearching ? 'Tutup Pencarian' : 'Cari Pesanan',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchQuery = '';
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: AppColors.secondary),
              tooltip: 'Pesan Masuk',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminInboxScreen()));
              },
            ),
            const SizedBox(width: 10),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [Tab(text: 'Akan Disewa'), Tab(text: 'Riwayat / Aktif')],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildListView(pesananAkanDisewa, true),
                _buildListView(pesananRiwayatAktif, false),
              ],
            ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> data, bool isTabAkanDisewa) {
    if (data.isEmpty) return const Center(child: Text('Tidak ada data pesanan.'));
    return RefreshIndicator(
      onRefresh: _ambilPesanan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) => _buildKartuPesanan(data[index]),
      ),
    );
  }

  Widget _buildKartuPesanan(Map<String, dynamic> transaksi) {
    String status = transaksi['status_transaksi'] ?? 'menunggu_dp';
    bool isLunas = status == 'disewa' || status == 'selesai';

    List detailPesanan = transaksi['detail_pesanan'] ?? [];

    String labelStatus;
    Color warnaLabel;
    switch (status) {
      case 'menunggu_dp': labelStatus = 'Menunggu DP'; warnaLabel = AppColors.error; break;
      case 'dp_dibayar': labelStatus = 'DP Dibayar'; warnaLabel = AppColors.primary; break;
      case 'menunggu_konfirmasi': labelStatus = 'Menunggu Konfirmasi'; warnaLabel = AppColors.warning; break;
      case 'akan_diambil': labelStatus = 'Akan Diambil'; warnaLabel = AppColors.primary; break;
      case 'disewa': labelStatus = 'Sedang Disewa'; warnaLabel = AppColors.secondary; break;
      case 'selesai': 
        bool adaKendala = false;
        for (var item in detailPesanan) {
          if (item['kondisi_pengembalian'] != null && item['kondisi_pengembalian'] != 'Normal') {
            adaKendala = true;
            break;
          }
        }
        labelStatus = adaKendala ? 'Selesai (Berkendala)' : 'Selesai'; 
        warnaLabel = adaKendala ? AppColors.error : AppColors.success; 
        break;
      case 'ditolak': labelStatus = 'Ditolak'; warnaLabel = AppColors.error; break;
      default: labelStatus = status; warnaLabel = AppColors.primary;
    }

    int jumlahMacamBarang = detailPesanan.length;
    
    String namaBarangUtama = 'Pesanan';
    String urlFotoUtama = '';
    int totalUnitSeluruhnya = 0;
    
    if (detailPesanan.isNotEmpty) {
      namaBarangUtama = detailPesanan[0]['nama_barang'] ?? 'Alat Camping';
      urlFotoUtama = detailPesanan[0]['url_foto'] ?? '';
      for (var item in detailPesanan) {
        totalUnitSeluruhnya += int.tryParse(item['jumlah_pesan'].toString()) ?? 0;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER PROFIL
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.secondary.withOpacity(0.2),
                  backgroundImage: (transaksi['foto_profil'] != null && transaksi['foto_profil'].toString().isNotEmpty)
                      ? NetworkImage(transaksi['foto_profil'].toString())
                      : null,
                  child: (transaksi['foto_profil'] == null || transaksi['foto_profil'].toString().isEmpty)
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaksi['nama_pemesan'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      Text(transaksi['id_transaksi'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: warnaLabel.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labelStatus,
                    style: TextStyle(color: warnaLabel, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // INFO BARANG (Grouped)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: urlFotoUtama.isNotEmpty
                    ? Image.network(urlFotoUtama, width: 60, height: 60, fit: BoxFit.cover)
                    : Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.image)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(namaBarangUtama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                      if (jumlahMacamBarang > 1)
                        Text('dan ${jumlahMacamBarang - 1} barang lainnya', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      Text('Total Item: $totalUnitSeluruhnya Unit', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      
                      // LOGIKA TEKS LUNAS ATAU SISA TAGIHAN
                      isLunas 
                        ? const Text('Status Pembayaran: LUNAS', style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold))
                        : Text('Sisa Tagihan: Rp ${formatRupiah(transaksi['sisa_tagihan'] ?? 0)}', style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // --- TOMBOL DETAIL SELALU ADA DI SINI ---
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => AdminDetailPesananScreen(pesanan: transaksi)
                    )
                  ).then((_) => _ambilPesanan());
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Detail'),
              ),
            ),
            
            // TOMBOL AKSI BERDASARKAN STATUS — hanya muncul jika sudah bayar DP
            if (status == 'menunggu_konfirmasi' || status == 'dp_dibayar') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(transaksi['id_transaksi'].toString(), 'ditolak'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                      child: ElevatedButton(
                        onPressed: () {
                          _updateStatus(transaksi['id_transaksi'].toString(), 'akan_diambil');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                        child: const Text('Konfirmasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              )
            ] else if (status == 'akan_diambil') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FormPelunasanScreen(
                          pesanan: transaksi,
                          onSelesai: () => _updateStatus(transaksi['id_transaksi'].toString(), 'disewa')
                        )),
                      ).then((_) => _ambilPesanan());
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Lengkapi Pelunasan Sewa', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            ] else if (status == 'disewa') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminFormPengembalianScreen(
                              transaksi: transaksi,
                              onSelesai: () => _ambilPesanan(),
                            ),
                          ),
                        ).then((_) => _ambilPesanan());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      ),
                      child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Laporkan Kendala', style: TextStyle(fontSize: 13))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Pengembalian Normal?'),
                            content: const Text('Konfirmasi bahwa barang dikembalikan tanpa kendala kerusakan atau hilang.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _pengembalianNormal(transaksi['id_transaksi'].toString());
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                child: const Text('Ya, Normal', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4)),
                      child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Pengembalian Normal', style: TextStyle(color: Colors.white, fontSize: 13))),
                    ),
                  ),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pengembalianNormal(String idTransaksi) async {
    setState(() => _isLoading = true);
    try {
      final url = '${AppConfig.baseUrl}/transaksi/$idTransaksi/pengembalian';
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'items': []}),
      );
      
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barang berhasil dikembalikan secara normal'),
          backgroundColor: AppColors.success,
        ));
        _ambilPesanan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal memproses pengembalian'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }
}
