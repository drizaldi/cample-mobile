import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // untuk kIsWeb
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../sesi_user.dart';
import '../login_screen.dart';
import 'user_main_screen.dart';

class UserProfilScreen extends StatefulWidget {
  const UserProfilScreen({super.key});

  @override
  State<UserProfilScreen> createState() => _UserProfilScreenState();
}

class _UserProfilScreenState extends State<UserProfilScreen> {
  int totalSewa = 0;
  int totalKeranjang = 0;
  bool _isLoading = true;

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // --- State untuk Web Crop (metode Vigenesia) ---
  bool _isCropping = false;
  Uint8List? _rawImage;   // bytes asli sebelum crop
  static const double _cropSize = 280.0;
  final _cropKey = GlobalKey();
  final _transformCtrl = TransformationController();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _ambilDataStats();
  }

  // Sinkronisasi data ke penyimpanan lokal (SharedPreferences)
  Future<void> _updateSesiLokal(String? urlFoto, String? nama, String? email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (urlFoto != null) {
      await prefs.setString('fotoProfil', urlFoto);
      SesiUser.fotoProfil = urlFoto;
    }
    if (nama != null) {
      await prefs.setString('namaUser', nama);
      SesiUser.namaUser = nama;
    }
    if (email != null) {
      await prefs.setString('email', email);
      SesiUser.email = email;
    }
  }

  Future<void> _ambilDataStats() async {
    if (SesiUser.idUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/stats'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalSewa = data['total_sewa'];
          totalKeranjang = data['total_keranjang'];
        });

        await _updateSesiLokal(
          data['user']['foto_profil'], 
          data['user']['nama'], 
          data['user']['email']
        );
        // Rebuild agar foto profil terbaru tampil di CircleAvatar
        if (mounted) setState(() {});
      }
    } catch (e) {
      print("Error Stats: $e");
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
      if (byteData != null && mounted) {
        final croppedBytes = byteData.buffer.asUint8List();
        setState(() {
          _imageBytes = croppedBytes;
          _isCropping = false;
        });
        // Langsung upload setelah crop dikonfirmasi
        _uploadProfil(SesiUser.namaUser ?? '', SesiUser.email ?? '');
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
                      child: CustomPaint(painter: _CircleBorderPainter()),
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

  Future<void> _pilihFoto() async {
    if (SesiUser.isGuest) {
      _showLoginDialog();
      return;
    }
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    if (kIsWeb) {
      // WEB: Tampilkan halaman crop custom (metode Vigenesia)
      final bytes = await pickedFile.readAsBytes();
      _transformCtrl.value = Matrix4.identity();
      setState(() {
        _pickedImage = pickedFile;
        _rawImage = bytes;
        _isCropping = true;
      });
    } else {
      // MOBILE (Android/iOS): Gunakan image_cropper native
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Foto Profil',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Potong Foto Profil',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (croppedFile == null) return; // user batal crop
      final bytes = await XFile(croppedFile.path).readAsBytes();
      setState(() {
        _pickedImage = XFile(croppedFile.path);
        _imageBytes = bytes;
      });
      _uploadProfil(SesiUser.namaUser ?? '', SesiUser.email ?? '');
    }
  }

  Future<void> _uploadProfil(String namaBaru, String emailBaru) async {
    if (SesiUser.idUser == null) return;
    setState(() => _isLoading = true);
    
    try {
      // FIX: Route baru tidak pakai ID di URL, backend ambil dari token
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/user/update-profil'));
      request.fields['nama'] = namaBaru;
      request.fields['email'] = emailBaru;

      if (_pickedImage != null && _imageBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'foto_profil', 
          _imageBytes!,
          filename: _pickedImage!.name,
        ));
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var data = jsonDecode(responseData.body);
        
        await _updateSesiLokal(
          data['user']['foto_profil'], 
          data['user']['nama'], 
          data['user']['email']
        );

        // FIX: setState menyeluruh agar nama/email di layar ikut ter-refresh
        setState(() {
          _imageBytes = null;
          _pickedImage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil diperbarui!'), backgroundColor: AppColors.success));
      } else {
        final errData = await http.Response.fromStream(response);
        print("Error upload: ${errData.body}");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan profil!'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      print("Error Update: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
    }
    setState(() => _isLoading = false);
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perlu Login', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Silakan login terlebih dahulu untuk menggunakan fitur ini.'),
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
                  setState(() {
                    _ambilDataStats();
                  });
                }
              });
            },
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProfilDialog() {
    if (SesiUser.isGuest) {
      _showLoginDialog();
      return;
    }
    TextEditingController namaCtrl = TextEditingController(text: SesiUser.namaUser);
    TextEditingController emailCtrl = TextEditingController(text: SesiUser.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profil', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: namaCtrl, decoration: InputDecoration(labelText: 'Nama Lengkap', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
            const SizedBox(height: 16),
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          Container(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              onPressed: () {
                Navigator.pop(context);
                _uploadProfil(namaCtrl.text, emailCtrl.text);
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showGantiPasswordDialog() {
    if (SesiUser.isGuest) {
      _showLoginDialog();
      return;
    }
    TextEditingController pwdLamaCtrl = TextEditingController();
    TextEditingController pwdBaruCtrl = TextEditingController();
    TextEditingController pwdKonfirmasiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isLoading = false;
            return AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Ganti Password', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: pwdLamaCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Password Lama', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
                  const SizedBox(height: 16),
                  TextField(controller: pwdBaruCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Password Baru', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
                  const SizedBox(height: 16),
                  TextField(controller: pwdKonfirmasiCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Konfirmasi Password Baru', labelStyle: const TextStyle(color: AppColors.textSecondary), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentLight)))),
                ],
              ),
              actions: [
                TextButton(
                  // ignore: dead_code
                  onPressed: isLoading ? null : () => Navigator.pop(context), 
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))
                ),
                Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    // ignore: dead_code
                    onPressed: isLoading ? null : () async {
                      if (pwdLamaCtrl.text.isEmpty || pwdBaruCtrl.text.isEmpty || pwdKonfirmasiCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi semua field!'), backgroundColor: AppColors.error));
                        return;
                      }
                      if (pwdBaruCtrl.text != pwdKonfirmasiCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru tidak cocok!'), backgroundColor: AppColors.error));
                        return;
                      }

                      setStateDialog(() => isLoading = true);
                      
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
                        setStateDialog(() => isLoading = false);
                        
                        if (response.statusCode == 200) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diubah!'), backgroundColor: AppColors.success));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['pesan'] ?? 'Gagal ganti password'), backgroundColor: AppColors.error));
                        }
                      } catch (e) {
                        setStateDialog(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan koneksi!'), backgroundColor: AppColors.error));
                      }
                    },
                    child: isLoading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _hubungiAdmin() async {
    // Format: 628xxx (kode negara tanpa +, tanpa angka 0 di depan)
    // Nomor ini bisa diubah langsung di sini: lib/screens/user/user_profil_screen.dart
    const String noWA = "6285750091480";
    const String pesan = "Halo Admin Cample, saya butuh bantuan terkait aplikasi.";
    final Uri url = Uri.parse("https://wa.me/$noWA?text=${Uri.encodeComponent(pesan)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp!')));
    }
  }

  // --- FUNGSI TAMPILKAN INFORMASI TOKO (GAYA ADMIN) ---
  Future<void> _showInformasiToko() async {
    // Tampilkan loading sebentar jika perlu
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Kita gunakan endpoint '/profil' agar datanya persis seperti di Admin!
      final response = await http.get(Uri.parse('$baseUrl/profil'));
      
      // Tutup loading
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final toko = jsonDecode(response.body);
        
        // Ambil data dari JSON
        String namaToko = toko['nama_toko'] ?? 'Cample Store Official';
        String alamat = toko['alamat'] ?? '-';
        String kontak = toko['kontak'] ?? '-';
        String? urlFoto = toko['url_foto']; // Akan mengambil foto Bapak Jokowi

        // Tampilkan Dialog dengan desain yang cantik
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FOTO PROFIL ADMIN
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.secondary.withOpacity(0.2),
                    backgroundImage: urlFoto != null ? NetworkImage(urlFoto) : null,
                    child: urlFoto == null ? const Icon(Icons.storefront, size: 40, color: AppColors.primary) : null,
                  ),
                  const SizedBox(height: 15),
                  
                  // NAMA TOKO & ROLE
                  Text(namaToko, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text('Administrator', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 25),

                  // CARD INFORMASI DETAIL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100], // Warna background abu-abu muda seperti di gambar 2
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on, color: Colors.grey, size: 28),
                          title: const Text('Alamat', style: TextStyle(fontSize: 13, color: Colors.black54)),
                          subtitle: Text(alamat, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                        ),
                        const Divider(height: 0),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone, color: Colors.grey, size: 28),
                          title: const Text('Kontak (WA)', style: TextStyle(fontSize: 13, color: Colors.black54)),
                          subtitle: Text(kontak, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // TOMBOL TUTUP
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengambil data toko.')));
      }
    } catch (e) {
      Navigator.pop(context); // Tutup loading jika error
      print("Error ambil info toko: $e");
    }
  }

  void _logout() async {
    await SesiUser.hapusSesi(); 
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (context) => const UserMainScreen(initialIndex: 3)), 
      (route) => false
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
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _ambilDataStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageBytes != null 
                              ? MemoryImage(_imageBytes!) as ImageProvider
                              : (SesiUser.fotoProfil != null ? NetworkImage(SesiUser.fotoProfil!) : null),
                          child: _imageBytes == null && SesiUser.fotoProfil == null 
                              ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _pilihFoto, 
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(SesiUser.isGuest ? 'Guest' : (SesiUser.namaUser ?? 'Nama User'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(SesiUser.isGuest ? 'Silakan login untuk mengakses semua fitur' : (SesiUser.email ?? ''), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Total Sewa', totalSewa.toString()),
                      Container(width: 1, height: 40, color: AppColors.accentLight.withOpacity(0.5)),
                      _buildStatItem('Keranjang', totalKeranjang.toString()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildMenuTile(Icons.person_outline, 'Edit Profil', 'Ubah Nama & Email', _showEditProfilDialog),
                  _buildMenuTile(Icons.storefront_outlined, 'Informasi Toko', 'Detail kontak admin toko', _showInformasiToko),
                  _buildMenuTile(Icons.lock_outline, 'Ganti Password', 'Amankan akun anda', _showGantiPasswordDialog),
                  _buildMenuTile(Icons.help_outline, 'Pusat Bantuan', 'Hubungi admin via WhatsApp', _hubungiAdmin),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SesiUser.isGuest
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((val) {
                                if (val == true && mounted) {
                                  setState(() => _ambilDataStats());
                                }
                              });
                            },
                            child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: AppColors.error),
                            label: const Text('Tombol Keluar', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentLight.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient, 
            borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.secondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// Painter border lingkaran panduan crop (Web)
class _CircleBorderPainter extends CustomPainter {
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
