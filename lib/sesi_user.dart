import 'package:shared_preferences/shared_preferences.dart';

class SesiUser {
  static String? idUser;
  static String? namaUser;
  static String? email;
  static String? role;
  static String? fotoProfil;
  static String? token;

  static bool get isGuest => idUser == null;

  // 1. Fungsi Simpan Sesi ke storage yang kompatibel dengan semua platform (Web, Android, iOS)
  static Future<void> simpanSesi({
    required String id,
    required String nama,
    required String mail,
    required String hakAkses,
    String? foto,
    String? authToken
  }) async {
    idUser = id;
    namaUser = nama;
    email = mail;
    role = hakAkses;
    fotoProfil = foto;
    token = authToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idUser', id);
    await prefs.setString('namaUser', nama);
    await prefs.setString('email', mail);
    await prefs.setString('role', hakAkses);
    if (foto != null) await prefs.setString('fotoProfil', foto);
    if (authToken != null) await prefs.setString('token', authToken);
  }

  // 2. Muat Sesi (Membaca data saat aplikasi baru dibuka/refresh)
  static Future<void> muatSesi() async {
    final prefs = await SharedPreferences.getInstance();
    idUser = prefs.getString('idUser');
    namaUser = prefs.getString('namaUser');
    email = prefs.getString('email');
    role = prefs.getString('role');
    fotoProfil = prefs.getString('fotoProfil');
    token = prefs.getString('token');
  }

  // 3. Hapus Sesi (Logout)
  static Future<void> hapusSesi() async {
    idUser = null;
    namaUser = null;
    email = null;
    role = null;
    fotoProfil = null;
    token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Menghapus semua data yang tersimpan
  }
}