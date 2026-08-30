// ignore_for_file: avoid_print, use_build_context_synchronously
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';


/// Dipanggil SETELAH checkout berhasil.
/// Menampilkan info rekening tujuan & form upload bukti TF.
class UploadBuktiTfScreen extends StatefulWidget {
  final String idPesanan;
  final String namaBank;
  final String noRekening;
  final String namaPemilik;
  final int dpDibayar;
  final String namaBarang;
  final bool isTransaksi;

  const UploadBuktiTfScreen({
    super.key,
    required this.idPesanan,
    required this.namaBank,
    required this.noRekening,
    required this.namaPemilik,
    required this.dpDibayar,
    required this.namaBarang,
    this.isTransaksi = false,
  });

  @override
  State<UploadBuktiTfScreen> createState() => _UploadBuktiTfScreenState();
}

class _UploadBuktiTfScreenState extends State<UploadBuktiTfScreen> {
  XFile? _imageFile;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  Future<void> _konfirmasiUpload() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih foto bukti transfer terlebih dahulu!'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse(widget.isTransaksi 
          ? '${AppConfig.baseUrl}/transaksi/${widget.idPesanan}/upload-dp'
          : '${AppConfig.baseUrl}/pesanan/${widget.idPesanan}/upload-dp');
      var request = http.MultipartRequest('POST', uri);
      
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes('bukti_tf_dp', await _imageFile!.readAsBytes(), filename: _imageFile!.name)
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('bukti_tf_dp', _imageFile!.path)
        );
      }
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        // Navigasi ke halaman sukses (pop semua sampai ke root beranda user)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => _BerhasilKirimScreen(
              idPesanan: widget.idPesanan,
              namaBarang: widget.namaBarang,
              dpDibayar: widget.dpDibayar,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengunggah: ${response.body}'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Upload Bukti Transfer DP',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pesanan berhasil dibuat! Sekarang lakukan transfer DP dan upload bukti transfernya.',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info rekening tujuan
            const Text('Rekening Tujuan Transfer DP',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.namaBank,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text('a/n ${widget.namaPemilik}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: AppColors.background, thickness: 2),
                    ),
                    const Text('Nomor Rekening',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.noRekening,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: 2,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text('Jumlah DP yang harus ditransfer:',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(
                            'Rp ${formatRupiah(widget.dpDibayar)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Upload foto bukti
            const Text('Upload Bukti Transfer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
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
                    // Preview foto
                    GestureDetector(
                      onTap: () => _showPilihSumber(),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _imageFile != null
                                  ? AppColors.primary
                                  : AppColors.accentLight,
                              width: _imageFile != null ? 2 : 1),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb 
                                    ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                                    : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 48, color: AppColors.secondary),
                                  SizedBox(height: 12),
                                  Text('Ketuk untuk upload bukti transfer',
                                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Tombol konfirmasi
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12)
              ),
              child: ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isUploading ? 'Mengirim...' : 'Kirim Bukti Transfer',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isUploading ? null : _konfirmasiUpload,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPilihSumber() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto (Kamera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman sukses setelah bukti TF dikirim
class _BerhasilKirimScreen extends StatelessWidget {
  final String idPesanan;
  final String namaBarang;
  final int dpDibayar;

  const _BerhasilKirimScreen({
    required this.idPesanan,
    required this.namaBarang,
    required this.dpDibayar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 80),
              const SizedBox(height: 20),
              const Text('Bukti Transfer Terkirim!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Pesanan #$idPesanan',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barang: $namaBarang',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('DP Ditransfer: Rp ${formatRupiah(dpDibayar)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    const Text(
                      'Pesanan Anda sedang dalam status "Menunggu Konfirmasi" admin. Anda akan mendapat notifikasi saat pesanan dikonfirmasi.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kembali ke Beranda',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
