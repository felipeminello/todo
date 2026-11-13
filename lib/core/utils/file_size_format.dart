import 'package:intl/intl.dart';

/// A file size for display, such as `512 B`, `1,5 KB` or `25 MB`, with the
/// decimal separator of [locale].
String formatFileSize(int bytes, {required String locale}) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${NumberFormat('#,##0.#', locale).format(value)} ${units[unit]}';
}
