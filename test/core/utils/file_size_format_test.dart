import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/utils/file_size_format.dart';

void main() {
  String format(int bytes) => formatFileSize(bytes, locale: 'pt');

  test('bytes below 1 KB are shown whole', () {
    expect(format(0), '0 B');
    expect(format(1023), '1.023 B');
  });

  test('larger sizes use the biggest unit that fits', () {
    expect(format(1024), '1 KB');
    expect(format(1536), '1,5 KB');
    expect(format(25 * 1024 * 1024), '25 MB');
    expect(format(3 * 1024 * 1024 * 1024), '3 GB');
  });

  test('keeps one decimal at most, with the locale separator', () {
    expect(format(1289748), '1,2 MB');
    expect(formatFileSize(1289748, locale: 'en'), '1.2 MB');
  });

  test('sizes beyond GB stay in GB', () {
    expect(format(2048 * 1024 * 1024 * 1024), '2.048 GB');
  });
}
