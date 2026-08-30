import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:http_parser/http_parser.dart'; 

// IMPORT SEMUA HALAMAN YANG SUDAH KITA BUAT
import 'detail_barang_screen.dart'; 
import 'admin_inbox_screen.dart'; // <--- IMPORT INBOX ADMIN

// KELAS BANTUAN UNTUK MENGELOLA KOTAK INPUT VARIAN
class VarianBarang {
  TextEditingController kodeController = TextEditingController();
  TextEditingController hargaController = TextEditingController();
  TextEditingController kapasitasController = TextEditingController();
  TextEditingController stokController = TextEditingController();

  void dispose() {
    kodeController.dispose();
    hargaController.dispose();
    kapasitasController.dispose();
    stokController.dispose();
  }
}

class AdminBarangDisewakanScreen extends StatefulWidget {
  const AdminBarangDisewakanScreen({super.key});

  @override
  _AdminBarangDisewakanScreenState createState() => _AdminBarangDisewakanScreenState();
}

class _AdminBarangDisewakanScreenState extends State<AdminBarangDisewakanScreen> {
  List<Map<String, dynamic>> daftarBarang = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();
  

  
  List<XFile> _fotoDipilihList = [];
  String _tipeBarang = 'Tenda';

  final _namaController = TextEditingController();
  final _deskripsiUmumController = TextEditingController();
  
  // List Pengelola Varian
  final List<VarianBarang> _varianControllers = [];

