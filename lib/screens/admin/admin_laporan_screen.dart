import 'package:flutter/material.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/utils/format_currency.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminLaporanScreen extends StatefulWidget {
  const AdminLaporanScreen({super.key});

  @override
  State<AdminLaporanScreen> createState() => _AdminLaporanScreenState();
}

class _AdminLaporanScreenState extends State<AdminLaporanScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> semuaTransaksi = [];
  
  DateTime _selectedDate = DateTime.now();
  bool _isYearly = false;

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilTransaksi();
  }

  Future<void> _ambilTransaksi() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/transaksi'));
      if (response.statusCode == 200) {
        setState(() {
          semuaTransaksi = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching transaksi: $e");
    }
    setState(() => _isLoading = false);
  }

  // Helper untuk mendapatkan daftar bulan
  final List<String> _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  void _pilihPeriode() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Pilih Periode Laporan'),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Rekap Tahunan'),
                      value: _isYearly,
                      onChanged: (val) {
                        setStateDialog(() {
                          _isYearly = val;
                        });
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: _isYearly
                          ? ListView.builder(
                              itemCount: 10,
                              itemBuilder: (context, index) {
                                int year = DateTime.now().year - 5 + index;
                                return ListTile(
                                  title: Text('Tahun $year'),
                                  onTap: () {
                                    setState(() {
                                      _isYearly = true;
                                      _selectedDate = DateTime(year, 1);
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: 12,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text('${_namaBulan[index]} ${_selectedDate.year}'),
                                  onTap: () {
                                    setState(() {
                                      _isYearly = false;
                                      _selectedDate = DateTime(_selectedDate.year, index + 1);
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter berdasarkan periode
    List<Map<String, dynamic>> transaksiTerfilter = semuaTransaksi.where((t) {
      if (t['created_at'] == null) return false;
      DateTime tgl = DateTime.parse(t['created_at']);
      if (_isYearly) {
        return tgl.year == _selectedDate.year;
      }
      return tgl.year == _selectedDate.year && tgl.month == _selectedDate.month;
    }).toList();

    // 2. Hitung Metrik
    int totalPendapatanSewa = 0;
    int totalDenda = 0;
    int totalSelesai = 0;
    int totalGagal = 0;

    // Untuk Top 5 Barang
    Map<String, int> hitungBarang = {};

    for (var t in transaksiTerfilter) {
      String status = (t['status_transaksi'] ?? '').toLowerCase();
      
      if (status == 'selesai') {
        totalSelesai++;
        
        // Pemasukan sewa = total harga transaksi
        totalPendapatanSewa += int.tryParse(t['total_harga'].toString()) ?? 0;
        
        // Pemasukan denda = total denda keterlambatan + denda kerusakan
        totalDenda += int.tryParse(t['denda_keterlambatan'].toString()) ?? 0;
        totalDenda += int.tryParse(t['denda_kerusakan'].toString()) ?? 0;
        
        // Hitung frekuensi sewa barang
        List detail = t['detail_pesanan'] ?? [];
        for (var item in detail) {
          String nama = item['nama_barang'] ?? 'Unknown';
          int jumlah = int.tryParse(item['jumlah_pesan'].toString()) ?? 0;
          if (hitungBarang.containsKey(nama)) {
            hitungBarang[nama] = hitungBarang[nama]! + jumlah;
          } else {
            hitungBarang[nama] = jumlah;
          }
        }
      } else if (status == 'ditolak') {
        totalGagal++;
      }
    }

    int grandTotal = totalPendapatanSewa + totalDenda;

    // Sort Top 5
    var sortedBarang = hitungBarang.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5 = sortedBarang.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan & Rekapitulasi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Cetak PDF'),
            onPressed: () => _cetakLaporanPdf(transaksiTerfilter, grandTotal, totalPendapatanSewa, totalDenda, top5),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- FILTER PERIODE ---
                  InkWell(
                    onTap: _pilihPeriode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.calendar_month, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                                  Text(_isYearly ? 'Periode: Tahun ${_selectedDate.year}' : 'Periode: ${_namaBulan[_selectedDate.month - 1]} ${_selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 16)),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppColors.secondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- KARTU GRAND TOTAL ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]
                    ),
                    child: Column(
                      children: [
                        Text('Total Pendapatan (Sewa + Denda)', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text('Rp ${formatRupiah(grandTotal)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- METRIK DETAIL ---
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Pendapatan Denda', 'Rp ${formatRupiah(totalDenda)}', Icons.money_off, AppColors.accent)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Trx Selesai', '$totalSelesai', Icons.check_circle, AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Trx Ditolak', '$totalGagal', Icons.cancel, AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- TOP 5 BARANG ---
                  const Text('5 Barang Terlaris', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (top5.isEmpty) const Text('Belum ada data barang disewa pada periode ini.', style: TextStyle(color: AppColors.textSecondary))
                  else Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: top5.asMap().entries.map((entry) {
                          int index = entry.key;
                          var item = entry.value;
                          return ListTile(
                            leading: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
                              alignment: Alignment.center,
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                            title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            trailing: Text('${item.value} disewa', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- RINCIAN TRANSAKSI ---
                  const Text('Rincian Transaksi Selesai', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  ...transaksiTerfilter.where((t) => (t['status_transaksi'] ?? '').toLowerCase() == 'selesai').map((t) {
                    List detail = t['detail_pesanan'] ?? [];
                    int sewa = int.tryParse(t['total_harga'].toString()) ?? 0;
                    int dendaTelat = int.tryParse(t['denda_keterlambatan'].toString()) ?? 0;
                    int dendaRusak = int.tryParse(t['denda_kerusakan'].toString()) ?? 0;
                    
                    DateTime tglMulai = t['tanggal_mulai'] != null ? DateTime.tryParse(t['tanggal_mulai'].toString()) ?? DateTime.now() : (t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) ?? DateTime.now() : DateTime.now());
                    DateTime tglSelesai = t['tanggal_selesai'] != null ? DateTime.tryParse(t['tanggal_selesai'].toString()) ?? DateTime.now() : (t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) ?? DateTime.now() : DateTime.now());
                    String formatTgl(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
                    String tglSewa = '${formatTgl(tglMulai)} - ${formatTgl(tglSelesai)}';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tglSewa, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800)),
                                Text('ID: ${t['id_transaksi']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 24, color: AppColors.background),
                            Text('Oleh: ${t['nama_pemesan'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            
                            // Looping items
                            ...detail.map((item) {
                              String kondisi = item['kondisi_pengembalian'] ?? 'Normal';
                              String ket = item['keterangan_kondisi'] ?? '-';
                              bool adaKendala = kondisi != 'Normal' && kondisi.isNotEmpty;
                              int hrg = int.tryParse(item['harga_satuan_asli'].toString()) ?? 0;
                              int dendaK = int.tryParse(item['denda_kerusakan'].toString()) ?? 0;
                              int dendaT = int.tryParse(item['denda_keterlambatan'].toString()) ?? 0;
                              
                              // Menghitung jumlah hari keterlambatan untuk ditampilkan pada UI
                              DateTime tSelesaiItem = item['tanggal_selesai'] != null ? DateTime.tryParse(item['tanggal_selesai'].toString()) ?? DateTime.now() : DateTime.now();
                              DateTime tKembali = t['tanggal_dikembalikan'] != null ? DateTime.tryParse(t['tanggal_dikembalikan'].toString()) ?? DateTime.now() : DateTime.now();
                              final DateTime tSelesaiHari = DateTime(tSelesaiItem.year, tSelesaiItem.month, tSelesaiItem.day);
                              final DateTime tKembaliHari = DateTime(tKembali.year, tKembali.month, tKembali.day);
                              int hTerlambat = tKembaliHari.difference(tSelesaiHari).inDays;
                              if (hTerlambat < 1) hTerlambat = 1;
                              String periodeTelat = '${formatTgl(tSelesaiItem)} - ${formatTgl(tKembali)} ($hTerlambat Hari)';
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: adaKendala ? AppColors.error.withOpacity(0.4) : (dendaT > 0 ? Colors.orange.withOpacity(0.4) : Colors.transparent))
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text('- ${item['nama_barang']} (${item['jumlah_pesan']} unit)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                                          Text('Rp ${formatRupiah(hrg * (int.tryParse(item['lama_sewa'].toString()) ?? 1))} (${item['lama_sewa'] ?? 1} Hari)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                                        ]
                                      ),
                                      if (dendaT > 0 || adaKendala) const SizedBox(height: 6),
                                      if (dendaT > 0) ...[
                                        Text('Terlambat Pengembalian: $periodeTelat', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text('Denda Keterlambatan: Rp ${formatRupiah(dendaT)}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontStyle: FontStyle.italic)),
                                      ],
                                      if (dendaT > 0 && adaKendala) const SizedBox(height: 6),
                                      if (adaKendala) ...[
                                        Text('Kendala: $kondisi', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text('Ket: $ket', style: const TextStyle(color: AppColors.error, fontSize: 12, fontStyle: FontStyle.italic)),
                                        if (dendaK > 0)
                                          Text('Denda Kerusakan: Rp ${formatRupiah(dendaK)}', style: const TextStyle(color: AppColors.error, fontSize: 12, fontStyle: FontStyle.italic)),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Biaya Sewa:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                Text('Rp ${formatRupiah(sewa)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ],
                            ),
                            if (dendaTelat > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Denda Keterlambatan:', style: TextStyle(fontSize: 13, color: Colors.orange)),
                                  Text('+ Rp ${formatRupiah(dendaTelat)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.orange)),
                                ],
                              ),
                            ],
                            if (dendaRusak > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Denda Kerusakan:', style: TextStyle(fontSize: 13, color: AppColors.error)),
                                  Text('+ Rp ${formatRupiah(dendaRusak)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.error)),
                                ],
                              ),
                            ],
                            if (dendaTelat > 0 || dendaRusak > 0) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Divider(color: AppColors.background),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Denda:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                                  Text('+ Rp ${formatRupiah(dendaTelat + dendaRusak)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.error)),
                                ],
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: AppColors.background, thickness: 2),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pendapatan:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                Text('Rp ${formatRupiah(sewa + dendaTelat + dendaRusak)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  if (transaksiTerfilter.where((t) => (t['status_transaksi'] ?? '').toLowerCase() == 'selesai').isEmpty)
                    const Text('Belum ada transaksi selesai di periode ini.', style: TextStyle(color: Colors.grey)),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentLight.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // --- PDF GENERATION ---
  Future<void> _cetakLaporanPdf(List<Map<String, dynamic>> transaksi, int grandTotal, int pendapatanSewa, int totalDenda, List<MapEntry<String, int>> top5) async {
    final doc = pw.Document();
    
    String namaPeriode = _isYearly ? 'Tahun ${_selectedDate.year}' : '${_namaBulan[_selectedDate.month - 1]} ${_selectedDate.year}';
    
    // Filter transaksi yang selesai saja
    var trxSelesai = transaksi.where((t) => (t['status_transaksi'] ?? '').toLowerCase() == 'selesai').toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // HEADER Laporan
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('CAMPLE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  pw.Text('Laporan Rekapitulasi Penyewaan', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Periode: $namaPeriode', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 20),
                ]
              )
            ),
            
            // RINGKASAN
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8)
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RINGKASAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Pendapatan Sewa'), pw.Text('Rp ${formatRupiah(pendapatanSewa)}'),
                  ]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Pendapatan Denda'), pw.Text('Rp ${formatRupiah(totalDenda)}'),
                  ]),
                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Grand Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
                    pw.Text('Rp ${formatRupiah(grandTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]),
                ]
              )
            ),
            pw.SizedBox(height: 20),

            // TOP 5
            pw.Text('BARANG TERLARIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...top5.map((item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('- ${item.key}'),
                pw.Text('${item.value} Unit'),
              ]
            )).toList(),
            if (top5.isEmpty) pw.Text('Tidak ada data barang disewa.'),
            
            pw.SizedBox(height: 20),

            // RINCIAN TRANSAKSI
            pw.Text('RINCIAN TRANSAKSI SELESAI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...trxSelesai.map((t) {
              List detail = t['detail_pesanan'] ?? [];
              int sewa = int.tryParse(t['total_harga'].toString()) ?? 0;
              int dTelat = int.tryParse(t['denda_keterlambatan'].toString()) ?? 0;
              int dRusak = int.tryParse(t['denda_kerusakan'].toString()) ?? 0;
              
              DateTime tglMulai = t['tanggal_mulai'] != null ? DateTime.tryParse(t['tanggal_mulai'].toString()) ?? DateTime.now() : (t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) ?? DateTime.now() : DateTime.now());
              DateTime tglSelesai = t['tanggal_selesai'] != null ? DateTime.tryParse(t['tanggal_selesai'].toString()) ?? DateTime.now() : (t['created_at'] != null ? DateTime.tryParse(t['created_at'].toString()) ?? DateTime.now() : DateTime.now());
              String formatTgl(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
              String tglStr = '${formatTgl(tglMulai)} - ${formatTgl(tglSelesai)}';
              
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('$tglStr - ID: ${t['id_transaksi']} (${t['nama_pemesan']})', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ]),
                    
                    ...detail.map((item) {
                      String kondisi = item['kondisi_pengembalian'] ?? 'Normal';
                      String ket = item['keterangan_kondisi'] ?? '-';
                      bool adaKendala = kondisi != 'Normal' && kondisi.isNotEmpty;
                      int dendaK = int.tryParse(item['denda_kerusakan'].toString()) ?? 0;
                      int dendaT = int.tryParse(item['denda_keterlambatan'].toString()) ?? 0;
                      
                      DateTime tSelesaiItem = item['tanggal_selesai'] != null ? DateTime.tryParse(item['tanggal_selesai'].toString()) ?? DateTime.now() : DateTime.now();
                      DateTime tKembali = t['tanggal_dikembalikan'] != null ? DateTime.tryParse(t['tanggal_dikembalikan'].toString()) ?? DateTime.now() : DateTime.now();
                      final DateTime tSelesaiHari = DateTime(tSelesaiItem.year, tSelesaiItem.month, tSelesaiItem.day);
                      final DateTime tKembaliHari = DateTime(tKembali.year, tKembali.month, tKembali.day);
                      int hTerlambat = tKembaliHari.difference(tSelesaiHari).inDays;
                      if (hTerlambat < 1) hTerlambat = 1;
                      String periodeTelat = '${formatTgl(tSelesaiItem)} - ${formatTgl(tKembali)} ($hTerlambat Hari)';
                      
                      return pw.Container(
                        padding: const pw.EdgeInsets.only(left: 10, top: 2),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                              pw.Text('- ${item['nama_barang']} (${item['jumlah_pesan']} unit)', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Rp ${formatRupiah((int.tryParse(item['harga_satuan_asli'].toString()) ?? 0) * (int.tryParse(item['lama_sewa'].toString()) ?? 1))} (${item['lama_sewa'] ?? 1} Hari)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                            ]),
                            if (dendaT > 0)
                              pw.Text('  TERLAMBAT: $periodeTelat | Denda: Rp ${formatRupiah(dendaT)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),
                            if (adaKendala)
                              pw.Text('  KENDALA: $kondisi ($ket)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800)),
                            if (dendaK > 0)
                              pw.Text('  DENDA KERUSAKAN: Rp ${formatRupiah(dendaK)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800)),
                          ]
                        )
                      );
                    }).toList(),
                    
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Sewa: Rp ${formatRupiah(sewa)} | Denda: Rp ${formatRupiah(dTelat + dRusak)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Subtotal: Rp ${formatRupiah(sewa + dTelat + dRusak)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ]),
                    pw.Divider(color: PdfColors.grey300),
                  ]
                )
              );
            }).toList(),
          ];
        }
      )
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Laporan_Cample_$namaPeriode',
    );
  }
}
