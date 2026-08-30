import 'package:apk_cample166/config/app_config.dart';
// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'package:apk_cample166/my_http.dart' as http;
import 'dart:convert';

import '../../sesi_user.dart';

class ChatScreen extends StatefulWidget {
  final String? targetIdUser; // Akan diisi jika Admin yang buka
  final String? namaLawanBicara; // Akan diisi jika Admin yang buka

  const ChatScreen({super.key, this.targetIdUser, this.namaLawanBicara});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _pesanController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> daftarPesan = [];
  Timer? _timer;
  bool _isLoading = true;
  String _pesanError = '';
  String _labelOnline = 'Memuat...'; // Status last seen lawan bicara
  String? _urlFotoLawanBicara;

  String get baseUrl => AppConfig.baseUrl;

  String get _idChatRoom {
    if (SesiUser.role == 'admin') {
      return widget.targetIdUser ?? '';
    } else {
      return SesiUser.idUser ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    _ambilPesan();
    _ambilStatusOnline();
    // Refresh pesan setiap 3 detik, refresh status online setiap 30 detik
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer t) {
      _ambilPesanPenyegaran();
      // Refresh status online setiap 10 iterasi (30 detik)
      if (t.tick % 10 == 0) _ambilStatusOnline();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pesanController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Ambil status online lawan bicara dari server
  Future<void> _ambilStatusOnline() async {
    try {
      if (SesiUser.role == 'admin') {
        // Admin melihat status user (dari endpoint daftar user)
        if (_idChatRoom.isEmpty) return;
        final response = await http.get(Uri.parse('$baseUrl/admin/users'));
        if (response.statusCode == 200) {
          final List<dynamic> users = jsonDecode(response.body);
          final user = users.firstWhere(
            (u) => u['id'].toString() == _idChatRoom,
            orElse: () => null,
          );
          if (user != null && mounted) {
            setState(() {
              _labelOnline = user['label_online'] ?? 'Tidak diketahui';
              _urlFotoLawanBicara = user['foto_profil'];
            });
          }
        }
      } else {
        // User melihat status admin — ambil dari infoToko
        final response = await http.get(Uri.parse('$baseUrl/admin/info'));
        if (response.statusCode == 200) {
          final admin = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _labelOnline = admin['label_online'] ?? 'Offline';
              _urlFotoLawanBicara = admin['foto_profil'];
            });
          }
        }
      }
    } catch (e) {
      print('Gagal ambil status online: $e');
    }
  }

  // Hitung label "Online", "X menit lalu", "X jam lalu", dll.
  String _hitungLastSeen(String updatedAtStr) {
    try {
      final lastSeen = DateTime.parse(updatedAtStr).toLocal();
      final diff = DateTime.now().difference(lastSeen);
      final menit = diff.inMinutes;
      final jam = diff.inHours;
      final hari = diff.inDays;
      if (menit < 2) return 'Online';
      if (menit < 60) return '$menit menit lalu';
      if (jam < 24) return '$jam jam lalu';
      return '$hari hari lalu';
    } catch (_) {
      return 'Tidak diketahui';
    }
  }

  Future<void> _ambilPesan() async {
    if (_idChatRoom.isEmpty) {
      setState(() {
        _isLoading = false;
        _pesanError = 'Sesi User tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/pesan/$_idChatRoom'));

      if (response.statusCode == 200) {
        setState(() {
          daftarPesan = jsonDecode(response.body);
          _isLoading = false;
          _pesanError = '';
        });
        _scrollKeBawah();
      } else {
        setState(() {
          _isLoading = false;
          _pesanError = 'Gagal memuat pesan (Kode: ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pesanError = 'Terjadi kesalahan jaringan atau API tidak merespons.';
      });
    }
  }

  Future<void> _ambilPesanPenyegaran() async {
    if (_idChatRoom.isEmpty || _pesanError.isNotEmpty) return;
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/pesan/$_idChatRoom'));
      if (response.statusCode == 200) {
        final dataBaru = jsonDecode(response.body);
        if (dataBaru.length != daftarPesan.length) {
          setState(() => daftarPesan = dataBaru);
          _scrollKeBawah();
        }
      }
    } catch (e) {}
  }

  Future<void> _kirimPesan() async {
    String teksPesan = _pesanController.text.trim();
    if (teksPesan.isEmpty || _idChatRoom.isEmpty) return;

    _pesanController.clear();
    String pengirimSaatIni = SesiUser.role == 'admin' ? 'admin' : 'user';

    setState(() {
      daftarPesan.add({
        'pengirim': pengirimSaatIni,
        'pesan': teksPesan,
      });
    });
    _scrollKeBawah();

    try {
      await http.post(
        Uri.parse('$baseUrl/chat/kirim'),
        body: {
          'id_user': _idChatRoom,
          'pengirim': pengirimSaatIni,
          'pesan': teksPesan,
        }
      );
    } catch (e) {
      print("Gagal kirim pesan: $e");
    }
  }

  void _scrollKeBawah() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Warna dot status online
  Color _warnaStatusOnline(String label) {
    if (label == 'Online') return AppColors.success;
    return AppColors.textSecondary;
  }

  Widget _buildIsiPesanOtomatis(String pesanTeks) {
    bool isMurniTautanGambar = pesanTeks.trim().startsWith('http') &&
        (pesanTeks.trim().endsWith('.jpg') ||
            pesanTeks.trim().endsWith('.png') ||
            pesanTeks.trim().endsWith('.jpeg'));

    if (isMurniTautanGambar) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          pesanTeks.trim(),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
          },
        ),
      );
    }

    List<String> barisTeks = pesanTeks.split('\n');
    List<Widget> komponenPesan = [];

    for (var baris in barisTeks) {
      String barisBersih = baris.trim();
      if (barisBersih.startsWith('http://') || barisBersih.startsWith('https://')) {
        komponenPesan.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                barisBersih,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Text(baris, style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        );
      } else {
        komponenPesan.add(
          Text(baris, style: const TextStyle(fontSize: 14, height: 1.3)),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: komponenPesan,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = SesiUser.role == 'admin';
    String namaHeader = isAdmin ? (widget.namaLawanBicara ?? 'Pelanggan') : 'Cample Admin';
    IconData iconHeader = isAdmin ? Icons.person : Icons.support_agent;
    Color warnaStatus = _warnaStatusOnline(_labelOnline);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.secondary.withOpacity(0.1),
              backgroundImage: (_urlFotoLawanBicara != null && _urlFotoLawanBicara!.isNotEmpty) ? NetworkImage(_urlFotoLawanBicara!) : null,
              child: (_urlFotoLawanBicara == null || _urlFotoLawanBicara!.isEmpty) ? Icon(iconHeader, color: AppColors.secondary) : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(namaHeader,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: warnaStatus,
                        shape: BoxShape.circle,
                        boxShadow: warnaStatus == AppColors.success ? [BoxShadow(color: AppColors.success.withOpacity(0.4), blurRadius: 4)] : null
                      ),
                    ),
                    Text(
                      _labelOnline,
                      style: TextStyle(color: warnaStatus, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pesanError.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 50),
                            const SizedBox(height: 10),
                            Text(_pesanError,
                                style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _pesanError = '';
                                });
                                _ambilPesan();
                              },
                              child: const Text('Coba Lagi'),
                            )
                          ],
                        ),
                      )
                    : daftarPesan.isEmpty
                        ? const Center(
                            child: Text(
                                'Belum ada pesan. Silakan mulai percakapan.',
                                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: daftarPesan.length,
                            itemBuilder: (context, index) {
                              final chat = daftarPesan[index];
                              bool isMe = chat['pengirim'] == SesiUser.role;

                              if (chat['tipe_pesan'] == 'kartu_pesanan') {
                                return const SizedBox.shrink();
                              }

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.80),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isMe
                                          ? const Radius.circular(16)
                                          : const Radius.circular(4),
                                      bottomRight: isMe
                                          ? const Radius.circular(4)
                                          : const Radius.circular(16),
                                    ),
                                    boxShadow: [
                                      if (!isMe) BoxShadow(
                                          color: AppColors.primary.withOpacity(0.05),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w500),
                                    child: _buildIsiPesanOtomatis(
                                        chat['pesan'] ?? ''),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          if (_pesanError.isEmpty || _pesanError.contains('Gagal memuat'))
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pesanController,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                      ),
                      onSubmitted: (value) => _kirimPesan(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle
                    ),
                    child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _kirimPesan),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