  List<String> kategoriList = ['Semua'];
  List<String> rawKategoriList = ['Tenda', 'Carrier', 'Alat Masak']; // Untuk autocomplete admin
  String kategoriAktif = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ambilKategori();
    _ambilDataDariDatabase();
  }

  Future<void> _ambilKategori() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/kategori'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          rawKategoriList = data.map((e) => e.toString()).toList();
          kategoriList = ['Semua', ...rawKategoriList];
        });
      }
    } catch (e) {
      print("Error Kategori: $e");
    }
  }

  Future<void> _ambilDataDariDatabase() async {
    final String url = '${AppConfig.baseUrl}/barang';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          daftarBarang = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _kirimKeDatabase(Map<String, String> dataBody, List<XFile> fileFotoList) async {
    final String url = '${AppConfig.baseUrl}/barang';
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll({'Accept': 'application/json'});
      request.fields.addAll(dataBody); 

      if (fileFotoList.isNotEmpty) {
        for (var file in fileFotoList) {
          if (kIsWeb) {
            request.files.add(http.MultipartFile.fromBytes('foto[]', await file.readAsBytes(), filename: file.name, contentType: MediaType('image', 'jpeg')));
          } else {
            request.files.add(await http.MultipartFile.fromPath('foto[]', file.path));
          }
        }
      }

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil Simpan Barang & Varian!')));
        _ambilDataDariDatabase();
        _ambilKategori(); // Refresh kategori agar yang baru ditambahkan langsung muncul
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan ke database.')));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI HAPUS BARANG (API) ---
  Future<void> _hapusBarang(String idBarang) async {
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator())
    );

    try {
      final String url = '${AppConfig.baseUrl}/barang/$idBarang';
      final response = await http.delete(Uri.parse(url));
      
      Navigator.pop(context); // Tutup loading

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang berhasil dihapus!'), backgroundColor: AppColors.success));
        _ambilDataDariDatabase(); // Refresh halaman setelah dihapus
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menghapus barang.'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      Navigator.pop(context);
      print("Error Hapus: $e");
    }
  }

  // --- DIALOG KONFIRMASI HAPUS ---
  void _konfirmasiHapus(String idBarang, String namaBarang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Barang?', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: Text('Apakah Anda yakin ingin menghapus "$namaBarang" dan seluruh variannya secara permanen?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                _hapusBarang(idBarang); // Panggil fungsi API Hapus
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _pilihBanyakFoto(StateSetter setModalState) async {
    final List<XFile> pickedImages = await _picker.pickMultiImage(imageQuality: 80);
    if (pickedImages.isNotEmpty) {
      setModalState(() => _fotoDipilihList.addAll(pickedImages));
    }
  }

  void _tampilkanFormTambahBarang() {
    _namaController.clear();
    _deskripsiUmumController.clear();
    _fotoDipilihList.clear(); 
    
    // Reset Varian menjadi 1 form default
    for (var v in _varianControllers) { v.dispose(); }
    _varianControllers.clear();
    _varianControllers.add(VarianBarang());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(10))
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Tambah Barang Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.accentLight, thickness: 1),
                ),
                const Text('Kategori Baru (Ketik / Pilih)', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 5),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return rawKategoriList;
                    return rawKategoriList.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    setModalState(() => _tipeBarang = selection);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    if (controller.text.isEmpty) controller.text = _tipeBarang;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) => _tipeBarang = v, // Bebas ngetik kategori baru!
                      decoration: InputDecoration(
                        hintText: 'Pilih yang ada atau ketik kategori baru',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)),
                        suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.secondary),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                const Text('Foto Barang', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fotoDipilihList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _fotoDipilihList.length) {
                        return GestureDetector(
                          onTap: () => _pilihBanyakFoto(setModalState),
                          child: Container(width: 90, decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.accentLight), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo_outlined, color: AppColors.secondary)),
                        );
                      }
                      return Container(
                        width: 90, margin: const EdgeInsets.only(right: 12),
                        clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accentLight)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            kIsWeb ? Image.network(_fotoDipilihList[index].path, fit: BoxFit.cover) : Image.file(File(_fotoDipilihList[index].path), fit: BoxFit.cover),
                            Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => setModalState(() => _fotoDipilihList.removeAt(index)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                TextField(controller: _namaController, decoration: InputDecoration(labelText: 'Nama Barang (Misal: Tenda Consina)', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
                const SizedBox(height: 16),
                TextField(controller: _deskripsiUmumController, maxLines: 3, decoration: InputDecoration(labelText: 'Deskripsi Detail', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Varian & Stok Barang', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                    TextButton.icon(
                      onPressed: () => setModalState(() => _varianControllers.add(VarianBarang())), 
                      icon: const Icon(Icons.add, color: AppColors.primary), label: const Text('Tambah Varian', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
                
                ..._varianControllers.asMap().entries.map((entry) {
                  int index = entry.key;
                  VarianBarang varian = entry.value;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: TextField(controller: varian.kodeController, decoration: InputDecoration(labelText: 'Kode/Nama Varian (Misal: Magnum 4P)', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                              if (_varianControllers.length > 1) 
                                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => setModalState(() { varian.dispose(); _varianControllers.removeAt(index); })),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: varian.hargaController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga/Hari', prefixText: 'Rp ', labelStyle: const TextStyle(color: AppColors.textSecondary), prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary), filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: varian.kapasitasController, decoration: InputDecoration(labelText: 'Kapasitas', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: varian.stokController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Stok (Jml)', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, 
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 50)
                    ),
                    onPressed: () async {
                      if (_namaController.text.isNotEmpty) {
                        List<Map<String, dynamic>> dataVarian = _varianControllers.map((v) => {
                          'kode': v.kodeController.text,
                          'harga': v.hargaController.text,
                          'kapasitas': v.kapasitasController.text,
                          'stok': v.stokController.text,
                        }).where((v) => v['kode'] != "").toList();

                        Map<String, String> payloadData = {
                          'nama_barang': _namaController.text,
                          'tipe_barang': _tipeBarang,
                          'deskripsi': _deskripsiUmumController.text,
                          'varians': jsonEncode(dataVarian), 
                        };
                        
                        Navigator.pop(context); 
                        await _kirimKeDatabase(payloadData, _fotoDipilihList); 
                      }
                    },
                    child: const Text('Simpan Permanen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0, surfaceTintColor: Colors.transparent,
        title: const Text('Cample Catalog', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppColors.secondary),
            tooltip: 'Pesan Masuk',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminInboxScreen()));
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Container(
            color: AppColors.background, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                border: Border.all(color: AppColors.accentLight.withOpacity(0.5)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Cari Disini...', hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: AppColors.secondary),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                )
              ),
            ),
          ),
          Container(
            color: AppColors.background, height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(), // Memastikan bisa di-scroll
              itemCount: kategoriList.length,
              itemBuilder: (context, index) {
                bool isSelected = kategoriAktif == kategoriList[index];
                return GestureDetector(
                  onTap: () => setState(() => kategoriAktif = kategoriList[index]),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.surface,
                      border: Border.all(color: isSelected ? Colors.transparent : AppColors.accentLight.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                    ),
                    child: Text(kategoriList[index], style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),
          (() {
            List<Map<String, dynamic>> barangDifilter = daftarBarang.where((item) {
              bool matchKategori = kategoriAktif == 'Semua' || item['tipe_barang'] == kategoriAktif;
              bool matchSearch = _searchQuery.isEmpty || 
                  (item['nama_barang'] != null && item['nama_barang'].toString().toLowerCase().contains(_searchQuery.toLowerCase()));
              return matchKategori && matchSearch;
            }).toList();

            if (barangDifilter.isEmpty) return const Expanded(child: Center(child: Text('Katalog Kosong.')));
            return Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- ITEM PERTAMA (CARD BESAR DI ATAS) ---
                    GestureDetector(
                      onTap: () async {
                        bool? refresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailBarangScreen(barang: barangDifilter[0])));
                        if (refresh == true) _ambilDataDariDatabase();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Container(
                                    height: 180, width: double.infinity, color: AppColors.surface,
                                    child: barangDifilter[0]['url_foto'] != null ? Image.network(barangDifilter[0]['url_foto'], fit: BoxFit.cover) : const Icon(Icons.image),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(barangDifilter[0]['nama_barang'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
                                        const SizedBox(height: 4),
                                          if ((barangDifilter[0]['persen_diskon'] ?? 0) > 0) ...[
                                          Text('Mulai dari Rp ${formatRupiah(barangDifilter[0]['harga_sewa'])}/hari', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                                          Text('Mulai dari Rp ${formatRupiah(barangDifilter[0]['harga_setelah_diskon'])}/hari', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 15)),
                                        ] else
                                          Text('Mulai dari Rp ${formatRupiah(barangDifilter[0]['harga_sewa'])}/hari', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.secondary, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('Total Stok Keseluruhan: ${barangDifilter[0]['stok']} unit', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                )
                              ],
                            ),
                            if ((barangDifilter[0]['persen_diskon'] ?? 0) > 0)
                              Positioned(
                                top: 10, left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))]),
                                  child: Text('-${barangDifilter[0]['persen_diskon']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                                ),
                              ),
                            // TOMBOL HAPUS UNTUK ITEM PERTAMA
                            Positioned(
                              top: 10, right: 10,
                              child: Container(
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                child: IconButton(
                                    icon: const Icon(Icons.delete, color: AppColors.error),
                                    onPressed: () => _konfirmasiHapus(barangDifilter[0]['id_barang'], barangDifilter[0]['nama_barang']),
                                  ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // --- SISA ITEM (GRID DI BAWAH) ---
                  if (barangDifilter.length > 1)
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
                      itemCount: barangDifilter.length - 1,
                      itemBuilder: (context, index) {
                        final item = barangDifilter[index + 1];
                        return GestureDetector(
                          onTap: () async {
                            bool? refresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => DetailBarangScreen(barang: item)));
                            if (refresh == true) _ambilDataDariDatabase();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.accentLight.withOpacity(0.3)),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Container(width: double.infinity, color: AppColors.surface, child: item['url_foto'] != null ? Image.network(item['url_foto'], fit: BoxFit.cover) : const Icon(Icons.image)))),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['nama_barang'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                                          const SizedBox(height: 4),
                                          if ((item['persen_diskon'] ?? 0) > 0) ...[
                                            Text('Rp ${formatRupiah(item['harga_sewa'])}/hari', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                                            Text('Rp ${formatRupiah(item['harga_setelah_diskon'])}/hari', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.secondary)),
                                          ] else
                                            Text('Rp ${formatRupiah(item['harga_sewa'])}/hari', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.secondary)),
                                          const SizedBox(height: 4),
                                          Text('Stok: ${item['stok']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                if ((item['persen_diskon'] ?? 0) > 0)
                                  Positioned(
                                    top: 8, left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))]),
                                      child: Text('-${item['persen_diskon']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                                    ),
                                  ),
                                // TOMBOL HAPUS UNTUK ITEM GRID
                                Positioned(
                                  top: 8, right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                                      onPressed: () => _konfirmasiHapus(item['id_barang'], item['nama_barang']),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          })(),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          onPressed: _tampilkanFormTambahBarang, 
          child: const Icon(Icons.add, color: Colors.white, size: 28)
        )
      ),
    );
  }
}
