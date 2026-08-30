import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/theme/app_colors.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import '../../sesi_user.dart';
import '../admin/checkout_screen.dart'; // Import halaman checkout
import 'user_sesuaikan_pesanan_screen.dart'; // Import layar penyesuaian pesanan

class UserKeranjangScreen extends StatefulWidget {
  const UserKeranjangScreen({super.key});

  @override
  State<UserKeranjangScreen> createState() => _UserKeranjangScreenState();
}

class _UserKeranjangScreenState extends State<UserKeranjangScreen> {
  List<Map<String, dynamic>> daftarKeranjang = [];
  List<String> selectedKeranjangIds = []; // NEW: Track selected items
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ambilKeranjang();
  }

  Future<void> _ambilKeranjang() async {
    if (SesiUser.idUser == null) return;
    final String url = '${AppConfig.baseUrl}/keranjang/${SesiUser.idUser}';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          daftarKeranjang = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _hapusItem(String id) async {
    final String url = '${AppConfig.baseUrl}/keranjang/$id';
    await http.delete(Uri.parse(url));
    setState(() {
      selectedKeranjangIds.remove(id);
    });
    _ambilKeranjang(); // Refresh tampilan
  }

  // Hitung grand total
  int _hitungGrandTotal() {
    int total = 0;
    for (var item in daftarKeranjang) {
      if (selectedKeranjangIds.contains(item['id_keranjang'].toString())) {
        int qty = int.tryParse(item['qty'].toString()) ?? 1;
        int hargaSewa = int.tryParse(item['harga_sewa'].toString()) ?? 0;
        
        // Ambil lama sewa jika ada, default 1 hari
        int lamaSewa = 1;
        if (item['tanggal_mulai'] != null && item['tanggal_selesai'] != null) {
          DateTime start = DateTime.parse(item['tanggal_mulai']);
          DateTime end = DateTime.parse(item['tanggal_selesai']);
          lamaSewa = end.difference(start).inDays + 1;
        }
        
        total += (hargaSewa * qty * lamaSewa);
      }
    }
    return total;
  }

  // Checkout semua yang dipilih
  void _checkoutTerpilih() async {
    if (selectedKeranjangIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 barang untuk di-checkout!')),
      );
      return;
    }

    // Filter daftar item yang dicentang
    List<Map<String, dynamic>> itemsToCheckout = daftarKeranjang
        .where((item) => selectedKeranjangIds.contains(item['id_keranjang'].toString()))
        .toList();

    // 1. Cari kombinasi rentang tanggal terlama dari barang yang SUDAH memiliki tanggal
    DateTime? terawal;
    DateTime? terakhir;

    for (var item in itemsToCheckout) {
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
    }

    // 2. Jika tidak ada SATUPUN barang yang punya tanggal, tolak
    if (terawal == null || terakhir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang belum memiliki tanggal sewa. Silakan tekan Sesuaikan Pesanan terlebih dahulu.'), backgroundColor: AppColors.error),
      );
      return;
    }

    // 3. Terapkan tanggal terlama ke semua item terpilih (termasuk yang tadinya kosong)
    // Validasi: tanggal mulai tidak boleh sebelum hari ini
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (terawal.isBefore(today)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Tanggal Tidak Valid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: const Text(
            'Salah satu atau semua barang memiliki tanggal mulai sewa yang sudah lewat.\n\n'
            'Silakan tekan "Sesuaikan Pesanan" dan pilih ulang tanggal sewa sebelum checkout.',
            style: TextStyle(height: 1.5),
          ),
          actions: [ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Sesuaikan Tanggal', style: TextStyle(color: Colors.white)),
          )],
        ),
      );
      return;
    }

    String tMulaiStr = terawal.toIso8601String().split('T')[0];
    String tSelesaiStr = terakhir.toIso8601String().split('T')[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Update via API
    for (var item in itemsToCheckout) {
      try {
        await http.put(
          Uri.parse('${AppConfig.baseUrl}/keranjang/${item['id_keranjang']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'qty': int.tryParse(item['qty'].toString()) ?? 1,
            'id_varian': item['id_varian'],
            'tanggal_mulai': tMulaiStr,
            'tanggal_selesai': tSelesaiStr,
          })
        );
        // Update local item
        item['tanggal_mulai'] = tMulaiStr;
        item['tanggal_selesai'] = tSelesaiStr;
      } catch (e) {
        print(e);
      }
    }

    if (mounted) Navigator.pop(context); // Tutup loading

    // Karena ini bulk checkout, kita arahkan ke CheckoutScreen dengan mode bulk
    bool? success = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          isBulk: true,
          bulkItems: itemsToCheckout,
        )
      )
    );

    if (success == true) {
      // Hapus item yang berhasil dicheckout dari keranjang
      for (var id in selectedKeranjangIds) {
        await http.delete(Uri.parse('${AppConfig.baseUrl}/keranjang/$id'));
      }
      setState(() {
        selectedKeranjangIds.clear();
      });
      _ambilKeranjang();
    }
  }

  void _bukaSesuaikanPesanan() async {
    if (selectedKeranjangIds.isEmpty) return;

    List<Map<String, dynamic>> itemsToCheckout = daftarKeranjang
        .where((item) => selectedKeranjangIds.contains(item['id_keranjang'].toString()))
        .toList();

    bool? refresh = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSesuaikanPesananScreen(bulkItems: itemsToCheckout),
      )
    );

    if (refresh == true) {
      // Jika user klik Simpan Perubahan atau berhasil Checkout, load keranjang lagi
      _ambilKeranjang();
    }
  }

  // --- MUNCULKAN BOTTOM SHEET DETAIL PESAN (MIRIP PESAN BIASA DENGAN PILIHAN VARIAN) ---
  void _checkoutItem(Map<String, dynamic> item) async {
    // Tampilkan loading dialog sebentar saat mengambil daftar varian
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<dynamic> daftarVarian = [];
    String debugInfo = "";
    try {
      final idBarang = item['id_barang'];
      debugInfo += "ID: $idBarang. ";
      
      if (idBarang != null) {
         final response = await http.get(Uri.parse('${AppConfig.baseUrl}/barang/$idBarang/varian'));
         debugInfo += "HTTP: ${response.statusCode}. ";
         if (response.statusCode == 200) {
           daftarVarian = jsonDecode(response.body);
           debugInfo += "Count: ${daftarVarian.length}. ";
         } else {
           debugInfo += "Body: ${response.body}. ";
         }
      } else {
         debugInfo += "idBarang is NULL. ";
      }
    } catch (e) {
      debugInfo += "Exception: $e";
      print("Gagal mengambil varian: $e");
    }

    Navigator.pop(context); // Tutup loading dialog

    if (daftarVarian.isEmpty) {
      // TAMPILKAN DEBUG INFO KE USER AGAR KETAHUAN KENAPA GAGAL
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Gagal Memuat Varian', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.error)),
          content: Text('Sistem tidak dapat memuat daftar varian barang ini.\n\nInfo Debugging:\n$debugInfo', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)))
          ]
        )
      );
      return;
    }

    int jumlahPesan = int.tryParse(item['qty'].toString()) ?? 1;
    // Inisialisasi tanggal dari data keranjang — TETAP tanggal asli untuk label tombol
    final todayInit = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime? tanggalMulai = item['tanggal_mulai'] != null ? DateTime.parse(item['tanggal_mulai']) : null;
    DateTime? tanggalSelesai = item['tanggal_selesai'] != null ? DateTime.parse(item['tanggal_selesai']) : null;
    // Flag: apakah tanggal asli sudah expired?
    final bool wasExpired = tanggalMulai != null && tanggalMulai.isBefore(todayInit);
    // Flag: user sudah pilih tanggal baru secara eksplisit via date picker
    bool newDatePicked = false;
    // Hitung lama sewa dari tanggal asli (meski expired, untuk tampilan)
    int lamaSewa = 1;
    if (tanggalMulai != null && tanggalSelesai != null) {
      lamaSewa = tanggalSelesai.difference(tanggalMulai).inDays + 1;
      if (lamaSewa < 1) lamaSewa = 1;
    }
    Map<String, dynamic>? varianTerpilih;
    try {
       varianTerpilih = daftarVarian.firstWhere((v) => v['id_varian'].toString() == item['id_varian'].toString());
    } catch (e) {
       varianTerpilih = daftarVarian[0];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            int hargaSewa = varianTerpilih != null ? int.parse(varianTerpilih!['harga_sewa'].toString()) : 0;
            int totalBayar = hargaSewa * jumlahPesan * lamaSewa;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pilih Varian & Jumlah', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    const Text('Pilih Kode/Varian', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: daftarVarian.length,
                        itemBuilder: (context, index) {
                          final varian = daftarVarian[index];
                          bool isSelected = varianTerpilih == varian;
                          int stokVarian = int.tryParse(varian['stok'].toString()) ?? 0;
                          bool isHabis = stokVarian <= 0;

                          return GestureDetector(
                            onTap: isHabis ? null : () {
                              setModalState(() {
                                varianTerpilih = varian;
                                jumlahPesan = 1; // Reset jumlah jika varian berubah
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isHabis ? Colors.grey[200] : Colors.white,
                                border: Border.all(color: isSelected ? AppColors.primary : (isHabis ? Colors.grey[400]! : Colors.grey[300]!), width: isSelected ? 2 : 1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(varian['nama_varian'] ?? 'Varian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHabis ? Colors.grey : Colors.black)),
                                      if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Sisa Stok: $stokVarian', style: TextStyle(color: isHabis ? AppColors.error : AppColors.primary, fontSize: 12, fontWeight: isHabis ? FontWeight.bold : FontWeight.normal)),
                                  const SizedBox(height: 4),
                                  Text('Rp ${formatRupiah(varian['harga_sewa'])}/hr', style: TextStyle(color: isHabis ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),

                    // Kontrol Jumlah
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jumlah Pesan (Unit)', style: TextStyle(fontSize: 16)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                              onPressed: jumlahPesan > 1 ? () => setModalState(() => jumlahPesan--) : null,
                            ),
                            Text('$jumlahPesan', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              onPressed: () {
                                if (varianTerpilih == null) return;
                                int stokTersedia = int.tryParse(varianTerpilih!['stok'].toString()) ?? 0;
                                if (jumlahPesan < stokTersedia) {
                                  setModalState(() => jumlahPesan++);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batas maksimum stok tercapai!')));
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    // TANGGAL SEWA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tanggal Sewa', style: TextStyle(fontSize: 16)),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(tanggalMulai != null 
                              ? '${tanggalMulai!.day}/${tanggalMulai!.month} - ${tanggalSelesai!.day}/${tanggalSelesai!.month} ($lamaSewa Hari)' 
                              : 'Pilih Tanggal'),
                          onPressed: () async {
                            final nowDate = DateTime.now();
                            final todayDate = DateTime(nowDate.year, nowDate.month, nowDate.day);
                            // Clamp hanya untuk initialDateRange di picker:
                            // Jika tanggal mulai sudah lewat → buka dari hari ini,
                            // tanggal selesai tetap asli (agar user tinggal tekan Save)
                            final clampedStart = (tanggalMulai != null && tanggalMulai!.isBefore(todayDate))
                                ? todayDate
                                : tanggalMulai;
                            final clampedEnd = (tanggalSelesai != null && clampedStart != null && tanggalSelesai!.isBefore(clampedStart))
                                ? clampedStart
                                : tanggalSelesai;
                            final initRange = (clampedStart != null && clampedEnd != null)
                                ? DateTimeRange(start: clampedStart, end: clampedEnd!)
                                : null;
                            final pickedDate = await showDateRangePicker(
                              context: context,
                              firstDate: todayDate,
                              lastDate: todayDate.add(const Duration(days: 365)),
                              initialDateRange: initRange,
                              helpText: 'Pilih Tanggal (Ketuk 2x untuk 1 hari)',
                              saveText: 'PILIH',
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primary,
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (pickedDate != null) {
                              setModalState(() {
                                tanggalMulai = pickedDate.start;
                                tanggalSelesai = pickedDate.end;
                                int selisih = pickedDate.end.difference(pickedDate.start).inDays;
                                lamaSewa = selisih + 1;
                                newDatePicked = true; // User sudah pilih tanggal baru eksplisit
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Total Harga & Tombol
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total (Per Hari)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('Rp ${formatRupiah(totalBayar)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (varianTerpilih != null && tanggalMulai != null) ? AppColors.success : Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                ),
                                 onPressed: (varianTerpilih != null && tanggalMulai != null) ? () async {
                                  // Blokir jika tanggal asli expired DAN user belum pilih tanggal baru eksplisit
                                  if (wasExpired && !newDatePicked) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Row(children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                                          SizedBox(width: 8),
                                          Text('Perbarui Tanggal Sewa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ]),
                                        content: const Text(
                                          'Tanggal sewa sebelumnya sudah kadaluarsa.\n\nSilakan tekan tombol tanggal dan pilih ulang tanggal sewa yang baru sebelum menyimpan.',
                                          style: TextStyle(height: 1.5),
                                        ),
                                        actions: [ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Pilih Tanggal Baru', style: TextStyle(color: Colors.white)),
                                        )],
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    final response = await http.put(
                                      Uri.parse('${AppConfig.baseUrl}/keranjang/${item['id_keranjang']}'),
                                      headers: {'Content-Type': 'application/json'},
                                      body: jsonEncode(
                                        {
                                          'qty': jumlahPesan,
                                          'id_varian': varianTerpilih!['id_varian'],
                                          'tanggal_mulai': tanggalMulai!.toIso8601String().split('T')[0],
                                          'tanggal_selesai': tanggalSelesai!.toIso8601String().split('T')[0],
                                        }
                                      )
                                    );
                                    if (response.statusCode == 200) {
                                      Navigator.pop(context);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: const Text('Perubahan Keranjang Disimpan!'), backgroundColor: AppColors.success),
                                        );
                                        _ambilKeranjang();
                                      }
                                    }
                                  } catch (e) {
                                    print(e);
                                  }
                                } : null,
                                child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (varianTerpilih != null && tanggalMulai != null) ? AppColors.primary : Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                ),
                                 onPressed: (varianTerpilih != null && tanggalMulai != null) ? () async {
                                    // Blokir jika tanggal asli expired DAN user belum pilih tanggal baru eksplisit
                                    if (wasExpired && !newDatePicked) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Row(children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                                            SizedBox(width: 8),
                                            Text('Perbarui Tanggal Sewa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ]),
                                          content: const Text(
                                            'Tanggal sewa sebelumnya sudah kadaluarsa.\n\nSilakan tekan tombol tanggal dan pilih ulang tanggal sewa yang baru sebelum checkout.',
                                            style: TextStyle(height: 1.5),
                                          ),
                                          actions: [ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Pilih Tanggal Baru', style: TextStyle(color: Colors.white)),
                                          )],
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);

                                  Map<String, dynamic> fakeBarang = {
                                    'id_barang': varianTerpilih!['id_barang'],
                                    'nama_barang': item['nama_barang'] ?? 'Barang',
                                    'gambar': item['gambar'] ?? 'placeholder.png'
                                  };

                                  bool? success = await Navigator.push(
                                    context, 
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        barang: fakeBarang,
                                        varianTerpilih: varianTerpilih!,
                                        jumlahPesan: jumlahPesan,
                                        lamaSewa: lamaSewa,
                                        idKeranjang: item['id_keranjang'].toString(),
                                        tanggalMulai: tanggalMulai,
                                        tanggalSelesai: tanggalSelesai,
                                      )
                                    )
                                  );

                                  if (success == true) {
                                    await _hapusItem(item['id_keranjang'].toString());
                                  }
                                } : null,
                                child: const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        )
                      ],
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Keranjang Saya', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : daftarKeranjang.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_shopping_cart, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Keranjang Anda masih kosong', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: daftarKeranjang.length,
                  itemBuilder: (context, index) {
                    final item = daftarKeranjang[index];
                    final String keranjangId = item['id_keranjang'].toString();
                    final bool isSelected = selectedKeranjangIds.contains(keranjangId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppColors.secondary : AppColors.accentLight.withOpacity(0.5), width: isSelected ? 1.5 : 1),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
                        ]
                      ),
                      child: InkWell(
                        onTap: () => _checkoutItem(item), // Tekan card untuk edit varian/qty
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: isSelected,
                                activeColor: AppColors.secondary,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedKeranjangIds.add(keranjangId);
                                    } else {
                                      selectedKeranjangIds.remove(keranjangId);
                                    }
                                  });
                                },
                              ),
                              Container(
                                width: 70, height: 70, color: Colors.grey[200],
                                child: item['url_foto'] != null ? Image.network(item['url_foto'], fit: BoxFit.cover) : const Icon(Icons.image),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['nama_barang'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                    Text('Varian: ${item['nama_varian']} (Jumlah: ${item['qty']})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    if (item['tanggal_mulai'] != null)
                                      Text('${item['tanggal_mulai']} s.d ${item['tanggal_selesai']}', style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('Rp ${formatRupiah(item['harga_sewa'])}/hari', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                onPressed: () => _hapusItem(keranjangId),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: daftarKeranjang.isEmpty ? null : Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selectedKeranjangIds.length == daftarKeranjang.length && daftarKeranjang.isNotEmpty,
                        activeColor: AppColors.secondary,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedKeranjangIds = daftarKeranjang.map((e) => e['id_keranjang'].toString()).toList();
                            } else {
                              selectedKeranjangIds.clear();
                            }
                          });
                        },
                      ),
                      const Text('Semua', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          Text('Rp ${formatRupiah(_hitungGrandTotal())}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedKeranjangIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: () {
                            if (SesiUser.role == 'admin') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa menyesuaikan pesanan.')));
                              return;
                            }
                            _bukaSesuaikanPesanan();
                          },
                          child: const Text('Sesuaikan Pesanan', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: () {
                            if (SesiUser.role == 'admin') {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memesan barang.')));
                              return;
                            }
                            _checkoutTerpilih();
                          },
                          child: Text('Checkout (${selectedKeranjangIds.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
