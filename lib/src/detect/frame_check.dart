import 'dart:typed_data';

bool isJpeg(Uint8List bytes) { return bytes.length >= 3 && bytes.length <= 7 * 1024 * 1024 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF; }
