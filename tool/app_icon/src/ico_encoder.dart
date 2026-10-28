import 'dart:typed_data';

import 'icon_generation_exception.dart';
import 'png_info.dart';

/// Packs square PNG images into one .ico file, each entry stored as PNG.
///
/// PNG-compressed entries are valid in every size since Windows Vista, which
/// lets each size carry its own artwork instead of a downscale of one image.
Uint8List encodeIco(List<Uint8List> pngImages) {
  const headerSize = 6;
  const entrySize = 16;

  final infos = [for (final png in pngImages) PngInfo.read(png)];
  for (final info in infos) {
    if (info.width != info.height || info.width > 256) {
      throw IconGenerationException(
        'Entrada de .ico inválida: ${info.width}x${info.height}. '
        'Use imagens quadradas de até 256 px.',
      );
    }
  }

  final builder = BytesBuilder(copy: false);
  final header = ByteData(headerSize)
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // type: icon
    ..setUint16(4, pngImages.length, Endian.little);
  builder.add(header.buffer.asUint8List());

  var offset = headerSize + entrySize * pngImages.length;
  for (var i = 0; i < pngImages.length; i++) {
    final size = infos[i].width;
    final entry = ByteData(entrySize)
      // 0 means 256 in the one-byte width and height fields.
      ..setUint8(0, size == 256 ? 0 : size)
      ..setUint8(1, size == 256 ? 0 : size)
      ..setUint8(2, 0) // palette size
      ..setUint8(3, 0) // reserved
      ..setUint16(4, 1, Endian.little) // colour planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, pngImages[i].length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    builder.add(entry.buffer.asUint8List());
    offset += pngImages[i].length;
  }

  for (final png in pngImages) {
    builder.add(png);
  }
  return builder.takeBytes();
}
