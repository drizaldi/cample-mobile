import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import '../../sesi_user.dart';
import 'user_detail_pesanan_screen.dart';
import '../login_screen.dart';

class UserPesananScreen extends StatefulWidget {
  const UserPesananScreen({super.key});

  @override
  State<UserPesananScreen> createState() => _UserPesananScreenState();
}

class _UserPesananScreenState extends State<UserPesananScreen> {
  List<Map<String, dynamic>> pesananSaya = [];
  bool _isLoading = true;

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilPesananSistem();
  }

  Future<void> _ambilPesananSistem() async {
    setState(() => _isLoading = true);
    try {
      String idUser = SesiUser.idUser ?? '';
      if (idUser.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await http.get(Uri.parse('$baseUrl/transaksi/user/$idUser'));
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> dataTransaksi =
            List<Map<String, dynamic>>.from(jsonDecode(response.body));
        setState(() {
          pesananSaya = dataTransaksi;
        });
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  /// Label status yang ramah untuk user
  String _labelStatus(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu_dp':
        return 'Menunggu Pembayaran DP';
      case 'dp_dibayar':
        return 'DP Dibayar';
      case 'menunggu_konfirmasi':
        return 'Menunggu Konfirmasi Admin';
      case 'akan_diambil':
        return 'Siap Diambil';
      case 'disewa':
        return 'Sedang Disewa';
      case 'selesai':
        return 'Selesai';
      case 'ditolak':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _warnaStatus(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu_dp':
        return AppColors.error;
      case 'dp_dibayar':
        return AppColors.success;
      case 'menunggu_konfirmasi':
        return AppColors.warning;
      case 'akan_diambil':
        return AppColors.primary;
      case 'disewa':
        return AppColors.secondary;
      case 'selesai':
        return AppColors.success;
      case 'ditolak':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconStatus(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu_dp':
        return Icons.payment;
      case 'dp_dibayar':
        return Icons.check_circle;
      case 'menunggu_konfirmasi':
        return Icons.hourglass_top;
      case 'akan_diambil':
        return Icons.store;
      case 'disewa':
        return Icons.vpn_key;
      case 'selesai':
        return Icons.check_circle;
      case 'ditolak':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildKartuPesananUser(Map<String, dynamic> transaksi) {
    String status = transaksi['status_transaksi'] ?? 'menunggu_dp';
    Color warna = _warnaStatus(status);
    String label = _labelStatus(status);
    IconData ikon = _iconStatus(status);

    List detailPesanan = transaksi['detail_pesanan'] ?? [];
    int jumlahMacamBarang = detailPesanan.length;
    
    // Ambil info dari barang pertama sebagai perwakilan gambar
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
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: warna.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: warna.withOpacity(0.2)))
            ),
            child: Row(
              children: [
                Icon(ikon, color: warna, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold, color: warna),
                  ),
                ),
                Text(
                  transaksi['id_transaksi'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),

          // Barang (Group)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: urlFotoUtama.isNotEmpty
                        ? Image.network(urlFotoUtama, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image))
                        : const Icon(Icons.image),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(namaBarangUtama,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      if (jumlahMacamBarang > 1)
                        Text(
                            'dan ${jumlahMacamBarang - 1} barang lainnya',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                      Text('Total Item: $totalUnitSeluruhnya Unit',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Baris bawah: sisa tagihan + tombol
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.toLowerCase() == 'selesai'
                          ? 'Status Pembayaran'
                          : status.toLowerCase() == 'disewa'
                              ? 'Sisa Tagihan'
                              : 'Total DP',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      status.toLowerCase() == 'selesai'
                          ? 'LUNAS'
                          : 'Rp ${formatRupiah(status.toLowerCase() == 'disewa' ? (transaksi['sisa_tagihan'] ?? 0) : (transaksi['total_dp'] ?? 0))}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: status.toLowerCase() == 'selesai'
                              ? AppColors.success
                              : AppColors.secondary),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UserDetailPesananScreen(pesanan: transaksi),
                        ),
                      ).then((_) => _ambilPesananSistem());
                    },
                    child: Text(
                      status.toLowerCase() == 'menunggu_dp'
                          ? 'Bayar DP'
                          : 'Detail Transaksi',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    if (SesiUser.isGuest) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Pesanan Saya', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text('Anda Belum Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              const Text('Silakan login untuk melihat daftar pesanan Anda.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((val) {
                    if (val == true && mounted) {
                      setState(() {
                        _ambilPesananSistem();
                      });
                    }
                  });
                },
                child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // Filter pencarian
    List<Map<String, dynamic>> filteredPesanan = pesananSaya.where((p) {
      if (_searchQuery.isEmpty) return true;
      String query = _searchQuery.toLowerCase();
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
      
      return idTrx.contains(query) || status.contains(query) || matchItem;
    }).toList();

    // Status aktif (tidak selesai/ditolak)
    List<Map<String, dynamic>> pesananBerjalan = filteredPesanan
        .where((p) => !['selesai', 'ditolak']
            .contains((p['status_transaksi'] ?? '').toLowerCase()))
        .toList();

    List<Map<String, dynamic>> riwayatPesanan = filteredPesanan
        .where((p) => ['selesai', 'ditolak']
            .contains((p['status_transaksi'] ?? '').toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Cari ID, barang, status...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.black38),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
              : const Text('Pesanan Saya',
                  style:
                      TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.textPrimary),
              tooltip: _isSearching ? 'Tutup Pencarian' : 'Cari Pesanan',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchQuery = '';
                });
              },
            ),
            const SizedBox(width: 10),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Sedang Proses'),
              Tab(text: 'Riwayat Selesai'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  pesananBerjalan.isEmpty
                      ? _buildKondisiKosong(
                          'Belum ada pesanan yang sedang berjalan.')
                      : RefreshIndicator(
                          onRefresh: _ambilPesananSistem,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: pesananBerjalan.length,
                            itemBuilder: (ctx, i) =>
                                _buildKartuPesananUser(pesananBerjalan[i]),
                          ),
                        ),
                  riwayatPesanan.isEmpty
                      ? _buildKondisiKosong('Belum ada riwayat pesanan.')
                      : RefreshIndicator(
                          onRefresh: _ambilPesananSistem,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: riwayatPesanan.length,
                            itemBuilder: (ctx, i) =>
                                _buildKartuPesananUser(riwayatPesanan[i]),
                          ),
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildKondisiKosong(String pesan) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(pesan,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
