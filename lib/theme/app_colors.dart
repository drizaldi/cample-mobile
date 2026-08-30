import 'package:flutter/material.dart';

class AppColors {
  // Tema Asli Aplikasi: Aksentuasi Hijau & Latar Bersih
  static const Color primary = Colors.green; // Hijau Asli
  static const Color secondary = Colors.green; // Sama rata dengan primary
  static const Color accent = Colors.green; // Sama rata
  static const Color accentLight = Colors.green; // Sama rata
  
  static const Color background = Colors.white; // Putih Murni
  static const Color surface = Colors.white; // Putih Murni
  
  static const Color textPrimary = Colors.black87; // Hitam Standar
  static const Color textSecondary = Colors.black54; // Abu-abu gelap standar

  // Dikembalikan ke Merah Standar untuk fitur bahaya (hapus keranjang / stok habis)
  static const Color error = Colors.red; 
  
  static const Color success = Colors.green; // Hijau
  
  // Status (disewa, belum lunas, dp) diseragamkan dengan warna utama (Hijau)
  static const Color warning = Colors.green; 

  // Gradien Ditiadakan (menggunakan warna solid hijau di kedua titik)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.green, Colors.green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Colors.green, Colors.green], 
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
