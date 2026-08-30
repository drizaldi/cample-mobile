import 'package:flutter/material.dart';
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
import 'form_pelunasan_screen.dart';
import 'admin_form_pengembalian_screen.dart';

class AdminDetailPesananScreen extends StatefulWidget {
  final Map<String, dynamic> pesanan; // Sebenarnya ini adalah transaksi

  const AdminDetailPesananScreen({super.key, required this.pesanan});

  @override
  State<AdminDetailPesananScreen> createState() => _AdminDetailPesananScreenState();
}

class _AdminDetailPesananScreenState extends State<AdminDetailPesananScreen> {
  late Map<String, dynamic> transaksi;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    transaksi = Map<String, dynamic>.from(widget.pesanan);
  }

  Future<void> _updateStatus(String statusBaru) async {
    setState(() => _isLoading = true);
    try {
      final String id = transaksi['id_transaksi'];
      final url = '${AppConfig.baseUrl}/pesanan/$id/status';

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': statusBaru}),
      );
      final data = jsonDecode(resp.body);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() => transaksi['status_transaksi'] = statusBaru);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status diubah ke: $statusBaru'),
          backgroundColor: AppColors.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: ${data['pesan'] ?? 'Error'}'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }

  void _showKonfirmasiDialog(String statusBaru, String judul, String isi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: Text(isi, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          Container(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(statusBaru);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text('Ya, Konfirmasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomableImage(String url, String label, Color color) {
    return SizedBox(
      width: 110,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.network(url, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)))),
              ),
              Container(width: double.infinity, color: color.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String kodeTransaksi = transaksi['id_transaksi'] ?? '-';
    String namaPemesan = transaksi['nama_pemesan'] ?? 'User Tanpa Nama';
    String status = transaksi['status_transaksi'] ?? 'Diproses';
    String? urlBuktiTf = transaksi['url_bukti_tf_dp'];
    String? urlFotoKtp = transaksi['url_foto_ktp'];

    double totalHarga = double.tryParse(transaksi['total_harga'].toString()) ?? 0;
    double totalDp = double.tryParse(transaksi['total_dp'].toString()) ?? 0;
    double sisaTagihan = double.tryParse(transaksi['sisa_tagihan'].toString()) ?? 0;

    List detailPesanan = transaksi['detail_pesanan'] ?? [];

    // Tentukan label status yang ramah
    String labelStatus = _getLabelStatus(status, detailPesanan);

    Color warnaStatus = AppColors.warning;
    if (status.toLowerCase().contains('akan_diambil') || status.toLowerCase().contains('disewa') || status.toLowerCase().contains('selesai')) {
      warnaStatus = AppColors.success;
    } else if (status.toLowerCase() == 'menunggu_konfirmasi' || status.toLowerCase() == 'dp_dibayar') {
      warnaStatus = AppColors.primary;
    } else if (status.toLowerCase().contains('tolak') || status.toLowerCase().contains('batal')) {
      warnaStatus = AppColors.error;
    }

    bool isLunas = status == 'Sudah Disewa' || status == 'Selesai' || status == 'disewa' || status == 'selesai';

    // Tombol aksi berdasarkan status
    Widget? tombolAksi = _buildTombolAksi(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Pesanan (Admin)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. PROFIL PEMESAN ---
                const Text('Informasi Pemesan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[300]),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColors.background,
                            backgroundImage: (transaksi['foto_profil'] != null && transaksi['foto_profil'].toString().isNotEmpty)
                                ? NetworkImage(transaksi['foto_profil'].toString())
                                : null,
                            child: (transaksi['foto_profil'] == null || transaksi['foto_profil'].toString().isEmpty)
                                ? const Icon(Icons.person, color: AppColors.primary, size: 30)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(namaPemesan, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              const Text('Pelanggan / Customer', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. STATUS PESANAN ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warnaStatus.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: warnaStatus.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(labelStatus, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 5),
                      Text('ID Transaksi: $kodeTransaksi', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- 3. DOKUMEN PENDUKUNG (TF & KTP) ---
                if ((urlBuktiTf != null && urlBuktiTf.isNotEmpty) || (urlFotoKtp != null && urlFotoKtp.isNotEmpty)) ...[
                  const Text('Dokumen Pendukung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (urlBuktiTf != null && urlBuktiTf.isNotEmpty)
                        _buildZoomableImage(urlBuktiTf, 'Bukti Transfer DP', AppColors.primary),
                      if (urlBuktiTf != null && urlBuktiTf.isNotEmpty && urlFotoKtp != null && urlFotoKtp.isNotEmpty)
                        const SizedBox(width: 8),
                      if (urlFotoKtp != null && urlFotoKtp.isNotEmpty)
                        _buildZoomableImage(urlFotoKtp, 'Foto KTP', AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // --- 4. DAFTAR BARANG YANG DISEWA ---
                const Text('Daftar Barang', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: detailPesanan.length,
                  itemBuilder: (context, index) {
                    var item = detailPesanan[index];
                    String namaBarang = item['nama_barang'] ?? 'Alat';
                    String namaVarian = item['nama_varian'] ?? '-';
                    String urlFoto = item['url_foto'] ?? '';
                    int qty = int.tryParse(item['jumlah_pesan'].toString()) ?? 0;
                    int lama = int.tryParse(item['lama_sewa'].toString()) ?? 0;
                    double tHarga = double.tryParse(item['total_harga'].toString()) ?? 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 70, height: 70, color: AppColors.background,
                                child: urlFoto.isNotEmpty
                                    ? Image.network(urlFoto, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.image, color: Colors.grey))
                                    : const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(namaBarang, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('Varian: $namaVarian | $lama Hari', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                  if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Masa Sewa: ${item['tanggal_mulai']} s/d ${item['tanggal_selesai']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('$qty x', style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
                                      Text('Rp ${formatRupiah(tHarga)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15)),
                                    ],
                                  ),
                                  // BANNER ORANGE: Keterlambatan (terpisah dari kerusakan fisik)
                                  if (item['denda_keterlambatan'] != null && item['denda_keterlambatan'].toString() != '0') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, color: Colors.orange, size: 14),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Terlambat — Denda: Rp ${formatRupiah(item['denda_keterlambatan'] ?? 0)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // BANNER MERAH: Kerusakan / Kehilangan fisik barang
                                  if (item['kondisi_pengembalian'] != null && item['kondisi_pengembalian'] != 'Normal') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withOpacity(0.5))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.warning, color: AppColors.error, size: 16),
                                              const SizedBox(width: 4),
                                              Text('Kendala: ${item['kondisi_pengembalian']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 12)),
                                            ],
                                          ),
                                          if (item['keterangan_kondisi'] != null && item['keterangan_kondisi'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text('Ket: ${item['keterangan_kondisi']}', style: TextStyle(color: AppColors.error, fontSize: 11)),
                                            ),
                                          if (item['denda_kerusakan'] != null && item['denda_kerusakan'].toString() != '0')
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text('Denda Kerusakan: Rp ${formatRupiah(item['denda_kerusakan'] ?? 0)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                          if (item['url_foto_pengembalian'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: _buildZoomableImage(item['url_foto_pengembalian'], 'Foto Kendala', AppColors.error),
                                            )
                                        ],
                                      ),
                                    ),
                                  ] else if (status == 'selesai' && item['kondisi_pengembalian'] == 'Normal' && (item['denda_keterlambatan'] == null || item['denda_keterlambatan'].toString() == '0')) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                        const SizedBox(width: 4),
                                        Text('Dikembalikan Normal', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // --- 6. RINCIAN BIAYA ---
                const Text('Rincian Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
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
                      children: [
                        _buildBarisInfo('Metode Pembayaran', transaksi['metode_pembayaran'] ?? '-'),
                        const Divider(height: 24, color: AppColors.background),
                        _buildBarisInfo('Total Biaya Sewa', 'Rp ${formatRupiah(totalHarga)}', isBold: true),
                        const Divider(height: 24, color: AppColors.background),
                        _buildBarisInfo('DP Dibayar', 'Rp ${formatRupiah(totalDp)}'),
                        const Divider(height: 24, color: AppColors.background),
                        if (transaksi['nominal_pelunasan'] != null && transaksi['nominal_pelunasan'].toString() != '0') ...[
                          _buildBarisInfo('Pelunasan Dibayar', 'Rp ${formatRupiah(transaksi['nominal_pelunasan'] ?? 0)}'),
                          const Divider(height: 24, color: AppColors.background),
                        ],
                        _buildBarisInfo(
                          'Sisa Tagihan',
                          isLunas ? 'LUNAS' : 'Rp ${formatRupiah(sisaTagihan)}',
                          isBold: true,
                          color: isLunas ? AppColors.success : AppColors.error
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // --- TOMBOL AKSI ADMIN (STICKY DI BAWAH) ---
          if (tombolAksi != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : tombolAksi,
              ),
            ),
        ],
      ),
    );
  }

  String _getLabelStatus(String status, List detailPesanan) {
    switch (status.toLowerCase()) {
      case 'menunggu_dp': return 'MENUNGGU PEMBAYARAN DP';
      case 'dp_dibayar': return 'DP DIBAYAR';
      case 'menunggu_konfirmasi': return 'MENUNGGU KONFIRMASI ADMIN';
      case 'akan_diambil': return 'AKAN SEGERA DIAMBIL';
      case 'disewa': return 'SEDANG DISEWA';
      case 'selesai':
        bool adaKendala = false;
        for (var item in detailPesanan) {
          if (item['kondisi_pengembalian'] != null && item['kondisi_pengembalian'] != 'Normal') {
            adaKendala = true;
            break;
          }
        }
        return adaKendala ? 'SELESAI (BERKENDALA)' : 'SELESAI';
      case 'ditolak': return 'DITOLAK';
      default: return status.toUpperCase();
    }
  }

  Widget? _buildTombolAksi(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu_konfirmasi':
      case 'dp_dibayar':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showKonfirmasiDialog('ditolak', 'Tolak Pesanan?', 'Apakah Anda yakin ingin menolak pesanan ini?'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => _showKonfirmasiDialog('akan_diambil', 'Konfirmasi DP?', 'Dengan mengkonfirmasi, stok barang akan dikurangi dan penyewa akan diberitahu bahwa pesanannya siap diambil.'),
                child: const Text('Konfirmasi DP', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      case 'akan_diambil':
        return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size(double.infinity, 50)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FormPelunasanScreen(
                  pesanan: transaksi,
                  onSelesai: () => setState(() => transaksi['status_transaksi'] = 'disewa'),
                ),
              ),
            );
          },
          child: const Text('Lengkapi Pelunasan Sewa', style: TextStyle(color: Colors.white)),
        );
      case 'disewa':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size(double.infinity, 50)),
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
                          _pengembalianNormal();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        child: const Text('Ya, Normal', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Pengembalian Normal', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminFormPengembalianScreen(
                      transaksi: transaksi,
                      onSelesai: () {
                        setState(() => transaksi['status_transaksi'] = 'selesai');
                      },
                    ),
                  ),
                );
              },
              child: const Text('Laporan Kendala (Rusak/Hilang)'),
            ),
          ],
        );
      default:
        return null;
    }
  }

  Future<void> _pengembalianNormal() async {
    setState(() => _isLoading = true);
    try {
      final String id = transaksi['id_transaksi'];
      final url = '${AppConfig.baseUrl}/transaksi/$id/pengembalian';

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'items': []}), // array kosong berarti normal semua
      );
      
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() => transaksi['status_transaksi'] = 'selesai');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barang berhasil dikembalikan secara normal'),
          backgroundColor: AppColors.success,
        ));
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

  Widget _buildBarisInfo(String label, String nilai, {bool isBold = false, Color color = AppColors.textPrimary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
