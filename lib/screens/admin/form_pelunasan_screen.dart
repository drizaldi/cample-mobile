// ignore_for_file: avoid_print, use_build_context_synchronously
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FormPelunasanScreen extends StatefulWidget {
  final Map<String, dynamic> pesanan;
  final VoidCallback? onSelesai;

  const FormPelunasanScreen({
    super.key,
    required this.pesanan,
    this.onSelesai,
  });

  @override
  State<FormPelunasanScreen> createState() => _FormPelunasanScreenState();
}

class _FormPelunasanScreenState extends State<FormPelunasanScreen> {
  final _nominalController = TextEditingController();
  XFile? _fotoKtp;
  bool _isLoading = false;
  String _metodePelunasan = 'Transfer';

  @override
  void initState() {
    super.initState();
    // Pre-fill sisa tagihan
    final sisa = widget.pesanan['sisa_tagihan'] ?? 0;
    _nominalController.text = sisa.toString();
  }

  @override
  void dispose() {
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _pickKtp(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _fotoKtp = picked);
  }

  Future<void> _submitPelunasan() async {
    if (_fotoKtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto KTP penyewa wajib diisi!'),
          backgroundColor: AppColors.warning));
      return;
    }
    if (_nominalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nominal pelunasan wajib diisi!'),
          backgroundColor: AppColors.warning));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final idToUse = widget.pesanan['id_transaksi'] ?? widget.pesanan['id_pesanan'];
      final uri = Uri.parse('${AppConfig.baseUrl}/pesanan/$idToUse/pelunasan');

      var request = http.MultipartRequest('POST', uri);
      request.fields['nominal_pelunasan'] = _nominalController.text;
      request.fields['metode_pelunasan'] = _metodePelunasan;
      
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes('foto_ktp', await _fotoKtp!.readAsBytes(), filename: _fotoKtp!.name)
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('foto_ktp', _fotoKtp!.path)
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        // Tampilkan struk pelunasan
        final totalHarga = double.tryParse(widget.pesanan['total_harga'].toString()) ?? 0;
        // total_dp ada di level transaksi, dp_dibayar ada di level pesanan (satuan)
        final dpDibayar = double.tryParse(
          (widget.pesanan['total_dp'] ?? widget.pesanan['dp_dibayar'] ?? 0).toString()
        ) ?? 0;
        final nominalLunas = int.tryParse(_nominalController.text) ?? 0;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StrukPelunasanScreen(
              pesanan: widget.pesanan,
              nominalPelunasan: nominalLunas,
              metodePelunasan: _metodePelunasan,
              totalHarga: totalHarga.toInt(),
              dpDibayar: dpDibayar.toInt(),
            ),
          ),
        );
        widget.onSelesai?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: ${response.body}'),
            backgroundColor: AppColors.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppColors.error));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final detailPesanan = widget.pesanan['detail_pesanan'];
    final bool isBulk = detailPesanan != null && detailPesanan is List && detailPesanan.length > 1;
    final sisa = widget.pesanan['sisa_tagihan'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Form Pelunasan Sewa',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ringkasan pesanan
            const Text('Ringkasan Pesanan',
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
                    // --- Jika lebih dari 1 barang: jabarkan per item ---
                    if (isBulk) ...[
                      _buildItemHeader('Barang'),
                      ...detailPesanan.map<Widget>((d) {
                        return _buildItemValue(d['nama_barang'] ?? '-');
                      }).toList(),
                      const SizedBox(height: 8),
                      _buildItemHeader('Varian'),
                      ...detailPesanan.map<Widget>((d) {
                        return _buildItemValue(d['nama_varian'] ?? '-');
                      }).toList(),
                      const SizedBox(height: 8),
                      _buildItemHeader('Lama Sewa'),
                      ...detailPesanan.map<Widget>((d) {
                        String nama = d['nama_barang'] ?? '-';
                        String lama = '${d['lama_sewa'] ?? 0} Hari';
                        return _buildItemKeyValue(nama, lama);
                      }).toList(),
                      const SizedBox(height: 8),
                      _buildItemHeader('Masa Sewa'),
                      ...detailPesanan.map<Widget>((d) {
                        String nama = d['nama_barang'] ?? '-';
                        String masa = (d['tanggal_mulai'] != null)
                            ? '${d['tanggal_mulai']} s/d ${d['tanggal_selesai']}'
                            : '-';
                        return _buildItemKeyValue(nama, masa);
                      }).toList(),
                    ] else ...[
                      // --- Jika 1 barang: tampilkan ringkas seperti sebelumnya ---
                      _buildSingleItemSummary(detailPesanan),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.background, thickness: 2),
                    ),
                    _row('Sisa Tagihan (Pelunasan)', 'Rp ${formatRupiah(sisa)}',
                        warna: AppColors.error, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nominal pelunasan
            const Text('Nominal yang Diterima',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nominalController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                filled: true,
                fillColor: AppColors.background,
                hintText: 'Masukkan nominal',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 24),

            // Metode pelunasan
            const Text('Metode Pelunasan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: ['Transfer', 'Tunai'].map((m) {
                final selected = _metodePelunasan == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _metodePelunasan = m),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.surface,
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.accentLight.withOpacity(0.5),
                            width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: selected ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Center(
                        child: Text(m,
                            style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Foto KTP Penyewa
            const Text('Foto KTP Penyewa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Wajib diambil foto untuk identitas penyewa.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showPilihSumber(),
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _fotoKtp != null
                          ? AppColors.primary
                          : AppColors.accentLight,
                      width: _fotoKtp != null ? 2 : 1),
                ),
                child: _fotoKtp != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(_fotoKtp!.path, fit: BoxFit.cover)
                            : Image.file(File(_fotoKtp!.path), fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined,
                              size: 48, color: AppColors.secondary),
                          SizedBox(height: 12),
                          Text('Ketuk untuk foto KTP',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            if (_fotoKtp != null)
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Ganti Foto KTP'),
                onPressed: () => _showPilihSumber(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12)
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submitPelunasan,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _isLoading ? 'Memproses...' : 'Selesaikan & Cetak Struk',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
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
                _pickKtp(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickKtp(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String nilai,
      {Color warna = Colors.black87, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(nilai,
              style: TextStyle(
                  color: warna,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14)),
        ],
      ),
    );
  }

  // Header label untuk kelompok item
  Widget _buildItemHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label,
          style: const TextStyle(
              color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  // Nilai item (list)
  Widget _buildItemValue(String nilai) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Text('• $nilai',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  // Nilai item dengan key (nama barang : nilai)
  Widget _buildItemKeyValue(String key, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('  $key',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
          Text(nilai,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Tampilan ringkasan untuk 1 barang
  Widget _buildSingleItemSummary(dynamic detailPesanan) {
    String namaBarang = '-';
    String namaVarian = '-';
    String lamaSewa = '-';
    String jumlahPesan = '-';
    String masaSewa = '-';
    if (detailPesanan != null && detailPesanan is List && detailPesanan.isNotEmpty) {
      var first = detailPesanan[0];
      namaBarang = first['nama_barang'] ?? '-';
      namaVarian = first['nama_varian'] ?? '-';
      lamaSewa = '${first['lama_sewa'] ?? 0}';
      jumlahPesan = '${first['jumlah_pesan'] ?? 0}';
      if (first['tanggal_mulai'] != null) {
        masaSewa = '${first['tanggal_mulai']} s/d ${first['tanggal_selesai']}';
      }
    } else {
      namaBarang = widget.pesanan['nama_barang'] ?? '-';
      namaVarian = widget.pesanan['nama_varian'] ?? '-';
      lamaSewa = '${widget.pesanan['lama_sewa'] ?? 0}';
      jumlahPesan = '${widget.pesanan['jumlah_pesan'] ?? 0}';
      if (widget.pesanan['tanggal_mulai'] != null) {
        masaSewa = '${widget.pesanan['tanggal_mulai']} s/d ${widget.pesanan['tanggal_selesai']}';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Barang', '$namaBarang ($namaVarian)'),
        _row('Jumlah', '$jumlahPesan Unit'),
        _row('Lama Sewa', '$lamaSewa Hari'),
        if (masaSewa != '-') _row('Masa Sewa', masaSewa),
      ],
    );
  }
}

// ─────────────────────────────────────────────
/// Struk Pelunasan (bisa di-print / screenshot)
// ─────────────────────────────────────────────
class StrukPelunasanScreen extends StatelessWidget {
  final Map<String, dynamic> pesanan;
  final int nominalPelunasan;
  final String metodePelunasan;
  final int totalHarga;
  final int dpDibayar;

  const StrukPelunasanScreen({
    super.key,
    required this.pesanan,
    required this.nominalPelunasan,
    required this.metodePelunasan,
    required this.totalHarga,
    required this.dpDibayar,
  });

  @override
  Widget build(BuildContext context) {
    final detailPesanan = pesanan['detail_pesanan'];
    final bool isBulk = detailPesanan != null && detailPesanan is List && detailPesanan.length > 1;

    final namaPemesan = pesanan['nama_pemesan'] ?? '-';
    final idPesanan = pesanan['id_transaksi'] ?? pesanan['id_pesanan'] ?? '-';
    final now = DateTime.now();
    final tanggal =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Struk Pelunasan',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print / PDF'),
            onPressed: () => _cetakPdf(context, namaPemesan, idPesanan, tanggal, detailPesanan, isBulk),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    const Icon(Icons.store, color: AppColors.primary, size: 40),
                    const SizedBox(height: 6),
                    const Text('CAMPLE',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 2,
                            color: AppColors.primary)),
                    const Text('Toko Rental Alat Camping',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(tanggal,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const Divider(height: 24),

                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('✓ PELUNASAN DITERIMA',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 16),

                    // Detail
                    _struRow('No. Pesanan', '#$idPesanan'),
                    _struRow('Nama Penyewa', namaPemesan),
                    const Divider(),
                    // --- Barang detail (per item jika bulk) ---
                    if (isBulk && detailPesanan != null) ...[
                      _struLabel('Barang & Varian'),
                      ...detailPesanan.map<Widget>((d) => _struRow('', '• ${d['nama_barang'] ?? '-'} (${d['nama_varian'] ?? '-'})')).toList(),
                      _struLabel('Harga Satuan / Hari'),
                      ...detailPesanan.map<Widget>((d) {
                        final harga = int.tryParse((d['harga_satuan_asli'] ?? 0).toString()) ?? 0;
                        return _struRow(d['nama_barang'] ?? '-', 'Rp ${formatRupiah(harga)}');
                      }).toList(),
                      _struLabel('Lama Sewa'),
                      ...detailPesanan.map<Widget>((d) => _struRow(d['nama_barang'] ?? '-', '${d['lama_sewa'] ?? 0} Hari')).toList(),
                      _struLabel('Masa Sewa'),
                      ...detailPesanan.map<Widget>((d) {
                        final masa = (d['tanggal_mulai'] != null)
                            ? '${d['tanggal_mulai']} s/d ${d['tanggal_selesai']}'
                            : '-';
                        return _struRow(d['nama_barang'] ?? '-', masa);
                      }).toList(),
                    ] else if (!isBulk) ...[
                      _buildSingleStrukDetail(detailPesanan),
                    ],
                    const Divider(),
                    _struRow('Total Biaya Sewa', 'Rp ${formatRupiah(totalHarga)}'),
                    _struRow('DP Sudah Dibayar', 'Rp ${formatRupiah(dpDibayar)}',
                        warna: Colors.grey),
                    _struRow(
                        'Pelunasan ($metodePelunasan)',
                        'Rp ${formatRupiah(nominalPelunasan)}',
                        warna: AppColors.primary),
                    const Divider(),
                    _struRow(
                        'STATUS',
                        'L U N A S',
                        warna: AppColors.primary),

                    const SizedBox(height: 20),
                    const Text(
                      'Terima kasih sudah menyewa di Cample!\nHarap kembalikan barang tepat waktu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Selesai & Kembali',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _struRow(String label, String nilai,
      {Color warna = Colors.black87, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          Expanded(
            flex: 3,
            child: Text(nilai,
                textAlign: label.isEmpty ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: warna,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Label section header di struk
  Widget _struLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(label,
          style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
    );
  }

  // Detail 1 barang di struk
  Widget _buildSingleStrukDetail(dynamic detailPesanan) {
    String namaBarang = '-';
    String namaVarian = '-';
    String lamaSewa = '-';
    String jumlahPesan = '-';
    String masaSewa = '-';
    int hargaSatuan = 0;
    if (detailPesanan != null && detailPesanan is List && detailPesanan.isNotEmpty) {
      var first = detailPesanan[0];
      namaBarang = first['nama_barang'] ?? '-';
      namaVarian = first['nama_varian'] ?? '-';
      lamaSewa = '${first['lama_sewa'] ?? 0}';
      jumlahPesan = '${first['jumlah_pesan'] ?? 0}';
      hargaSatuan = int.tryParse((first['harga_satuan_asli'] ?? 0).toString()) ?? 0;
      if (first['tanggal_mulai'] != null) {
        masaSewa = '${first['tanggal_mulai']} s/d ${first['tanggal_selesai']}';
      }
    } else {
      namaBarang = pesanan['nama_barang'] ?? '-';
      namaVarian = pesanan['nama_varian'] ?? '-';
      lamaSewa = '${pesanan['lama_sewa'] ?? 0}';
      jumlahPesan = '${pesanan['jumlah_pesan'] ?? 0}';
      hargaSatuan = int.tryParse((pesanan['harga_satuan_asli'] ?? 0).toString()) ?? 0;
      if (pesanan['tanggal_mulai'] != null) {
        masaSewa = '${pesanan['tanggal_mulai']} s/d ${pesanan['tanggal_selesai']}';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _struRow('Barang', namaBarang),
        _struRow('Varian', namaVarian),
        _struRow('Jumlah', '$jumlahPesan Unit'),
        if (hargaSatuan > 0) _struRow('Harga Satuan/Hari', 'Rp ${formatRupiah(hargaSatuan)}'),
        _struRow('Lama Sewa', '$lamaSewa Hari'),
        if (masaSewa != '-') _struRow('Masa Sewa', masaSewa),
      ],
    );
  }

  Future<void> _cetakPdf(BuildContext context, String namaPemesan, String idPesanan, String tanggal, dynamic detailPesanan, bool isBulk) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context ctx) {
          return [
            pw.Center(child: pw.Text('CAMPLE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Toko Rental Alat Camping', style: const pw.TextStyle(fontSize: 12))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(tanggal, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800))),
            pw.Divider(height: 24),
            
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text('PELUNASAN DITERIMA', style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
              ),
            ),
            pw.SizedBox(height: 16),

            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('No. Pesanan', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.Text('#$idPesanan', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Nama Penyewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.Text(namaPemesan, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              ]),
              pw.Divider(height: 20),
              if (!isBulk && detailPesanan != null && detailPesanan is List && detailPesanan.isNotEmpty) ...[
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Barang', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                  pw.Text('${detailPesanan[0]['nama_barang'] ?? '-'} (${detailPesanan[0]['nama_varian'] ?? '-'})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Jumlah', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                  pw.Text('${detailPesanan[0]['jumlah_pesan'] ?? 0} Unit', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Harga Satuan/Hari', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                  pw.Text('Rp ${formatRupiah(int.tryParse((detailPesanan[0]['harga_satuan_asli'] ?? 0).toString()) ?? 0)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Lama Sewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                  pw.Text('${detailPesanan[0]['lama_sewa'] ?? 0} Hari', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                ]),
                if (detailPesanan[0]['tanggal_mulai'] != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Masa Sewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                    pw.Text('${detailPesanan[0]['tanggal_mulai']} s/d ${detailPesanan[0]['tanggal_selesai']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
                  ]),
                ],
              ],
              if (isBulk && detailPesanan != null && detailPesanan is List) ...[
                pw.Text('Barang & Varian', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.SizedBox(height: 2),
                ...detailPesanan.map<pw.Widget>((d) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('- ${d['nama_barang'] ?? '-'} (${d['nama_varian'] ?? '-'})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                  pw.Text('${d['jumlah_pesan'] ?? 0} Unit', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                ])).toList(),
                pw.SizedBox(height: 6),

                pw.Text('Harga Satuan / Hari', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.SizedBox(height: 2),
                ...detailPesanan.map<pw.Widget>((d) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('${d['nama_barang'] ?? '-'}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                  pw.Text('Rp ${formatRupiah(int.tryParse((d['harga_satuan_asli'] ?? 0).toString()) ?? 0)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                ])).toList(),
                pw.SizedBox(height: 6),

                pw.Text('Lama Sewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.SizedBox(height: 2),
                ...detailPesanan.map<pw.Widget>((d) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('${d['nama_barang'] ?? '-'}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                  pw.Text('${d['lama_sewa'] ?? 0} Hari', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                ])).toList(),
                pw.SizedBox(height: 6),

                pw.Text('Masa Sewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.SizedBox(height: 2),
                ...detailPesanan.map<pw.Widget>((d) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('${d['nama_barang'] ?? '-'}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                  pw.Text((d['tanggal_mulai'] != null) ? '${d['tanggal_mulai']} s/d ${d['tanggal_selesai']}' : '-', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal)),
                ])).toList(),
              ],
              
              pw.Divider(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total Biaya Sewa', style: pw.TextStyle(fontSize: 12, color: PdfColors.black, fontWeight: pw.FontWeight.normal)),
                pw.Text('Rp ${formatRupiah(totalHarga)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('DP (Midtrans)', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, fontWeight: pw.FontWeight.normal)),
                pw.Text('- Rp ${formatRupiah(dpDibayar)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.red800, fontWeight: pw.FontWeight.normal)),
              ]),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Pelunasan ($metodePelunasan)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('Rp ${formatRupiah(nominalPelunasan)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.black, fontWeight: pw.FontWeight.normal)),
              ]),
              
              pw.SizedBox(height: 30),
              pw.Center(child: pw.Text('Terima kasih sudah menyewa di Cample!', style: pw.TextStyle(fontSize: 12, color: PdfColors.black, fontWeight: pw.FontWeight.normal))),
              pw.Center(child: pw.Text('Harap kembalikan barang tepat waktu.', style: pw.TextStyle(fontSize: 12, color: PdfColors.black, fontWeight: pw.FontWeight.normal))),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Struk_Pelunasan_$idPesanan',
    );
  }
}
