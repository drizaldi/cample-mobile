import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// PASTIKAN IMPORT INI SESUAI DENGAN NAMA FOLDER & FILE ANDA
import 'user_beranda_screen.dart';
import 'user_pesanan_screen.dart';
import 'user_profil_screen.dart';
import 'user_katalog_screen.dart'; // Menggunakan Katalog yang sudah diperbaiki
import '../admin/chat_screen.dart'; // Import layar Chat
import 'user_keranjang_screen.dart'; // Kita akan buat file ini di Langkah 3
import '../../sesi_user.dart';
import '../login_screen.dart';

class UserMainScreen extends StatefulWidget {
  final int initialIndex;
  const UserMainScreen({super.key, this.initialIndex = 0});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  // Memasukkan UserKatalogScreen ke dalam tab agar Katalog yang benar muncul!
  List<Widget> get _pages => [
    UserBerandaScreen(
      onGoToKatalog: () {
        _onItemTapped(1); // Langsung pindah ke tab Katalog
      },
    ),
    const UserKatalogScreen(), // Tab indeks 1 sekarang berisi Katalog yang benar
    const UserPesananScreen(),
    const UserProfilScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
              Navigator.pop(context); // Tutup dialog
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())).then((val) {
                if (val == true && mounted) {
                  setState(() {}); // Refresh setelah sukses login
                }
              });
            },
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cample', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          // TOMBOL CHAT (SEKARANG SUDAH PINDAH HALAMAN)
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppColors.textPrimary),
            tooltip: 'Chat',
            onPressed: () {
              if (SesiUser.isGuest) {
                _tampilkanDialogLogin();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
              }
            },
          ),
          // TOMBOL KERANJANG (SEKARANG SUDAH PINDAH HALAMAN)
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
            tooltip: 'Keranjang',
            onPressed: () {
              if (SesiUser.isGuest) {
                _tampilkanDialogLogin();
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UserKeranjangScreen()));
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          currentIndex: _selectedIndex,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Katalog'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}