import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Format FCFA amount: 5000 → "5 000 FCFA"
  static String fcfa(num amount) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return '${formatter.format(amount)} FCFA';
  }

  /// Format phone: 0701020304 → "07 01 02 03 04"
  static String phone(String number) {
    final cleaned = number.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} '
          '${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} '
          '${cleaned.substring(8, 10)}';
    }
    return number;
  }

  /// Format distance: 1.5 → "1.5 km"
  static String distance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Format date: relative or absolute
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format rating: 4.5 → "4.5"
  static String rating(double value) {
    return value.toStringAsFixed(1);
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
