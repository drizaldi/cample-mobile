import 'package:flutter/material.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import 'package:apk_cample166/config/app_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdminFormPengembalianScreen extends StatefulWidget {
  final Map<String, dynamic> transaksi;
  final VoidCallback onSelesai;

  const AdminFormPengembalianScreen({
    Key? key,
    required this.transaksi,
    required this.onSelesai,
  }) : super(key: key);

  @override
  State<AdminFormPengembalianScreen> createState() => _AdminFormPengembalianScreenState();
}

class _AdminFormPengembalianScreenState extends State<AdminFormPengembalianScreen> {
  bool _isLoading = false;
  late List<dynamic> _detailPesanan;
  
  // State per item
  Map<int, String> _kondisiItems = {};
  Map<int, TextEditingController> _dendaControllers = {};
  Map<int, TextEditingController> _keteranganControllers = {};
  Map<int, XFile?> _fotoItems = {};

  final List<String> _kondisiOptions = ['Normal', 'Rusak Ringan', 'Rusak Berat', 'Hilang'];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _detailPesanan = widget.transaksi['detail_pesanan'] ?? [];
    for (int i = 0; i < _detailPesanan.length; i++) {
      _kondisiItems[i] = 'Normal';
      _dendaControllers[i] = TextEditingController(text: '0');
      _keteranganControllers[i] = TextEditingController();
      _fotoItems[i] = null;
    }
  }

  @override
  void dispose() {
    for (var c in _dendaControllers.values) c.dispose();
    for (var c in _keteranganControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() => _fotoItems[index] = image);
    }
  }

  Future<void> _submitPengembalian() async {
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/transaksi/${widget.transaksi['id_transaksi']}/pengembalian');
      var request = http.MultipartRequest('POST', url);
      
      for (int i = 0; i < _detailPesanan.length; i++) {
        String idPesanan = _detailPesanan[i]['id_pesanan'].toString();
        request.fields['items[$i][id_pesanan]'] = idPesanan;
        request.fields['items[$i][kondisi]'] = _kondisiItems[i]!;
        request.fields['items[$i][denda_kerusakan]'] = (_dendaControllers[i]!.text.replaceAll(RegExp(r'[^0-9]'), '')).isEmpty ? '0' : _dendaControllers[i]!.text.replaceAll(RegExp(r'[^0-9]'), '');
        request.fields['items[$i][keterangan]'] = _keteranganControllers[i]!.text;
        
        if (_fotoItems[i] != null) {
          if (kIsWeb) {
            request.files.add(http.MultipartFile.fromBytes('items[$i][foto]', await _fotoItems[i]!.readAsBytes(), filename: _fotoItems[i]!.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('items[$i][foto]', _fotoItems[i]!.path));
          }
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengembalian berhasil dikonfirmasi', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.success),
        );
        widget.onSelesai();
        Navigator.pop(context);
      } else {
        throw Exception('Gagal menyimpan pengembalian: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Pengembalian', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _detailPesanan.length,
                    itemBuilder: (context, index) => _buildItemCard(_detailPesanan[index], index),
                  ),
                ),
                Container(
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _submitPengembalian,
                      child: const Text('Konfirmasi Laporan & Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(dynamic item, int index) {
    bool isBermasalah = _kondisiItems[index] != 'Normal';

    // Hitung keterlambatan otomatis dari tanggal_selesai per item
    final dynamic tglSelesaiRaw = item['tanggal_selesai'];
    int hariTerlambat = 0;
    bool isTerlambat = false;
    String tglSelesaiStr = '';
    if (tglSelesaiRaw != null) {
      try {
        final DateTime tglSelesai = DateTime.parse(tglSelesaiRaw.toString());
        tglSelesaiStr = '${tglSelesai.day}/${tglSelesai.month}/${tglSelesai.year}';
        final DateTime sekarang = DateTime.now();
        // Menghitung selisih hari berdasarkan tanggal kalender (mengabaikan komponen waktu)
        final DateTime tglSelesaiHariSaja = DateTime(tglSelesai.year, tglSelesai.month, tglSelesai.day);
        final DateTime sekarangHariSaja = DateTime(sekarang.year, sekarang.month, sekarang.day);
        if (sekarangHariSaja.isAfter(tglSelesaiHariSaja)) {
          hariTerlambat = sekarangHariSaja.difference(tglSelesaiHariSaja).inDays;
          isTerlambat = true;
        }
      } catch (_) {}
    }

    // Hitung estimasi denda keterlambatan (hanya untuk info, backend yang simpan)
    double tHarga = double.tryParse(item['total_harga'].toString()) ?? 0;
    int lamaSewa = int.tryParse(item['lama_sewa'].toString()) ?? 1;
    if (lamaSewa < 1) lamaSewa = 1;
    int estimasiDendaTerlambat = isTerlambat ? ((tHarga / lamaSewa) * hariTerlambat).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBermasalah ? AppColors.error.withOpacity(0.5) : AppColors.accentLight.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item['url_foto'] != null
                      ? Image.network(item['url_foto'], width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width:72, height:72, color: AppColors.background))
                      : Container(width: 72, height: 72, color: AppColors.background, child: const Icon(Icons.image, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['nama_barang'] ?? 'Barang', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Varian: ${item['nama_varian']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Jumlah: ${item['jumlah_pesan']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),

            // BANNER KETERLAMBATAN OTOMATIS (sistem yang mendeteksi, bukan pilihan admin)
            if (isTerlambat) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠ Terlambat $hariTerlambat Hari — Denda: Rp ${estimasiDendaTerlambat.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                          ),
                          if (tglSelesaiStr.isNotEmpty)
                            Text(
                              'Jadwal selesai: $tglSelesaiStr | Denda dihitung otomatis oleh sistem',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: AppColors.background, thickness: 2),
            ),
            const Text('Kondisi Pengembalian:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: isBermasalah ? AppColors.error : AppColors.accentLight),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.background,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _kondisiItems[index],
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  items: _kondisiOptions.map((k) => DropdownMenuItem(
                    value: k,
                    child: Text(k, style: TextStyle(color: k == 'Normal' ? AppColors.textPrimary : AppColors.error)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _kondisiItems[index] = val);
                  },
                ),
              ),
            ),
            if (isBermasalah) ...[
              const SizedBox(height: 20),
              const Text('Denda Kerusakan/Kehilangan (Rp):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _dendaControllers[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Keterangan Tambahan:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _keteranganControllers[index],
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Misal: Tenda sobek di bagian pintu',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Bukti Foto Kondisi:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickImage(index),
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.accentLight, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _fotoItems[index] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_fotoItems[index]!.path, fit: BoxFit.cover)
                              : Image.file(File(_fotoItems[index]!.path), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: AppColors.secondary, size: 36),
                            SizedBox(height: 12),
                            Text('Ketuk untuk ambil foto', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
