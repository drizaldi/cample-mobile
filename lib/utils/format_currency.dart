// lib/utils/format_currency.dart

String formatRupiah(dynamic number) {
  if (number == null) return '0';
  String numStr = number.toString();
  // Gunakan regex untuk menambahkan titik setiap 3 digit dari belakang
  RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String mathFunc(Match match) => '${match[1]}.';
  return numStr.replaceAllMapped(reg, mathFunc);
}
