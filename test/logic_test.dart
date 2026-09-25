import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_vision/src/detect/coco_labels.dart';
import 'package:smart_vision/src/detect/frame_check.dart';
import 'package:smart_vision/src/detect/yolo_decoder.dart';
import 'package:smart_vision/src/format/arabic_date.dart';
import 'package:smart_vision/src/theme/logo_palette.dart';
import 'package:smart_vision/src/prefs/app_prefs.dart';
import 'package:smart_vision/src/screens/help_screen.dart';
import 'package:smart_vision/src/voice/voice_intent.dart';

void main() {
  test('date uses latin digits and 12 hour marks', () {
    expect(formatArabicDate(DateTime(2026, 1, 3, 5, 50)), '\u20662026/1/3م 5:50ص\u2069');
    expect(formatArabicDate(DateTime(2026, 1, 3, 12, 0)), '\u20662026/1/3م 12:00م\u2069');
    expect(formatArabicDate(DateTime(2026, 1, 3, 0, 5)), '\u20662026/1/3م 12:05ص\u2069');
    expect(formatArabicDate(DateTime(2026, 9, 25, 13, 5)), '\u20662026/9/25م 1:05م\u2069');
  });

  testWidgets('date line is one text', (tester) async {
    const text = '\u20662026/1/3م 5:50ص\u2069';
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Text(text)),
      ),
    ));
    expect(find.text(text), findsOneWidget);
  });

  test('voice commands stay on known intents', () {
    expect(matchIntent('صف المشهد'), 'describe');
    expect(matchIntent('صف ما أمامي'), 'describe');
    expect(matchIntent('اقرأ النص'), 'read');
    expect(matchIntent('ما هذا الشيء'), 'describe');
    expect(matchIntent('ساعدني'), 'help');
    expect(matchIntent('ما الأوامر المتاحة'), 'help');
    expect(matchIntent('الإعدادات'), 'settings');
    expect(matchIntent('عن التطبيق'), 'about');
    expect(matchIntent('مرحبا'), isNull);
    expect(matchIntent(''), isNull);
    expect(matchIntent('ا' * 201), isNull);
    expect(voiceHelpScript(), contains('صف ما أمامي'));
  });

  test('obstacle sensitivity tightens as it rises', () {
    expect(obstacleAreaLimit('high') < obstacleAreaLimit('medium'), isTrue);
    expect(obstacleAreaLimit('medium') < obstacleAreaLimit('low'), isTrue);
    expect(speechRateWords(0.32), 'بطيئة');
    expect(speechRateWords(0.45), 'متوسطة');
    expect(speechRateWords(0.65), 'سريعة');
  });

  testWidgets('help lists voice commands', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HelpScreen(palette: LogoPalette.fallback, onSpeak: (_) async {}),
      ),
    ));
    expect(find.textContaining('صف ما أمامي'), findsOneWidget);
    expect(find.text('استمع للمساعدة'), findsOneWidget);
    expect(find.text('الأوامر والمساعدة'), findsOneWidget);
  });

  test('jpeg check rejects other bytes', () {
    expect(isJpeg(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00])), isTrue);
    expect(isJpeg(Uint8List.fromList([0x89, 0x50, 0x4E])), isFalse);
  });

  test('coco labels cover eighty classes', () {
    expect(cocoLabelsAr.length, 80);
    expect(cocoLabelsAr.first, 'شخص');
    expect(cocoLabelsAr[2], 'سيارة');
  });

  test('decoder keeps a close person', () {
    final data = List<double>.filled(6, 0);
    data[0] = 10;
    data[1] = 10;
    data[2] = 200;
    data[3] = 200;
    data[4] = 0.91;
    data[5] = 0;
    final found = decodeYolo(data, const [1, 1, 6], inputSize: 320);
    expect(found, hasLength(1));
    expect(found.first.label, 'شخص');
    expect(found.first.area, greaterThan(0.2));
  });

  test('palette reads blue and orange from pixels', () {
    final source = img.Image(width: 16, height: 8, numChannels: 3);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        source.setPixelRgb(x, y, 11, 58, 106);
      }
      for (var x = 8; x < 12; x++) {
        source.setPixelRgb(x, y, 80, 180, 240);
      }
      for (var x = 12; x < 16; x++) {
        source.setPixelRgb(x, y, 242, 140, 40);
      }
    }
    final palette = paletteFromImage(source);
    expect(palette.hasLogo, isTrue);
    expect(palette.navy.toARGB32(), 0xFF0B3A6A);
    expect((palette.orange.toARGB32() >> 16) & 255, greaterThan(180));
  });
}
