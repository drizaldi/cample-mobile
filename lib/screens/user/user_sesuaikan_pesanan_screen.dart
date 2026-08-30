import 'package:flutter/material.dart';
import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import 'package:apk_cample166/utils/format_currency.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/sesi_user.dart';
import '../admin/checkout_screen.dart';

class UserSesuaikanPesananScreen extends StatefulWidget {
  final List<Map<String, dynamic>> bulkItems;

  const UserSesuaikanPesananScreen({super.key, required this.bulkItems});

  @override
  State<UserSesuaikanPesananScreen> createState() => _UserSesuaikanPesananScreenState();
}

class _UserSesuaikanPesananScreenState extends State<UserSesuaikanPesananScreen> {
  bool _isLoading = true;
  
  // Data State
  DateTime? _masterTanggalMulai;
  DateTime? _masterTanggalSelesai;
  
  // Maps to store variations and current state for each item, keyed by id_keranjang
  Map<String, List<dynamic>> _varianPerItem = {};
  Map<String, Map<String, dynamic>> _varianTerpilihPerItem = {};
  Map<String, int> _qtyPerItem = {};

  @override
  void initState() {
    super.initState();
    _inisialisasiData();
  }

  Future<void> _inisialisasiData() async {
    // Tentukan master tanggal terlama (terpanjang) sebagai default
    DateTime? terawal;
    DateTime? terakhir;

    for (var item in widget.bulkItems) {
      if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null) {
        DateTime tMulai = DateTime.parse(item['tanggal_mulai']);
        DateTime tSelesai = DateTime.parse(item['tanggal_selesai']);
        
        if (terawal == null || tMulai.isBefore(terawal)) {
          terawal = tMulai;
        }
        if (terakhir == null || tSelesai.isAfter(terakhir)) {
          terakhir = tSelesai;
        }
      }
      
      _qtyPerItem[item['id_keranjang'].toString()] = int.tryParse(item['qty'].toString()) ?? 1;
    }

    _masterTanggalMulai = terawal;
    _masterTanggalSelesai = terakhir;

    // Ambil data varian untuk tiap barang
    for (var item in widget.bulkItems) {
      String idKeranjang = item['id_keranjang'].toString();
      String idBarang = item['id_barang'].toString();
      
      try {
        final response = await http.get(Uri.parse('${AppConfig.baseUrl}/barang/$idBarang/varian'));
        if (response.statusCode == 200) {
          List<dynamic> varian = jsonDecode(response.body);
          _varianPerItem[idKeranjang] = varian;
          
          // Set selected varian
          try {
            _varianTerpilihPerItem[idKeranjang] = varian.firstWhere((v) => v['id_varian'].toString() == item['id_varian'].toString());
          } catch (e) {
            if (varian.isNotEmpty) {
              _varianTerpilihPerItem[idKeranjang] = varian[0];
            }
          }
        }
      } catch (e) {
        debugPrint("Gagal fetch varian barang $idBarang: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pilihTanggal(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Clamp initialDateRange ke hari ini jika tanggal yang tersimpan sudah lewat.
    DateTimeRange? initialRange;
    if (_masterTanggalMulai != null && _masterTanggalSelesai != null) {
      final clampedStart = _masterTanggalMulai!.isBefore(today) ? today : _masterTanggalMulai!;
      final clampedEnd = _masterTanggalSelesai!.isBefore(clampedStart) ? clampedStart : _masterTanggalSelesai!;
      initialRange = DateTimeRange(start: clampedStart, end: clampedEnd);
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _masterTanggalMulai = picked.start;
        _masterTanggalSelesai = picked.end;
      });
    }
  }

  Future<bool> _simpanKeDatabase() async {
    if (_masterTanggalMulai == null || _masterTanggalSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih tanggal sewa terlebih dahulu!'), backgroundColor: AppColors.error),
      );
      return false;
    }

    // Validasi: tanggal mulai tidak boleh sebelum hari ini
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (_masterTanggalMulai!.isBefore(today)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Tanggal Tidak Valid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'Tanggal mulai sewa sudah melewati hari ini.\n\n'
            'Silakan tekan tombol "Pilih Tanggal" dan pilih tanggal mulai yang baru (hari ini atau setelahnya) sebelum melanjutkan checkout.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Pilih Tanggal Baru', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool allSuccess = true;

    for (var item in widget.bulkItems) {
      String idKeranjang = item['id_keranjang'].toString();
      var varianTerpilih = _varianTerpilihPerItem[idKeranjang];
      int qty = _qtyPerItem[idKeranjang] ?? 1;

      if (varianTerpilih == null) continue;

      try {
        final response = await http.put(
          Uri.parse('${AppConfig.baseUrl}/keranjang/$idKeranjang'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'qty': qty,
            'id_varian': varianTerpilih['id_varian'],
            'tanggal_mulai': _masterTanggalMulai!.toIso8601String().split('T')[0],
            'tanggal_selesai': _masterTanggalSelesai!.toIso8601String().split('T')[0],
          })
        );
        if (response.statusCode != 200) {
          allSuccess = false;
        }
      } catch (e) {
        allSuccess = false;
        debugPrint(e.toString());
      }
    }

