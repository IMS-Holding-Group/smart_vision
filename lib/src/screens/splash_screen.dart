import 'dart:async';

import 'package:flutter/material.dart';

import '../app_session.dart';
import '../prefs/app_prefs.dart';
import '../services/firebase_boot.dart';
import '../services/speech_service.dart';
import '../services/yolo_service.dart';
import '../theme/logo_palette.dart';
import '../theme/sv_button.dart';

class SplashScreen extends StatefulWidget {
  final LogoPalette palette;
  final void Function(AppSession session) onReady;

  const SplashScreen({super.key, required this.palette, required this.onReady});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final yolo = YoloService();
    final speech = SpeechService();
    final prefs = await AppPrefs.load();
    try {
      await speech.warmup(rate: prefs.speechRate);
    } catch (_) {}
    var firebaseReady = false;
    String? uid;
    final pending = <Future<void>>[
      () async {
        firebaseReady = await startFirebase();
        if (firebaseReady) { uid = await signInAnonymous(); }
      }(),
      () async { await yolo.load(); }(),
    ];
    try {
      await Future.wait(pending).timeout(const Duration(seconds: 6));
    } catch (_) {}
    final notes = <String>[];
    if (!yolo.isReady) { notes.add('تعذر تحميل نموذج الكشف'); }
    if (!firebaseReady) {
      notes.add('تعذر الاتصال');
    } else if (uid == null) {
      notes.add('تعذر تسجيل الدخول');
    }
    if (notes.isNotEmpty) {
      try {
        await speech.speak('${notes.join('. ')}. ستستمر الوظائف المتاحة').timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    if (!mounted) {
      yolo.close();
      await speech.dispose();
      return;
    }
    widget.onReady(AppSession(
      speech: speech,
      yolo: yolo,
      prefs: prefs,
      firebaseReady: firebaseReady,
      uid: uid,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: Semantics(
          label: 'جار تجهيز التطبيق',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (palette.hasLogo)
                Image.asset('assets/images/logo.png', width: 160, height: 160, semanticLabel: 'شعار الرؤية الذكية'),
              if (palette.hasLogo) const SizedBox(height: 16),
              Text('الرؤية الذكية', style: svText(palette, size: 32, weight: FontWeight.w700, color: palette.navy)),
              const SizedBox(height: 24),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: palette.navy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
