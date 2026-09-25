import 'dart:math';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class LogoPalette {
  final Color navy;
  final Color sky;
  final Color orange;
  final Color background;
  final Color text;
  final bool hasLogo;

  const LogoPalette({
    required this.navy,
    required this.sky,
    required this.orange,
    required this.background,
    required this.text,
    required this.hasLogo,
  });

  static const fallback = LogoPalette(
    navy: Color(0xFF0B3A6A),
    sky: Color(0xFF3FA9F5),
    orange: Color(0xFFF28C28),
    background: Color(0xFFF7F8FA),
    text: Color(0xFF102033),
    hasLogo: false,
  );

  static Future<LogoPalette> load() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) { return fallback; }
      return paletteFromImage(decoded);
    } catch (_) {
      return fallback;
    }
  }
}

LogoPalette paletteFromImage(img.Image source) {
  var blueCount = 0;
  var orangeCount = 0;
  var darkL = 2.0;
  var lightL = -1.0;
  var darkRgb = 0xFF0B3A6A;
  var lightRgb = 0xFF3FA9F5;
  var orangeR = 0;
  var orangeG = 0;
  var orangeB = 0;
  final stepX = max(1, source.width ~/ 48);
  final stepY = max(1, source.height ~/ 48);
  for (var y = 0; y < source.height; y += stepY) {
    for (var x = 0; x < source.width; x += stepX) {
      final pixel = source.getPixel(x, y);
      final alpha = pixel.a.toInt();
      if (alpha < 128) { continue; }
      final red = pixel.r.round().clamp(0, 255);
      final green = pixel.g.round().clamp(0, 255);
      final blue = pixel.b.round().clamp(0, 255);
      final maxC = max(red, max(green, blue)) / 255;
      final minC = min(red, min(green, blue)) / 255;
      final light = (maxC + minC) / 2;
      final delta = maxC - minC;
      if (delta < 0.08) { continue; }
      final sat = delta / (1 - (2 * light - 1).abs());
      final hue = _hue(red / 255, green / 255, blue / 255, maxC, delta);
      final packed = 0xFF000000 | (red << 16) | (green << 8) | blue;
      if (hue >= 190 && hue <= 255 && sat > 0.25) {
        blueCount += 1;
        if (light < darkL) {
          darkL = light;
          darkRgb = packed;
        }
        if (light > lightL) {
          lightL = light;
          lightRgb = packed;
        }
      }
      if (hue >= 10 && hue <= 50 && sat > 0.4) {
        orangeCount += 1;
        orangeR += red;
        orangeG += green;
        orangeB += blue;
      }
    }
  }
  final navy = blueCount == 0 ? LogoPalette.fallback.navy : Color(darkRgb);
  final sky = blueCount == 0 ? LogoPalette.fallback.sky : Color(lightRgb);
  final orange = orangeCount == 0
      ? LogoPalette.fallback.orange
      : Color(0xFF000000 | ((orangeR ~/ orangeCount) << 16) | ((orangeG ~/ orangeCount) << 8) | (orangeB ~/ orangeCount));
  return LogoPalette(
    navy: navy,
    sky: sky,
    orange: orange,
    background: const Color(0xFFF7F8FA),
    text: navy,
    hasLogo: true,
  );
}

double _hue(double red, double green, double blue, double maxC, double delta) {
  if (delta == 0) { return 0; }
  double hue;
  if (maxC == red) {
    hue = ((green - blue) / delta) % 6;
  } else if (maxC == green) {
    hue = ((blue - red) / delta) + 2;
  } else {
    hue = ((red - green) / delta) + 4;
  }
  hue *= 60;
  if (hue < 0) { hue += 360; }
  return hue;
}
