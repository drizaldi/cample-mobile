import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// PASTIKAN IMPORT INI SESUAI DENGAN FOLDER ANDA
import 'screens/login_screen.dart';
import 'screens/admin/admin_main_screen.dart';
import 'screens/user/user_main_screen.dart';
import 'sesi_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Wajib ada
  await dotenv.load(fileName: ".env"); // Load konfigurasi env
  await SesiUser.muatSesi(); // Membaca data yang tersimpan sebelum render layar
  runApp(const MyApp());
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cek apakah user sudah pernah login sebelumnya
    Widget layarAwal = const UserMainScreen(); // Mode Guest secara default

    if (SesiUser.idUser != null) {
      if (SesiUser.role == 'admin') {
        layarAwal = const AdminMainScreen();
      }
    }

    return MaterialApp(
      title: 'Cample',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(), // <-- Supaya bisa digeser pakai mouse di Chrome
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: layarAwal, // Akan langsung masuk ke Beranda jika sesi masih ada
    );
  }
}
