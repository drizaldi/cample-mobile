import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import '../../sesi_user.dart';
import '../user/menunggu_pembayaran_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic>? barang;
  final Map<String, dynamic>? varianTerpilih;
  final int? jumlahPesan;
  final int? lamaSewa;
  final String? idKeranjang; // Tambahan untuk hapus otomatis dari keranjang
  
  final bool isBulk;
  final List<Map<String, dynamic>>? bulkItems;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;

  const CheckoutScreen({
    super.key,
    this.barang,
    this.varianTerpilih,
    this.jumlahPesan,
    this.lamaSewa,
    this.idKeranjang,
    this.isBulk = false,
    this.bulkItems,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _bayarSekarang(int total, int dp, int sisaTagihan) async {
    setState(() => _isLoading = true);

    try {
      if (widget.isBulk) {
        // --- LOGIKA BULK CHECKOUT ---
        final String url = '${AppConfig.baseUrl}/pesanan/bulk';
        
        List<Map<String, dynamic>> itemsPayload = [];
        for (var item in widget.bulkItems!) {
          int qty = int.tryParse(item['qty'].toString()) ?? 1;
          int lamaSewaItem = 1;
          if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null) {
             DateTime start = DateTime.parse(item['tanggal_mulai']);
             DateTime end = DateTime.parse(item['tanggal_selesai']);
             lamaSewaItem = end.difference(start).inDays + 1;
          }

          itemsPayload.add({
            'id_varian': item['id_varian'],
            'jumlah_pesan': qty,
            'lama_sewa': lamaSewaItem,
            'tanggal_mulai': item['tanggal_mulai'] != null ? DateTime.parse(item['tanggal_mulai']).toIso8601String().split('T')[0] : null,
            'tanggal_selesai': item['tanggal_selesai'] != null ? DateTime.parse(item['tanggal_selesai']).toIso8601String().split('T')[0] : null,
          });
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'items': itemsPayload,
            'id_user': SesiUser.idUser,
            'nama_pemesan': SesiUser.namaUser ?? 'Pengguna',
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
           final responseData = jsonDecode(response.body);
           final String idTransaksi = responseData['id_transaksi'] ?? '';
           final String snapUrl     = responseData['snap_url'] ?? '';
           final int totalDp        = responseData['total_dp'] ?? dp;
           final String namaBarang  = responseData['nama_barang'] ?? 'Bulk Checkout';
           final DateTime expiredAt = responseData['expired_at'] != null
               ? DateTime.parse(responseData['expired_at']).toLocal()
               : DateTime.now().add(const Duration(minutes: 30));

           // Hapus barang dari keranjang setelah checkout berhasil
           for (var item in widget.bulkItems!) {
             if (item['id_keranjang'] != null) {
               try {
                 await http.delete(Uri.parse('${AppConfig.baseUrl}/keranjang/${item['id_keranjang']}'));
               } catch (e) {
                 print("Gagal hapus keranjang bulk: $e");
               }
             }
           }

           // Buat daftar nama barang untuk ditampilkan
           final List<String> daftarBarang = widget.bulkItems!
               .map((item) => '${item['nama_barang']} (${item['nama_varian']})')
               .toList();

           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MenungguPembayaranScreen(
                idTransaksi: idTransaksi,
                snapUrl: snapUrl,
                expiredAt: expiredAt,
                totalDp: totalDp,
                namaBarang: namaBarang,
                daftarNamaBarang: daftarBarang,
              ),
            ),
          );
        } else {
           final responseData = jsonDecode(response.body);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['pesan'] ?? 'Gagal Memproses Pesanan!'), backgroundColor: AppColors.error));
        }

      } else {
        // --- LOGIKA SINGLE CHECKOUT ---
        final String url = '${AppConfig.baseUrl}/pesanan';
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_varian': widget.varianTerpilih!['id_varian'],
            'jumlah_pesan': widget.jumlahPesan,
            'lama_sewa': widget.lamaSewa,
            'tanggal_mulai': widget.tanggalMulai?.toIso8601String().split('T')[0],
            'tanggal_selesai': widget.tanggalSelesai?.toIso8601String().split('T')[0],
            'nama_pemesan': SesiUser.namaUser ?? 'Pengguna Tidak Dikenal',
            'id_user': SesiUser.idUser,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          final String idTransaksi = responseData['id_transaksi'] ?? '';
          final String snapUrl     = responseData['snap_url'] ?? '';
          final int totalDp        = responseData['total_dp'] ?? dp;
          final String namaBarang  = responseData['nama_barang'] ?? widget.barang?['nama_barang'] ?? '';
          final DateTime expiredAt = responseData['expired_at'] != null
              ? DateTime.parse(responseData['expired_at']).toLocal()
              : DateTime.now().add(const Duration(minutes: 30));

          // Hapus dari keranjang jika berasal dari keranjang
          if (widget.idKeranjang != null) {
            try {
              await http.delete(Uri.parse('${AppConfig.baseUrl}/keranjang/${widget.idKeranjang}'));
            } catch (e) {
              print("Gagal hapus keranjang: $e");
            }
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MenungguPembayaranScreen(
                idTransaksi: idTransaksi,
                snapUrl: snapUrl,
                expiredAt: expiredAt,
                totalDp: totalDp,
                namaBarang: namaBarang,
                daftarNamaBarang: [
                  '${widget.barang?['nama_barang'] ?? ''} (${widget.varianTerpilih?['nama_varian'] ?? ''})'
                ],
              ),
            ),
          );
        } else {
          final responseData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['pesan'] ?? 'Gagal Memproses Pesanan!'), backgroundColor: AppColors.error));
        }
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan jaringan!'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    int totalHarga = 0;
    
    if (widget.isBulk) {
       for (var item in widget.bulkItems!) {
          int qty = int.tryParse(item['qty'].toString()) ?? 1;
          int lamaSewaItem = 1;
          if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null) {
             DateTime start = DateTime.parse(item['tanggal_mulai']);
             DateTime end = DateTime.parse(item['tanggal_selesai']);
             lamaSewaItem = end.difference(start).inDays + 1;
          }
          int hargaSewa = int.tryParse(item['harga_sewa'].toString()) ?? 0;
          totalHarga += (hargaSewa * qty * lamaSewaItem);
       }
    } else {
       int hargaSewa = int.tryParse(widget.varianTerpilih!['harga_sewa'].toString()) ?? 0;
       final int persenDiskon = widget.barang!['persen_diskon'] ?? 0;
       if (persenDiskon > 0) {
         hargaSewa = hargaSewa - (hargaSewa * persenDiskon / 100).round();
       }
       totalHarga = hargaSewa * widget.jumlahPesan! * widget.lamaSewa!;
    }

    int dpDibayar = (totalHarga / 2).round();
    int sisaTagihan = totalHarga - dpDibayar;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran (Checkout)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Rincian Pesanan
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rincian Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('Pastikan atau cek kembali tanggal sudah sesuai dengan rentang waktu yang ingin disewa!', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Divider(height: 24, color: AppColors.background),
                        if (widget.isBulk) 
                           ...widget.bulkItems!.map((item) {
                              int qty = int.tryParse(item['qty'].toString()) ?? 1;
                              int lamaSewaItem = 1;
                              String masaSewaStr = '-';
                              if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null) {
                                 DateTime start = DateTime.parse(item['tanggal_mulai']);
                                 DateTime end = DateTime.parse(item['tanggal_selesai']);
                                 lamaSewaItem = end.difference(start).inDays + 1;
                                 masaSewaStr = '${item['tanggal_mulai']} s/d ${item['tanggal_selesai']}';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Text('- ${item['nama_barang']} (${item['nama_varian']})', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                     Text('  $qty Unit x $lamaSewaItem Hari', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                     if (masaSewaStr != '-')
                                       Text('  Masa Sewa: $masaSewaStr', style: const TextStyle(color: AppColors.secondary, fontSize: 12)),
                                  ]
                                )
                              );
                           }).toList()
                        else ...[
                           Text('Barang: ${widget.barang!['nama_barang']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.5)),
                           Text('Varian: ${widget.varianTerpilih!['nama_varian']}', style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                           Text('Jumlah: ${widget.jumlahPesan} Unit', style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                           Text('Lama Sewa: ${widget.lamaSewa} Hari', style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                           if (widget.tanggalMulai != null && widget.tanggalSelesai != null)
                             Text(
                               'Masa Sewa: ${widget.tanggalMulai!.toIso8601String().split("T")[0]} s/d ${widget.tanggalSelesai!.toIso8601String().split("T")[0]}',
                               style: const TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.5),
                             ),
                        ],
                        const Divider(height: 24, color: AppColors.background),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Harga', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            Text('Rp ${formatRupiah(totalHarga)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rincian Pembayaran (Sistem DP)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rincian Pembayaran',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                        const Divider(height: 24, color: AppColors.background),
                        const Text(
                            'Sistem mewajibkan Down Payment (DP) 50%.',
                            style: TextStyle(
                                color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('DP Dibayar Sekarang:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              Text('Rp ${formatRupiah(dpDibayar)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary, fontSize: 15))
                            ]),
                        const SizedBox(height: 8),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sisa Bayar di Toko:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                              Text('Rp ${formatRupiah(sisaTagihan)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.error, fontSize: 15))
                            ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Metode Pembayaran (Midtrans)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))]
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.payment, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                                Text('Bayar Online', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.background),
                        const Text('Pembayaran DP dilakukan secara online. Anda dapat memilih berbagai metode pembayaran yang tersedia, antara lain:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Virtual Account', 'QRIS', 'GoPay', 'OVO', 'Dana', 'Kartu Kredit']
                            .map((m) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(m, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            )).toList(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Batas waktu pembayaran adalah 30 menit setelah pesanan dibuat.', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: _isLoading ? const LinearGradient(colors: [Colors.grey, Colors.grey]) : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16)
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _isLoading
                ? null
                : () => _bayarSekarang(totalHarga, dpDibayar, sisaTagihan),
            child: Text(
              'Konfirmasi & Bayar DP Rp ${formatRupiah(dpDibayar)}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
