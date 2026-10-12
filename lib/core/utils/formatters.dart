import 'package:intl/intl.dart';

class Formatters {
  static String currency(double value) {
    return NumberFormat.currency(locale: 'ar', symbol: 'ر.س').format(value);
  }

  static String date(DateTime value) {
    return DateFormat('yyyy/MM/dd').format(value);
  }
}
