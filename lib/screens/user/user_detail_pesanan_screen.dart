import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
import 'menunggu_pembayaran_screen.dart';

class UserDetailPesananScreen extends StatefulWidget {
  final Map<String, dynamic> pesanan; // Ini adalah object Transaksi

  const UserDetailPesananScreen({super.key, required this.pesanan});

  @override
  State<UserDetailPesananScreen> createState() => _UserDetailPesananScreenState();
}

class _UserDetailPesananScreenState extends State<UserDetailPesananScreen> {
  late Map<String, dynamic> transaksi;
  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    transaksi = Map<String, dynamic>.from(widget.pesanan);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadBuktiTf();
    }
  }

  Future<void> _uploadBuktiTf() async {
    if (_imageFile == null) return;
    setState(() => _isUploading = true);

    try {
      final String idTransaksi = transaksi['id_transaksi'];
      // Upload via API transaksi (bulk)
      final uri = Uri.parse('${AppConfig.baseUrl}/transaksi/$idTransaksi/upload-dp');
      
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('bukti_tf_dp', _imageFile!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bukti Transfer berhasil diunggah!'),
          backgroundColor: AppColors.success,
        ));
        setState(() {
          transaksi['status_transaksi'] = 'menunggu_konfirmasi';
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${response.body}'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }

    setState(() => _isUploading = false);
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
    String namaPemesan = transaksi['nama_pemesan'] ?? '-';
    String status = transaksi['status_transaksi'] ?? 'Diproses';
    String? urlBuktiTf = transaksi['url_bukti_tf_dp'];
    String? urlFotoKtp = transaksi['url_foto_ktp'];
    
    double totalHarga = double.tryParse(transaksi['total_harga'].toString()) ?? 0;
    double totalDp = double.tryParse(transaksi['total_dp'].toString()) ?? 0;
    double sisaTagihan = double.tryParse(transaksi['sisa_tagihan'].toString()) ?? 0;
    
    List detailPesanan = transaksi['detail_pesanan'] ?? [];

    Color warnaStatus = AppColors.warning;
    if (status.toLowerCase().contains('selesai') || status.toLowerCase().contains('disewa') || status.toLowerCase().contains('diambil')) {
      warnaStatus = AppColors.success;
    } else if (status.toLowerCase() == 'dp_dibayar' || status.toLowerCase() == 'menunggu_konfirmasi') {
      warnaStatus = AppColors.primary;
    } else if (status.toLowerCase().contains('tolak') || status.toLowerCase().contains('batal')) {
      warnaStatus = AppColors.error;
    }

    bool isLunas = status == 'Sudah Disewa' || status == 'Selesai' || status == 'disewa' || status == 'selesai';

    // Label status yang ramah (tidak raw backend)
    String labelStatus = _getLabelStatusUser(status);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Detail Transaksi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- KARTU STATUS & KODE TRANSAKSI ---
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
            const SizedBox(height: 20),

            // --- UPLOAD BUKTI TF SECTION (JIKA STATUS MENUNGGU_DP) ---
            if (status.toLowerCase() == 'menunggu_dp') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long, color: AppColors.primary, size: 40),
                    const SizedBox(height: 10),
                    const Text('Menunggu Pembayaran DP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 5),
                    const Text('Selesaikan pembayaran DP pesanan Anda melalui Midtrans.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Bayar DP via Midtrans'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          // Extract needed fields from transaksi
                          final snapUrl = transaksi['snap_url'] ?? '';
                          final expiredAtStr = transaksi['expired_at'];
                          DateTime expiredAt = expiredAtStr != null 
                              ? DateTime.parse(expiredAtStr).toLocal() 
                              : DateTime.now().add(const Duration(minutes: 30));
                          final totalDp = int.tryParse(transaksi['total_dp'].toString()) ?? 0;
                          
                          // Get first item name or default
                          String namaBarang = 'Sewa Alat';
                          final details = transaksi['detail_pesanan'];
                          if (details != null && details.isNotEmpty) {
                            namaBarang = details[0]['nama_barang'] ?? 'Sewa Alat';
                            if (details.length > 1) {
                              namaBarang += ' dan ${details.length - 1} lainnya';
                            }
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenungguPembayaranScreen(
                                idTransaksi: transaksi['id_transaksi'],
                                snapUrl: snapUrl,
                                expiredAt: expiredAt,
                                totalDp: totalDp,
                                namaBarang: namaBarang,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // --- BUKTI TF DP & FOTO KTP (JIKA SUDAH DIUPLOAD) ---
            if ((urlBuktiTf != null && urlBuktiTf.isNotEmpty) || (urlFotoKtp != null && urlFotoKtp.isNotEmpty)) ...[
              const Text('Dokumen Pendukung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urlBuktiTf != null && urlBuktiTf.isNotEmpty)
                    _buildZoomableImage(urlBuktiTf, 'Bukti Transfer', AppColors.primary),
                  if (urlBuktiTf != null && urlBuktiTf.isNotEmpty && urlFotoKtp != null && urlFotoKtp.isNotEmpty)
                    const SizedBox(width: 8),
                  if (urlFotoKtp != null && urlFotoKtp.isNotEmpty)
                    _buildZoomableImage(urlFotoKtp, 'Foto KTP', AppColors.primary),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // --- DAFTAR BARANG YANG DISEWA ---
            const Text('Daftar Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
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
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 60, height: 60, color: Colors.grey[200],
                            child: urlFoto.isNotEmpty
                                ? Image.network(urlFoto, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.image, color: Colors.grey))
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(namaBarang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text('Varian: $namaVarian | $lama Hari', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                              if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('Masa Sewa: ${item['tanggal_mulai']} s/d ${item['tanggal_selesai']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$qty x', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  Text('Rp ${formatRupiah(tHarga)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
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
            const SizedBox(height: 20),

            // --- KARTU RINCIAN BIAYA ---
            const Text('Rincian Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBarisInfo('Pemesan', namaPemesan),
                    const Divider(),
                    _buildBarisInfo('Metode Pembayaran', transaksi['metode_pembayaran'] ?? '-'),
                    const Divider(),
                    _buildBarisInfo('Total Biaya Sewa', 'Rp ${formatRupiah(totalHarga)}', isBold: true),
                    const Divider(),
                    _buildBarisInfo('Total DP Dibayar', 'Rp ${formatRupiah(totalDp)}'),
                    const Divider(),
                    if (transaksi['nominal_pelunasan'] != null && transaksi['nominal_pelunasan'].toString() != '0') ...[
                      _buildBarisInfo('Pelunasan Dibayar', 'Rp ${formatRupiah(transaksi['nominal_pelunasan'] ?? 0)}'),
                      const Divider(),
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
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildBarisInfo(String label, String nilai, {bool isBold = false, Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nilai, 
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getLabelStatusUser(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu_dp': return 'Menunggu Pembayaran DP';
      case 'dp_dibayar': return 'DP Dibayar';
      case 'menunggu_konfirmasi': return 'Menunggu Konfirmasi Admin';
      case 'akan_diambil': return 'Siap Diambil';
      case 'disewa': return 'Sedang Disewa';
      case 'selesai': return 'Selesai';
      case 'ditolak': return 'Ditolak';
      case 'dibatalkan': return 'Dibatalkan';
      default: return status;
    }
  }
}