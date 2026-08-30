import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // untuk kIsWeb
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../../theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:apk_cample166/my_http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../sesi_user.dart';
import '../login_screen.dart';
import 'admin_inbox_screen.dart'; // Import chat / inbox admin
import 'admin_manajemen_diskon_screen.dart';
import 'admin_laporan_screen.dart'; // Import Laporan Bulanan

class AdminProfilScreen extends StatefulWidget {
  const AdminProfilScreen({super.key});

  @override
  _AdminProfilScreenState createState() => _AdminProfilScreenState();
}

class _AdminProfilScreenState extends State<AdminProfilScreen> {
  // State Data Toko (Akan diisi dari Database)
  String namaToko = "Memuat...";
  String alamatToko = "Memuat...";
  String kontakToko = "Memuat...";
  String? urlFotoProfil;

  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  // --- State untuk Web Crop (metode Vigenesia) ---
  bool _isCropping = false;
  Uint8List? _rawImage;   // bytes asli sebelum crop
  XFile? _pendingFile;    // file yang dipilih, menunggu crop
  static const double _cropSize = 280.0;
  final _cropKey = GlobalKey();
  final _transformCtrl = TransformationController();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilProfilDariDatabase();
  }

  // --- AMBIL DATA PROFIL PERMANEN DARI SERVER ---
  Future<void> _ambilProfilDariDatabase() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/profil'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          namaToko = data['nama_toko'] ?? 'Cample Store';
          alamatToko = data['alamat'] ?? '-';
          kontakToko = data['kontak'] ?? '-';
          urlFotoProfil = data['url_foto'];
        });
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  // --- FUNGSI UPDATE DATA KE SERVER ---
  Future<void> _simpanKeDatabase(Map<String, String> dataTeks, XFile? fotoBaru, {Uint8List? webBytes}) async {
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/profil'));
      request.fields.addAll(dataTeks);

      if (fotoBaru != null) {
        if (kIsWeb && webBytes != null) {
          // Web: kirim bytes hasil crop
          request.files.add(http.MultipartFile.fromBytes('foto', webBytes, filename: fotoBaru.name, contentType: MediaType('image', 'png')));
        } else if (!kIsWeb) {
          request.files.add(await http.MultipartFile.fromPath('foto', fotoBaru.path));
        }
      }

      var response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan permanen!'), backgroundColor: AppColors.success));
        _ambilProfilDariDatabase(); // Refresh data di layar
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan profil.'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  // --- Web Crop: Ambil hasil crop dari RepaintBoundary ---
  Future<void> _confirmCrop() async {
    try {
      final boundary =
          _cropKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final uiImg = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null && mounted && _pendingFile != null) {
        final croppedBytes = byteData.buffer.asUint8List();
        setState(() => _isCropping = false);
        // Simpan ke server dengan bytes hasil crop
        await _simpanKeDatabase({
          'nama_toko': namaToko,
          'alamat': alamatToko,
          'kontak': kontakToko,
        }, _pendingFile!, webBytes: croppedBytes);
      }
    } catch (_) {
      setState(() => _isCropping = false);
    }
  }

  // --- Web Crop: Tampilan halaman crop full-screen ---
  Widget _buildCropPage() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false, // hapus tombol back bawaan jika ada
        title: const Text('Sesuaikan Foto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Cubit untuk zoom · Seret untuk memilih area',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    key: _cropKey,
                    child: SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: ClipOval(
                        child: Container(
                          color: Colors.black,
                          child: InteractiveViewer(
                            transformationController: _transformCtrl,
                            constrained: true,
                            minScale: 0.3,
                            maxScale: 8.0,
                            child: SizedBox(
                              width: _cropSize,
                              height: _cropSize,
                              child: Center(
                                child: Image.memory(
                                  _rawImage!,
                                  fit: BoxFit.contain,
                                  width: _cropSize,
                                  height: _cropSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: SizedBox(
                      width: _cropSize,
                      height: _cropSize,
                      child: CustomPaint(painter: _AdminCircleBorderPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => setState(() => _isCropping = false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _confirmCrop,
                    child: const Text('Gunakan',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI GANTI FOTO PROFIL ---
  Future<void> _pilihFotoProfil() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    if (kIsWeb) {
      // WEB: Tampilkan halaman crop custom (metode Vigenesia)
      final bytes = await pickedImage.readAsBytes();
      _transformCtrl.value = Matrix4.identity();
      setState(() {
        _pendingFile = pickedImage;
        _rawImage = bytes;
        _isCropping = true;
      });
    } else {
      // MOBILE (Android/iOS): Gunakan image_cropper native
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedImage.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Foto Profil Toko',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Potong Foto Profil Toko',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (croppedFile == null) return; // user batal crop
      final fotoFinal = XFile(croppedFile.path);
      await _simpanKeDatabase({
        'nama_toko': namaToko,
        'alamat': alamatToko,
        'kontak': kontakToko,
      }, fotoFinal);
    }
  }

  // --- FUNGSI EDIT INFORMASI TOKO ---
  void _editInfoToko() {
    TextEditingController namaCtrl = TextEditingController(text: namaToko);
    TextEditingController alamatCtrl = TextEditingController(text: alamatToko);
    TextEditingController kontakCtrl = TextEditingController(text: kontakToko);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Informasi Toko'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Toko')),
              TextField(controller: alamatCtrl, decoration: const InputDecoration(labelText: 'Alamat Toko')),
              TextField(controller: kontakCtrl, decoration: const InputDecoration(labelText: 'Nomor Kontak (WA)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Tembak data teks ke server
              _simpanKeDatabase({
                'nama_toko': namaCtrl.text,
                'alamat': alamatCtrl.text,
                'kontak': kontakCtrl.text,
              }, null);
            },
            child: const Text('Simpan Permanen'),
          )
        ],
      ),
    );
  }

  // --- FUNGSI GANTI PASSWORD ---
  void _gantiPassword() {
    TextEditingController pwdLamaCtrl = TextEditingController();
    TextEditingController pwdBaruCtrl = TextEditingController();
    TextEditingController pwdKonfirmasiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isPwdLoading = false;
            return AlertDialog(
              title: const Text('Ganti Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: pwdLamaCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password Lama')),
                  const SizedBox(height: 10),
                  TextField(controller: pwdBaruCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password Baru')),
                  const SizedBox(height: 10),
                  TextField(controller: pwdKonfirmasiCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru')),
                ],
              ),
              actions: [
                TextButton(
                  // ignore: dead_code
                  onPressed: isPwdLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: () async {
                    if (pwdLamaCtrl.text.isEmpty || pwdBaruCtrl.text.isEmpty || pwdKonfirmasiCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi semua field!'), backgroundColor: AppColors.error));
                      return;
                    }
                    if (pwdBaruCtrl.text != pwdKonfirmasiCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru tidak cocok!'), backgroundColor: AppColors.error));
                      return;
                    }
                    setStateDialog(() => isPwdLoading = true);
                    try {
                      final response = await http.post(
                        Uri.parse('$baseUrl/user/ganti-password'),
                        headers: {
                          'Authorization': 'Bearer ${SesiUser.token}',
                          'Accept': 'application/json',
                        },
                        body: {
                          'password_lama': pwdLamaCtrl.text,
                          'password_baru': pwdBaruCtrl.text
                        }
                      );
                      final data = jsonDecode(response.body);
                      setStateDialog(() => isPwdLoading = false);
                      if (response.statusCode == 200) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diubah!'), backgroundColor: AppColors.success));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'Gagal ganti password'), backgroundColor: AppColors.error));
                      }
                    } catch (e) {
                      setStateDialog(() => isPwdLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
                    }
                  },
                  // ignore: dead_code
                  child: isPwdLoading
                      // ignore: dead_code
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Password', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _hubungiDeveloper() async {
    // Format: 628xxx (kode negara tanpa +, tanpa angka 0 di depan)
    // Nomor ini bisa diubah langsung di sini: lib/screens/admin/admin_profil_screen.dart
    const String noWA = "6285750091480";
    const String pesan = "Halo Tim Developer Cample, saya sebagai Admin butuh bantuan terkait sistem.";
    final Uri url = Uri.parse("https://wa.me/$noWA?text=${Uri.encodeComponent(pesan)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp!')));
    }
  }

  // --- FUNGSI LOGOUT YANG SUDAH DIPERBAIKI ---
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              // 1. Tutup Dialog Konfirmasi
              Navigator.pop(context);

              // 2. Hapus Sesi di SharedPreferences secara permanen
              await SesiUser.hapusSesi();

              // 3. Pindah ke Halaman Login dan bersihkan semua tumpukan layar sebelumnya
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
              
              // 4. Tampilkan Notifikasi Sukses
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda berhasil Logout.'), backgroundColor: AppColors.success));
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jika sedang dalam mode crop web, tampilkan halaman crop
    if (kIsWeb && _isCropping && _rawImage != null) return _buildCropPage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // FOTO PROFIL & NAMA
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: AppColors.surface,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: urlFotoProfil != null ? NetworkImage(urlFotoProfil!) : null,
                                child: urlFotoProfil == null ? const Icon(Icons.store, size: 50, color: AppColors.primary) : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 5, right: 5,
                            child: GestureDetector(
                              onTap: _pilihFotoProfil,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                                  border: Border.all(color: AppColors.accentLight.withOpacity(0.5))
                                ),
                                child: const Icon(Icons.camera_alt, color: AppColors.secondary, size: 18),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(namaToko, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Administrator', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // INFORMASI TOKO
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Informasi Toko', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                            IconButton(icon: const Icon(Icons.edit, color: AppColors.secondary, size: 20), onPressed: _editInfoToko),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.background),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.location_on, color: AppColors.primary)
                          ),
                          title: const Text('Alamat', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          subtitle: Text(alamatToko, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.phone, color: AppColors.primary)
                          ),
                          title: const Text('Kontak (WA)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          subtitle: Text(kontakToko, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // PENGATURAN AKUN
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [

                      ListTile(
                        leading: const Icon(Icons.local_offer_outlined, color: AppColors.secondary),
                        title: const Text('Manajemen Diskon', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        subtitle: const Text('Kelola diskon barang', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminManajemenDiskonScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.background),
                      ListTile(
                        leading: const Icon(Icons.bar_chart, color: AppColors.secondary),
                        title: const Text('Laporan & Rekapitulasi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        subtitle: const Text('Rekap pendapatan dan barang terlaris', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminLaporanScreen())),
                      ),
                      const Divider(height: 1, color: AppColors.background),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppColors.secondary),
                        title: const Text('Ganti Password', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: _gantiPassword,
                      ),
                      const Divider(height: 1, color: AppColors.background),
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: AppColors.secondary),
                        title: const Text('Pusat Bantuan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: _hubungiDeveloper,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // TOMBOL LOGOUT
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppColors.error.withOpacity(0.5))
                      ),
                      elevation: 0,
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }
}

// Painter border lingkaran panduan crop (Web)
class _AdminCircleBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
