// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import 'user_main_screen.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:apk_cample166/config/app_config.dart';
import 'dart:convert';

class MenungguPembayaranScreen extends StatefulWidget {
  final String idTransaksi;
  final String snapUrl;
  final DateTime expiredAt;
  final int totalDp;
  final String namaBarang;
  // List nama barang untuk ditampilkan di detail pesanan
  final List<String>? daftarNamaBarang;

  const MenungguPembayaranScreen({
    super.key,
    required this.idTransaksi,
    required this.snapUrl,
    required this.expiredAt,
    required this.totalDp,
    required this.namaBarang,
    this.daftarNamaBarang,
  });

  @override
  State<MenungguPembayaranScreen> createState() => _MenungguPembayaranScreenState();
}

class _MenungguPembayaranScreenState extends State<MenungguPembayaranScreen> {
  late Timer _timer;
  Duration _sisaWaktu = Duration.zero;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _hitungSisaWaktu();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _hitungSisaWaktu());
  }

  void _hitungSisaWaktu() {
    final now = DateTime.now();
    if (now.isAfter(widget.expiredAt)) {
      if (!_isExpired) {
        setState(() {
          _isExpired = true;
          _sisaWaktu = Duration.zero;
        });
      }
      _timer.cancel();
    } else {
      setState(() {
        _sisaWaktu = widget.expiredAt.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _bukaSnapUrl() async {
    final Uri url = Uri.parse(widget.snapUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka halaman pembayaran. Coba salin link secara manual.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool _isSimulasiLoading = false;
  Future<void> _simulasiBayar() async {
    setState(() => _isSimulasiLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/transaksi/${widget.idTransaksi}/simulasi-bayar')
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulasi Pembayaran Berhasil!'), backgroundColor: AppColors.success),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UserMainScreen(initialIndex: 2)),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulasi Gagal: ${response.body}'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
    setState(() => _isSimulasiLoading = false);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Color get _timerColor {
    if (_isExpired) return AppColors.error;
    if (_sisaWaktu.inMinutes < 5) return Colors.orange;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menunggu Pembayaran DP', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false, // Cegah back tanpa sengaja
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // --- TIMER CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _timerColor.withValues(alpha: 0.4)),
                boxShadow: [BoxShadow(color: _timerColor.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Icon(
                    _isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                    size: 52,
                    color: _timerColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isExpired ? 'Waktu Pembayaran Habis' : 'Selesaikan Pembayaran Dalam',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isExpired ? '00:00' : _formatDuration(_sisaWaktu),
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _timerColor, letterSpacing: 2),
                  ),
                  if (!_isExpired)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Menit : Detik',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- INFO PESANAN ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentLight.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                  const Divider(height: 20),
                  _baris('ID Transaksi', widget.idTransaksi),
                  const SizedBox(height: 8),
                  // Tampilkan daftar barang jika ada, fallback ke namaBarang
                  if (widget.daftarNamaBarang != null && widget.daftarNamaBarang!.isNotEmpty)
                    _barisBarang('Barang', widget.daftarNamaBarang!)
                  else
                    _baris('Barang', widget.namaBarang),
                  const SizedBox(height: 8),
                  _baris('Total DP (50%)', 'Rp ${_formatRupiah(widget.totalDp)}', valueColor: AppColors.primary, bold: true),
                  const Divider(height: 20),
                  const Text(
                    '⚠️ Sisa tagihan akan dibayar secara offline di toko saat pengambilan barang.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // --- TOMBOL BAYAR / EXPIRED ---
            if (!_isExpired) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  onPressed: _bukaSnapUrl,
                  child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.cancel_outlined, color: AppColors.error, size: 32),
                    SizedBox(height: 8),
                    Text('Pembayaran kadaluarsa', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Pesanan ini telah otomatis dibatalkan oleh sistem.', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // --- TOMBOL CEK STATUS ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const UserMainScreen(initialIndex: 2)),
                  (route) => false,
                ),
                child: const Text('Lihat Riwayat Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ),

            const SizedBox(height: 16),

            // --- TOMBOL SIMULASI (DEV) ---
            if (!_isExpired)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSimulasiLoading ? null : _simulasiBayar,
                  child: _isSimulasiLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simulasi Bayar Berhasil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'Anda dapat menutup halaman ini. Status pembayaran akan diperbarui otomatis oleh sistem setelah pembayaran berhasil dikonfirmasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _baris(String label, String value, {Color? valueColor, bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // Widget khusus untuk menampilkan daftar barang (multi-baris)
  Widget _barisBarang(String label, List<String> barangList) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: barangList.map((nama) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                nama,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final result = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result.write('.');
      result.write(str[i]);
      count++;
    }
    return result.toString().split('').reversed.join('');
  }
}
