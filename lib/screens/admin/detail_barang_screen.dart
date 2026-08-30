import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';



class DetailBarangScreen extends StatefulWidget {
  final Map<String, dynamic> barang;

  const DetailBarangScreen({super.key, required this.barang});

  @override
  _DetailBarangScreenState createState() => _DetailBarangScreenState();
}

class _DetailBarangScreenState extends State<DetailBarangScreen> {
  bool _isLoading = false;

  // Controller untuk Form Tambah Varian (Alat Admin)
  final TextEditingController _namaVarianController = TextEditingController();
  final TextEditingController _hargaVarianController = TextEditingController();
  final TextEditingController _kapasitasVarianController = TextEditingController();
  final TextEditingController _stokVarianController = TextEditingController();

  // State diskon aktif
  Map<String, dynamic>? _diskonAktif;

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    // Inisialisasi dari data barang yang sudah ada
    final diskonRaw = widget.barang['diskon'];
    final persen = widget.barang['persen_diskon'] ?? 0;
    if (diskonRaw != null && (persen as num) > 0) {
      _diskonAktif = Map<String, dynamic>.from(diskonRaw);
    }
  }

  // --- FUNGSI REFRESH DATA VARIAN LOKAL SETELAH EDIT/HAPUS/TAMBAH ---
  Future<void> _refreshVarianLokal() async {
    try {
      final response = await http.get(
          Uri.parse('$baseUrl/barang/${widget.barang['id_barang']}/varian'));
      if (response.statusCode == 200) {
        setState(() {
          widget.barang['daftar_varian'] = jsonDecode(response.body);
          int totalStok = 0;
          for (var v in widget.barang['daftar_varian']) {
            totalStok += int.tryParse(v['stok'].toString()) ?? 0;
          }
          widget.barang['stok'] = totalStok;
        });
      }
    } catch (e) {
      print("Error refresh varian: $e");
    }
  }

  // --- FUNGSI ADMIN: MENGIRIM VARIAN BARU KE DATABASE ---
  Future<void> _tambahVarianSusulan() async {
    if (_namaVarianController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/barang/${widget.barang['id_barang']}/varian'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'nama_varian': _namaVarianController.text,
          'harga_sewa': _hargaVarianController.text,
          'kapasitas': _kapasitasVarianController.text,
          'stok': _stokVarianController.text,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Varian baru berhasil ditambahkan!')));
        await _refreshVarianLokal();
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI ADMIN: UPDATE VARIAN (GANTI STOK/HARGA) ---
  Future<void> _prosesUpdateVarian(String idVarian, String nama, String harga,
      String kap, String stok) async {
    setState(() => _isLoading = true);
    final String url = '$baseUrl/barang/varian/$idVarian';
    try {
      final response = await http.put(Uri.parse(url),
          body: {'nama_varian': nama, 'harga_sewa': harga, 'kapasitas': kap, 'stok': stok});
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Varian berhasil diupdate!'),
            backgroundColor: AppColors.success));
        await _refreshVarianLokal();
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI ADMIN: HAPUS VARIAN BESERTA STOKNYA ---
  Future<void> _prosesHapusVarian(String idVarian) async {
    setState(() => _isLoading = true);
    final String url = '$baseUrl/barang/varian/$idVarian';
    try {
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Varian berhasil dihapus!'),
            backgroundColor: AppColors.success));
        await _refreshVarianLokal();
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI ADMIN: MUNCULKAN POP-UP FORM TAMBAH VARIAN ---
  void _tampilkanModalTambahVarian() {
    _namaVarianController.clear();
    _hargaVarianController.clear();
    _kapasitasVarianController.clear();
    _stokVarianController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Varian Baru',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _namaVarianController,
                  decoration: const InputDecoration(
                      labelText: 'Kode/Nama Varian (Misal: A3)')),
              TextField(
                  controller: _hargaVarianController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga Sewa/Hari', prefixText: 'Rp ')),
              TextField(
                  controller: _kapasitasVarianController,
                  decoration:
                      const InputDecoration(labelText: 'Kapasitas/Ukuran (Opsional)')),
              TextField(
                  controller: _stokVarianController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Jumlah Stok Baru')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              _tambahVarianSusulan();
            },
            child:
                const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI ADMIN: MUNCULKAN DIALOG EDIT & HAPUS VARIAN ---
  void _tampilkanDialogEditVarian(Map<String, dynamic> varian) {
    TextEditingController namaCtrl =
        TextEditingController(text: varian['nama_varian']);
    TextEditingController hargaCtrl =
        TextEditingController(text: varian['harga_sewa'].toString());
    TextEditingController kapasitasCtrl =
        TextEditingController(text: varian['kapasitas'].toString());
    TextEditingController stokCtrl =
        TextEditingController(text: varian['stok'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit atau Hapus Varian',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: namaCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Kode/Nama Varian')),
              TextField(
                  controller: hargaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga Sewa/Hari', prefixText: 'Rp ')),
              TextField(
                  controller: kapasitasCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Kapasitas/Ukuran (Opsional)')),
              TextField(
                  controller: stokCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Ubah Stok')),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // TOMBOL HAPUS (KIRI)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.delete),
            label: const Text('Hapus'),
            onPressed: () {
              Navigator.pop(context);
              _prosesHapusVarian(varian['id_varian'].toString());
            },
          ),
          // TOMBOL SIMPAN (KANAN)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              _prosesUpdateVarian(varian['id_varian'].toString(),
                  namaCtrl.text, hargaCtrl.text, kapasitasCtrl.text, stokCtrl.text);
            },
            child:
                const Text('Simpan', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- FUNGSI ADMIN: SET DISKON ---
  Future<void> _tampilkanFormDiskon() async {
    final persenCtrl = TextEditingController(
        text: _diskonAktif != null ? _diskonAktif!['persen'].toString() : '');
    DateTime? mulai;
    DateTime? akhir;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Set Diskon Barang',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: persenCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Persentase Diskon (%)',
                    hintText: 'Contoh: 20',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Pilih Waktu Mulai
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today,
                      color: AppColors.primary),
                  title: const Text('Waktu Mulai Diskon'),
                  subtitle: Text(
                      mulai != null
                          ? '${mulai!.day}/${mulai!.month}/${mulai!.year} ${mulai!.hour}:${mulai!.minute.toString().padLeft(2, '0')}'
                          : 'Belum dipilih',
                      style: TextStyle(
                          color:
                              mulai != null ? Colors.black87 : Colors.grey)),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d == null) return;
                    final t = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    setModal(() => mulai =
                        DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                ),
                const Divider(height: 1),
                // Pilih Waktu Akhir
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.event_busy, color: AppColors.error),
                  title: const Text('Waktu Berakhir Diskon'),
                  subtitle: Text(
                      akhir != null
                          ? '${akhir!.day}/${akhir!.month}/${akhir!.year} ${akhir!.hour}:${akhir!.minute.toString().padLeft(2, '0')}'
                          : 'Belum dipilih',
                      style: TextStyle(
                          color:
                              akhir != null ? Colors.black87 : Colors.grey)),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: (mulai ?? DateTime.now())
                            .add(const Duration(hours: 1)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d == null) return;
                    final t = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.now());
                    if (t == null) return;
                    setModal(() => akhir =
                        DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50)),
                  onPressed: () async {
                    if (persenCtrl.text.isEmpty ||
                        mulai == null ||
                        akhir == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Isi semua field diskon!'),
                              backgroundColor: AppColors.error));
                      return;
                    }
                    Navigator.pop(ctx);
                    await _simpanDiskon(
                        persen: int.tryParse(persenCtrl.text) ?? 0,
                        mulai: mulai!,
                        akhir: akhir!);
                  },
                  child: const Text('Simpan Diskon',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _simpanDiskon(
      {required int persen,
      required DateTime mulai,
      required DateTime akhir}) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/diskon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_barang': widget.barang['id_barang'],
          'persen': persen,
          'mulai': mulai.toIso8601String(),
          'akhir': akhir.toIso8601String(),
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _diskonAktif = data['data'] != null
            ? Map<String, dynamic>.from(data['data'])
            : null);
        // Update juga nilai di widget.barang agar harga coret langsung muncul
        if (_diskonAktif != null) {
          final hargaAsli = int.tryParse(widget.barang['harga_sewa'].toString()) ?? 0;
          widget.barang['persen_diskon'] = persen;
          widget.barang['harga_setelah_diskon'] =
              hargaAsli - (hargaAsli * persen / 100).round();
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Diskon berhasil disimpan!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _hapusDiskon() async {
    if (_diskonAktif == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/admin/diskon/${_diskonAktif!['id']}'));
      if (response.statusCode == 200) {
        setState(() {
          _diskonAktif = null;
          widget.barang['persen_diskon'] = 0;
          widget.barang['harga_setelah_diskon'] = widget.barang['harga_sewa'];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Diskon berhasil dihapus!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI CUSTOMER: MUNCULKAN FRAME PEMESANAN (LALU KE CHECKOUT) ---
  void _tampilkanModalPemesanan() {
    List<dynamic> daftarVarian = widget.barang['daftar_varian'] ?? [];
    int selectedVarianIndex = -1;
    int lamaSewa = 1;
    int jumlahPesan = 1;
    DateTime? tanggalMulai;
    DateTime? tanggalSelesai;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          int totalBayar = 0;
          if (selectedVarianIndex != -1 && daftarVarian.isNotEmpty) {
            int hargaVarian = int.tryParse(
                    daftarVarian[selectedVarianIndex]['harga_sewa'].toString()) ??
                0;
            // Terapkan diskon jika ada
            final int persen = widget.barang['persen_diskon'] ?? 0;
            if (persen > 0) {
              hargaVarian = hargaVarian - (hargaVarian * persen / 100).round();
            }
            totalBayar = hargaVarian * jumlahPesan * lamaSewa;
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.70,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pilih Varian & Jumlah',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),

                // LIST VARIAN
                const Text('Daftar Varian Tersedia',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: daftarVarian.asMap().entries.map((entry) {
                        int index = entry.key;
                        var varian = entry.value;
                        int stok =
                            int.tryParse(varian['stok'].toString()) ?? 0;
                        bool isHabis = stok <= 0;
                        bool isSelected = selectedVarianIndex == index;
                        int hargaVarian =
                            int.tryParse(varian['harga_sewa'].toString()) ?? 0;
                        final int persen =
                            widget.barang['persen_diskon'] ?? 0;
                        final int hargaDiskon = persen > 0
                            ? hargaVarian - (hargaVarian * persen / 100).round()
                            : hargaVarian;

                        return GestureDetector(
                          onTap: isHabis
                              ? null
                              : () {
                                  setModalState(() {
                                    selectedVarianIndex = index;
                                    if (jumlahPesan > stok) jumlahPesan = stok;
                                  });
                                },
                          child: Container(
                            width: (MediaQuery.of(context).size.width / 2) - 22,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isHabis
                                  ? Colors.grey[200]
                                  : (isSelected
                                      ? AppColors.secondary.withOpacity(0.1)
                                      : Colors.white),
                              border: Border.all(
                                  color: isHabis
                                      ? Colors.grey[400]!
                                      : (isSelected
                                          ? AppColors.primary
                                          : Colors.grey[300]!),
                                  width: isSelected ? 2 : 1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                        child: Text(
                                            varian['nama_varian'] ?? '-',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isHabis
                                                    ? Colors.grey
                                                    : Colors.black),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)),
                                    if (isSelected)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.primary, size: 18)
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Kapasitas: ${varian['kapasitas']}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isHabis
                                            ? Colors.grey
                                            : Colors.black87)),
                                Text('Sisa Stok: $stok',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isHabis
                                            ? AppColors.error
                                            : AppColors.success)),
                                const SizedBox(height: 6),
                                if (persen > 0) ...[
                                  Text('Rp ${formatRupiah(hargaVarian)}/hr',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          decoration:
                                              TextDecoration.lineThrough)),
                                  Text('Rp ${formatRupiah(hargaDiskon)}/hr',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isHabis
                                              ? Colors.grey
                                              : AppColors.error)),
                                ] else
                                  Text('Rp ${formatRupiah(hargaVarian)}/hr',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isHabis
                                              ? Colors.grey
                                              : AppColors.error)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(),

                // JUMLAH PESANAN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jumlah Pesan (Unit)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.primary),
                            onPressed: jumlahPesan > 1
                                ? () => setModalState(() => jumlahPesan--)
                                : null),
                        Text('$jumlahPesan',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppColors.primary),
                          onPressed: () {
                            if (selectedVarianIndex == -1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Pilih varian dulu!')));
                              return;
                            }
                            int stokVarian = int.tryParse(daftarVarian[
                                            selectedVarianIndex]['stok']
                                        .toString()) ??
                                0;
                            if (jumlahPesan < stokVarian) {
                              setModalState(() => jumlahPesan++);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Pesanan mencapai batas maksimum stok!')));
                            }
                          },
                        ),
                      ],
                    )
                  ],
                ),

                // TANGGAL SEWA (menggantikan Lama Sewa manual)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tanggal Sewa',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(tanggalMulai != null
                          ? '${tanggalMulai!.day}/${tanggalMulai!.month} - ${tanggalSelesai!.day}/${tanggalSelesai!.month} ($lamaSewa hr)'
                          : 'Pilih Tanggal'),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          helpText: 'Pilih Tanggal Sewa',
                          saveText: 'PILIH',
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() {
                            tanggalMulai = picked.start;
                            tanggalSelesai = picked.end;
                            lamaSewa = picked.end.difference(picked.start).inDays + 1;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // TOTAL BAYAR & TOMBOL CHECKOUT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Bayar',
                            style: TextStyle(color: Colors.grey)),
                        Text('Rp ${formatRupiah(totalBayar)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: (selectedVarianIndex != -1 && tanggalMulai != null)
                              ? AppColors.primary
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: (selectedVarianIndex != -1 && tanggalMulai != null)
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memesan barang.')));
                              return;
                            }
                          : null,
                      child: const Text('Lanjut Pembayaran',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> semuaFoto = widget.barang['semua_foto'] ?? [];
    int totalStokSemuaVarian =
        int.tryParse(widget.barang['stok'].toString()) ?? 0;
    List<dynamic> daftarVarian = widget.barang['daftar_varian'] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Produk',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SLIDER FOTO
                      Container(
                        height: 300,
                        color: Colors.white,
                        child: semuaFoto.isNotEmpty
                            ? PageView.builder(
                                itemCount: semuaFoto.length,
                                itemBuilder: (context, index) =>
                                    Image.network(semuaFoto[index],
                                        fit: BoxFit.cover),
                              )
                            : const Center(
                                child: Icon(Icons.image,
                                    size: 100, color: Colors.grey)),
                      ),

                      // INFO UTAMA
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Harga dengan info diskon
                            if (_diskonAktif != null) ...[
                              Text(
                                'Mulai Rp ${formatRupiah(widget.barang['harga_sewa'])}/hari',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Mulai Rp ${formatRupiah(widget.barang['harga_setelah_diskon'])}/hari',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.secondary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: Text(
                                      '-${_diskonAktif!['persen']}%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                'Mulai Rp ${formatRupiah(widget.barang['harga_sewa'])}/hari',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.secondary),
                              ),
                            const SizedBox(height: 12),
                            Text(widget.barang['nama_barang'] ?? 'Tanpa Nama',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accentLight.withOpacity(0.5))
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                      'Total Semua Stok: $totalStokSemuaVarian unit',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // DESKRIPSI BARANG
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Deskripsi Produk',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16, color: AppColors.textPrimary)),
                            const Divider(height: 24, color: AppColors.background),
                            Text(
                                widget.barang['deskripsi'] ??
                                    'Tidak ada deskripsi',
                                style: const TextStyle(
                                    fontSize: 14, height: 1.6, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // MANAJEMEN DISKON (Alat Admin) DIHAPUS - Dipindah ke Profil Admin
                      const SizedBox(height: 10),

                      // AREA ALAT ADMIN (KELOLA VARIAN)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Alat Admin (Daftar Varian)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary, fontSize: 15)),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.secondary,
                                    side: const BorderSide(color: AppColors.secondary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                  ),
                                  onPressed: _tampilkanModalTambahVarian,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Tambah Varian', style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),

                            // DAFTAR VARIAN BISA DIKLIK UNTUK EDIT/HAPUS
                            ...daftarVarian.map<Widget>((varian) {
                              return InkWell(
                                onTap: () =>
                                    _tampilkanDialogEditVarian(varian),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.accentLight.withOpacity(0.5))
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    title: Text(varian['nama_varian'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                    subtitle: Text(
                                        'Harga: Rp ${formatRupiah(varian['harga_sewa'])}\nKapasitas: ${varian['kapasitas']}', style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit,
                                            size: 20,
                                            color: AppColors.secondary),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            shape: BoxShape.circle
                                          ),
                                          child: Text('${varian['stok']}',
                                              style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // TOMBOL PESAN MENGAMBANG DI BAWAH
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, -4))
                        ]),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: InkWell(
                              onTap: () {},
                              child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_outlined,
                                        color: AppColors.secondary),
                                    SizedBox(height: 2),
                                    Text('Chat',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))
                                  ])),
                        ),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: totalStokSemuaVarian > 0
                                ? _tampilkanModalPemesanan
                                : null,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: totalStokSemuaVarian > 0
                                    ? AppColors.primaryGradient
                                    : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                              ),
                              child: Text(
                                  totalStokSemuaVarian > 0
                                      ? 'Pesan Sekarang'
                                      : 'Stok Habis',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.5)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
