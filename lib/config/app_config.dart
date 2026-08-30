import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl {
    // Membaca URL dari file .env
    String? envUrl = dotenv.env['API_BASE_URL'];
    
    if (envUrl == null || envUrl.isEmpty) {
      throw Exception('API_BASE_URL tidak ditemukan di file .env! Pastikan file .env sudah ada dan berisi konfigurasi yang benar.');
    }
    
    return envUrl;
  }
}
