import 'package:intl/intl.dart';

class Formatters {
  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );
    return formatter.format(amount);
  }

  static String priceRange(double min, double max) {
    return '${currency(min)} – ${currency(max)}';
  }

  static String weight(double kg) {
    if (kg >= 100) {
      final qtl = kg / 100;
      return '${qtl.toStringAsFixed(1)} qtl (${kg.toStringAsFixed(0)} kg)';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}
