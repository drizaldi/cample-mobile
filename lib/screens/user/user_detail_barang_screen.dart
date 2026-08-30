import 'package:apk_cample166/config/app_config.dart';
import 'package:apk_cample166/utils/format_currency.dart';
// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import '../admin/checkout_screen.dart'; 
import '../admin/chat_screen.dart';
import 'user_keranjang_screen.dart'; 
import '../../sesi_user.dart'; 
import '../login_screen.dart';

class UserDetailBarangScreen extends StatefulWidget {
  final Map<String, dynamic> barang;
  final String? idKeranjang;

  const UserDetailBarangScreen({super.key, required this.barang, this.idKeranjang});

  @override
  State<UserDetailBarangScreen> createState() => _UserDetailBarangScreenState();
}

class _UserDetailBarangScreenState extends State<UserDetailBarangScreen> {
  List<dynamic> daftarVarian = [];
  bool _isLoadingVarian = true;
  
  // State untuk slider foto
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilVarianBarang();
  }

  // --- AMBIL VARIAN BARANG DARI SERVER ---
  Future<void> _ambilVarianBarang() async {
    final idBarang = widget.barang['id_barang'] ?? widget.barang['id'];
    try {
      final response = await http.get(Uri.parse('$baseUrl/barang/$idBarang/varian'));
      if (response.statusCode == 200) {
        setState(() {
          daftarVarian = jsonDecode(response.body);
          _isLoadingVarian = false;
        });
      } else {
        if (widget.barang['varian'] != null) {
          setState(() {
            daftarVarian = widget.barang['varian'];
            _isLoadingVarian = false;
          });
        } else {
          setState(() => _isLoadingVarian = false);
        }
      }
    } catch (e) {
      print("Error ambil varian: $e");
      setState(() => _isLoadingVarian = false);
    }
  }

  void _tampilkanDialogLogin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perlu Login', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Silakan login terlebih dahulu untuk mengakses fitur ini.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((val) {
                if (val == true && mounted) {
                  setState(() {});
                }
              });
            },
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI TAMBAH KERANJANG ---
  void _tambahKeKeranjang() {
    _tampilkanBottomSheetPesanan();
  }

  // --- BOTTOM SHEET PEMESANAN ---
  void _tampilkanBottomSheetPesanan() {
    if (SesiUser.isGuest) {
      _tampilkanDialogLogin();
      return;
    }

    if (daftarVarian.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maaf, varian/stok barang ini sedang kosong.'), backgroundColor: AppColors.error));
      return;
    }

    int jumlahPesan = 1;
    int lamaSewa = 1;
    DateTime? tanggalMulai;
    DateTime? tanggalSelesai;
    Map<String, dynamic>? varianTerpilih;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final int persenDiskon = widget.barang['persen_diskon'] ?? 0;
            int hargaVarian = varianTerpilih != null ? int.parse(varianTerpilih!['harga_sewa'].toString()) : 0;
            if (persenDiskon > 0) {
              hargaVarian = hargaVarian - (hargaVarian * persenDiskon / 100).round();
            }
            int totalBayar = hargaVarian * jumlahPesan * lamaSewa;

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

                    const Text('Daftar Varian Tersedia', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          final int persenDiskon = widget.barang['persen_diskon'] ?? 0;
                          int hargaNormal = int.tryParse(varian['harga_sewa'].toString()) ?? 0;
                          int hargaDiskon = persenDiskon > 0 ? hargaNormal - (hargaNormal * persenDiskon / 100).round() : hargaNormal;

                          return GestureDetector(
                            onTap: isHabis ? null : () {
                              setModalState(() {
                                varianTerpilih = varian;
                                // Reset jumlah pesan ke 1 saat varian berubah
                                jumlahPesan = 1;
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
                                  Text('Kapasitas: ${varian['kapasitas'] ?? '-'}', style: TextStyle(color: isHabis ? Colors.grey : Colors.grey[700], fontSize: 12)),
                                  Text('Sisa Stok: $stokVarian', style: TextStyle(color: isHabis ? AppColors.error : AppColors.primary, fontSize: 12, fontWeight: isHabis ? FontWeight.bold : FontWeight.normal)),
                                  const SizedBox(height: 4),
                                  if (persenDiskon > 0) ...[
                                    Text('Rp ${formatRupiah(hargaNormal)}/hr', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 11)),
                                    Text('Rp ${formatRupiah(hargaDiskon)}/hr', style: TextStyle(color: isHabis ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold)),
                                  ] else
                                    Text('Rp ${formatRupiah(hargaNormal)}/hr', style: TextStyle(color: isHabis ? Colors.grey : AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),

                    // KONTROL JUMLAH & LAMA SEWA
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
                                if (varianTerpilih == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih varian dulu!')));
                                  return;
                                }
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
                            final pickedDate = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              helpText: 'Pilih Tanggal (Ketuk 2x untuk 1 hari)',
                              saveText: 'PILIH',
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.error,
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
                                // Menghitung dari awal sewa hingga selesai, e.g. 29 ke 30 dihitung 2 hari. 
                                // Jika dikembalikan di hari yg sama (29 ke 29), dihitung 1 hari.
                                int selisih = pickedDate.end.difference(pickedDate.start).inDays;
                                lamaSewa = selisih + 1; 
                              });
                            }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 10),

                    // TOTAL & TOMBOL LANJUT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Bayar', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('Rp ${formatRupiah(totalBayar)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Row(
                          children: [
                            // Tombol Keranjang
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                              onPressed: varianTerpilih != null ? () async {
                                if (SesiUser.role == 'admin') {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memasukkan ke keranjang.')));
                                  return;
                                }
                                final String url = '${AppConfig.baseUrl}/keranjang';
                                try {
                                  final response = await http.post(
                                    Uri.parse(url),
                                    body: {
                                      'id_user': SesiUser.idUser,
                                      'id_barang': widget.barang['id_barang'].toString(),
                                      'nama_varian': varianTerpilih!['nama_varian'],
                                      'qty': jumlahPesan.toString(),
                                      'tanggal_mulai': tanggalMulai?.toIso8601String().split('T')[0] ?? '',
                                      'tanggal_selesai': tanggalSelesai?.toIso8601String().split('T')[0] ?? '',
                                    }
                                  );
                                  if (response.statusCode == 200) {
                                    Navigator.pop(context);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Dimasukkan ke Keranjang! 🛒'), backgroundColor: AppColors.success),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print(e);
                                }
                              } : null,
                            ),
                            const SizedBox(width: 8),
                            // Tombol Pembayaran
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (varianTerpilih != null && tanggalMulai != null) ? AppColors.error : Colors.grey,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: (varianTerpilih != null && tanggalMulai != null)
                                ? () async {
                                    if (SesiUser.role == 'admin') {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memesan barang.')));
                                      return;
                                    }
                                    Navigator.pop(context); 
                                    
                                    bool? success = await Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => CheckoutScreen(
                                        barang: widget.barang,
                                        varianTerpilih: varianTerpilih!,
                                        jumlahPesan: jumlahPesan,
                                        lamaSewa: lamaSewa,
                                        tanggalMulai: tanggalMulai,
                                        tanggalSelesai: tanggalSelesai,
                                      ),
                                    ));

                                    if (success == true && widget.idKeranjang != null) {
                                      try {
                                        await http.delete(Uri.parse('${AppConfig.baseUrl}/keranjang/${widget.idKeranjang}'));
                                        if (mounted) Navigator.pop(context, true);
                                      } catch (e) {
                                        print("Gagal hapus keranjang: $e");
                                      }
                                    }
                                  }
                                : null,
                              child: const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String urlFoto = widget.barang['url_foto'] ?? '';
    String namaBarang = widget.barang['nama_barang'] ?? 'Alat Camping';
    String hargaSewa = widget.barang['harga_sewa']?.toString() ?? '0';
    String deskripsi = widget.barang['deskripsi'] ?? 'Tidak ada deskripsi tersedia.';
    final int persenDiskon = widget.barang['persen_diskon'] ?? 0;
    final int hargaSetelahDiskon = widget.barang['harga_setelah_diskon'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FOTO BARANG DENGAN SLIDER
            Builder(
              builder: (context) {
                List<dynamic> semuaFoto = widget.barang['semua_foto'] ?? [];
                if (semuaFoto.isEmpty && urlFoto.isNotEmpty) {
                  semuaFoto = [urlFoto];
                }

                return Stack(
                  children: [
                    Container(
                      width: double.infinity, height: 350, 
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                        ],
                      ),
                      child: semuaFoto.isNotEmpty 
                        ? PageView.builder(
                            controller: _pageController,
                            itemCount: semuaFoto.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Image.network(semuaFoto[index], fit: BoxFit.cover);
                            },
                          )
                        : const Icon(Icons.image, size: 100, color: Colors.grey),
                    ),
                    if (semuaFoto.length > 1)
                      Positioned(
                        bottom: 15,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            semuaFoto.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentImageIndex == index
                                    ? AppColors.primary
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }
            ),
            
            // INFO HARGA & DESKRIPSI
            Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(namaBarang, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2, color: AppColors.textPrimary))),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
                        ),
                        child: IconButton(icon: const Icon(Icons.add_shopping_cart, size: 24, color: AppColors.secondary), onPressed: _tambahKeKeranjang),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (persenDiskon > 0) ...[
                    Text('Mulai Rp ${formatRupiah(hargaSewa)}/hari', style: TextStyle(fontSize: 14, color: Colors.grey.shade500, decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Rp ${formatRupiah(hargaSetelahDiskon)}/hari', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(12)),
                          child: Text('-$persenDiskon%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ] else
                    Text('Mulai Rp ${formatRupiah(hargaSewa)}/hari', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1)),
                  const Text('Deskripsi Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(deskripsi, style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- AREA VARIAN TERSEDIA (TAMPILAN USER) ---
            Container(
              color: AppColors.background, width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Varian Tersedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
                  const SizedBox(height: 15),
                  if (_isLoadingVarian)
                    const Center(child: CircularProgressIndicator())
                  else if (daftarVarian.isEmpty)
                    const Text('Belum ada varian atau stok kosong.', style: TextStyle(color: Colors.grey))
                  else
                    ...daftarVarian.map<Widget>((varian) {
                      int stok = int.tryParse(varian['stok'].toString()) ?? 0;
                      bool isHabis = stok <= 0;
                      int hrgNormal = int.tryParse(varian['harga_sewa'].toString()) ?? 0;
                      int hrgDiskon = persenDiskon > 0 ? hrgNormal - (hrgNormal * persenDiskon / 100).round() : hrgNormal;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isHabis ? Colors.grey[50] : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isHabis ? Colors.grey[300]! : AppColors.accentLight.withOpacity(0.5)),
                          boxShadow: isHabis ? [] : [
                            BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
                          ]
                        ),
                        child: ListTile(
                          title: Text(
                            varian['nama_varian'] ?? '-', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: isHabis ? Colors.grey : Colors.black87)
                          ),
                          subtitle: Text(
                            persenDiskon > 0 
                                ? 'Harga: Rp ${formatRupiah(hrgDiskon)}/hr | Kapasitas: ${varian['kapasitas']}'
                                : 'Harga: Rp ${formatRupiah(hrgNormal)}/hr | Kapasitas: ${varian['kapasitas']}', 
                            style: TextStyle(color: isHabis ? Colors.grey : Colors.black54, fontSize: 12)
                          ),
                          trailing: CircleAvatar(
                            backgroundColor: isHabis ? Colors.grey : AppColors.primary, radius: 18,
                            child: Text('$stok', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 80), // Ruang ekstra agar tidak tertutup tombol bawah
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                if (SesiUser.role == 'admin') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memesan barang atau membuka keranjang.')));
                  return;
                }
                if (SesiUser.isGuest) {
                  _tampilkanDialogLogin();
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const UserKeranjangScreen()));
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                    SizedBox(height: 4),
                    Text('Keranjang', style: TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () {
                if (SesiUser.isGuest) {
                  _tampilkanDialogLogin();
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_outlined, color: Colors.black87),
                    SizedBox(height: 4),
                    Text('Chat', style: TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _isLoadingVarian ? null : () {
                    if (SesiUser.role == 'admin') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tindakan Ditolak: Admin tidak bisa memesan barang.')));
                      return;
                    }
                    _tampilkanBottomSheetPesanan();
                  },
                  child: _isLoadingVarian 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Pesan Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
