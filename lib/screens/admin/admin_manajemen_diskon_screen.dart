import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/my_http.dart' as http;
import '../../sesi_user.dart';

class AdminManajemenDiskonScreen extends StatefulWidget {
  const AdminManajemenDiskonScreen({super.key});

  @override
  State<AdminManajemenDiskonScreen> createState() => _AdminManajemenDiskonScreenState();
}

class _AdminManajemenDiskonScreenState extends State<AdminManajemenDiskonScreen> {
  List<dynamic> _daftarDiskon = [];
  List<dynamic> _daftarBarang = [];
  bool _isLoading = true;

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDataSemua();
  }

  Future<void> _ambilDataSemua() async {
    setState(() => _isLoading = true);
    try {
      final resBarang = await http.get(Uri.parse('$baseUrl/barang'));
      if (resBarang.statusCode == 200) {
        _daftarBarang = jsonDecode(resBarang.body);
      }

      final resDiskon = await http.get(Uri.parse('$baseUrl/admin/diskon'));
      if (resDiskon.statusCode == 200) {
        _daftarDiskon = jsonDecode(resDiskon.body);
      }
    } catch (e) {
      debugPrint('Error ambil data diskon: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _hapusDiskon(int id) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Diskon?'),
        content: const Text('Hapus diskon ini permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;

    final res = await http.delete(Uri.parse('$baseUrl/admin/diskon/$id'));
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diskon dihapus!'), backgroundColor: AppColors.success));
      _ambilDataSemua();
    }
  }

  void _tampilkanFormDiskon() {
    final persenCtrl = TextEditingController();
    String? idBarangTerpilih;
    String mulaiTgl = '';
    String mulaiJam = '';
    String akhirTgl = '';
    String akhirJam = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> pilihTanggal(bool isMulai) async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setModalState(() {
                final dateStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                if (isMulai) mulaiTgl = dateStr;
                else akhirTgl = dateStr;
              });
            }
          }

          Future<void> pilihJam(bool isMulai) async {
            // Gunakan CupertinoDatePicker mode waktu untuk tampilan iOS (roda/geser atas bawah)
            final TimeOfDay? picked = await showModalBottomSheet<TimeOfDay>(
              context: context,
              builder: (BuildContext builder) {
                TimeOfDay tempTime = TimeOfDay.now();
                return Container(
                  height: 250,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                          TextButton(onPressed: () => Navigator.pop(context, tempTime), child: const Text('Selesai')),
                        ],
                      ),
                      Expanded(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          use24hFormat: true,
                          initialDateTime: DateTime.now(),
                          onDateTimeChanged: (DateTime newDateTime) {
                            tempTime = TimeOfDay.fromDateTime(newDateTime);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

            if (picked != null) {
              setModalState(() {
                final jam24 = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                if (isMulai) mulaiJam = jam24;
                else akhirJam = jam24;
              });
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Set Diskon Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.surface, thickness: 2),
                  const SizedBox(height: 16),
                  
                  // PILIH BARANG
                  const Text('Pilih Barang', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    value: idBarangTerpilih,
                    hint: const Text('Pilih barang yang akan didiskon'),
                    items: _daftarBarang.map<DropdownMenuItem<String>>((barang) {
                      return DropdownMenuItem<String>(
                        value: barang['id_barang'].toString(),
                        child: Text(
                          barang['nama_barang'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => idBarangTerpilih = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: persenCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Persentase Diskon (Contoh: 20 untuk 20%)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      suffixText: '%',
                      filled: true,
                      fillColor: AppColors.surface
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Waktu Mulai', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => pilihTanggal(true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(mulaiTgl.isEmpty ? 'Pilih Tanggal' : mulaiTgl, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => pilihJam(true),
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(mulaiJam.isEmpty ? 'Pilih Jam' : mulaiJam, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Waktu Berakhir', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => pilihTanggal(false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(akhirTgl.isEmpty ? 'Pilih Tanggal' : akhirTgl, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => pilihJam(false),
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(akhirJam.isEmpty ? 'Pilih Jam' : akhirJam, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () async {
                        if (idBarangTerpilih == null || persenCtrl.text.isEmpty || mulaiTgl.isEmpty || mulaiJam.isEmpty || akhirTgl.isEmpty || akhirJam.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field harus diisi!'), backgroundColor: AppColors.error));
                          return;
                        }

                      // Jam sudah dalam format 24h (HH:MM)
                      final mulai = '$mulaiTgl $mulaiJam:00';
                      final akhir = '$akhirTgl $akhirJam:00';

                      Navigator.pop(ctx);
                      
                      try {
                        final res = await http.post(
                          Uri.parse('$baseUrl/admin/diskon'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer ${SesiUser.token}',
                          },
                          body: jsonEncode({
                            'id_barang': idBarangTerpilih,
                            'persen': int.parse(persenCtrl.text),
                            'mulai': mulai,
                            'akhir': akhir,
                          }),
                        );
                        if (res.statusCode == 200 || res.statusCode == 201) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diskon tersimpan!'), backgroundColor: AppColors.success));
                          _ambilDataSemua();
                        } else {
                          final errBody = jsonDecode(res.body);
                          final pesan = errBody['message'] ?? errBody['pesan'] ?? 'Gagal menyimpan diskon.';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: AppColors.error));
                        }
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                      }
                    },
                    child: const Text('Simpan Diskon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
                ],
              ),
            ),
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manajemen Diskon', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30)
        ),
        child: FloatingActionButton.extended(
          onPressed: _tampilkanFormDiskon,
          backgroundColor: Colors.transparent,
          elevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Tambah Diskon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _daftarDiskon.isEmpty
              ? const Center(child: Text('Belum ada riwayat diskon.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _daftarDiskon.length,
                  itemBuilder: (ctx, idx) {
                    final diskon = _daftarDiskon[idx];
                    final diskonSeb = idx > 0 ? _daftarDiskon[idx - 1] : null;
                    
                    final String tglDibuat = (diskon['created_at'] ?? '').toString().length >= 10 ? (diskon['created_at'] ?? '').toString().substring(0, 10) : '';
                    final String tglDibuatSeb = (diskonSeb?['created_at'] ?? '').toString().length >= 10 ? (diskonSeb?['created_at'] ?? '').toString().substring(0, 10) : '';
                    
                    final bool tampilTgl = tglDibuat != tglDibuatSeb && tglDibuat.isNotEmpty;

                    final DateTime waktuAkhir = DateTime.tryParse(diskon['akhir'].toString()) ?? DateTime.now();
                    final bool isExpired = DateTime.now().isAfter(waktuAkhir);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (tampilTgl)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.secondary.withOpacity(0.3))
                                ),
                                child: Text(tglDibuat, style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isExpired ? AppColors.background : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isExpired ? AppColors.accentLight : AppColors.secondary.withOpacity(0.3)),
                            boxShadow: [if (!isExpired) BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Detail Diskon', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Barang: ${diskon['nama_barang'] ?? 'Tidak diketahui'}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      const SizedBox(height: 8),
                                      Text('Diskon: ${diskon['persen']}%', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 8),
                                      Text('Mulai: ${(diskon['mulai'] as String?)?.replaceFirst(' ', ', ') ?? '-'}', style: const TextStyle(color: AppColors.textSecondary)),
                                      Text('Berakhir: ${(diskon['akhir'] as String?)?.replaceFirst(' ', ', ') ?? '-'}', style: const TextStyle(color: AppColors.textSecondary)),
                                      const SizedBox(height: 12),
                                      Text('Dibuat Pada: ${diskon['created_at'] ?? '-'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup', style: TextStyle(color: AppColors.primary)))
                                  ],
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isExpired ? AppColors.accentLight.withOpacity(0.3) : AppColors.secondary.withOpacity(0.1),
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(Icons.local_offer, color: isExpired ? AppColors.textSecondary.withOpacity(0.5) : AppColors.secondary)
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text('${diskon['nama_barang'] ?? 'Barang'} (${diskon['persen']}%)', 
                                        style: TextStyle(
                                          decoration: isExpired ? TextDecoration.lineThrough : null,
                                          color: isExpired ? AppColors.textSecondary : AppColors.textPrimary,
                                          fontWeight: FontWeight.w800
                                        ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                    if (isExpired) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Berakhir', style: TextStyle(color: Color(0xFF757575), fontSize: 10, fontWeight: FontWeight.w600)),
                                      )
                                    ]
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('${diskon['mulai']} s/d ${diskon['akhir']}',
                                    style: TextStyle(color: isExpired ? const Color(0xFF9E9E9E) : const Color(0xFF757575), fontSize: 11)
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete_outline, color: isExpired ? const Color(0xFF9E9E9E).withOpacity(0.5) : const Color(0xFFD32F2F)),
                                  onPressed: () => _hapusDiskon(diskon['id']),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
