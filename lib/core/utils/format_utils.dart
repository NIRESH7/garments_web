import 'package:intl/intl.dart';

class FormatUtils {
  static String formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dt;
      if (date is DateTime) {
        dt = date;
      } else if (date is String) {
        dt = DateTime.parse(date);
      } else {
        return 'N/A';
      }
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (e) {
      return 'N/A';
    }
  }

  static String formatWeight(dynamic value) {
    if (value == null) return '0.00';
    try {
      if (value is num) {
        return value.toStringAsFixed(2);
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed.toStringAsFixed(2);
        }
      }
      return value.toString();
    } catch (e) {
      return '0.00';
    }
  }

  static String formatQuantity(dynamic value) {
    if (value == null) return '0';
    try {
      if (value is int) {
        return value.toString();
      }
      if (value is double) {
        return value.round().toString();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed.round().toString();
        }
      }
      return value.toString();
    } catch (e) {
      return '0';
    }
  }

  static String formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    try {
      if (value is num) {
        return value.toStringAsFixed(2);
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed.toStringAsFixed(2);
        }
      }
      return value.toString();
    } catch (e) {
      return '0.00';
    }
  }
}
