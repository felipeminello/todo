import 'dart:typed_data';

import 'icon_generation_exception.dart';

/// Dimensions and transparency of a PNG, read from its chunks without decoding pixels.
class PngInfo {
  const PngInfo({
    required this.width,
    required this.height,
    required this.hasAlpha,
  });

  factory PngInfo.read(Uint8List bytes, {String source = 'PNG'}) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 33 ||
        !List.generate(8, (i) => bytes[i] == signature[i]).every((ok) => ok)) {
      throw IconGenerationException('$source não é um PNG válido.');
    }
    final data = ByteData.sublistView(bytes);
    // IHDR is always the first chunk: width, height, bit depth, colour type.
    final width = data.getUint32(16);
    final height = data.getUint32(20);
    final colorType = bytes[25];
    var hasAlpha = colorType == 4 || colorType == 6;

    // A tRNS chunk adds transparency to grey, RGB and palette images; it must precede IDAT.
    var offset = 8;
    while (!hasAlpha && offset + 8 <= bytes.length) {
      final length = data.getUint32(offset);
      final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
      if (type == 'tRNS') hasAlpha = true;
      if (type == 'IDAT') break;
      offset += 12 + length;
    }

    return PngInfo(width: width, height: height, hasAlpha: hasAlpha);
  }

  final int width;
  final int height;
  final bool hasAlpha;
}
