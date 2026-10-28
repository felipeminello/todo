import 'dart:io';
import 'dart:typed_data';

import 'icon_generation_exception.dart';

/// Minimal 8-bit RGB/RGBA PNG codec, enough to crop Chrome screenshots.
class PngImage {
  PngImage(this.width, this.height, this.channels, this.pixels);

  /// Decodes the non-interlaced 8-bit RGB or RGBA PNGs that Chrome writes.
  factory PngImage.decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    late int width, height, channels;
    final idat = BytesBuilder(copy: false);
    var offset = 8;
    while (offset + 8 <= bytes.length) {
      final length = data.getUint32(offset);
      final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
      final body = Uint8List.sublistView(
        bytes,
        offset + 8,
        offset + 8 + length,
      );
      if (type == 'IHDR') {
        width = data.getUint32(offset + 8);
        height = data.getUint32(offset + 12);
        final bitDepth = body[8], colorType = body[9], interlace = body[12];
        if (bitDepth != 8 ||
            interlace != 0 ||
            (colorType != 2 && colorType != 6)) {
          throw const IconGenerationException(
            'Formato de PNG não suportado no recorte.',
          );
        }
        channels = colorType == 6 ? 4 : 3;
      } else if (type == 'IDAT') {
        idat.add(body);
      }
      offset += 12 + length;
    }

    final raw = Uint8List.fromList(zlib.decode(idat.takeBytes()));
    final stride = width * channels;
    final pixels = Uint8List(stride * height);
    var src = 0;
    for (var y = 0; y < height; y++) {
      final filter = raw[src++];
      final row = y * stride;
      for (var x = 0; x < stride; x++) {
        final left = x >= channels ? pixels[row + x - channels] : 0;
        final up = y > 0 ? pixels[row - stride + x] : 0;
        final upLeft = (x >= channels && y > 0)
            ? pixels[row - stride + x - channels]
            : 0;
        final predictor = switch (filter) {
          0 => 0,
          1 => left,
          2 => up,
          3 => (left + up) >> 1,
          4 => _paeth(left, up, upLeft),
          _ => throw const IconGenerationException('Filtro de PNG inválido.'),
        };
        pixels[row + x] = (raw[src++] + predictor) & 0xFF;
      }
    }
    return PngImage(width, height, channels, pixels);
  }

  final int width;
  final int height;

  /// 3 for RGB, 4 for RGBA.
  final int channels;
  final Uint8List pixels;

  bool get isOpaque {
    if (channels == 3) return true;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 0xFF) return false;
    }
    return true;
  }

  /// The top-left [w] x [h] region.
  PngImage cropTopLeft(int w, int h) {
    final stride = w * channels;
    final out = Uint8List(stride * h);
    for (var y = 0; y < h; y++) {
      final from = y * width * channels;
      out.setRange(y * stride, (y + 1) * stride, pixels, from);
    }
    return PngImage(w, h, channels, out);
  }

  /// Drops the alpha channel; only meaningful when [isOpaque].
  PngImage withoutAlpha() {
    if (channels == 3) return this;
    final out = Uint8List(width * height * 3);
    for (var i = 0, j = 0; i < pixels.length; i += 4, j += 3) {
      out[j] = pixels[i];
      out[j + 1] = pixels[i + 1];
      out[j + 2] = pixels[i + 2];
    }
    return PngImage(width, height, 3, out);
  }

  /// Encodes with filter 0 and a fixed zlib level, so equal pixels give equal bytes.
  Uint8List encode() {
    final stride = width * channels;
    final raw = Uint8List((stride + 1) * height);
    for (var y = 0; y < height; y++) {
      raw.setRange(
        y * (stride + 1) + 1,
        (y + 1) * (stride + 1),
        pixels,
        y * stride,
      );
    }
    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8)
      ..setUint8(9, channels == 4 ? 6 : 2);
    return (BytesBuilder(copy: false)
          ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
          ..add(_chunk('IHDR', header.buffer.asUint8List()))
          ..add(_chunk('IDAT', ZLibCodec(level: 9).encode(raw)))
          ..add(_chunk('IEND', const [])))
        .takeBytes();
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    return pb <= pc ? b : c;
  }

  static Uint8List _chunk(String type, List<int> body) {
    final typeBytes = type.codeUnits;
    final out = ByteData(12 + body.length)..setUint32(0, body.length);
    final bytes = out.buffer.asUint8List()
      ..setRange(4, 8, typeBytes)
      ..setRange(8, 8 + body.length, body);
    out.setUint32(8 + body.length, _crc32(bytes, 4, 8 + body.length));
    return bytes;
  }

  static final _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(Uint8List bytes, int start, int end) {
    var crc = 0xFFFFFFFF;
    for (var i = start; i < end; i++) {
      crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }
}