    if (mounted) {
      Navigator.pop(context); // Tutup loading
    }

    if (!allSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan saat menyimpan perubahan.'), backgroundColor: AppColors.error),
        );
      }
      return false;
    }

    return true;
  }

  void _simpanPerubahan() async {
    bool success = await _simpanKeDatabase();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan Pesanan Disimpan!'), backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true); // true = refresh keranjang
    }
  }

  void _checkout() async {
    bool success = await _simpanKeDatabase();
    if (success && mounted) {
      // Ambil ulang data widget.bulkItems dengan data terbaru untuk dikirim ke CheckoutScreen
      List<Map<String, dynamic>> updatedBulkItems = widget.bulkItems.map((item) {
        String idK = item['id_keranjang'].toString();
        var varian = _varianTerpilihPerItem[idK];
        return {
          ...item,
          'qty': _qtyPerItem[idK],
          'id_varian': varian != null ? varian['id_varian'] : item['id_varian'],
          'nama_varian': varian != null ? varian['nama_varian'] : item['nama_varian'],
          'harga_sewa': varian != null ? varian['harga_sewa'] : item['harga_sewa'],
          'tanggal_mulai': _masterTanggalMulai!.toIso8601String().split('T')[0],
          'tanggal_selesai': _masterTanggalSelesai!.toIso8601String().split('T')[0],
        };
      }).toList();

      bool? checkoutSuccess = await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            isBulk: true,
            bulkItems: updatedBulkItems,
          )
        )
      );
      
      if (checkoutSuccess == true && mounted) {
         Navigator.pop(context, true); // Balik ke keranjang jika sukses
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sesuaikan Pesanan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top: Master Tanggal Sewa
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tanggal Sewa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: () => _pilihTanggal(context),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _masterTanggalMulai != null
                              ? "${_masterTanggalMulai!.day.toString().padLeft(2, '0')}/${_masterTanggalMulai!.month.toString().padLeft(2, '0')} - ${_masterTanggalSelesai!.day.toString().padLeft(2, '0')}/${_masterTanggalSelesai!.month.toString().padLeft(2, '0')}"
                              : "Pilih Tanggal",
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // List of items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.bulkItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.bulkItems[index];
                      final String idKeranjang = item['id_keranjang'].toString();
                      final varianList = _varianPerItem[idKeranjang] ?? [];
                      final varianTerpilih = _varianTerpilihPerItem[idKeranjang];
                      final qty = _qtyPerItem[idKeranjang] ?? 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nama_barang'] ?? 'Barang', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              
                              // Varian Dropdown
                              const Text('Pilih Varian', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: varianTerpilih != null ? varianTerpilih['id_varian'].toString() : null,
                                    hint: const Text("Pilih Varian"),
                                    items: varianList.map((v) {
                                      int stok = int.tryParse(v['stok'].toString()) ?? 0;
                                      return DropdownMenuItem<String>(
                                        value: v['id_varian'].toString(),
                                        enabled: stok > 0,
                                        child: Text('${v['nama_varian']} (Stok: $stok) - Rp ${formatRupiah(v['harga_sewa'])}', 
                                          style: TextStyle(color: stok > 0 ? Colors.black : Colors.grey.shade400, fontSize: 14)
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _varianTerpilihPerItem[idKeranjang] = varianList.firstWhere((v) => v['id_varian'].toString() == val);
                                          _qtyPerItem[idKeranjang] = 1; // Reset qty when varian changes
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Jumlah (Qty) Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Jumlah Pesan (Unit)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                        onPressed: qty > 1 ? () {
                                          setState(() {
                                            _qtyPerItem[idKeranjang] = qty - 1;
                                          });
                                        } : null,
                                      ),
                                      Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                        onPressed: () {
                                          int maxStok = 0;
                                          if (varianTerpilih != null) {
                                            maxStok = int.tryParse(varianTerpilih['stok'].toString()) ?? 0;
                                          }
                                          if (qty < maxStok) {
                                            setState(() {
                                              _qtyPerItem[idKeranjang] = qty + 1;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Maksimal stok varian tercapai')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _simpanPerubahan,
                  child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    if (SesiUser.role == 'admin') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa checkout pesanan.')));
                      return;
                    }
                    _checkout();
                  },
                  child: const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
